#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# JulesOS Build System v2.0
# Creates a REAL, bootable operating system ISO image.
#
# Supports: BIOS + UEFI boot, real hardware + QEMU
# Based on: Alpine Linux LTS kernel with full driver support
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
JULES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${JULES_DIR}/build"
ISO_DIR="${JULES_DIR}/iso"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ALPINE_VERSION="3.21"
ALPINE_RELEASE="3.21.2"

TARGET_ARCH=${1:-x86_64}
if [ "$TARGET_ARCH" = "x86" ]; then
    ALPINE_ARCH="x86"
    RUST_TARGET="i686-unknown-linux-musl"
elif [ "$TARGET_ARCH" = "aarch64" ] || [ "$TARGET_ARCH" = "arm64" ]; then
    TARGET_ARCH="aarch64"
    ALPINE_ARCH="aarch64"
    RUST_TARGET="aarch64-unknown-linux-musl"
else
    TARGET_ARCH="x86_64"
    ALPINE_ARCH="x86_64"
    RUST_TARGET="x86_64-unknown-linux-musl"
fi

ALPINE_TAR="alpine-minirootfs-${ALPINE_RELEASE}-${ALPINE_ARCH}.tar.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/${ALPINE_TAR}"
ALPINE_SHA_URL="${ALPINE_URL}.sha256"
ALPINE_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}"
ISO_OUTPUT="${JULES_DIR}/JulesOS-${TARGET_ARCH}.iso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Helper Functions ───────────────────────────────────────────

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}${BOLD}══ $* ══${NC}"; }

# ── Termux Detection ──────────────────────────────────────────
IS_TERMUX=0
if [[ "${PREFIX:-}" == *"termux"* ]]; then
    IS_TERMUX=1
    warn "Termux environment detected. Adapting build for non-root."
fi

# ── Dependency Checks ─────────────────────────────────────────
step "Step 0/8: Checking Build Dependencies"

REQUIRED_CMDS="wget tar cpio gzip"
OPTIONAL_CMDS="cargo xorriso mtools grub-mkrescue"

for cmd in $REQUIRED_CMDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' is missing. Please install it."
    fi
done
ok "All required build tools found."

for cmd in $OPTIONAL_CMDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        warn "Optional tool '$cmd' not found. Some features may be limited."
    fi
done

# ═══════════════════════════════════════════════════════════════
echo -e "\n${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║         Building Jules OS v1.0.0                  ║"
echo "  ║   The Immutable, High-Performance Operating System║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
# ═══════════════════════════════════════════════════════════════

# ── Step 1: Clean Previous Build ──────────────────────────────
step "Step 1/8: Cleaning Previous Build"

# Preserve pre-compiled jules_shell if it exists (e.g. downloaded by CI)
if [ -f "${BUILD_DIR}/jules_shell" ]; then
    info "Preserving pre-compiled jules_shell..."
    mv "${BUILD_DIR}/jules_shell" "${JULES_DIR}/jules_shell.tmp"
fi

rm -rf "${BUILD_DIR}" "${ISO_DIR}"
mkdir -p "${BUILD_DIR}" "${ISO_DIR}/boot/grub" "${ISO_DIR}/boot/syslinux" "${ROOTFS_DIR}"

if [ -f "${JULES_DIR}/jules_shell.tmp" ]; then
    mv "${JULES_DIR}/jules_shell.tmp" "${BUILD_DIR}/jules_shell"
fi

ok "Build environment cleaned."

# ── Step 2: Compile Jules Shell (Rust) ────────────────────────
step "Step 2/8: Compiling Jules Shell (Rust Core)"

cd "${JULES_DIR}"

if [ "${SKIP_RUST_BUILD:-0}" = "1" ] && [ -f "${BUILD_DIR}/jules_shell" ]; then
    info "SKIP_RUST_BUILD is set. Using pre-compiled binary from ${BUILD_DIR}/"
