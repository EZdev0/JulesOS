# Jules OS Architecture

Jules OS is built on a highly customized, ultra-minimalist Linux foundation, designed to run flawlessly inside Termux via QEMU or directly on bare-metal PC hardware.

## Core Design Principles
1. **Immutable Root Filesystem**: The base OS is loaded entirely into RAM via an `initramfs` (initrd.img). The physical image on disk is never modified. This means any malware, mistaken deletions, or kernel panics are completely wiped out upon a simple reboot.
2. **Persistent Data Vault**: User data (`/home`) is mounted dynamically from an external virtual drive (`data.img`). This ensures user files are safely preserved across updates and system resets.
3. **The Jules Shell (C++)**: Replacing the standard `/bin/sh` or `/sbin/init`, the system directly hands over PID 1 control to a statically compiled C++ application. This provides a lightning-fast, highly aesthetic (CachyOS-style) command interface.

## Build Process (`build.sh`)
* **Step 1:** Compiles the C++ `jules_shell` statically using `cmake`.
* **Step 2:** Downloads the Alpine Linux minirootfs and virt-kernel.
* **Step 3:** Integrates the compiled C++ shell and custom `init.sh` script into the rootfs.
* **Step 4:** Packages the modified rootfs into a compressed `initrd.img` archive.
* **Step 5:** Utilizes `syslinux` and `xorriso` to create a bootable `.iso` file (`JulesOS.iso`), configured for a silent, invisible boot sequence.

## Execution Process (`boot.sh`)
* Analyzes host architecture to apply QEMU flags natively.
* Generates a 1GB `data.img` (Persistent Vault) if it doesn't exist.
* Launches QEMU entirely headless (`-nographic`) or with proper TTY forwarding, making it the perfect terminal OS for Android/Termux environments.
