#!/bin/bash
set -e

# Configuration
JULES_DIR="$(pwd)"
BUILD_DIR="${JULES_DIR}/build"
ISO_DIR="${JULES_DIR}/iso"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
KERNEL_VERSION="3.21.2" # Alpine branch
ALPINE_TAR="alpine-minirootfs-3.21.2-x86_64.tar.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/${ALPINE_TAR}"

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
cmake ..
make -j$(nproc)
cd "${JULES_DIR}"

# 2. Download Alpine Minirootfs (The Real Linux Base)
echo "[+] Fetching minimal Linux RootFS (Alpine)..."
wget -qO "${BUILD_DIR}/${ALPINE_TAR}" "${ALPINE_URL}"

# Extract RootFS
echo "[+] Extracting RootFS..."
mkdir -p "${ROOTFS_DIR}"
tar -xf "${BUILD_DIR}/${ALPINE_TAR}" -C "${ROOTFS_DIR}"

# 3. Integrate Jules Shell and Initialization Scripts
echo "[+] Integrating Jules OS Core files into RootFS..."
# Place the compiled C++ shell into the OS
cp "${BUILD_DIR}/jules_shell" "${ROOTFS_DIR}/bin/jules_shell"
chmod +x "${ROOTFS_DIR}/bin/jules_shell"

# Place our init script as the main boot script
cp "${JULES_DIR}/scripts/init.sh" "${ROOTFS_DIR}/init"
chmod +x "${ROOTFS_DIR}/init"

# Symlink so standard tools find our shell if needed
ln -sf /bin/jules_shell "${ROOTFS_DIR}/bin/sh" 2>/dev/null || true

# Pre-install some networking / system configs in the rootfs
# We mount standard directories so 'apk' or scripts work easily inside if chrooted
mkdir -p "${ROOTFS_DIR}/home"

# 4. We need a Kernel.
# Since compiling a kernel from source takes ~1-2 hours, we will fetch Alpine's pre-compiled 'virt' kernel
# which is perfect and extremely fast for QEMU/Termux.
echo "[+] Fetching pre-compiled Linux Kernel (Alpine virt-kernel)..."
mkdir -p "${BUILD_DIR}/kernel_pkg"
cd "${BUILD_DIR}/kernel_pkg"
# Find the exact kernel package version
KERNEL_PKG_URL=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/v3.21/main/x86_64/ | grep -o 'linux-virt-[0-9].*\.apk' | tail -n 1)
wget -q "https://dl-cdn.alpinelinux.org/alpine/v3.21/main/x86_64/${KERNEL_PKG_URL}"
tar -zxf "${KERNEL_PKG_URL}"
cp boot/vmlinuz-virt "${ISO_DIR}/boot/bzImage"

# We don't use their initramfs, we pack our own!
cd "${JULES_DIR}"

# 5. Pack our RootFS into a bootable Initramfs
echo "[+] Packing Jules OS RootFS (Initramfs)..."
cd "${ROOTFS_DIR}"
find . | cpio -o -H newc | gzip -9 > "${ISO_DIR}/boot/initrd.img"
cd "${JULES_DIR}"

# 6. Configure the Bootloader (Syslinux/Isolinux)
echo "[+] Configuring Syslinux (Invisible Boot)..."
mkdir -p "${ISO_DIR}/boot/syslinux"
cat << 'EOF_SYSLINUX' > "${ISO_DIR}/boot/syslinux/syslinux.cfg"
DEFAULT jules
LABEL jules
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  # quiet loglevel=0 console=ttyS0 makes it "invisible" on the screen (fast boot)
  APPEND root=/dev/ram0 rw console=ttyS0 quiet loglevel=0
EOF_SYSLINUX

# 7. Create the bootable ISO
echo "[+] Creating Bootable ISO Image (JulesOS.iso)..."
# We use xorriso to create an ISO that boots on legacy and EFI (via isohybrid)
# Using a simplified xorriso command for syslinux
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${ISO_DIR}/boot/syslinux/"
cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/boot/syslinux/" 2>/dev/null || cp /usr/lib/syslinux/modules/bios/isolinux.bin "${ISO_DIR}/boot/syslinux/"

xorriso -as mkisofs -o JulesOS.iso \
  -b boot/syslinux/isolinux.bin \
  -c boot/syslinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -R -J -v -T "${ISO_DIR}" >/dev/null 2>&1

echo "================================================"
echo "[SUCCESS] Jules OS built successfully!"
echo "[SUCCESS] Image: $(pwd)/JulesOS.iso"
echo "[SUCCESS] Run ./scripts/boot.sh to test it!"
echo "================================================"
