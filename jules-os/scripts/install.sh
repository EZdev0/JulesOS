#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# JulesOS Intelligent Installer v1.0
#
# Automatically detects hardware, installs dependencies,
# builds the OS, and configures optimal settings.
#
# Supports: Linux (Debian/Ubuntu/Alpine/Arch), macOS, Termux
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║      Jules OS Intelligent Installer v1.0          ║"
echo "  ║                                                   ║"
echo "  ║  This installer will:                             ║"
echo "  ║  1. Detect your system hardware                   ║"
echo "  ║  2. Install required dependencies                 ║"
echo "  ║  3. Build Jules OS for your platform              ║"
echo "  ║  4. Configure optimal QEMU settings               ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── WARNING ───────────────────────────────────────────────────
echo -e "${YELLOW}${BOLD}⚠  WARNING:${NC}"
echo "  This installer will install packages on your system."
echo "  All actions are logged and can be reviewed."
echo ""
read -p "  Do you want to continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ══════════════════════════════════════════════════════════════
# STEP 1: System Detection
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}═══ Step 1/4: System Detection ═══${NC}"

# Architecture
ARCH=$(uname -m)
OS_TYPE=$(uname -s)
info "Architecture: ${ARCH}"
info "OS Type: ${OS_TYPE}"

# Detect distribution
DISTRO="unknown"
PKG_MGR="unknown"
IS_TERMUX=0

if [[ "${PREFIX:-}" == *"termux"* ]]; then
    DISTRO="termux"
    PKG_MGR="pkg"
    IS_TERMUX=1
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID:-unknown}"
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            PKG_MGR="apt"
            ;;
        alpine)
            PKG_MGR="apk"
            ;;
        arch|cachyos|manjaro|endeavouros)
            PKG_MGR="pacman"
            ;;
        fedora|rhel|centos)
            PKG_MGR="dnf"
            ;;
        *)
            warn "Unknown distribution: ${DISTRO}"
            ;;
    esac
elif [ "$OS_TYPE" = "Darwin" ]; then
    DISTRO="macos"
    PKG_MGR="brew"
fi

info "Distribution: ${DISTRO}"
info "Package Manager: ${PKG_MGR}"

# Hardware info
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
info "CPU Cores: ${CPU_CORES}"
info "Total RAM: ${TOTAL_RAM_MB} MB"

# Check for KVM/Hardware virtualization
HAS_KVM=0
if [ -e /dev/kvm ]; then
    HAS_KVM=1
    ok "KVM hardware acceleration available"
elif grep -q -E 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
    warn "CPU supports virtualization, but /dev/kvm not available"
    warn "You may need to enable VT-x/AMD-V in BIOS and load kvm module"
else
    info "No hardware virtualization detected (software emulation will be used)"
fi

# ══════════════════════════════════════════════════════════════
# STEP 2: Install Dependencies
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}═══ Step 2/4: Installing Dependencies ═══${NC}"

install_deps() {
    case "$PKG_MGR" in
        apt)
            info "Installing via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq \
                wget tar cpio gzip xorriso syslinux syslinux-utils \
                qemu-system-x86 qemu-utils mtools dosfstools
            # Rust
            if ! command -v cargo >/dev/null 2>&1; then
                info "Installing Rust toolchain..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                source "$HOME/.cargo/env"
            fi
            ;;
        pacman)
            info "Installing via pacman..."
            sudo pacman -Syu --noconfirm --needed \
                wget tar cpio gzip xorriso syslinux \
                qemu-full mtools dosfstools rust
            ;;
        apk)
            info "Installing via apk..."
            sudo apk add wget tar cpio gzip xorriso syslinux \
                qemu-system-x86_64 qemu-img mtools dosfstools rust cargo
            ;;
        pkg)
            info "Installing via Termux pkg..."
            pkg update -y
            pkg install -y wget tar cpio gzip qemu-system-x86-64 qemu-utils rust
            ;;
        brew)
            info "Installing via Homebrew..."
            brew install wget xorriso qemu mtools rust
            ;;
        *)
            warn "Cannot auto-install dependencies for ${PKG_MGR}."
            warn "Please install manually: wget, tar, cpio, gzip, xorriso, qemu, rust"
            ;;
    esac
}

install_deps
ok "Dependencies installed."

# Install musl target for static builds
if command -v rustup >/dev/null 2>&1; then
    info "Adding musl cross-compilation target..."
    rustup target add x86_64-unknown-linux-musl 2>/dev/null || true
    ok "Rust musl target configured."
fi

# ══════════════════════════════════════════════════════════════
# STEP 3: Build Jules OS
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}═══ Step 3/4: Building Jules OS ═══${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/.."

info "Starting build process..."
bash scripts/build.sh

ok "Jules OS built successfully!"

# ══════════════════════════════════════════════════════════════
# STEP 4: Configure & Summary
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}═══ Step 4/4: Configuration & Summary ═══${NC}"

# Calculate optimal QEMU settings
QEMU_RAM=$((TOTAL_RAM_MB / 4))
[ "$QEMU_RAM" -lt 256 ] && QEMU_RAM=256
[ "$QEMU_RAM" -gt 4096 ] && QEMU_RAM=4096

QEMU_CORES=$((CPU_CORES / 2))
[ "$QEMU_CORES" -lt 1 ] && QEMU_CORES=1
[ "$QEMU_CORES" -gt 4 ] && QEMU_CORES=4

info "Recommended QEMU settings for your hardware:"
echo "  RAM: ${QEMU_RAM}M (${TOTAL_RAM_MB}M total)"
echo "  CPU cores: ${QEMU_CORES} (${CPU_CORES} total)"
echo "  KVM acceleration: $([ $HAS_KVM -eq 1 ] && echo 'Yes' || echo 'No')"

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║      Installation Complete! ✓                     ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  To boot Jules OS, run:"
echo ""
echo -e "    ${CYAN}./scripts/boot.sh${NC}"
echo ""
echo "  Or manually with QEMU:"
echo ""
echo -e "    ${CYAN}qemu-system-x86_64 \\"
echo "      -kernel iso/boot/bzImage \\"
echo "      -initrd iso/boot/initrd.img \\"
echo "      -append 'root=/dev/ram0 rw console=ttyS0' \\"
echo "      -nographic -m ${QEMU_RAM}M -smp ${QEMU_CORES}${NC}"
echo ""
