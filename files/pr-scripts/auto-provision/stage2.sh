#!/bin/sh

# Source our reusable functions
if [ -f /pr-scripts/functions.sh ]; then
    . /pr-scripts/functions.sh
else
    echo "ERROR: /pr-scripts/functions.sh not found!"
    exit 1
fi

# Get the name of the script without the path
SCRIPT_NAME=$(basename "$0")

# Count the number of running instances of the script (excluding the current one)
NUM_INSTANCES=$(pgrep -f "${SCRIPT_NAME}" | grep -v "$$" | wc -l)

# If more than one instance is found, exit
if [ "$NUM_INSTANCES" -gt 1 ]; then
    log_say "${SCRIPT_NAME} is already running, exiting."
    exit 1
fi

# Print our PR Logo
print_logo

# Wait for Internet connection
wait_for_internet

# Install our base requirements and dns fix
# This also takes care of opkg update
base_requirements_check && log_say "Requirements check successful." || { log_say "Requirements check failed."; exit 1; }

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
    NEW_PARTITION=$(fdisk -l $BOOT_DEVICE | grep "^$BOOT_DEVICE" | tail -n 1 | awk '{print $1}')

    # Create our ext4 partition for docker
    yes | mkfs.ext4 $NEW_PARTITION

    # Create our mountpoint if it does not exist
    [ ! -d /opt/docker2 ] && { mkdir /opt/docker2; }

    # Set the mountpoint in uci
    uci set fstab.@mount[-1].target='/opt/docker2'
    uci set fstab.@mount[-1].device="$NEW_PARTITION"
    uci set fstab.@mount[-1].fstype='ext4'
    uci set fstab.@mount[-1].enabled='1'
    uci set fstab.@mount[-1].enabled_fsck='0'
    uci commit fstab

    # Mount our new partition
    mount -t ext4 "${NEW_PARTITION}" /opt/docker2

    # Edit our /etc/config/dockerd for the new mountpoint
    sed -i "s|option data_root '/opt/docker/'|option data_root '/opt/docker2/'|g" /etc/config/dockerd

    # Remove the comment from the extra_iptables_args line
    sed -i '/^#\s*option extra_iptables_args/s/^#//' /etc/config/dockerd
else
    log_say "We did not create the docker partition as there was not enough space free on the boot disk"
fi
########################## END FIX DOCKER PARTITION ##########################

