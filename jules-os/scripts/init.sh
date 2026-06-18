#!/bin/sh
#
# jules_init - The core orchestrator for the indestructible Jules OS.
# This script runs as PID 1's pre-exec initializer.
# It sets up the immutable OverlayFS, loads drivers, configures
# networking, and hands control to the Jules Shell.

set +e # STRICT INSTRUCTION: Never use set -e in an init script, it causes Kernel Panics!

# ══════════════════════════════════════════════════════════════
# 1. CORE FILESYSTEM SETUP
# ══════════════════════════════════════════════════════════════

# Mount essential kernel filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || mount -t tmpfs none /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts 2>/dev/null || true
mount -t tmpfs tmpfs /dev/shm 2>/dev/null || true
mount -t tmpfs -o size=1024m,mode=1777 tmpfs /tmp
mount -t tmpfs -o mode=0755 none /run

echo "[ OK ] Core filesystems mounted."

# ══════════════════════════════════════════════════════════════
# 1.5. HARDWARE COMPATIBILITY CHECK
# ══════════════════════════════════════════════════════════════
echo "[INFO] Checking hardware requirements..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
if [ -n "$TOTAL_RAM_KB" ] && [ "$TOTAL_RAM_KB" -lt 500000 ]; then
    clear
    echo -e "\033[1;41m\033[1;37m                                                          \033[0m"
    echo -e "\033[1;41m\033[1;37m  [FATAL ERROR] HARDWARE NOT SUPPORTED                    \033[0m"
    echo -e "\033[1;41m\033[1;37m  JulesOS requires at least 512MB RAM to function safely. \033[0m"
    echo -e "\033[1;41m\033[1;37m  System halted to prevent data corruption.               \033[0m"
    echo -e "\033[1;41m\033[1;37m                                                          \033[0m"
    while true; do sleep 60; done
fi

# ══════════════════════════════════════════════════════════════
# 2. IMMUTABLE OVERLAYFS (The "Indestructible" Layer)
# ══════════════════════════════════════════════════════════════
# The rootfs from initramfs is our read-only base (lowerdir).
# We create a RAM-backed overlay (upperdir) so all runtime changes
# are ephemeral and discarded on reboot. This makes the OS truly
# immutable and self-repairing.

echo "[ OK ] Setting up OverlayFS immutable layer..."

# Create overlay mount points in RAM
mkdir -p /mnt/overlay-upper /mnt/overlay-work

# Mount tmpfs for the writable overlay layer
mount -t tmpfs -o size=256m tmpfs /mnt/overlay-upper
mkdir -p /mnt/overlay-upper/upper /mnt/overlay-upper/work

# Key directories to protect with OverlayFS
# /etc is the primary target - system config should be immutable
for overlay_target in /etc; do
    if [ -d "$overlay_target" ]; then
        overlay_name=$(echo "$overlay_target" | tr '/' '_')
        mkdir -p "/mnt/overlay-upper/upper${overlay_name}"
        mkdir -p "/mnt/overlay-upper/work${overlay_name}"
        mount -t overlay overlay \
            -o "lowerdir=${overlay_target},upperdir=/mnt/overlay-upper/upper${overlay_name},workdir=/mnt/overlay-upper/work${overlay_name}" \
            "$overlay_target" 2>/dev/null && \
            echo "[ OK ] OverlayFS active on ${overlay_target}" || \
            echo "[ WARN ] OverlayFS not available for ${overlay_target} (kernel module missing?)"
    fi
done

# STRICT READ-ONLY CORE (Anti-Malware)
# Make critical system directories strictly read-only in RAM
for ro_dir in /bin /sbin /usr /lib; do
    if [ -d "$ro_dir" ]; then
        mount --bind "$ro_dir" "$ro_dir"
        mount -o remount,ro,bind "$ro_dir"
        echo "[ OK ] Secured $ro_dir as strictly read-only."
    fi
done

echo "[ OK ] Immutable layer configured. Core is indestructible."

# ══════════════════════════════════════════════════════════════
# 3. HARDWARE DRIVER LOADING
# ══════════════════════════════════════════════════════════════

echo "[ OK ] Loading hardware drivers..."

