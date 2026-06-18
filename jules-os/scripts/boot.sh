#!/bin/bash

JULES_DIR="$(pwd)"
ISO_PATH="${JULES_DIR}/JulesOS.iso"
DATA_IMG="${JULES_DIR}/data.img"
RAM_SIZE="512" # Megabytes
CORES="2"

echo "================================================"
echo "          Booting Jules OS (QEMU)               "
echo "================================================"

if [ ! -f "${ISO_PATH}" ]; then
    echo "[!] Error: JulesOS.iso not found! Run ./scripts/build.sh first."
    # do not exit, just return
    # shellcheck disable=SC2317
    return 1 2>/dev/null || exit 1
fi

# Create a persistent data vault if it doesn't exist
if [ ! -f "${DATA_IMG}" ]; then
    echo "[+] Creating Persistent Data Vault (data.img, 1GB)..."
    qemu-img create -f qcow2 "${DATA_IMG}" 1G
    # Note: Formatting happens inside the guest if needed, but for now
    # we just provide the block device. A more advanced init.sh would mkfs.ext4 it.
fi

# Detect Architecture for Termux / PC Compatibility
ARCH=$(uname -m)
QEMU_CMD="qemu-system-x86_64"

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "[i] ARM Architecture detected. Using software emulation for x86_64..."
    # On Android Termux, hardware acceleration for x86 on ARM isn't natively possible without root/KVM.
    ACCEL="-machine q35"
else
    echo "[i] x86_64 Architecture detected."
    # Try to enable hardware acceleration if available (KVM on Linux, HVF on macOS)
    if [ -e /dev/kvm ]; then
        ACCEL="-enable-kvm -cpu host"
        echo "[i] KVM Hardware Acceleration Enabled."
    else
        ACCEL="-machine q35 -cpu max"
        echo "[i] No KVM detected. Using software virtualization."
    fi
fi

echo "[+] Launching Jules OS..."
echo "------------------------------------------------"
echo "Press Ctrl+A, then X to exit QEMU."
echo "------------------------------------------------"

# Run QEMU Headless (ncurses/serial) for Termux compatibility
# -nographic maps the serial console directly to the terminal
# shellcheck disable=SC2086
$QEMU_CMD $ACCEL \
    -m ${RAM_SIZE} \
    -smp ${CORES} \
    -cdrom "${ISO_PATH}" \
    -drive file="${DATA_IMG}",format=qcow2,if=virtio \
    -net nic,model=virtio -net user \
    -nographic \
    -no-reboot

echo "================================================"
echo "[+] Jules OS Shutdown Complete."
echo "================================================"
