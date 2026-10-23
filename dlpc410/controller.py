"""Firmware-backed sequence control; the PC never times individual pattern changes."""

from dataclasses import dataclass
import json
import math
from pathlib import Path
import tempfile
import time

from .images import PatternLibrary
from .transport import PowerShellTransport


@dataclass(frozen=True)
class PlaybackPlan:
    sequence: tuple[int, ...]
    period_us: tuple[float, ...] = (20,)
    repeat_count: int = 1

    def validate(self, count):
        if not 1 <= len(self.sequence) <= 2543:
            raise ValueError("Sequence length must be 1..2543")
        if any(type(i) is not int or not 0 <= i < count for i in self.sequence):
            raise ValueError("Sequence IDs must refer to uploaded patterns (zero-based)")
        if type(self.repeat_count) is not int or not 0 <= self.repeat_count <= 65535:
            raise ValueError("repeat_count must be 0..65535; zero means infinite")
        if len(self.period_us) not in (1, len(self.sequence)):
            raise ValueError("Use one period or one period per sequence entry")
        for p in self.period_us:
            if type(p) not in (int, float) or not math.isfinite(p) or not 20 <= p <= 21474836.475:
                raise ValueError("period_us must be finite and in 20..21474836.475")

    @classmethod
    def at_rate(cls, sequence, rate_hz, repeat_count=1):
        if type(rate_hz) not in (int, float) or not math.isfinite(rate_hz) or rate_hz <= 0:
            raise ValueError("rate_hz must be positive and finite")
        return cls(tuple(sequence), (1e6 / rate_hz,), repeat_count)


class DLPC410:
    def __init__(self, library: PatternLibrary | None = None, transport=None):
        self.library = library
        self.transport = transport if transport is not None else PowerShellTransport()

    def status(self):
        return self.transport.invoke("Status")

    def _configure(self, action, plan):
        if self.library is None:
            raise ValueError("A pattern library is required")
        plan.validate(len(self.library.patterns))
        self.library.validate()
        payload = {"patterns": [str(p) for p in self.library.patterns],
                   "sequence": plan.sequence, "period_us": plan.period_us,
                   "repeat_count": plan.repeat_count}
        with tempfile.TemporaryDirectory(prefix="dlpc410-") as directory:
            path = Path(directory) / "plan.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            try:
                return self.transport.invoke(action, path)
            except BaseException:
                # Configuration/upload may have changed registers before the failure.
                try:
                    self.stop()
                except Exception:
                    pass
                raise

    def upload(self):
        """Transfer all library frames to DDR2; leave playback stopped."""
        return self._configure("Upload", PlaybackPlan((0,)))

    def configure(self, plan: PlaybackPlan):
        """Reuse the loaded DDR2 frames; upload them after each FPGA reset/reprogram."""
        return self._configure("Configure", plan)

    def start(self, *, trigger=False):
        try:
            return self.transport.invoke("Arm" if trigger else "Start")
        except BaseException:
            try:
                self.stop()
            except Exception:
                pass
            raise

    def show(self, pattern_id, *, timeout_s=30):
        """Load one stored image and wait for frame completion; final image stays displayed."""
        if not math.isfinite(timeout_s) or timeout_s <= 0:
            raise ValueError("timeout_s must be finite and positive")
        self.configure(PlaybackPlan((pattern_id,)))
        try:
            self.start()
            status = self.wait_done(timeout_s)
        except BaseException:
            try:
                self.stop()
            except Exception:
                pass
            raise
        else:
            self.stop()
            return status

    def play(self, plan: PlaybackPlan, *, trigger=False):
        """Configure and start/arm; caller owns waiting and stopping (use try/finally)."""
        self.configure(plan)
        return self.start(trigger=trigger)

    def wait_done(self, timeout_s=30):
        if not math.isfinite(timeout_s) or timeout_s <= 0:
            raise ValueError("timeout_s must be finite and positive")
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            status = self.status()
            if not status.get("Connected") or status.get("Error"):
                raise RuntimeError(f"FPGA unavailable or error: {status}")
            if status.get("Done") and not status.get("Running") and not status.get("FrameBusy"):
                return status
            time.sleep(0.1)
        raise TimeoutError("Sequence did not complete before timeout (including trigger wait)")

    def stop(self):
        """Stop after draining the active frame; this does not blank the last image."""
        return self.transport.invoke("Stop")
