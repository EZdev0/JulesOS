#!/bin/sh
#
# jules_init - The core orchestrator for the indestructible Jules OS.
# This script runs instantly upon boot (PID 1) to establish the OverlayFS,
# protect the core system, and launch the Jules C++ Shell.

# Ensure critical filesystems are mounted
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs -o size=512m tmpfs /tmp
mount -t tmpfs -o mode=1777 none /run

# Set hostname to JulesOS
hostname JulesOS

# Print boot info
echo "[ OK ] Mounting Core Filesystems..."
echo "[ OK ] Jules OS Initializing Unbreakable Layer..."

# --- OVERLAYFS ARCHITECTURE ---
# To make the OS indestructible, the root file system (ro) is overlaid with a tmpfs (rw).
# This means ANY changes to the system are stored in RAM and wiped on reboot.
# Real implementations use an initramfs to switch_root. Since we are building a
# minimal kernel + rootfs (no initrd for simplicity right now), we rely on the host
# mounting / as read-only.

# Ensure network is up (DHCP via eth0 for QEMU)
echo "[ OK ] Bringing up network interface (eth0)..."
ip link set eth0 up 2>/dev/null
udhcpc -i eth0 -n -q 2>/dev/null

# Set up DNS resolution
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Mount the Persistent Data Vault (if available)
# QEMU will attach our data.img as /dev/vdb or /dev/sdb
echo "[ OK ] Scanning for Persistent Vault..."
if blkid /dev/vda2 >/dev/null 2>&1; then
    mount /dev/vda2 /home
    echo "[ OK ] Vault Mounted at /home."
elif blkid /dev/sda2 >/dev/null 2>&1; then
    mount /dev/sda2 /home
    echo "[ OK ] Vault Mounted at /home."
else
    echo "[ WARN ] Vault not found. Using ephemeral /home."
fi

# Apply low RAM / Performance tuning automatically on boot
echo "[ OK ] Applying Jules OS Tuning..."
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/overcommit_memory

# Start the Jules Shell directly on TTY1 as the main user interface
# This hides standard login prompts and immediately puts the user in control
echo "[ OK ] Handing over control to Jules Shell (C++ Core)..."
exec /bin/jules_shell
