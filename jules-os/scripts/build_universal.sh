#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# JulesOS Universal Multi-Arch Builder
# Creates a bootable ISO containing x86, x86_64, and aarch64.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

JULES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UNIVERSAL_DIR="${JULES_DIR}/universal_build"
ISO_DIR="${UNIVERSAL_DIR}/iso"

echo "================================================"
echo "  Building Universal ISO (x86, x86_64, aarch64) "
echo "================================================"

rm -rf "${UNIVERSAL_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

ARCHS="x86_64 x86 aarch64"

for ARCH in $ARCHS; do
    echo ">>> Building Architecture: $ARCH"
    
    mkdir -p "${JULES_DIR}/build"
    if [ -f "${JULES_DIR}/binaries/${ARCH}/jules_shell" ]; then
        cp "${JULES_DIR}/binaries/${ARCH}/jules_shell" "${JULES_DIR}/build/jules_shell"
        echo "✅ Using pre-compiled binary for $ARCH"
    fi
    
    bash "${JULES_DIR}/scripts/build.sh" "$ARCH" || {
        echo "❌ Build failed for $ARCH"
        exit 1
    }
    
    mkdir -p "${ISO_DIR}/boot/${ARCH}"
    cp "${JULES_DIR}/iso/boot/bzImage" "${ISO_DIR}/boot/${ARCH}/bzImage"
    cp "${JULES_DIR}/iso/boot/initrd.img" "${ISO_DIR}/boot/${ARCH}/initrd.img"
    echo "✅ Placed $ARCH binaries in Universal ISO structure."
done

echo ">>> Creating Universal GRUB Configuration..."
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF_GRUB'
set timeout=15
set default=0

# Detect CPU Architecture
if [ "${grub_cpu}" = "x86_64" ]; then
    set target_arch="x86_64"
    set console_param="console=ttyS0"
elif [ "${grub_cpu}" = "i386" ]; then
    set target_arch="x86"
    set console_param="console=ttyS0"
elif [ "${grub_cpu}" = "arm64" ]; then
    set target_arch="aarch64"
    set console_param="console=ttyAMA0"
else
    # Fallback
    set target_arch="x86_64"
    set console_param="console=ttyS0"
fi

menuentry "Jules OS Universal (Auto-Detect: ${grub_cpu})" {
    echo "Loading Jules OS for ${target_arch}..."
    linux /boot/${target_arch}/bzImage root=/dev/ram0 rw ${console_param} quiet loglevel=3 mitigations=off
    initrd /boot/${target_arch}/initrd.img
}

menuentry "Jules OS Universal (Debug Mode)" {
    echo "Loading Jules OS Debug for ${target_arch}..."
    linux /boot/${target_arch}/bzImage root=/dev/ram0 rw ${console_param} loglevel=7 debug mitigations=off
    initrd /boot/${target_arch}/initrd.img
}
EOF_GRUB

echo ">>> Generating JulesOS-Universal.iso using grub-mkrescue..."
if command -v grub-mkrescue >/dev/null 2>&1; then
    grub-mkrescue -o "${JULES_DIR}/JulesOS-Universal.iso" "${ISO_DIR}" 2>/dev/null
    
    if [ -f "${JULES_DIR}/JulesOS-Universal.iso" ]; then
        echo "================================================"
        echo "✅ JulesOS-Universal.iso created successfully!"
        echo "================================================"
        ls -lh "${JULES_DIR}/JulesOS-Universal.iso"
    else
        echo "❌ ISO generation failed."
        exit 1
    fi
else
    echo "❌ grub-mkrescue not found! Please install grub-pc-bin, grub-efi-amd64-bin, grub-efi-ia32-bin, and grub-efi-arm64-bin."
    exit 1
fi