# List of our packages to install
PACKAGE_LIST="attr avahi-dbus-daemon base-files busybox ca-bundle certtool cgi-io curl davfs2 dbus luci-app-uhttpd frpc luci-app-frpc kmod-rtl8xxxu rtl8188eu-firmware kmod-rtl8192ce kmod-rtl8192cu kmod-rtl8192de dcwapd jq bash git-http kmod-mwifiex-pcie kmod-mwifiex-sdio kmod-rtl8723bs kmod-rtlwifi kmod-rtlwifi-btcoexist kmod-rtlwifi-pci kmod-rtlwifi-usb kmod-wil6210 libuwifi kmod-8139cp kmod-8139too kmod-net-rtl8192su kmod-phy-realtek kmod-r8169 kmod-rtl8180 kmod-rtl8187 kmod-rtl8192c-common kmod-rtl8192se kmod-rtl8812au-ct kmod-rtl8821ae kmod-rtw88 kmod-sound-hda-codec-realtek kmod-switch-rtl8306 kmod-switch-rtl8366-smi kmod-switch-rtl8366rb kmod-switch-rtl8366s kmod-switch-rtl8367b kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 librtlsdr r8169-firmware rtl-sdr rtl8192ce-firmware rtl8192cu-firmware rtl8192de-firmware rtl8192eu-firmware rtl8192se-firmware rtl8192su-firmware rtl8723au-firmware rtl8723bu-firmware rtl8821ae-firmware rtl8822be-firmware rtl8822ce-firmware rtl_433 kmod-mt76 kmod-mt76-connac kmod-mt76-core kmod-mt76-usb kmod-mt7603 kmod-mt7615-common kmod-mt7615-firmware kmod-mt7615e kmod-mt7663-firmware-ap kmod-mt7663-firmware-sta kmod-mt7663-usb-sdio kmod-mt7663s kmod-mt7663u kmod-mt76x0-common kmod-mt76x02-common kmod-mt76x02-usb kmod-mt76x0e kmod-mt76x0u kmod-mt76x2 kmod-mt76x2-common kmod-mt76x2u kmod-mt7915e kmod-ar5523 kmod-mt7921e mt7601u-firmware kmod-ath kmod-brcmutil kmod-libertas-sdio kmod-libertas-spi kmod-libertas-usb kmod-mt7601u iwlwifi-firmware-iwl100 iwlwifi-firmware-iwl1000 iwlwifi-firmware-iwl105 iwlwifi-firmware-iwl135 iwlwifi-firmware-iwl2000 iwlwifi-firmware-iwl2030 iwlwifi-firmware-iwl3160 iwlwifi-firmware-iwl3168 iwlwifi-firmware-iwl5000 iwlwifi-firmware-iwl5150 iwlwifi-firmware-iwl6000g2 iwlwifi-firmware-iwl6000g2a iwlwifi-firmware-iwl6000g2b iwlwifi-firmware-iwl6050 iwlwifi-firmware-iwl7260 iwlwifi-firmware-iwl7265 iwlwifi-firmware-iwl7265d iwlwifi-firmware-iwl8260c iwlwifi-firmware-iwl8265 iwlwifi-firmware-iwl9000 iwlwifi-firmware-iwl9260 kmod-iwlwifi luci-app-wifischedule dropbear firewall fstools fuse3-utils fwtool getrandom git glib2 gnupg hostapd-common ip-full ip6tables ipset iptables iptables-mod-ipopt iw iwinfo jshn adblock luci-app-adblock wwan jsonfilter kernel kmod-bluetooth kmod-btmrvl kmod-cfg80211 kmod-crypto-aead kmod-crypto-ccm kmod-crypto-cmac kmod-crypto-ctr kmod-crypto-ecb kmod-crypto-ecdh kmod-crypto-gcm kmod-crypto-gf128 kmod-usb-wdm kmod-usb-net-ipheth kmod-crypto-ghash kmod-crypto-hash kmod-crypto-hmac kmod-crypto-kpp kmod-crypto-lib-blake2s kmod-crypto-lib-chacha20 kmod-crypto-lib-chacha20poly1305 kmod-crypto-lib-curve25519 kmod-usb-net-asix-ax88179 kmod-crypto-lib-poly1305 kmod-crypto-manager kmod-crypto-null kmod-crypto-rng kmod-crypto-seqiv kmod-crypto-sha256 kmod-fuse kmod-gpio-button-hotplug kmod-hid kmod-input-core kmod-input-evdev kmod-ip6tables kmod-ipt-conntrack kmod-ipt-core kmod-ipt-ipopt kmod-ipt-ipset kmod-ipt-nat kmod-ipt-offload kmod-lib-crc-ccitt kmod-lib-crc16 kmod-mac80211 kmod-mmc luci-compat luci-lib-ipkg kmod-mwlwifi kmod-nf-conntrack kmod-nf-conntrack6 kmod-nf-flow kmod-nf-ipt kmod-nf-ipt6 kmod-nf-nat kmod-nf-reject kmod-nf-reject6 kmod-nfnetlink kmod-nls-base kmod-ppp kmod-pppoe kmod-pppox kmod-brcmfmac usbmuxd kmod-regmap-core kmod-slhc kmod-tun kmod-udptunnel4 kmod-udptunnel6 kmod-usb-core kmod-wireguard libatomic1 libattr libavahi-client libavahi-dbus-support libblkid1 libbpf0 libbz2-1.0 libc kmod-usb-net-rndis libcap libcurl4 libdaemon libdbus libelf1 libev libevdev libevent2-7 libexif libexpat libffi libffmpeg-mini libflac libfuse1 libfuse3-3 libgcc1 libgmp10 libgnutls libhttp-parser kmod-usb-net-cdc-ncm libid3tag libip4tc2 libip6tc2 libipset13 libiwinfo-data libiwinfo-lua libiwinfo20210430 libjpeg-turbo libjson-c5 liblua5.1.5 liblucihttp-lua liblucihttp0 liblzo2 libmbedtls12 libmnl0 luci-app-ttyd kmod-usb-net-cdc-eem libmount1 libncurses6 libneon libnettle8 libnftnl11 libnghttp2-14 libnl-tiny1 libogg0 libopenssl-conf libopenssl1.1 libowipcalc libpam libpcre libpopt0 libprotobuf-c libpthread libreadline8 kmod-usb-net-cdc-subset librt libsmartcols1 libsodium libsqlite3-0 libtasn1 libtirpc libubus-lua libuci-lua libuci20130104 libuclient20201210 libudev-zero liburing libusb-1.0-0 libustream-wolfssl20201210 libuuid1 kmod-usb-net-cdc-ether libvorbis libxml2 libxtables12 logd lua luci luci-app-attendedsysupgrade luci-app-firewall luci-app-minidlna luci-app-openvpn luci-app-opkg luci-app-samba4 kmod-usb-net-hso luci-app-wireguard luci-base luci-i18n-firewall-en kmod-usb2 kmod-usb3 luci-i18n-wireguard-en luci-lib-base luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-mod-admin-full luci-mod-network luci-mod-status luci-mod-system luci-proto-ipv6 luci-proto-ppp luci-proto-wireguard luci-theme-bootstrap luci-theme-material luci-theme-openwrt-2020 minidlna mount-utils mtd mwifiex-sdio-firmware mwlwifi-firmware-88w8964 netifd odhcp6c odhcpd-ipv6only openssh-sftp-client openssh-sftp-server openssl-util openvpn-openssl openwrt-keyring opkg owipcalc ppp ppp-mod-pppoe procd procd-seccomp procd-ujail python3-base python3-email python3-light python3-logging python3-openssl python3-pysocks python3-urllib resolveip rpcd rpcd-mod-file rpcd-mod-iwinfo rpcd-mod-luci luci-app-statistics rpcd-mod-rpcsys rpcd-mod-rrdns rsync samba4-libs samba4-server nano sshfs terminfo ubi-utils luci-app-commands uboot-envtools ubox ubus ubusd uci uclient-fetch uhttpd uhttpd-mod-ubus urandom-seed urngd usbutils usign vpnbypass vpnc-scripts watchcat wg-installer-client wget-ssl wireguard-tools wireless-regdb wpad zlib kmod-usb-storage block-mount kmod-fs-ext4 kmod-fs-exfat e2fsprogs fdisk luci-app-nlbwmon luci-app-vnstat luci-app-fileassistant luci-app-plugsy"

