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

# Termux Detection
IS_TERMUX=0
if [[ "$PREFIX" == *"termux"* ]]; then
    IS_TERMUX=1
    echo "[!] Termux environment detected. Adapting build process for non-root execution."
fi

# Dependency Checks
for cmd in wget tar cpio gzip cmake make; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "[ERROR] Required command '$cmd' is missing."
        if [ "$IS_TERMUX" -eq 1 ]; then
            echo "-> Run: pkg install $cmd"
        else
            echo "-> Please install it before continuing."
        fi
        exit 1
    fi
done

echo "================================================"
echo "      Building Jules OS (Enhanced Version)      "
echo "================================================"

# Clean previous builds
echo "[+] Cleaning previous build artifacts..."
rm -rf "${BUILD_DIR}" "${ISO_DIR}"
mkdir -p "${BUILD_DIR}" "${ISO_DIR}/boot" "${ROOTFS_DIR}"

# 1. Compile the Jules Shell (C++)
echo "[+] Compiling Jules Shell (C++ Core)..."
cd "${BUILD_DIR}"
if [ "$IS_TERMUX" -eq 1 ]; then
    STATIC_OPT="-DSTATIC_BUILD=OFF"
elif ld --help 2>&1 | grep -q "static"; then
    STATIC_OPT="-DSTATIC_BUILD=ON"
else
    STATIC_OPT="-DSTATIC_BUILD=OFF"
fi
cmake ${STATIC_OPT} ..
make -j"$(nproc)"
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

# 3. Add essential packages to rootfs using chroot if possible,
# but for simplicity we will rely on init.sh installing them on first boot
# or we just ensure the basics are there.
# Minirootfs already has apk.

# 4. Integrate Jules OS Core files into RootFS
echo "[+] Integrating Jules OS Core files into RootFS..."
cp "${BUILD_DIR}/jules_shell" "${ROOTFS_DIR}/bin/jules_shell"
chmod +x "${ROOTFS_DIR}/bin/jules_shell"

# Place our init script
cp "${JULES_DIR}/scripts/init.sh" "${ROOTFS_DIR}/init"
chmod +x "${ROOTFS_DIR}/init"

# Ensure directories exist
mkdir -p "${ROOTFS_DIR}/home"
mkdir -p "${ROOTFS_DIR}/root"
mkdir -p "${ROOTFS_DIR}/etc/apk"

# Set up repositories in rootfs so apk works immediately
echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" > "${ROOTFS_DIR}/etc/apk/repositories"
echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> "${ROOTFS_DIR}/etc/apk/repositories"

# 5. Fetch Kernel
echo "[+] Fetching pre-compiled Linux Kernel (Alpine virt-kernel)..."
mkdir -p "${BUILD_DIR}/kernel_pkg"
cd "${BUILD_DIR}/kernel_pkg"
KERNEL_PKG_URL=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/ | grep -oE 'linux-virt-[0-9][a-zA-Z0-9.-]*\.apk' | head -n 1)
wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/x86_64/${KERNEL_PKG_URL}"
tar -zxf "${KERNEL_PKG_URL}" || true
if [ -f boot/vmlinuz-virt ]; then
    cp boot/vmlinuz-virt "${ISO_DIR}/boot/bzImage"
    echo "[OK] Kernel (vmlinuz-virt) successfully extracted."
else
    echo "[ERROR] Kernel file not found in the downloaded package!"
    exit 1
fi
cd "${JULES_DIR}"

# 6. Pack Initramfs
echo "[+] Packing Jules OS RootFS (Initramfs)..."
cd "${ROOTFS_DIR}"
find . -print0 | cpio --null -o -H newc | gzip -9 > "${ISO_DIR}/boot/initrd.img"
cd "${JULES_DIR}"

# 7. Configure Bootloader
echo "[+] Configuring Syslinux..."
mkdir -p "${ISO_DIR}/boot/syslinux"
cat << 'EOF_SYSLINUX' > "${ISO_DIR}/boot/syslinux/syslinux.cfg"
DEFAULT jules
LABEL jules
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND root=/dev/ram0 rw console=ttyS0 quiet loglevel=0 mitigations=off nowatchdog no_timer_check
EOF_SYSLINUX

