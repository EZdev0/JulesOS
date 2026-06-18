# jules-os – Core OS DOX

## Purpose
Contains all components of the Jules OS: the Rust shell binary, build/boot/init scripts, documentation, and tests. This is the self-contained OS project that produces a bootable ISO image.

## Ownership
All files under `jules-os/` are part of the OS build artifact chain.

## Local Contracts

### Source Code (`src/`)
- **Language**: Rust 2021 edition
- **Target**: `x86_64-unknown-linux-musl` (static binary)
- **Entry point**: `src/main.rs` (PID 1 capable init + interactive shell)
- **Modules**: `commands.rs` (shell commands), `colors.rs` (ANSI output), `system.rs` (procfs/sysfs)
- **Legacy**: `src/legacy/` contains the original C++ implementation (reference only)

### Scripts (`scripts/`)
- `build.sh` – Full OS build pipeline (Rust compile → rootfs → kernel → ISO)
- `boot.sh` – QEMU launcher with hardware detection
- `init.sh` – PID 1 init script (OverlayFS, drivers, network, user setup)
- `install.sh` – Intelligent installer with dependency management

### Documentation (`docs/`)
- `features.md` – 50-step feature roadmap
- `architecture.md` – System architecture overview

## Work Guidance
- The Rust binary must be statically linked (verify with `file` command)
- init.sh must handle all boot responsibilities: filesystems, drivers, network, user
- build.sh must produce a bootable ISO that works on both QEMU and real hardware
- All shell scripts must use `set -euo pipefail` for strict error handling

## Verification
```bash
cargo clippy --all-targets -- -D warnings
cargo test
bash -n scripts/build.sh
sh -n scripts/init.sh
bash -n scripts/boot.sh
bash -n scripts/install.sh
```

## Child DOX Index
This directory has no child DOX files. All subdirectories are covered by this document.
