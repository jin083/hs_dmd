# Learnings — dmd-fpga-overhaul

## [2026-03-01] Session ses_358573838ffe770I0py8xc3zTU — Setup

### Worktree
- Branch: `feat/dmd-fpga-overhaul`
- Path: `C:\Users\wlsgu\project\hs_dmd-overhaul`
- Base commit: 1f91eb4

### VHDL conventions (from AGENTS.md)
- snake_case signals, `_q` suffix for registered, `_a` suffix for architecture
- Entity/Arch separation: `*_e.vhd` (entity), `*_a.vhd` (architecture) — TI convention
- Active-low signals: `*z` suffix (e.g., `load4z`, `arstz`)
- Port directions: `_i` input, `_o` output in appsfpga_e.vhd IO pins

### Critical anti-patterns
- NEVER edit files in `ipcore_dir/` — regenerate via CoreGen if changes needed
- NEVER modify the ~30 unchanged TI reference files
- NEVER modify `MEM_IO.vhd` memory addressing
- NEVER use `ROW_MD="01"` (auto-increment) for Load2 — must use `ROW_MD="10"` (random)
- NEVER set pattern timing < 20µs (4000 cycles at 200MHz)

### Clock domains
- `ifclk` 48 MHz: USB (USB_IO)
- `mem_clk0` 150 MHz: DDR2 (MEM_IO, MIG)
- `clk_g` / `system_clk` 200 MHz: System (appscore, registers, trigger_control)
- DDR output 400 MHz: DMD (appsfpga_io, OSERDES)
- CDC via async FIFOs: FIFO_RCV2 (USB→MEM), read_fifo (MEM→SYS), mem_read_enable_fifo (SYS→MEM)

### Key facts about Load2
- Load2 DOES NOT improve speed — it INCREASES load time per frame (2x row cycles)
- Load2 HALVES memory per pattern (doubles storage capacity)
- Must use ROW_MD="10" (random addressing), NOT auto-increment
