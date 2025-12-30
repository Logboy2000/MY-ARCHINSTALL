#!/bin/bash
set -e

setfont ter-132b

# --- 1. Ask user for target disk ---
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL
echo
read -rp "Enter the disk to format (e.g., /dev/sda): " DISK

# --- Confirm ---
echo "WARNING: ALL DATA ON $DISK WILL BE LOST!"
read -rp "Are you sure? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborting."
    exit 1
fi

# --- 2. Show total disk and RAM for reference ---
DISK_SIZE=$(lsblk -dn -o SIZE "$DISK")
RAM_SIZE=$(free -h | awk '/Mem:/ {print $2}')
echo "Disk size: $DISK_SIZE"
echo "RAM size: $RAM_SIZE"

# --- 3. Ask for swap size ---
read -rp "Enter swap size (e.g., 4G): " SWAP_SIZE

# --- 4. Partitioning ---
# We'll use parted in GPT mode
parted -s "$DISK" mklabel gpt

# EFI /boot partition 2GiB
parted -s "$DISK" mkpart primary fat32 1MiB 2049MiB
parted -s "$DISK" set 1 boot on

# Swap partition
parted -s "$DISK" mkpart primary linux-swap 2049MiB "$((2049 + ${SWAP_SIZE%G} * 1024))MiB"

# Root partition (rest of disk)
parted -s "$DISK" mkpart primary ext4 "$((2049 + ${SWAP_SIZE%G} * 1024))MiB" 100%

# --- 5. Format partitions ---
BOOT_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"

mkfs.fat -F32 "$BOOT_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 "$ROOT_PART"

echo "Partitioning and formatting complete."
echo "Boot: $BOOT_PART, Swap: $SWAP_PART, Root: $ROOT_PART"
