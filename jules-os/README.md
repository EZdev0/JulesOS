# Jules OS

Welcome to **Jules OS**, the ultimate, most secure, stable, and fastest operating system designed by Jules.
This OS runs flawlessly in QEMU/Limbo, operates entirely in RAM with an immutable core (making it indestructible and self-repairing), and boots instantly into a highly optimized, memory-safe Rust shell.

## 🚀 Key Features
*   **Immutable Core (OverlayFS):** Rebooting instantly restores a pristine system. No viruses, no corruption.
*   **Blazing Fast & Safe:** Built on an Alpine Linux kernel base with a PID 1 Shell entirely written in **Rust** (statically compiled via musl). 
*   **JRD (Jules Resource Daemon):** Intelligent, dynamic load balancing that automatically freezes resource-hogging background tasks to keep the UI smooth.
*   **Auto-Desktop & Recovery:** Instantly attempts to boot into a Wayland Desktop Environment (Sway). If it crashes, seamlessly falls back to the Jules Recovery Shell.
*   **Hardware Watchdog:** Continuous real-time monitoring of RAM usage and zombie processes.
*   **ZRAM Compression:** Instantly compresses unused memory pages to maximize multitasking on low RAM devices.

## 📁 Project Structure
*   `src/`: The Rust source code for the custom `Jules Shell` (PID 1, JRD, Watchdog).
*   `scripts/`: Automation scripts to build the OS (`build.sh`), test it locally (`test_full.sh`), and boot it (`boot.sh`).
*   `docs/`: Detailed feature roadmap (`features.md`) and architectural overview (`architecture.md`).
*   `.github/workflows/`: Full CI/CD pipeline ensuring 100% stable ISO builds.

## 🛠️ How to Build and Run
1. Run `./scripts/build.sh` to download the kernel, compile the Rust shell, and generate the hybrid ISO image.
2. Run `./scripts/boot.sh` to launch Jules OS locally via QEMU.
3. Run `./scripts/test_full.sh` in a Docker container to run the comprehensive 7-stage test suite (Formatting, Clippy, Build, Unit Tests, Binary checks, ShellCheck).

## 📜 Documentation
Check `docs/features.md` for the complete 50-step roadmap and prioritized features list!
