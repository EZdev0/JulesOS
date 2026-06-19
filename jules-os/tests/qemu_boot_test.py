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

import argparse

def run_test():
    parser = argparse.ArgumentParser(description="Jules OS QEMU Boot Validation")
    parser.add_argument("--arch", default="x86_64", help="Target architecture to test")
    parser.add_argument("--universal", action="store_true", help="Test the Universal ISO via CDROM")
    args = parser.parse_args()

    print(f"🚀 [Sub-Agent] Starting QEMU Boot Validation for Jules OS ({args.arch})...")
    
    # Configure architecture-specific QEMU arguments
    if args.arch == "aarch64" or args.arch == "arm64":
        qemu_bin = "qemu-system-aarch64"
        machine_args = ["-machine", "virt", "-cpu", "max"]
        console_dev = "ttyAMA0"
    elif args.arch == "x86" or args.arch == "i386" or args.arch == "i686":
        qemu_bin = "qemu-system-i386"
        machine_args = []
        console_dev = "ttyS0"
    else:
        qemu_bin = "qemu-system-x86_64"
        machine_args = []
        console_dev = "ttyS0"
        
    if args.universal:
        qemu_cmd = [
            qemu_bin,
        ] + machine_args + [
            "-cdrom", "JulesOS-Universal.iso",
            "-nographic",
            "-m", "1024M",
            "-no-reboot"
        ]
    else:
        qemu_cmd = [
            qemu_bin,
        ] + machine_args + [
            "-kernel", "iso/boot/bzImage",
            "-initrd", "iso/boot/initrd.img",
            "-append", f"console={console_dev} quiet loglevel=3 mitigations=off",
            "-nographic",
            "-m", "1024M",
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
        print(f"❌ [Sub-Agent] {qemu_bin} not found. Please install QEMU for {args.arch}.")
        sys.exit(1)

    success_markers = [
        "Core filesystems mounted",
        "Immutable layer configured. Core is indestructible",
        "Jules OS v1.0.0 initialized successfully",
        "Handing over control to Jules Shell (Rust Core)"
    ]
    
    found_markers = set()
    timeout = 90  # seconds
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
                if marker in line and marker not in found_markers:
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
