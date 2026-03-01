#!/bin/bash
# GHDL Compilation Script for DMD FPGA Overhaul
# Compiles all VHDL files and runs testbenches

export PATH="$PATH:/c/Users/wlsgu/AppData/Local/Microsoft/WinGet/Packages/ghdl.ghdl.ucrt64.mcode_Microsoft.Winget.Source_8wekyb3d8bbwe/bin"

GHDL="ghdl"
FLAGS="--std=08 -fsynopsys -fexplicit"
RTL_DIR="src/rtl"
SIM_DIR="src/sim"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          GHDL Compilation & Simulation Script              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf work
mkdir -p work
cd work

echo ""
echo "=== Phase 1: Compiling Design Files ==="
echo ""

# Compile packages first
$GHDL -a $FLAGS ../$RTL_DIR/appsfpga_dmd_types_pkg.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ appsfpga_dmd_types_pkg.vhd"
$GHDL -a $FLAGS ../$RTL_DIR/appsfpga_clk_pkg.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ appsfpga_clk_pkg.vhd"

# Compile basic components
$GHDL -a $FLAGS ../$RTL_DIR/counter_4096.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ counter_4096.vhd"
$GHDL -a $FLAGS ../$RTL_DIR/fifo_30x512.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ fifo_30x512.vhd"

# Compile control registers
$GHDL -a $FLAGS ../$RTL_DIR/control_registers.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ control_registers.vhd"

# Compile DMD trigger control
$GHDL -a $FLAGS ../$RTL_DIR/DMD_trigger_control.vhdl 2>&1 | grep -E "error|warning" || echo "  ✅ DMD_trigger_control.vhdl"

# Compile new modules
$GHDL -a $FLAGS ../$RTL_DIR/pattern_sequencer.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ pattern_sequencer.vhd"
$GHDL -a $FLAGS ../$RTL_DIR/timing_controller.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ timing_controller.vhd"
$GHDL -a $FLAGS ../$RTL_DIR/trigger_mux.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ trigger_mux.vhd"

echo ""
echo "=== Phase 2: Compiling Testbenches ==="
echo ""

# Compile testbenches
$GHDL -a $FLAGS ../$SIM_DIR/trigger_mux_tb.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ trigger_mux_tb.vhd"
$GHDL -a $FLAGS ../$SIM_DIR/timing_controller_tb.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ timing_controller_tb.vhd"
$GHDL -a $FLAGS ../$SIM_DIR/pattern_sequencer_tb.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ pattern_sequencer_tb.vhd"
$GHDL -a $FLAGS ../$SIM_DIR/load2_tb.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ load2_tb.vhd"
$GHDL -a $FLAGS ../$SIM_DIR/integration_tb.vhd 2>&1 | grep -E "error|warning" || echo "  ✅ integration_tb.vhd"

echo ""
echo "=== Phase 3: Running Simulations ==="
echo ""

# Run simulations
echo "Running trigger_mux_tb..."
$GHDL -e $FLAGS trigger_mux_tb 2>&1 | grep -E "error" || echo "  ✅ Elaborated"
$GHDL -r $FLAGS trigger_mux_tb --wave=trigger_mux.ghw 2>&1 | tail -20

echo ""
echo "Running timing_controller_tb..."
$GHDL -e $FLAGS timing_controller_tb 2>&1 | grep -E "error" || echo "  ✅ Elaborated"
$GHDL -r $FLAGS timing_controller_tb --wave=timing_controller.ghw 2>&1 | tail -20

echo ""
echo "Running pattern_sequencer_tb..."
$GHDL -e $FLAGS pattern_sequencer_tb 2>&1 | grep -E "error" || echo "  ✅ Elaborated"
$GHDL -r $FLAGS pattern_sequencer_tb --wave=pattern_sequencer.ghw 2>&1 | tail -20

echo ""
echo "Running load2_tb..."
$GHDL -e $FLAGS load2_tb 2>&1 | grep -E "error" || echo "  ✅ Elaborated"
$GHDL -r $FLAGS load2_tb --wave=load2.ghw 2>&1 | tail -20

echo ""
echo "Running integration_tb..."
$GHDL -e $FLAGS integration_tb 2>&1 | grep -E "error" || echo "  ✅ Elaborated"
$GHDL -r $FLAGS integration_tb --wave=integration.ghw 2>&1 | tail -20

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    COMPILATION COMPLETE                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
