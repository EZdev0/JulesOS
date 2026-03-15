# Jules OS Memory & Project State
This file acts as a persistent memory and state tracker for Jules OS, ensuring context is never lost across sessions.

**Project State:** Phase 1 (Core Foundation) COMPLETE.
**Date:** March 2024

## 1. Core Architecture (What we built)
- **Jules Shell (C++)**: Replacing `/bin/sh`, located at `/bin/jules_shell`. A static, dependency-free binary offering dynamic prompts and core commands (`boost`, `python`, `status`, `update`).
- **Immutable RootFS (OverlayFS)**: Built on Alpine Linux minirootfs. Modifies RAM (`tmpfs`), meaning every reboot is a completely clean, un-hackable slate.
- **Persistent Data Vault (`data.img`)**: The `boot.sh` script maps a virtual 1GB qcow2 drive to `/home`. All user data goes here and survives resets.
- **Automated Toolchain**: `build.sh` (Downloads kernel, compiles C++, packs ISO) and `boot.sh` (Detects ARM vs x86, runs QEMU headless for Termux).

## 2. Immediate Next Steps (Phase 2 - Next Session Reminders)
- **Ticket PRO-40**: Implement a Pure Python Print Fallback Renderer for scenarios where `curses` crashes.
- **Ticket PRO-41**: Develop the `jupdate` command in the C++ shell to actually pull OTA updates from GitHub and overwrite the base image.
- **Ticket PRO-42**: Prepare the graphics hooks (`-vga virtio` and Wayland) inside `boot.sh` to transition Jules OS from a CLI to a graphical UI (Jules DE).
- **AI Integration**: The C++ shell needs hooks to communicate with a local LLM or Python API for intelligent command completion.

## 3. How to Deploy on Termux
User instructions for deployment are stored in the README, but summarized here:
1. Ensure Termux is updated.
2. Install dependencies: `pkg install qemu-utils qemu-system-x86_64 cmake clang make wget xorriso fakeroot cpio e2fsprogs syslinux`
3. Clone the repo and run `./scripts/build.sh`
4. Boot the OS with `./scripts/boot.sh`
