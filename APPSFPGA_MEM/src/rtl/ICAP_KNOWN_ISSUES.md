# ICAP USB Programming - Known Issues

**Date:** 2026-03-02
**Status:** Implementation complete, requires verification before synthesis

## Overview
USB FPGA programming via ICAP has been implemented. The following issues were identified during code review and should be addressed before synthesis.

## Critical Issues

### 1. Clock Domain Crossing (CDC) - MEDIUM RISK
**Location:** USB_IO.vhd → appscore.vhd

**Problem:**
- USB_IO operates in `clk_180_u` (180MHz from USB PLL)
- icap_controller operates in `clk_g` (200MHz system clock)
- Signals crossing clock domains without synchronization:
  - `icap_data_out` (32-bit)
  - `icap_data_valid` (1-bit)
  - `icap_program_start` (1-bit)

**Impact:** Metastability, data corruption, intermittent failures

**Fix Required:** Add 2-stage synchronizers for all signals crossing from USB_IO to appscore:
```vhdl
-- In appscore.vhd, add synchronizers
signal icap_data_valid_sync : std_logic_vector(1 downto 0);
signal icap_program_start_sync : std_logic_vector(1 downto 0);

process(clk_g)
begin
    if rising_edge(clk_g) then
        icap_data_valid_sync <= icap_data_valid_sync(0) & icap_usb_data_valid;
        icap_program_start_sync <= icap_program_start_sync(0) & icap_usb_program_start;
    end if;
end process;

icap_data_valid_delayed <= icap_data_valid_sync(1);
```

**Status:** ✅ FIXED (2026-03-02)
- Added 2-stage synchronizers in appscore.vhd
- Added data latch for 32-bit icap_usb_data
- icap_data_valid_synced and icap_program_start_synced now used in ICAP_CTRL_INST

### 2. No FIFO Reset on Programming Mode Entry - LOW RISK
**Location:** USB_IO.vhd, line ~605

**Problem:** When entering programming mode, existing data in FIFOs is not cleared.

**Impact:** Stale data may be sent to ICAP

**Fix Required:** Clear relevant FIFOs when `icap_programming_mode` transitions to '1'

### 3. Register 0xFE End Condition Missing Address Check - HIGH RISK
**Location:** USB_IO.vhd, line 610

**Problem:**
```vhdl
elsif register_data_buffer_if(0) = '0' and icap_programming_mode = '1' then
    icap_programming_mode <= '0';
```
Missing `register_address_buffer_if = x"FE"` check. Any register write with bit 0 = 0 will end programming mode.

**Impact:** Programming mode may be accidentally terminated by other register writes

elsif register_write_enable = '1' and register_address_buffer_if = x"FE" and
      register_data_buffer_if(0) = '0' and icap_programming_mode = '1' then
```

**Status:** ✅ FIXED (2026-03-02)

### 4. Byte Order Complexity - LOW RISK
**Location:** USB_IO.vhd data path

**Problem:**
1. USB GPIF: bytes already swapped (`gpif_from_port(7:0) & gpif_from_port(15:8)`)
2. ICAP expects: MSB first
3. Current assembly: `icap_data_buffer_hi & icap_data_buffer_lo`

**Impact:** Bitstream may be byte-reversed

**Verification Required:** Test with actual bitstream to confirm byte order

### 5. ICAP CSB Disables Between Writes - MEDIUM RISK
**Location:** icap_controller.vhd, lines 187-196

**Problem:**
```vhdl
when PROGRAMMING =>
    if usb_data_valid = '1' then
        icap_csb <= '0';
    else
        icap_csb <= '1';  -- Disables ICAP between writes!
    end if;
```
Virtex-5 ICAP requires continuous write cycles. Disabling CSB between USB data causes write interruption.

**Impact:** Data corruption during programming

**Fix Required:** Keep CSB low throughout programming phase:
when PROGRAMMING =>
    icap_csb <= '0';  -- Always active
    if usb_data_valid = '1' then
        icap_i <= usb_data;
    end if;
```

**Status:** ✅ FIXED (2026-03-02)

## Minor Issues

### 4. No Timeout in icap_controller
**Location:** icap_controller.vhd

**Problem:** SYNC_WAIT state has no timeout

**Impact:** FPGA hangs if sync word not received

### 5. No Error Reporting to Host
**Problem:** `program_error` signal not communicated back to host

**Impact:** Host cannot detect programming failure

## Host Software Notes

### Python program_fpga() Protocol
1. Write 0x0001 to register 0xFE → Start programming mode
2. Send bitstream via bulk EP2 transfer
3. Write 0x0000 to register 0xFE → End programming mode

### Bitstream Requirements
- Must start with sync word 0xAA995566 (Virtex-5 format)
- May require byte-swapping (verify with actual hardware)
- Header may need to be removed (per icap_controller.vhd comments)

## Testing Recommendations

1. **Before Synthesis:**
   - Add CDC synchronizers
   - Simulate with GHDL

2. **After Synthesis:**
   - Test with JTAG backup ready
   - Use simple test bitstream first
   - Verify byte order with loopback test

3. **Production Use:**
   - Add timeout handling
   - Add error reporting to host
   - Add verification readback

## Files Modified

| File | Changes |
|------|---------|
| `USB_IO.vhd` | Added ICAP interface ports, register 0xFE handler, 16→32 bit assembly |
| `appscore.vhd` | Added icap_controller component/instantiation, signal routing |
| `appsfpga_load4_a.vhd` | Updated appscore component/instantiation with ICAP ports |
| `icap_controller.vhd` | (existing) ICAP primitive interface |
| `usb_backend_pyu.py` | Modified program_fpga() to use register 0xFE |

## Rollback Plan

If ICAP programming fails and FPGA becomes unresponsive:
1. Use JTAG to program known-good bitstream
2. Disable ICAP feature by not using program_fpga()
3. Use `D4100_GUI_FPGA.bin` with TI DLL for USB programming
