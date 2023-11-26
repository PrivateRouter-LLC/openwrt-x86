#!/bin/bash

BASEDIR=$(realpath "$0" | xargs dirname)

OUTPUT="${BASEDIR}/images"
BUILD_VERSION="21.02.7"
BOARD_NAME="x86"
BOARD_SUBNAME="64"
BUILDER="https://downloads.openwrt.org/releases/${BUILD_VERSION}/targets/${BOARD_NAME}/${BOARD_SUBNAME}/openwrt-imagebuilder-${BUILD_VERSION}-${BOARD_NAME}-${BOARD_SUBNAME}.Linux-x86_64.tar.xz"
BUILDER_NAME="${BUILDER##*/}"
BUILDER_FOLDER="${BUILDER_NAME%.tar.xz}"
KERNEL_PARTSIZE=200 #Kernel-Partitionsize in MB
ROOTFS_PARTSIZE=5120 #Rootfs-Partitionsize in MB

# Search for any file named "openwrt-imagebuilder*" but not ${BUILDER_NAME} and delete it
find "${BASEDIR}" -maxdepth 1 -type f -name "openwrt-imagebuilder*" ! -name "${BUILDER_NAME}" -exec rm -rf {} \;

# Search for any directory containing the name openwrt-imagebuilder, named different than "${BUILDER##*/}" and delete it
find "${BASEDIR}" -maxdepth 1 -type d -name "openwrt-imagebuilder*" ! -name "${BUILDER_FOLDER}" -exec rm -rf {} \;

# download image builder if needed
if [ ! -f "${BUILDER_NAME}" ]; then
	wget "$BUILDER"
fi

# extract image builder if needed
if [ ! -d "${BUILDER_FOLDER}" ] && [ -f "${BUILDER_NAME}" ]; then
      tar xJvf "${BUILDER_NAME}"
fi

[ -d "${OUTPUT}" ] && { rm -rf "${OUTPUT}"; mkdir "${OUTPUT}"; } || { mkdir "${OUTPUT}"; }

cd "${BUILDER_FOLDER}"

make clean

# Packages are added if no prefix is given, '-packaganame' does not integrate a package
sed -i "s/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_PARTSIZE/g" .config
sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE/g" .config

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      make image PROFILE="generic" \
      PACKAGES="wpad kmod-rt2800-usb rt2800-usb-firmware kmod-rtl8192cu kmod-cfg80211 kmod-mac80211 \
         base-files block-mount fdisk luci-app-minidlna minidlna samba4-server samba4-libs \
         luci-app-samba4 wireguard-tools luci-app-wireguard openvpn-openssl luci-app-openvpn watchcat \
         openssh-sftp-client luci-base luci-ssl luci-mod-admin-full luci-theme-bootstrap kmod-usb-storage kmod-usb-ohci \
         kmod-usb-uhci e2fsprogs resize2fs htop debootstrap luci-compat luci-lib-ipkg dnsmasq luci-app-ttyd irqbalance \
         ethtool netperf speedtest-netperf iperf3 curl wget rsync file lsof less mc tree usbutils diffutils \
         openssh-sftp-server nano kmod-fs-exfat kmod-fs-ext4 urngd usign vpn-policy-routing wg-installer-client \
         kmod-usb-core kmod-usb3 dropbear zlib wireless-regdb f2fsck kmod-usb-wdm kmod-usb-net-ipheth usbmuxd \
         kmod-usb-net-asix-ax88179 kmod-usb-net-cdc-ether mount-utils kmod-rtl8xxxu rtl8188eu-firmware \
         kmod-rtl8192ce kmod-rtl8192de adblock luci-app-adblock kmod-fs-squashfs squashfs-tools-unsquashfs \
         squashfs-tools-mksquashfs luci-app-uhttpd kmod-fs-f2fs kmod-fs-vfat git git-http jq kmod-igc bash libmpeg2" \
      FILES="${BASEDIR}/files/" \
      BIN_DIR="${OUTPUT}"
