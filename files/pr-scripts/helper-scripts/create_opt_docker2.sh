#!/bin/bash

# Log to the system log and echo if needed
log_say()
{
    SCRIPT_NAME=$(basename "$0")
    echo "${SCRIPT_NAME}: ${1}"
    logger "${SCRIPT_NAME}: ${1}"
    echo "${SCRIPT_NAME}: ${1}" >> "/tmp/${SCRIPT_NAME}.log"
}

########################## FIX DOCKER PARTITION ##########################
# Get the /dev/name of the filesystem we boot from
BOOT_DEVICE=$(mount | grep '/rom' | cut -d' ' -f1 | sed 's/[0-9]*$//')

# Get the total size of the drive in sectors
TOTAL_SECTORS=$(fdisk -l "$BOOT_DEVICE" | grep "^Disk $BOOT_DEVICE:" | awk '{print $7}')

# Find the last sector of the last partition
LAST_SECTOR=$(fdisk -l "$BOOT_DEVICE" | grep "^$BOOT_DEVICE" | awk '{print $3}' | sort -n | tail -1)

# If no partition exists, LAST_SECTOR would be empty. In that case, all space is unpartitioned.
if [ -z "$LAST_SECTOR" ]; then
    LAST_SECTOR=0
fi

# Calculate unpartitioned space in sectors
UNPARTITIONED_SECTORS=$((TOTAL_SECTORS - LAST_SECTOR))

# Usually, a sector is 512 bytes. But you might want to cross-check.
# Multiply unpartitioned sectors by 512 to get bytes and then convert to more readable unit.
UNPARTITIONED_BYTES=$((UNPARTITIONED_SECTORS * 512))

# Set base variable for whether or not we should create the partition
DO_PARTITION=0

# Check if greater than 5 gigs free on the device, if so mark DO_PARTITION as 1
if [ "$UNPARTITIONED_BYTES" -gt $((5*1024**3)) ]; then
    log_say "$BOOT_DEVICE has enough free space to create the /opt/docker2 partition."
    DO_PARTITION=1
else
    log_say "There's less than 5GB of unpartitioned free space on ${BOOT_DEVICE}."
    DO_PARTITION=0
fi

# If we should create the partition, do so
if [ "$DO_PARTITION" -eq 1 ]; then

    #Create our new partition for docker
    echo -e "n\n\n\n\nw" | fdisk $BOOT_DEVICE

    # Find our newest partition added
    NEW_PARTITION=$(fdisk -l $BOOT_DEVICE | awk -v device="$BOOT_DEVICE" '$0 ~ device && $0 !~ "BIOS boot" && $1 ~ device {part=$1} END {print part}')

    # Create our ext4 partition for docker
    yes | mkfs.ext4 $NEW_PARTITION

    # Create our mountpoint if it does not exist
    [ ! -d /opt/docker2 ] && { mkdir -p /opt/docker2; }

    # Set the mountpoint in uci
    uci set fstab.@mount[-1].target='/opt/docker2'
    uci set fstab.@mount[-1].device="$NEW_PARTITION"
    uci set fstab.@mount[-1].fstype='ext4'
    uci set fstab.@mount[-1].enabled='1'
    uci set fstab.@mount[-1].enabled_fsck='0'
    uci commit fstab

    # Mount our new partition
    mount -t ext4 "${NEW_PARTITION}" /opt/docker2

    [ -f /etc/config/dockerd ] && {
        # Stop our docker daemon
        /etc/init.d/dockerd stop

        # Edit our /etc/config/dockerd for the new mountpoint
        sed -i "s|option data_root '/opt/docker/'|option data_root '/opt/docker2/'|g" /etc/config/dockerd

        # Remove the comment from the extra_iptables_args line
        sed -i '/^#\s*option extra_iptables_args/s/^#//' /etc/config/dockerd

        # Check if /opt/docker exists, if so, move it to /opt/docker2
        if [ -d /opt/docker ]; then
            log_say "Moving /opt/docker to /opt/docker2"
            mv /opt/docker/* /opt/docker2/
            rm -rf /opt/docker
            ln -s /opt/docker2 /opt/docker
        fi

        # Restart our docker daemon
        /etc/init.d/dockerd start
    }
else
    log_say "We did not create the docker partition as there was not enough space free on the boot disk"
fi
########################## END FIX DOCKER PARTITION ##########################