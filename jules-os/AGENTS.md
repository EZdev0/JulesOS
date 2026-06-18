# jules-os – Core OS DOX

## Purpose
This directory encapsulates the entire **JulesOS Core**. It contains the native Rust shell (`jules_shell`), the critical boot and init scripts (`init.sh`, `build.sh`), and all essential documentation. The output of this component is the final, hybrid bootable `JulesOS.iso`.

## Ownership
- **Maintainer**: JulesOS Core Team
- **Scope**: Everything within `jules-os/` is under strict CI/CD governance.

## Local Contracts

### 🦀 1. Source Code (`src/`)
- **Language**: Rust 2021 edition (Memory-Safe).
- **Target Architecture**: `x86_64-unknown-linux-musl` (100% Statically Linked).
- **Entry Point**: `src/main.rs`. Acts as PID 1 capable init system and interactive shell. No `exit` or `panic` allowed in PID 1 scope.
- **Modules**: `commands.rs` (logic), `colors.rs` (ANSI rendering), `system.rs` (native procfs/sysfs parsers - *No external C-bindings like nix for core syscalls*).
- **Legacy**: `src/legacy/` holds deprecated C++ implementations (for historical reference only).

### 🛠️ 2. Build Scripts (`scripts/`)
- **`build.sh`**: The master assembler. Compiles Rust, downloads Alpine RootFS, injects the virtio-kernel, and generates the ISO using `grub-mkrescue` (hybrid BIOS/UEFI).
- **`init.sh`**: The PID 1 bootstrapping script. It handles `OverlayFS` mounting (immutable layer), hardware driver loading (`mdev`), network configuration, and finally execs into `jules_shell`. *Crucial: `set -e` is strictly prohibited here to prevent Kernel Panics on minor hardware probing failures.*
- **`boot.sh`**: QEMU launcher for rapid local testing.

### 🛡️ 3. Security & CI/CD Integrity
- **Linter Enforcements**: Rust code must pass `clippy --pedantic`. Shell scripts must pass `shellcheck -x`. Python scripts must pass `flake8` and `bandit`.
- **Vulnerability Scans**: The final output is automatically scanned by **Trivy** for OS vulnerabilities.
- **Caching**: All external downloads (`wget`, `apt-get`, `pip`) must use smart caching and timeouts (`--timeout=15`) to prevent pipeline billing leaks.

## Work Guidance
- **Safety First**: Any new feature must be tested via the local `test_local.ps1` Docker environment before committing.
- **Dependencies**: Do not introduce new heavy Rust crates (like `nix` or `tokio`) unless absolutely necessary. Rely on `std` and raw `libc`/`procfs` when acting as an OS core.
- **Documentation**: Whenever a Kernel Panic, build crash, or critical bug is resolved, you **MUST** document the root cause and the fix in `.agent/rules/LEARNING.md`.

## Verification
To verify changes locally before pushing:
```bash
# 1. Rust Integrity
cargo clippy --all-targets -- -D warnings
cargo test

# 2. Shell Script Validation
shellcheck -x scripts/*.sh

# 3. Full End-to-End Test (Windows Host)
./test_local.ps1
```

## Child DOX Index
This directory has no child DOX files. All subdirectories are fully governed by this root contract.
