#!/bin/sh
#
# jules_init - The core orchestrator for the indestructible Jules OS.

# Ensure critical filesystems are mounted
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs -o size=256m,mode=1777 tmpfs /tmp
mount -t tmpfs -o mode=0755 none /run

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
    if ! mount "$VAULT_DEV" /home 2>/dev/null; then
        echo "[ INFO ] Formatting new Vault at $VAULT_DEV..."
        mkfs.ext4 -F "$VAULT_DEV" 2>/dev/null || mkfs.vfat "$VAULT_DEV" 2>/dev/null
        mount "$VAULT_DEV" /home
    fi
    echo "[ OK ] Vault Mounted at /home."
else
    echo "[ WARN ] Vault not found. Using ephemeral /home."
    mount -t tmpfs tmpfs /home
fi

# Create some basic structure in /home
mkdir -p /home/jules
if [ ! -f /home/jules/.profile ]; then
    echo "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" > /home/jules/.profile
    echo "export HOME=/home/jules" >> /home/jules/.profile
    echo "alias ls='ls --color=auto'" >> /home/jules/.profile
    echo "alias ll='ls -lah --color=auto'" >> /home/jules/.profile
    echo "alias grep='grep --color=auto'" >> /home/jules/.profile
    echo "PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /home/jules/.profile
fi

export HOME=/home/jules
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd /home/jules

# Apply performance tuning
echo "[ OK ] Applying Jules OS Tuning..."
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/overcommit_memory
echo 10 > /proc/sys/vm/swappiness

# Start the Jules Shell directly
echo "[ OK ] Handing over control to Jules Shell (C++ Core)..."
exec /bin/jules_shell