count=$(echo "$PACKAGE_LIST" | wc -w)
log_say "Packages to install: ${count}"

for package in $PACKAGE_LIST; do
    if ! opkg list-installed | grep -q "^$package -"; then
        log_say "Installing $package..."
        opkg install $package
        if [ $? -eq 0 ]; then
            log_say "$package installed successfully."
        else
            log_say "Failed to install $package."
        fi
    else
        log_say "$package is already installed."
    fi
done

# Check and fix dnsmsaq
log_say "Checking if dnsmsaq-full is installed"
if ! opkg list-installed | grep -q "^dnsmasq-full "; then
    log_say "Removing original dnsmasq and installing dnsmasq-full"
    opkg remove dnsmasq
    # use --force-maintainer to preserve the existing config
    opkg install --force-maintainer dnsmasq-full
    if [ $? -eq 0 ]; then
        log_say "dnsmasq-full installed successfully."
    else
        log_say "Failed to install dnsmasq-full."
    fi
fi

# Install v2raya
log_say "Installing v2raya"
wget -qO /tmp/luci-app-v2ray_2.0.0-1_all.ipk https://github.com/kuoruan/luci-app-v2ray/releases/download/v2.0.0-1/luci-app-v2ray_2.0.0-1_all.ipk
opkg install /tmp/luci-app-v2ray_2.0.0-1_all.ipk

# Configure our PrivateRouter Wireless
uci del wireless.default_radio0
uci del wireless.radio0.disabled
uci commit wireless

uci set wireless.wifinet0=wifi-iface
uci set wireless.wifinet0.device='radio0'
uci set wireless.wifinet0.mode='ap'
uci set wireless.wifinet0.ssid='PrivateRouter'
uci set wireless.wifinet0.encryption='psk2'
uci set wireless.wifinet0.key='privaterouter'
uci set wireless.wifinet0.network='lan'
uci commit wireless

wifi down radio0
wifi up radio0

# Check if we have /etc/config/openvpn and if we do, echo the contents of /pr-scripts/config/openvpn into it
if [ -f /etc/config/openvpn ]; then
    cat </pr-scripts/config/openvpn >/etc/config/openvpn
fi

# Rewrite our rc.local to run our stage3 script
cat << EOF > /etc/rc.local
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

# Run Stage3 Script
sh /pr-scripts/auto-provision/stage3.sh

exit 0
EOF

reboot

exit 0