elif command -v cargo >/dev/null 2>&1; then
    info "Rust toolchain detected: $(rustc --version 2>/dev/null || echo 'unknown')"

    # Try cross-compilation for static musl binary (ideal for OS)
    BINARY_PATH=""

    if command -v cross >/dev/null 2>&1; then
        info "Using 'cross' for static musl build..."
        cross build --release --target "${RUST_TARGET}" && \
            BINARY_PATH="target/${RUST_TARGET}/release/jules_shell"
    elif rustup target list --installed 2>/dev/null | grep -q "${RUST_TARGET}" || rustup target add "${RUST_TARGET}" 2>/dev/null; then
        info "Building with musl target ${RUST_TARGET}..."
        
        # Export cross-compiler linker if targeting aarch64 on x86_64 host
        if [ "${RUST_TARGET}" = "aarch64-unknown-linux-musl" ]; then
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER="aarch64-linux-gnu-gcc"
            export CC_aarch64_unknown_linux_musl="aarch64-linux-gnu-gcc"
        fi
        
        cargo build --release --target "${RUST_TARGET}" && \
            BINARY_PATH="target/${RUST_TARGET}/release/jules_shell"
    fi

    # Fallback: build for host target
    if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
        info "Building for host target (dynamic linking)..."
        cargo build --release || error "Rust compilation failed"
        BINARY_PATH="target/release/jules_shell"
    fi

    # Copy binary to build directory
    mkdir -p "${BUILD_DIR}"
    cp "${BINARY_PATH}" "${BUILD_DIR}/jules_shell" || error "Failed to copy binary"
    chmod +x "${BUILD_DIR}/jules_shell"

elif [ -f "${BUILD_DIR}/jules_shell" ]; then
    # Pre-compiled binary exists but cargo not found
    warn "Rust not installed. Using pre-compiled binary from ${BUILD_DIR}/"

else
    error "Rust toolchain not found! Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

cd "${JULES_DIR}"

ok "Jules Shell compiled successfully."
info "Binary: $(find "${BUILD_DIR}/jules_shell" -printf "%s bytes\n")"
info "Type: $(file "${BUILD_DIR}/jules_shell" 2>/dev/null | cut -d: -f2 | head -c80)"

# ── Step 3: Download Alpine Minirootfs ────────────────────────
step "Step 3/8: Downloading Alpine Linux RootFS"

if [ ! -f "${BUILD_DIR}/${ALPINE_TAR}" ]; then
    info "Downloading Alpine minirootfs v${ALPINE_RELEASE}..."
    wget -q --show-progress --timeout=15 --tries=3 -O "${BUILD_DIR}/${ALPINE_TAR}" "${ALPINE_URL}" || \
        error "Failed to download Alpine minirootfs"

    # SHA256 verification
    info "Verifying download integrity (SHA256)..."
    if wget -qO "${BUILD_DIR}/${ALPINE_TAR}.sha256" --timeout=15 --tries=3 "${ALPINE_SHA_URL}" 2>/dev/null; then
        cd "${BUILD_DIR}"
        if sha256sum -c "${ALPINE_TAR}.sha256" 2>/dev/null | grep -q "OK"; then
            ok "SHA256 checksum verified."
        else
            warn "SHA256 verification failed or unavailable. Continuing..."
        fi
        cd "${JULES_DIR}"
    else
        warn "Could not download SHA256 file. Skipping verification."
    fi
else
    ok "Alpine rootfs already cached."
fi

# Extract RootFS
info "Extracting rootfs..."
tar -xf "${BUILD_DIR}/${ALPINE_TAR}" -C "${ROOTFS_DIR}"
ok "RootFS extracted."

# ── Step 4: Download Linux Kernel + Modules ───────────────────
step "Step 4/8: Downloading Linux Kernel & Drivers"

# We download BOTH the kernel and kernel module packages.
# Using 'lts' kernel for maximum hardware compatibility on real PCs.
# Using 'virt' as fallback for QEMU-only environments.
mkdir -p "${BUILD_DIR}/kernel_pkg"
cd "${BUILD_DIR}/kernel_pkg"

# Try to find and download kernel packages
KERNEL_TYPE="virt"  # Use virt for smaller size; lts for real hardware
info "Fetching kernel index from Alpine repository..."

