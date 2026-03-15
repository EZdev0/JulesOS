#!/bin/bash
set -e

# Configuration
JULES_DIR="$(pwd)"
BUILD_DIR="${JULES_DIR}/build"
ISO_DIR="${JULES_DIR}/iso"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ALPINE_VERSION="3.21"
ALPINE_RELEASE="3.21.2"
ALPINE_TAR="alpine-minirootfs-${ALPINE_RELEASE}-x86_64.tar.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/${ALPINE_TAR}"

echo "================================================"
echo "      Building Jules OS (No Simulation)         "
echo "================================================"

# Clean previous builds
echo "[+] Cleaning previous build artifacts..."
rm -rf "${BUILD_DIR}" "${ISO_DIR}"
mkdir -p "${BUILD_DIR}" "${ISO_DIR}/boot" "${ROOTFS_DIR}"

# 1. Compile the Jules Shell (C++)
echo "[+] Compiling Jules Shell (C++ Core)..."
cd "${BUILD_DIR}"
# Detect if we should try static linking
if ld --help | grep -q "static"; then
    STATIC_OPT="-DSTATIC_BUILD=ON"
else
    STATIC_OPT="-DSTATIC_BUILD=OFF"
fi
cmake ${STATIC_OPT} ..
make -j$(nproc)
cd "${JULES_DIR}"

# 2. Download Alpine Minirootfs
echo "[+] Fetching minimal Linux RootFS (Alpine)..."
if [ ! -f "${BUILD_DIR}/${ALPINE_TAR}" ]; then
    wget -qO "${BUILD_DIR}/${ALPINE_TAR}" "${ALPINE_URL}"
fi

# Extract RootFS
echo "[+] Extracting RootFS..."
mkdir -p "${ROOTFS_DIR}"
tar -xf "${BUILD_DIR}/${ALPINE_TAR}" -C "${ROOTFS_DIR}"

# 3. Integrate Jules OS Core files into RootFS
echo "[+] Integrating Jules OS Core files into RootFS..."
cp "${BUILD_DIR}/jules_shell" "${ROOTFS_DIR}/bin/jules_shell"
chmod +x "${ROOTFS_DIR}/bin/jules_shell"

# If it's a dynamic build, we need to copy libraries if we are on a compatible system
# But usually, it's better to just build it statically for the ISO.
# On Termux, building static might be hard, so we warn the user.
if [ "$(ldd "${BUILD_DIR}/jules_shell" 2>/dev/null | grep "not a dynamic executable")" == "" ]; then
    echo "[!] WARNING: Jules Shell is dynamically linked. It might not run in the Guest OS."
    echo "[!] Consider installing static-libs (e.g., 'pkg install static-libs' on Termux if available)."
fi

# Place our init script
cp "${JULES_DIR}/scripts/init.sh" "${ROOTFS_DIR}/init"
chmod +x "${ROOTFS_DIR}/init"

# Ensure /home and other dirs exist
mkdir -p "${ROOTFS_DIR}/home"
mkdir -p "${ROOTFS_DIR}/root"
mkdir -p "${ROOTFS_DIR}/etc/apk"

# 4. Fetch Kernel
echo "[+] Fetching pre-compiled Linux Kernel (Alpine virt-kernel)..."
mkdir -p "${BUILD_DIR}/kernel_pkg"
cd "${BUILD_DIR}/kernel_pkg"
KERNEL_PKG_URL=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/ | grep -o 'linux-virt-[0-9].*\.apk' | head -n 1)
wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/${KERNEL_PKG_URL}"
tar -zxf "${KERNEL_PKG_URL}"
cp boot/vmlinuz-virt "${ISO_DIR}/boot/bzImage"
cd "${JULES_DIR}"

# 5. Pack Initramfs
echo "[+] Packing Jules OS RootFS (Initramfs)..."
cd "${ROOTFS_DIR}"
find . | cpio -o -H newc | gzip -9 > "${ISO_DIR}/boot/initrd.img"
cd "${JULES_DIR}"

# 6. Configure Bootloader
echo "[+] Configuring Syslinux..."
mkdir -p "${ISO_DIR}/boot/syslinux"
cat << 'EOF_SYSLINUX' > "${ISO_DIR}/boot/syslinux/syslinux.cfg"
DEFAULT jules
LABEL jules
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND root=/dev/ram0 rw console=ttyS0 quiet loglevel=0
EOF_SYSLINUX

# 7. Create ISO
echo "[+] Creating Bootable ISO Image (JulesOS.iso)..."
# Check for xorriso
if command -v xorriso >/dev/null 2>&1; then
    # Try to find syslinux files in common locations
    SYSLINUX_DIR=""
    for d in /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/ISOLINUX /usr/lib/syslinux/bios; do
        if [ -f "$d/isolinux.bin" ]; then
            SYSLINUX_DIR="$d"
            break
        fi
    done

    if [ -n "$SYSLINUX_DIR" ]; then
        cp "$SYSLINUX_DIR/isolinux.bin" "${ISO_DIR}/boot/syslinux/"
        [ -f "$SYSLINUX_DIR/ldlinux.c32" ] && cp "$SYSLINUX_DIR/ldlinux.c32" "${ISO_DIR}/boot/syslinux/"

        xorriso -as mkisofs -o JulesOS.iso \
          -b boot/syslinux/isolinux.bin \
          -c boot/syslinux/boot.cat \
          -no-emul-boot -boot-load-size 4 -boot-info-table \
          -R -J -v -T "${ISO_DIR}" >/dev/null 2>&1
        echo "[SUCCESS] JulesOS.iso created."
    else
        echo "[!] WARNING: isolinux.bin not found. ISO might not be bootable."
        echo "[!] Creating a non-bootable ISO for inspection..."
        xorriso -as mkisofs -o JulesOS.iso -R -J "${ISO_DIR}" >/dev/null 2>&1
    fi
else
    echo "[!] xorriso not found. Skipping ISO creation."
    echo "[i] You can still use the files in ${ISO_DIR}/boot with QEMU directly."
fi

echo "================================================"
echo "[SUCCESS] Build process finished."
echo "================================================"
