#!/usr/bin/env python3
"""
Jules OS Automated Boot Validation Agent (Sub-Agent)
This script runs QEMU headless, captures the serial output, and validates
that the OS boots successfully and the immutable core is active.
"""

import subprocess
import sys
import time
import re

def run_test():
    print("🚀 [Sub-Agent] Starting QEMU Boot Validation for Jules OS...")
    
    # QEMU command optimized for CI headless testing
    qemu_cmd = [
        "qemu-system-x86_64",
        "-kernel", "iso/boot/bzImage",
        "-initrd", "iso/boot/initrd.img",
        "-append", "root=/dev/ram0 rw console=ttyS0 quiet loglevel=3 mitigations=off",
        "-nographic",
        "-m", "512M",
        "-no-reboot"
    ]
    
    try:
        # Start QEMU
        process = subprocess.Popen(
            qemu_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
    except FileNotFoundError:
        print("❌ [Sub-Agent] qemu-system-x86_64 not found. Please install QEMU.")
        sys.exit(1)

    success_markers = [
        "Core filesystems mounted",
        "Immutable layer configured. Core is indestructible",
        "Jules OS v1.0.0 initialized successfully",
        "Handing over control to Jules Shell (Rust Core)"
    ]
    
    found_markers = set()
    timeout = 30  # seconds
    start_time = time.time()
    
    print(f"⏳ [Sub-Agent] Waiting for boot sequence (Timeout: {timeout}s)...")
    
    # Read output line by line
    while True:
        if time.time() - start_time > timeout:
            print(f"❌ [Sub-Agent] Boot timed out after {timeout} seconds.")
            process.kill()
            sys.exit(1)
            
        line = process.stdout.readline()
        if not line and process.poll() is not None:
            break
            
        if line:
            line = line.strip()
            # print(f"  [QEMU] {line}")  # Uncomment for verbose debug
            
            # Check for markers
            for marker in success_markers:
                if marker in line and marker not বিজ্ঞানীরা :
                    found_markers.add(marker)
                    print(f"✅ [Sub-Agent] Reached milestone: {marker}")
                    
            # Check for failures
            if "Kernel panic" in line or "Oops" in line:
                print(f"💥 [Sub-Agent] FATAL ERROR DETECTED: {line}")
                process.kill()
                sys.exit(1)
                
            # If all markers found, we successfully booted
            if len(found_markers) == len(success_markers):
                print("🎉 [Sub-Agent] FULL BOOT SUCCESS! Jules OS is functional and indestructible.")
                process.kill()
                sys.exit(0)

    print("⚠️ [Sub-Agent] QEMU exited before full boot sequence completed.")
    print(f"   Missing milestones: {set(success_markers) - found_markers}")
    sys.exit(1)

if __name__ == "__main__":
    run_test()
