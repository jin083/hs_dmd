# Decisions — dmd-fpga-overhaul

## [2026-03-01] Session ses_358573838ffe770I0py8xc3zTU — Setup

### Wave 1 tasks (parallel: T1, T2, T3)
- T1 cleanup uses `quick` category — file ops only
- T2 docs uses `writing` category — technical writing
- T3 sim infra uses `quick` category — small utility file creation

### Register addresses allocated
- 0x29: USB_PATTERN_SWITCH
- 0x2A-0x2E: Pattern sequencer registers
- 0x2F-0x32: Timing controller registers
- 0x33-0x34: Trigger mux registers
- Load2 enable bit in existing register 0x0016 (bit 6)
