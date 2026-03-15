# Jules OS

Welcome to **Jules OS**, the ultimate, most secure, stable, and fastest operating system designed by Jules.
This OS runs flawlessly in Termux via QEMU, operates entirely in RAM with an immutable core (making it indestructible and self-repairing), and boots instantly into a custom, highly optimized C++ shell.

## 🚀 Key Features
*   **Immutable Core (OverlayFS):** Rebooting instantly restores a pristine system. No viruses, no corruption.
*   **Blazing Fast:** Built on a minimal Linux kernel, tuned with `-O3` C++ shell, and zswap for low RAM devices.
*   **The Jules Shell:** A custom C++ interface inspired by modern aesthetics (CachyOS) with instant commands like `boost`, `update`, and `python-mode`.
*   **Persistent Data Vault:** Your files (`/home`) are safely stored and persist across reboots, separate from the OS core.
*   **Native Internet & APK:** Immediate access to the web and lightning-fast package management.

## 📁 Project Structure
*   `src/`: The C++ source code for the custom `Jules Shell`.
*   `scripts/`: Automation scripts to build the OS (`build.sh`), test it (`test.sh`), and boot it (`boot.sh`).
*   `docs/`: Detailed feature roadmap (`features.md`) and architectural overview (`architecture.md`).
*   `iso/` & `build/`: Temporary directories for compiling the kernel and packaging the bootable image.

## 🛠️ How to Build and Run
1. Run `./scripts/build.sh` to download the kernel, compile the C++ shell, and generate the OS image.
2. Run `./scripts/boot.sh` to launch Jules OS in QEMU.

## 📜 Documentation
Check `docs/features.md` for the complete 50-step roadmap and prioritized features list!