# 8. Create ISO
echo "[+] Creating Bootable ISO Image (JulesOS.iso)..."
if [ "$IS_TERMUX" -eq 1 ]; then
    echo "[i] Skipping ISO creation under Termux (not strictly required)."
    echo "[+] Creating QEMU runner script for Termux (run_qemu.sh)..."
    cat << 'EOF_RUNNER' > run_qemu.sh
#!/bin/bash
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "[!] qemu-system-x86_64 not found. Install it before continuing."
    exit 1
fi

echo "[+] Starting Jules OS in QEMU..."
qemu-system-x86_64 \
    -kernel iso/boot/bzImage \
    -initrd iso/boot/initrd.img \
    -append "root=/dev/ram0 rw console=ttyS0 quiet loglevel=0 mitigations=off nowatchdog no_timer_check" \
    -nographic \
    -m 512M
EOF_RUNNER
    chmod +x run_qemu.sh
    echo "[SUCCESS] Build process finished. Run './run_qemu.sh' to start Jules OS."
else
    if command -v xorriso >/dev/null 2>&1; then
    SYSLINUX_DIR=""
    for d in /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/ISOLINUX /usr/lib/syslinux/bios /usr/lib/syslinux/modules/bios; do
        if [ -f "$d/isolinux.bin" ]; then
            SYSLINUX_DIR="$d"
            break
        fi
    done

    if [ -n "$SYSLINUX_DIR" ]; then
        cp "$SYSLINUX_DIR/isolinux.bin" "${ISO_DIR}/boot/syslinux/"

        # Make sure to copy ALL necessary syslinux module files.
        MODULES_DIR=""
        for d in /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/syslinux/bios; do
            if [ -f "$d/ldlinux.c32" ]; then
                MODULES_DIR="$d"
                break
            fi
        done

        if [ -n "$MODULES_DIR" ]; then
            cp "$MODULES_DIR/ldlinux.c32" "${ISO_DIR}/boot/syslinux/"
            [ -f "$MODULES_DIR/libutil.c32" ] && cp "$MODULES_DIR/libutil.c32" "${ISO_DIR}/boot/syslinux/"
            [ -f "$MODULES_DIR/menu.c32" ] && cp "$MODULES_DIR/menu.c32" "${ISO_DIR}/boot/syslinux/"
            [ -f "$MODULES_DIR/libcom32.c32" ] && cp "$MODULES_DIR/libcom32.c32" "${ISO_DIR}/boot/syslinux/"
        fi

        # also create boot.cat in syslinux directory
        touch "${ISO_DIR}/boot/syslinux/boot.cat"


        ISOHDPFX=""
        for d in /usr/lib/syslinux/mbr /usr/share/syslinux /usr/lib/ISOLINUX; do
            if [ -f "$d/isohdpfx.bin" ]; then
                ISOHDPFX="$d/isohdpfx.bin"
                break
            fi
        done

        if [ -n "$ISOHDPFX" ]; then
            xorriso -as mkisofs -o JulesOS.iso \
              -b boot/syslinux/isolinux.bin \
              -c boot/syslinux/boot.cat \
              -no-emul-boot -boot-load-size 4 -boot-info-table \
              -isohybrid-mbr "$ISOHDPFX" -partition_offset 16 \
              -R -J -v -T "${ISO_DIR}" >/dev/null 2>&1
        else
            echo "[i] isohdpfx.bin not found. Building without isohybrid-mbr."
            xorriso -as mkisofs -o JulesOS.iso \
              -b boot/syslinux/isolinux.bin \
              -c boot/syslinux/boot.cat \
              -no-emul-boot -boot-load-size 4 -boot-info-table \
              -R -J -v -T "${ISO_DIR}" >/dev/null 2>&1
        fi

        echo "[SUCCESS] JulesOS.iso created."


    else
        xorriso -as mkisofs -o JulesOS.iso -R -J "${ISO_DIR}" >/dev/null 2>&1
        echo "[i] Created non-bootable ISO (missing isolinux.bin)."
    fi
else
    echo "[!] xorriso not found. Skipping ISO creation."
fi

    echo "================================================"
    echo "[SUCCESS] Build process finished."
    echo "================================================"
fi