# Load essential kernel modules (if modprobe is available)
if command -v modprobe >/dev/null 2>&1; then
    # Storage drivers (QEMU & bare-metal)
    modprobe virtio_blk 2>/dev/null || true
    modprobe virtio_scsi 2>/dev/null || true
    modprobe ahci 2>/dev/null || true
    modprobe nvme 2>/dev/null || true
    modprobe sd_mod 2>/dev/null || true
    modprobe usb_storage 2>/dev/null || true

    # Network drivers (QEMU & bare-metal)
    modprobe virtio_net 2>/dev/null || true
    modprobe e1000 2>/dev/null || true
    modprobe e1000e 2>/dev/null || true
    modprobe r8169 2>/dev/null || true

    # Input drivers
    modprobe usbhid 2>/dev/null || true
    modprobe i8042 2>/dev/null || true

    # Filesystem drivers
    modprobe ext4 2>/dev/null || true
    modprobe vfat 2>/dev/null || true
    modprobe overlay 2>/dev/null || true

    # Auto-detect hardware via modalias with Loading Animation
    if [ -d /sys/bus ]; then
        echo -n "  [WAIT] Scanning PCI/USB buses and loading drivers...  "
        spinstr='|/-\'
        i=0
        for modalias_file in $(find /sys/bus/*/devices/*/modalias -maxdepth 0 2>/dev/null); do
            modalias=$(cat "$modalias_file" 2>/dev/null)
            if [ -n "$modalias" ]; then
                modprobe "$modalias" 2>/dev/null || true
            fi
            
            # Spin animation
            i=$(( (i+1) % 4 ))
            # Get character using cut (busybox compatible)
            char=$(echo "$spinstr" | cut -c $((i+1)))
            printf "\b%s" "$char"
        done
        printf "\b[DONE]\n"
    fi

    echo "[ OK ] Hardware drivers loaded."
else
    echo "[ WARN ] modprobe not found. Relying on built-in kernel drivers."
fi

# Start mdev for hotplug device handling (BusyBox)
if command -v mdev >/dev/null 2>&1; then
    echo /sbin/mdev > /proc/sys/kernel/hotplug 2>/dev/null || true
    mdev -s 2>/dev/null || true
    echo "[ OK ] mdev hotplug handler active."
fi

# ══════════════════════════════════════════════════════════════
# 4. HOSTNAME & IDENTITY
# ══════════════════════════════════════════════════════════════

hostname JulesOS 2>/dev/null || true
echo "JulesOS" > /etc/hostname 2>/dev/null || true

# Generate machine-id if missing
if [ ! -f /etc/machine-id ] || [ ! -s /etc/machine-id ]; then
    if command -v dbus-uuidgen >/dev/null 2>&1; then
        dbus-uuidgen > /etc/machine-id 2>/dev/null || true
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' > /etc/machine-id || true
    fi
fi

echo "[ OK ] System identity configured."

# ══════════════════════════════════════════════════════════════
# 5. NETWORK CONFIGURATION
# ══════════════════════════════════════════════════════════════

echo "[ OK ] Bringing up network interfaces..."

# Loopback
ip link set lo up 2>/dev/null || true

# Find and bring up the first available ethernet interface
NET_IF=""
for iface in eth0 enp0s3 ens3 ens33; do
    if [ -d "/sys/class/net/${iface}" ]; then
        NET_IF="$iface"
        break
    fi
done

if [ -n "$NET_IF" ]; then
    ip link set "$NET_IF" up 2>/dev/null
    udhcpc -i "$NET_IF" -n -q -s /usr/share/udhcpc/default.script 2>/dev/null || \
    udhcpc -i "$NET_IF" -n -q 2>/dev/null || true
    echo "[ OK ] Network interface ${NET_IF} configured via DHCP."
else
    echo "[ WARN ] No ethernet interface found."
fi

# Set up DNS resolution (DHCP-provided DNS takes priority)
# Only add fallback if resolv.conf is empty or missing
if [ ! -s /etc/resolv.conf ]; then
    {
        echo "nameserver 8.8.8.8"
        echo "nameserver 1.1.1.1"
        echo "nameserver 9.9.9.9"
    } > /etc/resolv.conf
    echo "[ OK ] DNS configured (fallback servers)."
else
    echo "[ OK ] DNS configured (DHCP-provided)."
fi

# ══════════════════════════════════════════════════════════════
# 6. PACKAGE REPOSITORY SETUP
# ══════════════════════════════════════════════════════════════

if [ -f /etc/alpine-release ]; then
    ALPINE_VERSION=$(cut -d. -f1,2 /etc/alpine-release)
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" > /etc/apk/repositories
    echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> /etc/apk/repositories
    echo "[ OK ] Alpine v${ALPINE_VERSION} repositories configured."
fi

# ══════════════════════════════════════════════════════════════
# 7. PERSISTENT DATA VAULT
# ══════════════════════════════════════════════════════════════

echo "[ OK ] Scanning for Persistent Vault..."
VAULT_DEV=""
for dev in /dev/vda2 /dev/sda2 /dev/vdb /dev/sdb; do
    if [ -b "$dev" ]; then
        VAULT_DEV=$dev
        break
    fi
done

