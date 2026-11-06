# D202 review reproducer — 2026-10-28

This bundle reproduces four boundary defects in the unchanged D202 RTL. `DONE` means the probes finished, not that the design passed. `review_result.json` and `simulation.log` record the observed defects.

The bench seeds two verified directory entries and uses a one-cycle synthetic FIFO. It does not exercise actual DDR2, USB, DMD optics, or JTAG. The three RTL copies match the released D202 source hashes. No production file or existing bitstream was changed.

In the existing Linux ISE VM, run `bash /path/to/this/folder/run.sh`. The script loads ISE 14.7, copies inputs into a temporary guest directory, and returns compile/simulation logs. It performs no device calls. Logs regenerated at another path may differ in file paths and timestamps.

The full Korean review is in `docs/reports/D202_REVIEW_2026-10-28.md` in the repository.
