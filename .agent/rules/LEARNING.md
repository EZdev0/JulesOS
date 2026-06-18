# 🧠 JulesOS: Agent Learning & Error Log

**Priority:** HIGH | **Last Update:** 2026-06-18
This file documents all encountered bugs, Kernel Panics, and build crashes in JulesOS, along with their root causes and verified solutions. Read this file BEFORE making core changes to PID 1 or the CI build pipeline!

---

## 1. Kernel Panic: "Attempted to kill init!" (Exitcode 0x00000100)
**Symptom:** When booting the ISO in QEMU (or Limbo), the system crashed immediately after loading the Immutable Layer or when launching `jules_shell`.
**Root Cause 1 (`set -e`):** The `/init` script (`scripts/init.sh`) utilized `set -e`. When non-essential hardware detection commands (e.g., in the `mdev` or `modalias` loops) failed under Alpine, the script aborted. Since `/init` exited, Linux immediately triggered a panic.
**Fix 1:** **NEVER** use `set -e` in `/init`! It has been permanently changed to `set +e`.
**Root Cause 2 (Headless TTY EOF):** `jules_shell` (in `src/main.rs`) exited via `break` in headless mode whenever standard input was closed (EOF) or a `flush()` error occurred. Since `jules_shell` acts as PID 1, terminating the `main()` function triggered a Kernel Panic.
**Fix 2:** Removed every `break` and `std::process::exit` from the PID 1 scope. Instead, the shell now gracefully switches to `loop { std::thread::sleep(Duration::from_secs(60)); }` to keep the kernel alive and signal handlers active even when terminal input is lost.

## 2. Windows Docker Desktop Crash: "EOF error during connect"
**Symptom:** Running `test_local.ps1` caused the Docker daemon on Windows to crash entirely.
**Root Cause:** Volume mounts (`-v ${PWD}:/build`) between Windows PowerShell and WSL2 Linux containers often provoke engine crashes during intensive I/O operations (like compiling an OS).
**Fix:** Avoid volume mounts in local Windows test scripts. Use `COPY . /build/` inside the `Dockerfile` and retrieve the generated `.iso` afterwards using `docker cp` to safely extract it to the host.

## 3. Rust Compile Error: "could not find `utsname` in `sys`"
**Symptom:** In newer versions of the `nix` crate (v0.29.0), compilation failed in `system.rs` because the `utsname` module was either hidden or required specific feature flags.
**Fix:** Avoid external C-Bindings (`nix`) for fundamental syscalls when ProcFS is available. `get_kernel_release()` now natively reads `/proc/sys/kernel/osrelease`, making it extremely performant and completely immune to future crate breaking changes.

## 4. ISO Not Bootable ("Not bootable" / "No Boot Device")
**Symptom:** Generated Hybrid-ISOs refused to boot on certain UEFI/BIOS systems and Emulators.
**Root Cause:** `grub-mkrescue` (in `scripts/build.sh`) silently ignores Hybrid EFI generation if the packages `grub-efi-amd64-bin` and `grub-pc-bin` are missing on the build host.
**Fix:** Explicitly added both packages + `mtools` to the CI workflow and Dockerfile to guarantee 100% Hybrid BIOS/UEFI bootability.

## 5. YAML Nested Mapping Error in GitHub Actions
**Symptom:** `Nested mappings are not allowed in compact mappings`
**Fix:** GitHub Actions step names cannot contain unquoted colons (e.g., `- name: Sub-Agent: QEMU`). Always wrap the full step name in double quotes.
