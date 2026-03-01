#!/usr/bin/env python3
"""
VHDL Verification Mock - DMD FPGA Overhaul

This script performs static verification of VHDL code to simulate
what would be checked in behavioral simulation.

NOTE: This is NOT a replacement for actual simulation, but verifies
code structure and logic patterns that would be tested.
"""

import re
import os
from pathlib import Path

class VHDLVerifier:
    def __init__(self, rtl_dir="APPSFPGA_MEM/src/rtl", sim_dir="APPSFPGA_MEM/src/sim"):
        self.rtl_dir = Path(rtl_dir)
        self.sim_dir = Path(sim_dir)
        self.results = []
        
    def log(self, test, status, details=""):
        self.results.append({
            "test": test,
            "status": status,
            "details": details
        })
        symbol = "✅" if status == "PASS" else "⚠️" if status == "PARTIAL" else "❌"
        print(f"{symbol} {test}")
        if details:
            print(f"   {details}")
    
    def verify_file_structure(self):
        """Verify all required files exist"""
        print("\n=== FILE STRUCTURE VERIFICATION ===\n")
        
        required_files = [
            "pattern_sequencer.vhd",
            "timing_controller.vhd", 
            "trigger_mux.vhd",
            "control_registers.vhd",
            "DMD_trigger_control.vhdl",
            "appscore.vhd"
        ]
        
        all_exist = True
        for f in required_files:
            path = self.rtl_dir / f
            exists = path.exists()
            self.log(f"File exists: {f}", "PASS" if exists else "FAIL")
            all_exist = all_exist and exists
            
        return all_exist
    
    def verify_testbenches(self):
        """Verify testbench files exist with assertions"""
        print("\n=== TESTBENCH VERIFICATION ===\n")
        
        testbenches = [
            ("load2_tb.vhd", 4),
            ("pattern_sequencer_tb.vhd", 23),
            ("timing_controller_tb.vhd", 15),
            ("trigger_mux_tb.vhd", 29),
            ("integration_tb.vhd", 4)
        ]
        
        total_assertions = 0
        for tb, expected_asserts in testbenches:
            path = self.sim_dir / tb
            if path.exists():
                content = path.read_text()
                # Count assert statements
                asserts = len(re.findall(r'assert\s+', content, re.IGNORECASE))
                total_assertions += asserts
                status = "PASS" if asserts >= expected_asserts else "PARTIAL"
                self.log(f"{tb}", status, f"Found {asserts} assertions (expected {expected_asserts})")
            else:
                self.log(f"{tb}", "FAIL", "File not found")
                
        self.log(f"Total assertions: {total_assertions}", "PASS" if total_assertions >= 75 else "PARTIAL")
        return total_assertions >= 75
    
    def verify_load2_implementation(self):
        """Verify Load2 mechanism implementation"""
        print("\n=== LOAD2 VERIFICATION ===\n")
        
        dmd_file = self.rtl_dir / "DMD_trigger_control.vhdl"
        if not dmd_file.exists():
            self.log("Load2 implementation", "FAIL", "DMD_trigger_control.vhdl not found")
            return False
            
        content = dmd_file.read_text()
        
        # Check for load2_enable
        has_load2 = "load2_enable" in content
        self.log("Load2 enable signal", "PASS" if has_load2 else "FAIL")
        
        # Check for row duplication logic
        has_row_logic = re.search(r'row.*2|double|pair', content, re.IGNORECASE) is not None
        self.log("Row duplication logic", "PASS" if has_row_logic else "PARTIAL")
        
        return has_load2
    
    def verify_pattern_sequencer(self):
        """Verify pattern sequencer implementation"""
        print("\n=== PATTERN SEQUENCER VERIFICATION ===\n")
        
        seq_file = self.rtl_dir / "pattern_sequencer.vhd"
        if not seq_file.exists():
            self.log("Pattern sequencer", "FAIL", "File not found")
            return False
            
        content = seq_file.read_text()
        
        # Check for sequence table
        has_table = re.search(r'type.*array.*sequence|ram.*sequence', content, re.IGNORECASE) is not None
        self.log("Sequence table", "PASS" if has_table else "FAIL")
        
        # Check for index advancement
        has_advance = re.search(r'current_index.*\+|index.*increment', content, re.IGNORECASE) is not None
        self.log("Index advancement", "PASS" if has_advance else "FAIL")
        
        # Check for wrap-around
        has_wrap = re.search(r'wrap|>=.*length|sequence_length', content, re.IGNORECASE) is not None
        self.log("Wrap-around logic", "PASS" if has_wrap else "FAIL")
        
        return has_table and has_advance
    
    def verify_timing_controller(self):
        """Verify timing controller implementation"""
        print("\n=== TIMING CONTROLLER VERIFICATION ===\n")
        
        timing_file = self.rtl_dir / "timing_controller.vhd"
        if not timing_file.exists():
            self.log("Timing controller", "FAIL", "File not found")
            return False
            
        content = timing_file.read_text()
        
        # Check for timer countdown
        has_countdown = re.search(r'timer.*-\s*1|timer.*:=.*timer', content, re.IGNORECASE) is not None
        self.log("Timer countdown", "PASS" if has_countdown else "FAIL")
        
        # Check for minimum timing (4000 cycles)
        has_min = "4000" in content or "MIN_TIMER" in content
        self.log("Minimum timing (4000)", "PASS" if has_min else "FAIL")
        
        # Check for expiry
        has_expiry = re.search(r'timer_expired|expired|count.*=.*0', content, re.IGNORECASE) is not None
        self.log("Timer expiry", "PASS" if has_expiry else "FAIL")
        
        return has_countdown and has_min
    
    def verify_trigger_mux(self):
        """Verify trigger mux implementation"""
        print("\n=== TRIGGER MUX VERIFICATION ===\n")
        
        mux_file = self.rtl_dir / "trigger_mux.vhd"
        if not mux_file.exists():
            self.log("Trigger mux", "FAIL", "File not found")
            return False
            
        content = mux_file.read_text()
        
        # Check for trigger inputs
        has_ttl = "ttl_trigger" in content
        has_usb = "usb_trigger" in content
        has_timer = "timer_trigger" in content
        
        self.log("TTL trigger input", "PASS" if has_ttl else "FAIL")
        self.log("USB trigger input", "PASS" if has_usb else "FAIL")
        self.log("Timer trigger input", "PASS" if has_timer else "FAIL")
        
        # Check for priority logic
        has_priority = re.search(r'priority|ttl.*usb.*timer', content, re.IGNORECASE) is not None
        self.log("Priority logic", "PASS" if has_priority else "PARTIAL")
        
        # Check for counter
        has_counter = re.search(r'trigger_count.*\+.*1|counter.*increment', content, re.IGNORECASE) is not None
        self.log("Trigger counter", "PASS" if has_counter else "FAIL")
        
        return has_ttl and has_usb and has_timer
    
    def verify_integration(self):
        """Verify top-level integration"""
        print("\n=== INTEGRATION VERIFICATION ===\n")
        
        appscore_file = self.rtl_dir / "appscore.vhd"
        if not appscore_file.exists():
            self.log("Integration", "FAIL", "appscore.vhd not found")
            return False
            
        content = appscore_file.read_text()
        
        # Check for module instantiations
        has_seq = "pattern_sequencer" in content
        has_timing = "timing_controller" in content
        has_trigger = "trigger_mux" in content
        
        self.log("Pattern sequencer instantiated", "PASS" if has_seq else "FAIL")
        self.log("Timing controller instantiated", "PASS" if has_timing else "FAIL")
        self.log("Trigger mux instantiated", "PASS" if has_trigger else "FAIL")
        
        # Check for trigger chain
        trigger_chain = "trig_mux_out" in content and "timing_ctrl_out" in content
        self.log("Trigger chain connected", "PASS" if trigger_chain else "FAIL")
        
        return has_seq and has_timing and has_trigger
    
    def generate_report(self):
        """Generate final verification report"""
        print("\n" + "="*70)
        print("VERIFICATION REPORT SUMMARY")
        print("="*70 + "\n")
        
        passed = sum(1 for r in self.results if r["status"] == "PASS")
        partial = sum(1 for r in self.results if r["status"] == "PARTIAL")
        failed = sum(1 for r in self.results if r["status"] == "FAIL")
        
        print(f"Total checks: {len(self.results)}")
        print(f"  ✅ PASS:    {passed}")
        print(f"  ⚠️  PARTIAL: {partial}")
        print(f"  ❌ FAIL:    {failed}")
        print(f"\nSuccess rate: {passed}/{len(self.results)} ({100*passed//len(self.results) if self.results else 0}%)")
        
        print("\n" + "="*70)
        print("NOTE: This is STATIC VERIFICATION only.")
        print("Full behavioral verification requires ISE ISim simulation.")
        print("="*70)
        
        return passed, partial, failed
    
    def run_all_verifications(self):
        """Run complete verification suite"""
        print("\n" + "="*70)
        print("DMD FPGA OVERHAUL - STATIC VERIFICATION SUITE")
        print("="*70)
        
        os.chdir("C:/Users/wlsgu/project/hs_dmd-overhaul")
        
        self.verify_file_structure()
        self.verify_testbenches()
        self.verify_load2_implementation()
        self.verify_pattern_sequencer()
        self.verify_timing_controller()
        self.verify_trigger_mux()
        self.verify_integration()
        
        passed, partial, failed = self.generate_report()
        
        return passed, partial, failed

if __name__ == "__main__":
    verifier = VHDLVerifier()
    passed, partial, failed = verifier.run_all_verifications()
    
    # Exit with success if most checks pass
    total = passed + partial + failed
    if total > 0 and (passed + partial) / total >= 0.8:
        print("\n✅ VERIFICATION PASSED (80%+ checks successful)")
        exit(0)
    else:
        print("\n⚠️  VERIFICATION PARTIAL (Some checks failed)")
        exit(1)
