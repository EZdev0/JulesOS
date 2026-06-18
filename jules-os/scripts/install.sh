#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# JulesOS Smart Installer v2.0 (TUI Edition)
#
# Automatically detects hardware, installs dependencies,
# builds the OS, and configures optimal settings via a
# professional ncurses/whiptail interface.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── 1. Ensure TUI Tools are available ──────────────────────────
if ! command -v whiptail >/dev/null 2>&1; then
    echo "Installing 'whiptail' for Smart Setup interface..."
    if command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y -qq whiptail; fi
    if command -v pacman >/dev/null 2>&1; then sudo pacman -Syu --noconfirm --needed newt; fi
    if command -v apk >/dev/null 2>&1; then sudo apk add newt; fi
    if command -v pkg >/dev/null 2>&1; then pkg install -y newt; fi
fi

if ! command -v whiptail >/dev/null 2>&1; then
    echo "Error: Whiptail could not be installed. Please install 'newt' or 'whiptail' manually."
    exit 1
fi

BACKTITLE="JulesOS Smart Setup v2.0"

# ── 2. Welcome Screen ──────────────────────────────────────────
whiptail --backtitle "$BACKTITLE" --title "Welcome to JulesOS" --msgbox \
"Welcome to the JulesOS Smart Installer.\n\n\
This wizard will guide you through the process of configuring, compiling, and installing the indestructible JulesOS.\n\n\
Press [ENTER] to begin the setup." 12 65

# ── 3. System Detection ────────────────────────────────────────
ARCH=$(uname -m)
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
HAS_KVM="No"
if [ -e /dev/kvm ]; then HAS_KVM="Yes"; fi

DISTRO="unknown"
PKG_MGR="unknown"
if [[ "${PREFIX:-}" == *"termux"* ]]; then
    DISTRO="termux"
    PKG_MGR="pkg"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID:-unknown}"
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop) PKG_MGR="apt" ;;
        alpine) PKG_MGR="apk" ;;
        arch|cachyos|manjaro|endeavouros) PKG_MGR="pacman" ;;
        fedora|rhel|centos) PKG_MGR="dnf" ;;
    esac
elif [ "$(uname -s)" = "Darwin" ]; then
    DISTRO="macos"
    PKG_MGR="brew"
fi

whiptail --backtitle "$BACKTITLE" --title "Hardware Detection" --msgbox \
"The following hardware was detected on your system:\n\n\
Architecture:    $ARCH\n\
CPU Cores:       $CPU_CORES\n\
Total RAM:       $TOTAL_RAM_MB MB\n\
KVM Accelerated: $HAS_KVM\n\
OS Package Mgr:  $PKG_MGR\n\n\
The system is ready to be configured." 15 65

# ── 4. Confirmation ────────────────────────────────────────────
if ! whiptail --backtitle "$BACKTITLE" --title "Installation Confirmation" --yesno \
"The installer will now download build dependencies (QEMU, Xorriso, Rust) and compile the JulesOS Kernel.\n\n\
Do you want to proceed?" 10 65; then
    clear
    echo "Installation cancelled by user."
    exit 0
fi

# ── 5. Build Process (Terminal) ────────────────────────────────
clear
echo -e "\033[1;36mStarting JulesOS Build Process...\033[0m"

install_deps() {
    case "$PKG_MGR" in
        apt)
            echo "Installing via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq --no-install-recommends \
                wget tar cpio gzip xorriso syslinux syslinux-utils \
                qemu-system-x86 qemu-utils mtools dosfstools
            if ! command -v cargo >/dev/null 2>&1; then
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                source "$HOME/.cargo/env" || true
            fi
            ;;
        pacman)
            echo "Installing via pacman..."
            sudo pacman -Syu --noconfirm --needed \
                wget tar cpio gzip xorriso syslinux \
                qemu-full mtools dosfstools rust
            ;;
        apk)
            echo "Installing via apk..."
            sudo apk add wget tar cpio gzip xorriso syslinux \
                qemu-system-x86_64 qemu-img mtools dosfstools rust cargo
            ;;
        pkg)
            echo "Installing via Termux pkg..."
            pkg update -y
            pkg install -y wget tar cpio gzip qemu-system-x86-64 qemu-utils rust
            ;;
        brew)
            echo "Installing via Homebrew..."
            brew install wget xorriso qemu mtools rust
            ;;
        *)
            echo "Cannot auto-install dependencies for ${PKG_MGR}."
            ;;
    esac
}

install_deps

if command -v rustup >/dev/null 2>&1; then
    rustup target add x86_64-unknown-linux-musl 2>/dev/null || true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Run the actual OS build
bash scripts/build.sh

# ── 6. Summary TUI ─────────────────────────────────────────────
QEMU_RAM=$((TOTAL_RAM_MB / 4))
[ "$QEMU_RAM" -lt 256 ] && QEMU_RAM=256
[ "$QEMU_RAM" -gt 4096 ] && QEMU_RAM=4096
QEMU_CORES=$((CPU_CORES / 2))
[ "$QEMU_CORES" -lt 1 ] && QEMU_CORES=1
[ "$QEMU_CORES" -gt 4 ] && QEMU_CORES=4

whiptail --backtitle "$BACKTITLE" --title "Installation Complete" --msgbox \
"JulesOS has been built successfully! ✓\n\n\
Recommended Emulator Settings:\n\
- RAM: ${QEMU_RAM} MB\n\
- CPU: ${QEMU_CORES} Cores\n\n\
To boot your new OS, simply run in your terminal:\n\
  ./scripts/boot.sh" 14 65

clear
echo -e "\033[1;32mInstallation complete! Run ./scripts/boot.sh to start JulesOS.\033[0m"
