# 🚀 JulesOS

**JulesOS** is a high-performance, indestructible, and hybrid (BIOS/UEFI) Linux operating system. The core is designed for extreme stability, speed (written natively in Rust), and flexibility (Cross-Architecture Binary Translation).

## 🌟 Core Features

- 🛡️ **Indestructible Core (Immutable Layer):** The operating system utilizes a strictly read-only RAM root filesystem (`OverlayFS`). Every reboot resets the system to a pristine, flawless state, permanently eliminating viruses and system corruption.
- ⚡ **Rust-Based Shell:** The Init process (PID 1) and the core shell (`jules_shell`) are written 100% in pure, native Rust, making memory leaks and C-pointer bugs (e.g., in signal handlers) impossible.
- 🚀 **CachyOS Performance Tuning:** Integrated `ZRAM` compression, AMD-P-State CPU governor forced to maximum performance, and aggressive BORE/EEVDF scheduler optimizations handled directly during the `init` boot process.
- 💻 **Cross-Architecture Translator (Box86/Wine):** A fully Python-written GUI tool (GTK3 Wayland, `translator_gui.py`) that allows older x86/32-bit and Windows `.exe` files to run natively on all architectures (like the Raspberry Pi 4) in an isolated sandbox via emulation.
- 📱 **Limbo PC Emulator Support (Android):** Fully optimized for Android emulation! JulesOS generates a Hybrid BIOS/UEFI bootable ISO that natively supports the Limbo PC Emulator out of the box. Just attach the ISO to the CD-ROM drive in Limbo, select x86_64 architecture, and boot instantly on your smartphone.
- 🧠 **Intelligent Resource Daemon (JRD):** An autonomous Rust thread within the kernel that actively monitors CPU consumption. If any process hogs >85% CPU, JRD intelligently sends `SIGSTOP` to freeze it, preventing system lag or Kernel Panics, and dynamically resumes it (`SIGCONT`) when resources free up.
- 🛠️ **Native Compiler Stack:** JulesOS is completely self-hosting. It bundles `gcc`, `g++`, `rust`, `cargo`, and `make` deeply into the RootFS, allowing you to compile complex software directly on the system without external dependencies.

## 🛠️ Architecture & Setup

The system internally relies on a highly stripped-down **Alpine Linux** RootFS. During the build pipeline, it generates an authentic `initramfs` powered by a custom **virtio-optimized kernel**.

### Local Testing (Windows Host)

For developers on Windows hosts, we have engineered an extremely robust local build and test environment that completely bypasses WSL-related crashes:

1. Launch Docker Desktop.
2. Run the provided script in PowerShell:
   ```powershell
   .\test_local.ps1
   ```
3. The script mounts the source into an isolated Ubuntu container, compiles JulesOS, executes an automated headless QEMU boot test (`qemu_boot_test.py`), and finally extracts the perfect, hybrid **`JulesOS.iso`** directly to your workspace.

## 📋 Agent Documentation (DOX)

All structural agent rules, failure analyses, and metadata are located in the `.agent/rules/` directory. 
Whenever new errors occur or system upgrades are developed, you must consult and update the `LEARNING.md` within this directory.
