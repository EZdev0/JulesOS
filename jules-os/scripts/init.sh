#!/bin/sh
#
# jules_init - The core orchestrator for the indestructible Jules OS.

# Ensure critical filesystems are mounted
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs -o size=512m tmpfs /tmp
mount -t tmpfs -o mode=1777 none /run

# Set hostname to JulesOS
hostname JulesOS

echo "[ OK ] Mounting Core Filesystems..."
echo "[ OK ] Jules OS Initializing Unbreakable Layer..."

# Ensure network is up (DHCP via eth0 for QEMU)
echo "[ OK ] Bringing up network interface (eth0)..."
ip link set lo up
ip link set eth0 up 2>/dev/null
udhcpc -i eth0 -n -q 2>/dev/null

# Set up DNS resolution
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Setup Alpine Repositories for apk
if [ -f /etc/alpine-release ]; then
    ALPINE_VERSION=$(cut -d. -f1,2 /etc/alpine-release)
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" > /etc/apk/repositories
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> /etc/apk/repositories
fi

# Mount the Persistent Data Vault
echo "[ OK ] Scanning for Persistent Vault..."
VAULT_DEV=""
for dev in /dev/vda2 /dev/sda2 /dev/vdb /dev/sdb; do
    if [ -b "$dev" ]; then
        VAULT_DEV=$dev
        break
    fi
done

if [ -n "$VAULT_DEV" ]; then
    # Try to mount, if it fails, format it (assuming it is a new data.img)
    if ! mount "$VAULT_DEV" /home 2>/dev/null; then
        echo "[ INFO ] Formatting new Vault at $VAULT_DEV..."
        # We need to make sure mkfs.ext4 is available, usually it is in alpine minirootfs if e2fsprogs is installed
        # If not, we might need to add it to the rootfs during build
        mkfs.ext4 -F "$VAULT_DEV"
        mount "$VAULT_DEV" /home
    fi
    echo "[ OK ] Vault Mounted at /home."
else
    echo "[ WARN ] Vault not found. Using ephemeral /home."
    mount -t tmpfs tmpfs /home
fi

# Apply performance tuning
echo "[ OK ] Applying Jules OS Tuning..."
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/overcommit_memory

# Create some basic structure in /home if empty
if [ ! -d /home/jules ]; then
    mkdir -p /home/jules
    echo "Welcome to Jules OS!" > /home/jules/README.txt
fi
export HOME=/home/jules
cd /home/jules

# Start the Jules Shell directly on TTY1
echo "[ OK ] Handing over control to Jules Shell (C++ Core)..."
exec /bin/jules_shell