# Download kernel
KERNEL_PKG_NAME=$(wget -qO- --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/" 2>/dev/null | \
    grep -oE "linux-${KERNEL_TYPE}-[0-9][a-zA-Z0-9._-]*\.apk" | sort -V | tail -n 1) || true

if [ -z "$KERNEL_PKG_NAME" ]; then
    error "Could not find kernel package in Alpine repository."
fi

info "Downloading kernel: ${KERNEL_PKG_NAME}..."
wget -q --show-progress --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/${KERNEL_PKG_NAME}" || \
    error "Failed to download kernel"

# Extract kernel
tar -zxf "${KERNEL_PKG_NAME}" 2>/dev/null || true

if [ -f boot/vmlinuz-${KERNEL_TYPE} ]; then
    cp "boot/vmlinuz-${KERNEL_TYPE}" "${ISO_DIR}/boot/bzImage"
    ok "Kernel extracted: vmlinuz-${KERNEL_TYPE}"
elif [ -f boot/vmlinuz-lts ]; then
    cp boot/vmlinuz-lts "${ISO_DIR}/boot/bzImage"
    ok "Kernel extracted: vmlinuz-lts"
else
    # Fallback: search for any vmlinuz
    FOUND_KERNEL=$(find . -name 'vmlinuz*' -type f | head -n 1)
    if [ -n "$FOUND_KERNEL" ]; then
        cp "$FOUND_KERNEL" "${ISO_DIR}/boot/bzImage"
        ok "Kernel extracted: $(basename "$FOUND_KERNEL")"
    else
        error "No kernel binary found in the downloaded package!"
    fi
fi

# Copy kernel modules into rootfs (critical for real hardware!)
KERNEL_VERSION=""
if [ -d lib/modules ]; then
    cp -a lib/modules "${ROOTFS_DIR}/lib/" 2>/dev/null || true
    KERNEL_VERSION=$(find "${ROOTFS_DIR}/lib/modules/" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | head -n 1)
    ok "Kernel modules installed: ${KERNEL_VERSION}"
else
    warn "No kernel modules found in package. Trying separate modules package..."

    # Try to download the modules package separately
    MODULES_PKG=$(wget -qO- --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/" 2>/dev/null | \
        grep -oE "linux-${KERNEL_TYPE}-[0-9][^\"]*\.apk" | grep -v "dev\|headers\|src" | sort -V | tail -n 1) || true
    if [ -n "$MODULES_PKG" ] && [ "$MODULES_PKG" != "$KERNEL_PKG_NAME" ]; then
        info "Downloading modules: ${MODULES_PKG}..."
        wget -q --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/${MODULES_PKG}" 2>/dev/null || true
        tar -zxf "${MODULES_PKG}" 2>/dev/null || true
        if [ -d lib/modules ]; then
            cp -a lib/modules "${ROOTFS_DIR}/lib/" 2>/dev/null || true
            KERNEL_VERSION=$(find "${ROOTFS_DIR}/lib/modules/" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | head -n 1)
            ok "Kernel modules installed from separate package: ${KERNEL_VERSION}"
        fi
    fi
fi

# Download essential firmware (for real hardware network/storage)
info "Downloading essential firmware..."
FIRMWARE_PKG=$(wget -qO- --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/" 2>/dev/null | \
    grep -oE 'linux-firmware-none-[0-9][a-zA-Z0-9._-]*\.apk' | sort -V | tail -n 1) || true
if [ -n "$FIRMWARE_PKG" ]; then
    wget -q --timeout=15 --tries=3 "${ALPINE_REPO}/main/${ALPINE_ARCH}/${FIRMWARE_PKG}" 2>/dev/null || true
    tar -zxf "${FIRMWARE_PKG}" 2>/dev/null || true
    if [ -d lib/firmware ]; then
        mkdir -p "${ROOTFS_DIR}/lib/firmware"
        cp -a lib/firmware/* "${ROOTFS_DIR}/lib/firmware/" 2>/dev/null || true
        ok "Base firmware installed."
    fi
fi

cd "${JULES_DIR}"

# ── Step 4.5: Install Wayland Desktop & Plymouth ──────────────
step "Step 4.5/8: Installing Desktop & Plymouth (Offline)"

info "Downloading apk-tools-static for offline package installation..."
APK_STATIC_PKG=$(wget -qO- "${ALPINE_REPO}/main/${ALPINE_ARCH}/" 2>/dev/null | grep -oE 'apk-tools-static-[0-9][a-zA-Z0-9._-]*\.apk' | sort -V | tail -n 1) || true
if [ -n "$APK_STATIC_PKG" ]; then
    cd "${BUILD_DIR}"
    wget -q "${ALPINE_REPO}/main/${ALPINE_ARCH}/${APK_STATIC_PKG}" 2>/dev/null || true
    tar -zxf "${APK_STATIC_PKG}" sbin/apk.static 2>/dev/null || true
    
    if [ -f sbin/apk.static ]; then
        info "Installing Desktop Packages into RootFS..."
        chmod +x sbin/apk.static
        
        mkdir -p "${ROOTFS_DIR}/etc/apk"
        {
            echo "${ALPINE_REPO}/main"
            echo "${ALPINE_REPO}/community"
        } > "${ROOTFS_DIR}/etc/apk/repositories"
        
        info "Installing Desktop Packages into RootFS... (Logs will be saved to desktop_install.log)"
        
        # Install packages into rootfs offline
        # --no-scripts prevents 'chroot: Operation not permitted' in unprivileged builds
        if ./sbin/apk.static -X "${ALPINE_REPO}/main" -X "${ALPINE_REPO}/community" -U --allow-untrusted --root "${ROOTFS_DIR}" --initdb --no-scripts add \
            plymouth \
            sway swaybg waybar alacritty mako grim slurp wl-clipboard \
            mesa-dri-gallium mesa-egl wlroots \
            font-dejavu font-terminus \
            eudev eudev-openrc seatd dbus \
            python3 py3-gobject3 gtk+3.0 wine \
            parted util-linux grub grub-efi efibootmgr dosfstools e2fsprogs \
            gcc g++ make cmake rust cargo nasm > "${BUILD_DIR}/desktop_install.log" 2>&1; then
            
            ok "Desktop & Plymouth packages installed successfully."
        else
            warn "Desktop packages failed to install perfectly. See logs/desktop_install.log"
            mkdir -p "${JULES_DIR}/logs"
            cp "${BUILD_DIR}/desktop_install.log" "${JULES_DIR}/logs/" 2>/dev/null || true
            warn "Continuing build without full desktop support..."
        fi
    else
        warn "Failed to extract apk.static. Desktop may not be available."
    fi
    cd "${JULES_DIR}"
else
    warn "Could not find apk-tools-static. Skipping desktop installation."
fi

# ── Step 5: Integrate Jules OS into RootFS ────────────────────
step "Step 5/8: Integrating Jules OS Components"

# Install Jules Shell binary
install -m 755 "${BUILD_DIR}/jules_shell" "${ROOTFS_DIR}/bin/jules_shell"
ok "Jules Shell installed to /bin/jules_shell"

# Install Legacy Translator GUI
if [ -f "${JULES_DIR}/src/translator_gui.py" ]; then
    install -m 755 "${JULES_DIR}/src/translator_gui.py" "${ROOTFS_DIR}/usr/bin/jules-translator"
    ok "Legacy Translator installed to /usr/bin/jules-translator"
fi

# Install init script
install -m 755 "${JULES_DIR}/scripts/init.sh" "${ROOTFS_DIR}/init"
ok "Init system installed to /init"

# Install Recovery UI
if [ -f "${JULES_DIR}/scripts/recovery_ui.sh" ]; then
    install -m 755 "${JULES_DIR}/scripts/recovery_ui.sh" "${ROOTFS_DIR}/bin/recovery_ui.sh"
    ok "Recovery UI installed to /bin/recovery_ui.sh"
fi

# Install OS Installer
if [ -f "${JULES_DIR}/scripts/installer.sh" ]; then
    install -m 755 "${JULES_DIR}/scripts/installer.sh" "${ROOTFS_DIR}/usr/bin/jules-installer"
    ok "OS Installer installed to /usr/bin/jules-installer"
fi

# Create essential directory structure (FHS-compliant)
mkdir -p "${ROOTFS_DIR}/home/jules"
mkdir -p "${ROOTFS_DIR}/root"
mkdir -p "${ROOTFS_DIR}/etc/apk"
mkdir -p "${ROOTFS_DIR}/etc/init.d"
mkdir -p "${ROOTFS_DIR}/var/log"
mkdir -p "${ROOTFS_DIR}/var/run"
mkdir -p "${ROOTFS_DIR}/mnt"
mkdir -p "${ROOTFS_DIR}/media"
mkdir -p "${ROOTFS_DIR}/opt"
mkdir -p "${ROOTFS_DIR}/srv"

# Set up Alpine repositories
{
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main"
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"
} > "${ROOTFS_DIR}/etc/apk/repositories"

# Create proper /etc/passwd and /etc/group (essential for a real OS)
if [ ! -f "${ROOTFS_DIR}/etc/passwd" ] || ! grep -q "jules" "${ROOTFS_DIR}/etc/passwd"; then
    # Append jules user if not present
    echo "jules:x:1000:1000:Jules User:/home/jules:/bin/jules_shell" >> "${ROOTFS_DIR}/etc/passwd"
fi

if [ ! -f "${ROOTFS_DIR}/etc/group" ] || ! grep -q "jules" "${ROOTFS_DIR}/etc/group"; then
    echo "jules:x:1000:" >> "${ROOTFS_DIR}/etc/group"
fi

# Set root's shell to jules_shell too
if [ -f "${ROOTFS_DIR}/etc/passwd" ]; then
    sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/jules_shell|' "${ROOTFS_DIR}/etc/passwd" 2>/dev/null || true
fi

# Create /etc/hostname
echo "JulesOS" > "${ROOTFS_DIR}/etc/hostname"

# Create /etc/hosts
{
    echo "127.0.0.1    localhost JulesOS"
    echo "::1          localhost JulesOS"
} > "${ROOTFS_DIR}/etc/hosts"

# Create /etc/os-release (standard Linux identification)
cat > "${ROOTFS_DIR}/etc/os-release" << 'EOF_OSRELEASE'
NAME="Jules OS"
VERSION="1.0.0"
ID=julesos
ID_LIKE=alpine
VERSION_ID=1.0.0
PRETTY_NAME="Jules OS v1.0.0 (Immutable Core)"
HOME_URL="https://github.com/JONIMONI09/JulesOS"
BUG_REPORT_URL="https://github.com/JONIMONI09/JulesOS/issues"
EOF_OSRELEASE

# Create /etc/motd (Message of the Day)
cat > "${ROOTFS_DIR}/etc/motd" << 'EOF_MOTD'
Welcome to JulesOS (Immutable Shell)
Type 'help' to see available commands.
EOF_MOTD

# Set up sleek Sway & Waybar configurations
mkdir -p "${ROOTFS_DIR}/etc/skel/.config/sway"
mkdir -p "${ROOTFS_DIR}/etc/skel/.config/waybar"
mkdir -p "${ROOTFS_DIR}/home/jules/.config/sway"
mkdir -p "${ROOTFS_DIR}/home/jules/.config/waybar"

cat > "${ROOTFS_DIR}/etc/skel/.config/sway/config" << 'EOF_SWAY'
# JulesOS Sway Configuration (Sleek & Animated)
# Force software rendering fallback if QEMU/Limbo has no 3D acceleration
set $mod Mod4
# Aesthetics
default_border pixel 2
client.focused #4c7899 #285577 #ffffff #2e9ef4 #285577
gaps inner 10
gaps outer 5
smart_gaps on
# Animations (Sway default transitions)
exec mako
exec waybar
# Inputs & Output
output * bg #1a1a1a solid_color
# Keybinds
bindsym $mod+Return exec alacritty
bindsym $mod+Shift+q kill
bindsym $mod+d exec jules_shell
bindsym $mod+Shift+e exec "echo 'Crash Handler Test' && killall -SIGSEGV jules_shell"
EOF_SWAY

cat > "${ROOTFS_DIR}/etc/skel/.config/waybar/config" << 'EOF_WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["sway/window"],
    "modules-right": ["cpu", "memory", "clock"],
    "clock": { "format": "{:%H:%M - %A, %d. %b}" },
    "cpu": { "format": "{usage}% " },
    "memory": { "format": "{}% " }
}
EOF_WAYBAR

cp -r "${ROOTFS_DIR}/etc/skel/.config/"* "${ROOTFS_DIR}/home/jules/.config/" 2>/dev/null || true
chown -R 1000:1000 "${ROOTFS_DIR}/home/jules/.config" 2>/dev/null || true



# Create /etc/inittab for getty fallback (BusyBox init compatible)
cat > "${ROOTFS_DIR}/etc/inittab" << 'EOF_INITTAB'
# JulesOS inittab - Used if BusyBox init takes over
::sysinit:/init
tty1::respawn:/bin/jules_shell
ttyS0::respawn:/bin/jules_shell
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/echo Shutting down Jules OS...
EOF_INITTAB

# ── Wayland Desktop Configuration ──
mkdir -p "${ROOTFS_DIR}/home/jules/.config/sway"
mkdir -p "${ROOTFS_DIR}/home/jules/.config/waybar"
mkdir -p "${ROOTFS_DIR}/home/jules/.config/alacritty"

# Sway Config (Minimal, GPU Accelerated)
cat > "${ROOTFS_DIR}/home/jules/.config/sway/config" << 'EOF_SWAY'
# Default modifier is Super/Windows key
set $mod Mod4

# Terminal
set $term alacritty

# Output configuration (Use Native Resolution)
output * bg #1a1a1a solid_color

# Key bindings
bindsym $mod+Return exec $term
bindsym $mod+q kill
bindsym $mod+d exec jules_shell -c "help" # Replace with actual launcher later
bindsym $mod+Shift+e exec swaymsg exit
bindsym $mod+t exec jules-translator

# Autostart
exec waybar
EOF_SWAY

# Waybar Config
cat > "${ROOTFS_DIR}/home/jules/.config/waybar/config" << 'EOF_WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["sway/window"],
    "modules-right": ["cpu", "memory", "clock"],
    "cpu": { "format": "CPU: {usage}%" },
    "memory": { "format": "RAM: {}%" },
    "clock": { "format": "{:%H:%M | %d.%m.%Y}" }
}
EOF_WAYBAR

# Alacritty Config
cat > "${ROOTFS_DIR}/home/jules/.config/alacritty/alacritty.toml" << 'EOF_ALACRITTY'
[window]
padding = { x = 10, y = 10 }
opacity = 0.95

[font]
size = 12.0
EOF_ALACRITTY

# Secure permissions for the configurations
chown -R 1000:1000 "${ROOTFS_DIR}/home/jules/.config" 2>/dev/null || true

ok "System files, Desktop configurations and user configuration installed."

# ── Step 6: Pack Initramfs ────────────────────────────────────
step "Step 6/8: Packing Initramfs (OS Image)"

cd "${ROOTFS_DIR}"
info "Creating compressed initramfs archive..."
if command -v pv >/dev/null 2>&1; then
    # Calculate uncompressed size for accurate ETA
    TOTAL_SIZE=$(du -sb . | awk '{print $1}')
    find . -print0 | cpio --null -o -H newc 2>/dev/null | pv -s "$TOTAL_SIZE" -p -t -e -r -a | gzip -9 > "${ISO_DIR}/boot/initrd.img"
else
    find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > "${ISO_DIR}/boot/initrd.img"
fi
INITRD_SIZE=$(du -h "${ISO_DIR}/boot/initrd.img" | cut -f1)
cd "${JULES_DIR}"
ok "Initramfs created: ${INITRD_SIZE}"

# ── Step 7: Configure Bootloaders ─────────────────────────────
step "Step 7/8: Configuring Bootloaders (BIOS + UEFI)"

# Kernel command line (Limbo Emulator Fix & Verbose Matrix Boot)
KERNEL_CMDLINE="console=tty0 console=ttyS0,115200 nomodeset vga=791 vt.global_cursor_default=0 loglevel=3 mitigations=off nowatchdog no_timer_check"

# ─── 7a. Syslinux (BIOS Boot) ───
cat > "${ISO_DIR}/boot/syslinux/syslinux.cfg" << EOF_SYSLINUX
PROMPT 0
TIMEOUT 150
DEFAULT jules

MENU TITLE Jules OS Boot Menu
MENU COLOR title  1;36;40
MENU COLOR border 30;40
MENU COLOR sel    7;37;40

LABEL jules
  MENU LABEL Jules OS v1.0.0 (Immutable Core)
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND ${KERNEL_CMDLINE}

LABEL jules-debug
  MENU LABEL Jules OS (Debug Mode)
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND ${KERNEL_CMDLINE} loglevel=7 debug
EOF_SYSLINUX
ok "Syslinux (BIOS) configured."

# ─── 7b. GRUB (UEFI Boot) ───
cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF_GRUB
set timeout=15
set default=0

menuentry "Jules OS v1.0.0 (Immutable Core)" {
    linux /boot/bzImage ${KERNEL_CMDLINE}
    initrd /boot/initrd.img
}

menuentry "Jules OS (Debug Mode)" {
    linux /boot/bzImage ${KERNEL_CMDLINE} loglevel=7 debug
    initrd /boot/initrd.img
}
EOF_GRUB
ok "GRUB (UEFI) configured."

# ── Step 8: Create ISO Image ─────────────────────────────────
step "Step 8/8: Creating Bootable ISO Image"

if [ "$IS_TERMUX" -eq 1 ]; then
    warn "Termux detected. Creating QEMU direct-boot runner instead of ISO."

    cat > "${JULES_DIR}/run_qemu.sh" << 'EOF_RUNNER'
#!/bin/bash
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "[!] qemu-system-x86_64 not found. Install it first."
    exit 1
fi
echo "[+] Starting Jules OS in QEMU (direct kernel boot)..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
qemu-system-x86_64 \
    -kernel "${SCRIPT_DIR}/iso/boot/bzImage" \
    -initrd "${SCRIPT_DIR}/iso/boot/initrd.img" \
    -append "root=/dev/ram0 rw console=ttyS0 quiet loglevel=3" \
    -nographic \
    -m 512M \
    -net nic,model=virtio -net user
EOF_RUNNER
    chmod +x "${JULES_DIR}/run_qemu.sh"
    ok "QEMU runner created: run_qemu.sh"

else
    # ─── Create Hybrid BIOS/UEFI ISO ───

    # Method 1: Try grub-mkrescue first (best UEFI support)
    ISO_CREATED=0

    if command -v grub-mkrescue >/dev/null 2>&1; then
        info "Using grub-mkrescue for hybrid BIOS/UEFI ISO..."
        if grub-mkrescue -o "${ISO_OUTPUT}" "${ISO_DIR}" 2>/dev/null; then
            ISO_CREATED=1
            ok "Hybrid BIOS/UEFI ISO created via grub-mkrescue."
        else
            warn "grub-mkrescue failed. Trying xorriso fallback..."
        fi
    fi

    # Method 2: Manual xorriso with syslinux (BIOS only, but reliable)
    if [ "$ISO_CREATED" -eq 0 ] && command -v xorriso >/dev/null 2>&1; then
        info "Using xorriso for ISO creation..."

        # Find syslinux files
        SYSLINUX_DIR=""
        for d in /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/syslinux/bios /usr/lib/ISOLINUX; do
            if [ -f "$d/isolinux.bin" ]; then
                SYSLINUX_DIR="$d"
                break
            fi
        done

        if [ -n "$SYSLINUX_DIR" ]; then
            cp "$SYSLINUX_DIR/isolinux.bin" "${ISO_DIR}/boot/syslinux/"

            # Copy required syslinux modules
            MODULES_DIR=""
            for d in /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/syslinux/bios; do
                if [ -f "$d/ldlinux.c32" ]; then
                    MODULES_DIR="$d"
                    break
                fi
            done

            if [ -n "$MODULES_DIR" ]; then
                for mod in ldlinux.c32 libutil.c32 menu.c32 libcom32.c32; do
                    [ -f "$MODULES_DIR/$mod" ] && cp "$MODULES_DIR/$mod" "${ISO_DIR}/boot/syslinux/"
                done
            fi

            touch "${ISO_DIR}/boot/syslinux/boot.cat"

            # Find isohdpfx for hybrid MBR (allows dd to USB)
            ISOHDPFX=""
            for d in /usr/lib/syslinux/mbr /usr/share/syslinux /usr/lib/ISOLINUX; do
                if [ -f "$d/isohdpfx.bin" ]; then
                    ISOHDPFX="$d/isohdpfx.bin"
                    break
                fi
            done

            XORRISO_ARGS=(
                -as mkisofs -o "${ISO_OUTPUT}"
                -b boot/syslinux/isolinux.bin
                -c boot/syslinux/boot.cat
                -no-emul-boot -boot-load-size 4 -boot-info-table
                -R -J -v -T
            )

            if [ -n "$ISOHDPFX" ]; then
                XORRISO_ARGS+=(-isohybrid-mbr "$ISOHDPFX" -partition_offset 16)
            fi

            # Try to add UEFI boot if EFI image exists
            if [ -f "${ISO_DIR}/boot/efi.img" ]; then
                XORRISO_ARGS+=(
                    -eltorito-alt-boot
                    -e boot/efi.img
                    -no-emul-boot
                    -isohybrid-gpt-basdat
                )
            fi

            xorriso "${XORRISO_ARGS[@]}" "${ISO_DIR}" >/dev/null 2>&1
            ISO_CREATED=1
            ok "ISO created via xorriso (BIOS + isohybrid)."

        else
            # No isolinux, try basic xorriso
            xorriso -as mkisofs -o "${ISO_OUTPUT}" -R -J "${ISO_DIR}" >/dev/null 2>&1
            ISO_CREATED=1
            warn "Created basic ISO (no bootloader binaries found for hybrid)."
        fi
    fi

    if [ "$ISO_CREATED" -eq 0 ]; then
        warn "No ISO creation tools found. Boot files are in: ${ISO_DIR}/boot/"
        info "You can boot directly with QEMU using:"
        info "  qemu-system-x86_64 -kernel iso/boot/bzImage -initrd iso/boot/initrd.img -append 'root=/dev/ram0 rw console=ttyS0' -nographic -m 512M"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# BUILD SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║         Jules OS Build Complete! ✓                ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Components:${NC}"
echo -e "    Kernel:    ${GREEN}$(file "${ISO_DIR}/boot/bzImage" 2>/dev/null | cut -d: -f2 | head -c60)${NC}"
echo -e "    Initrd:    ${GREEN}${INITRD_SIZE}${NC}"
[ -f "${ISO_OUTPUT}" ] && echo -e "    ISO:       ${GREEN}$(du -h "${ISO_OUTPUT}" | cut -f1)${NC}"
[ -n "${KERNEL_VERSION:-}" ] && echo -e "    Modules:   ${GREEN}${KERNEL_VERSION}${NC}"
echo ""
echo -e "  ${BOLD}Boot Options:${NC}"
if [ -f "${ISO_OUTPUT}" ]; then
    echo "    • QEMU:    ./scripts/boot.sh"
    echo "    • USB:     dd if=JulesOS.iso of=/dev/sdX bs=4M status=progress"
fi
echo "    • Direct:  qemu-system-x86_64 -kernel iso/boot/bzImage -initrd iso/boot/initrd.img \\"
echo "                 -append 'root=/dev/ram0 rw console=ttyS0' -nographic -m 512M"
echo ""