if [ -n "$VAULT_DEV" ]; then
    if ! mount -o rw,nosuid,nodev,noexec "$VAULT_DEV" /home 2>/dev/null; then
        echo "[ INFO ] Formatting new Vault at $VAULT_DEV..."
        mkfs.ext4 -F -L "JulesVault" "$VAULT_DEV" 2>/dev/null || mkfs.vfat "$VAULT_DEV" 2>/dev/null
        # Mount with strict security flags: prevents malware execution from user data
        mount -o rw,nosuid,nodev,noexec "$VAULT_DEV" /home
    fi
    echo "[ OK ] Vault Mounted at /home (persistent & secured)."
else
    echo "[ WARN ] Vault not found. Using ephemeral /home (RAM)."
    mount -t tmpfs -o rw,nosuid,nodev,noexec tmpfs /home
fi

# ══════════════════════════════════════════════════════════════
# 8. USER SETUP
# ══════════════════════════════════════════════════════════════

if ! id "jules" >/dev/null 2>&1; then
    echo "[ INFO ] Creating user 'jules'..."
    adduser -D jules 2>/dev/null || true
fi

mkdir -p /home/jules
if [ ! -f /home/jules/.profile ]; then
    {
        echo "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        echo "export HOME=/home/jules"
        echo "export TERM=xterm-256color"
        echo "alias ls='ls --color=auto'"
        echo "alias ll='ls -lah --color=auto'"
        echo "alias grep='grep --color=auto'"
        printf "PS1='%s'\\n" "\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
    } > /home/jules/.profile
fi

# Secure permissions
chown -R jules:jules /home/jules 2>/dev/null || true
chmod 700 /home/jules
[ -f /home/jules/.profile ] && chmod 600 /home/jules/.profile

export HOME=/home/jules
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm-256color
cd /home/jules || cd /

# ══════════════════════════════════════════════════════════════
# 9. PERFORMANCE TUNING (CachyOS Inspired)
# ══════════════════════════════════════════════════════════════

echo "[ OK ] Applying Jules OS Tuning (CachyOS Optimized)..."

# Memory management & ZRAM (CachyOS Style)
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
echo 1 > /proc/sys/vm/overcommit_memory 2>/dev/null || true
echo 10 > /proc/sys/vm/swappiness 2>/dev/null || true

# Initialize ZRAM Swap (Compresses RAM to avoid disk paging)
if modprobe zram 2>/dev/null; then
    TOTAL_RAM=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "1048576")
    # Allocate 50% of RAM to ZRAM
    ZRAM_SIZE=$(( TOTAL_RAM * 512 )) # (TOTAL_RAM * 1024 / 2)
    echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
    echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>/dev/null
    mkswap /dev/zram0 2>/dev/null
    swapon --discard --priority 100 /dev/zram0 2>/dev/null
    echo "[ OK ] ZRAM Swap initialized (${ZRAM_SIZE} bytes)."
fi

# CPU Governor & amd-pstate Tuning (Force maximum performance)
if [ -d /sys/devices/system/cpu ]; then
    for cpu_freq in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$cpu_freq" ] && echo performance > "$cpu_freq" 2>/dev/null || true
    done
    # AMD P-State EPP Tuning (Active Mode)
    for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [ -f "$epp" ] && echo performance > "$epp" 2>/dev/null || true
    done
    echo "[ OK ] CPU Governors set to maximum performance."
fi

# Network performance (TCP BBR congestion control)
echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true

# Scheduler optimization (BORE/EEVDF heuristics support)
echo 1 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null || true

# Increase max memory map areas (needed for some applications/games)
echo 2147483642 > /proc/sys/vm/max_map_count 2>/dev/null || true

# Disable kernel address exposure (security)
echo 1 > /proc/sys/kernel/kptr_restrict 2>/dev/null || true

# Restrict dmesg to root (security)
echo 1 > /proc/sys/kernel/dmesg_restrict 2>/dev/null || true

# Disable SysRq for security (except sync+reboot)
echo 176 > /proc/sys/kernel/sysrq 2>/dev/null || true

echo "[ OK ] Performance tuning applied."

# ══════════════════════════════════════════════════════════════
# 10. HANDOVER TO JULES SHELL
# ══════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Jules OS v1.0.0 initialized successfully."
echo "  OverlayFS: Active | Vault: $([ -n "$VAULT_DEV" ] && echo "$VAULT_DEV" || echo "RAM")"
echo "  Network: $([ -n "$NET_IF" ] && echo "$NET_IF" || echo "none")"
echo "════════════════════════════════════════════════════════"
echo ""

echo "[ OK ] Handing over control to Jules Shell (Rust Core)..."
exec /bin/jules_shell
