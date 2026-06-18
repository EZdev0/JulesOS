#!/bin/bash
# ══════════════════════════════════════════════════════════════
# JulesOS Interactive Installer
# Installs the Live OS permanently onto a target disk.
# ══════════════════════════════════════════════════════════════
set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Installer must be run as root.${NC}"
    exit 1
fi

clear
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    JULES OS INSTALLER                            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}WARNING: This installer will completely WIPE the selected drive!${NC}"
echo -e "${YELLOW}All existing data will be permanently destroyed.${NC}"
echo ""

# 1. Drive Selection
echo -e "${GREEN}Available Drives:${NC}"
lsblk -d -n -p -o NAME,SIZE,MODEL | grep -E "^/dev/(sd|nvme|vd)"
echo ""

TARGET_DEV=""
while true; do
    read -rp "Enter the target drive path (e.g., /dev/sda or /dev/vda): " TARGET_DEV
    if [ -b "$TARGET_DEV" ]; then
        break
    else
        echo -e "${RED}Invalid drive: $TARGET_DEV. Please try again.${NC}"
    fi
done

# Safety Confirmation
echo ""
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
echo -e "${RED}FINAL WARNING: YOU ARE ABOUT TO ERASE ALL DATA ON ${TARGET_DEV}${NC}"
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
read -rp "Type 'ERASE' to confirm and proceed: " CONFIRM
if [ "$CONFIRM" != "ERASE" ]; then
    echo -e "${GREEN}Installation aborted by user.${NC}"
    exit 0
fi

# 2. Partitioning
echo -e "\n${CYAN}[1/5] Partitioning ${TARGET_DEV}...${NC}"
parted -s "$TARGET_DEV" mklabel gpt
# BIOS Boot Partition
parted -s "$TARGET_DEV" mkpart primary 1MiB 3MiB
parted -s "$TARGET_DEV" set 1 bios_grub on
# EFI System Partition
parted -s "$TARGET_DEV" mkpart primary fat32 3MiB 259MiB
parted -s "$TARGET_DEV" set 2 esp on
# Root Partition
parted -s "$TARGET_DEV" mkpart primary ext4 259MiB 100%

# Determine partition names (handle nvme0n1p1 vs sda1)
if [[ "$TARGET_DEV" == *"nvme"* ]]; then
    PART_EFI="${TARGET_DEV}p2"
    PART_ROOT="${TARGET_DEV}p3"
else
    PART_EFI="${TARGET_DEV}2"
    PART_ROOT="${TARGET_DEV}3"
fi

# 3. Formatting
echo -e "${CYAN}[2/5] Formatting partitions...${NC}"
mkfs.vfat -F32 "$PART_EFI" >/dev/null
mkfs.ext4 -F -q "$PART_ROOT" >/dev/null

# 4. Mount & Copy System
echo -e "${CYAN}[3/5] Mounting and copying JulesOS system files...${NC}"
mkdir -p /mnt/jules
mount "$PART_ROOT" /mnt/jules
mkdir -p /mnt/jules/boot/efi
mount "$PART_EFI" /mnt/jules/boot/efi

# Copy all directories except volatile ones
for dir in /bin /etc /home /lib /opt /root /sbin /usr /var; do
    if [ -d "$dir" ]; then
        cp -a "$dir" /mnt/jules/
    fi
done

# Create empty mount points
mkdir -p /mnt/jules/{dev,proc,sys,run,tmp,mnt,media,srv}
chmod 1777 /mnt/jules/tmp

# 5. Bootloader Installation (Chroot)
echo -e "${CYAN}[4/5] Installing Hybrid GRUB Bootloader...${NC}"

# Bind mount pseudo-filesystems for chroot
mount --bind /dev /mnt/jules/dev
mount --bind /proc /mnt/jules/proc
mount --bind /sys /mnt/jules/sys
mount --bind /run /mnt/jules/run

# We need the kernel to be available in /boot
cp /boot/bzImage /mnt/jules/boot/vmlinuz-jules 2>/dev/null || cp /boot/vmlinuz* /mnt/jules/boot/vmlinuz-jules 2>/dev/null || true

# Chroot and install GRUB
chroot /mnt/jules /bin/bash -c "
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --removable >/dev/null 2>&1 || true
    grub-install --target=i386-pc --boot-directory=/boot ${TARGET_DEV} >/dev/null 2>&1 || true
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
"

# Clean up mounts
umount /mnt/jules/run
umount /mnt/jules/sys
umount /mnt/jules/proc
umount /mnt/jules/dev
umount /mnt/jules/boot/efi
umount /mnt/jules

echo -e "\n${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  SUCCESS: JulesOS has been permanently installed to ${TARGET_DEV} ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}You can now reboot your machine and remove the installation media.${NC}"
