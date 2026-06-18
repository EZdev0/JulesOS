# JulesOS – Root DOX

## Purpose
JulesOS is a minimal, immutable, high-performance Linux-based operating system. It boots from an ISO/initramfs into a custom Rust shell, providing an indestructible computing environment that resets to pristine state on every reboot.

## Ownership
- **Maintainer**: JulesOS Team
- **Repository**: JONIMONI09/JulesOS

## Local Contracts
- All shell code is written in **Rust** (memory-safe, statically compiled with musl)
- Build scripts are in **Bash** (POSIX-compatible where possible)
- Init system is **shell script** (runs as PID 1 in initramfs)
- The OS is based on **Alpine Linux** minirootfs with custom kernel
- CI/CD runs on **GitHub Actions** (Ubuntu runners for musl cross-compilation)

## Work Guidance
- Use `cargo clippy` and `cargo fmt` before every commit
- All Rust code must compile with zero warnings (`-D warnings`)
- Shell scripts must pass `shellcheck` analysis
- Static musl binaries are the default build target
- Security-critical code must use safe Rust (no `unsafe` without justification)

## Verification
```bash
# Rust linting and tests
cd jules-os && cargo clippy --all-targets -- -D warnings && cargo test

# Shell script validation
shellcheck jules-os/scripts/*.sh

# Build and verify ISO
cd jules-os && bash scripts/build.sh
file JulesOS.iso  # Must show "ISO 9660"
```

## Child DOX Index
- [jules-os/AGENTS.md](file:///d:/Repos_agy_ide/JulesOS/jules-os/AGENTS.md) – OS core: Rust shell, build system, init scripts, documentation
