# Source this script from other scripts

# Source our base OpenWRT functions
. /lib/functions.sh

# Set variables used by other scripts

# Partition UUIDs
ROOT_UUID=05d615b3-bef8-460c-9a23-52db8d09e000
DATA_UUID=05d615b3-bef8-460c-9a23-52db8d09e001

echo Board name is [$(board_name)]

# let's attempt to define some defaults...
LED_USB="green:usb"
LED_STATUS="green:qss"
LED_WAN="green:wan"

# CUSTOMIZE
case $(board_name) in
    *gl-xe300*)
        LED_USB="green:lte"
        LED_STATUS="green:lan"
        LED_WAN="green:wan"
        ;;
esac

# Set physical LED attributes
set_led_attribute()
{
    [ -f "/sys/class/leds/$1/$2" ] && echo "$3" > "/sys/class/leds/$1/$2"
}

# # Set LED attributes waiting for USB Drive
# led_signal_waiting_for_drive()
# {
#     set_led_attribute ${LED_USB} trigger none
#     set_led_attribute ${LED_USB} trigger timer
#     set_led_attribute ${LED_USB} delay_on 200
#     set_led_attribute ${LED_USB} delay_off 300
# }

led_signal_waiting_for_net()
{
    set_led_attribute ${LED_WAN} trigger none
    set_led_attribute ${LED_WAN} trigger timer
    set_led_attribute ${LED_WAN} delay_on 200
    set_led_attribute ${LED_WAN} delay_off 300
}

led_signal_autoprovision_working()
{
    set_led_attribute ${LED_STATUS} trigger none
    set_led_attribute ${LED_STATUS} trigger timer
    set_led_attribute ${LED_STATUS} delay_on 2000
    set_led_attribute ${LED_STATUS} delay_off 2000
}

led_signal_autoprovision_waiting_on_user()
{
    set_led_attribute ${LED_STATUS} trigger none
    set_led_attribute ${LED_STATUS} trigger timer
    set_led_attribute ${LED_STATUS} delay_on 200
    set_led_attribute ${LED_STATUS} delay_off 300
}

led_signal_waiting_for_drive()
{
    set_led_attribute ${LED_USB} trigger none
    set_led_attribute ${LED_USB} trigger timer
    set_led_attribute ${LED_USB} delay_on 200
    set_led_attribute ${LED_USB} delay_off 300
}

led_signal_formatting()
{
    set_led_attribute ${LED_USB} trigger none
    set_led_attribute ${LED_USB} trigger timer
    set_led_attribute ${LED_USB} delay_on 1000
    set_led_attribute ${LED_USB} delay_off 1000
}

led_stop_signaling()
{
    set_led_attribute ${LED_STATUS} trigger none
    set_led_attribute ${LED_USB} trigger none
    set_led_attribute ${LED_WAN} trigger none
}

# Log to the system log and echo if needed
log_say()
{
    SCRIPT_NAME=$(basename "$0")
    echo "${SCRIPT_NAME}: ${1}"
    logger "${SCRIPT_NAME}: ${1}"
    echo "${SCRIPT_NAME}: ${1}" >> "/tmp/${SCRIPT_NAME}.log"
}

# Command to check if a command ran successfully
check_run() {
    if eval "$@"; then
        return 0  # Command ran successfully, return true
    else
        return 1  # Command failed to run, return false
    fi
}

# Command to wait for Internet connection
wait_for_internet() {
    while ! ping -q -c3 1.1.1.1 >/dev/null 2>&1; do
        log_say "Waiting for Internet connection..."
        sleep 1
    done
    log_say "Internet connection established"
}

# Command to wait for opkg to finish
wait_for_opkg() {
  while pgrep -x opkg >/dev/null; do
    log_say "Waiting for opkg to finish..."
    sleep 1
  done
  log_say "opkg is released, our turn!"
}

update_opkg() 
{
    # Keep trying to run opkg update until it succeeds
    while ! check_run "opkg update"; do
        log_say "\"opkg update\" failed. Retrying in 15 seconds..."
        sleep 15
    done
}

print_logo()
{
    log_say "                                                                      "
    log_say " ███████████             ███                         █████            "
    log_say "░░███░░░░░███           ░░░                         ░░███             "
    log_say " ░███    ░███ ████████  ████  █████ █████  ██████   ███████    ██████ "
    log_say " ░██████████ ░░███░░███░░███ ░░███ ░░███  ░░░░░███ ░░░███░    ███░░███"
    log_say " ░███░░░░░░   ░███ ░░░  ░███  ░███  ░███   ███████   ░███    ░███████ "
    log_say " ░███         ░███      ░███  ░░███ ███   ███░░███   ░███ ███░███░░░  "
    log_say " █████        █████     █████  ░░█████   ░░████████  ░░█████ ░░██████ "
    log_say "░░░░░        ░░░░░     ░░░░░    ░░░░░     ░░░░░░░░    ░░░░░   ░░░░░░  "
    log_say "                                                                      "
    log_say "                                                                      "
    log_say " ███████████                        █████                             "
    log_say "░░███░░░░░███                      ░░███                              "
    log_say " ░███    ░███   ██████  █████ ████ ███████    ██████  ████████        "
    log_say " ░██████████   ███░░███░░███ ░███ ░░░███░    ███░░███░░███░░███       "
    log_say " ░███░░░░░███ ░███ ░███ ░███ ░███   ░███    ░███████  ░███ ░░░        "
    log_say " ░███    ░███ ░███ ░███ ░███ ░███   ░███ ███░███░░░   ░███            "
    log_say " █████   █████░░██████  ░░████████  ░░█████ ░░██████  █████           "
    log_say "░░░░░   ░░░░░  ░░░░░░    ░░░░░░░░    ░░░░░   ░░░░░░  ░░░░░            "
}

drive_is_big_enough()
{
    local DRIVE=$1 # The drive we check
    local DRIVE_SUFFIX="${DRIVE##*/}"
    local SIZE=0

    # this is needed for the mmc card in some (all?) Huawei 3G dongle.
    # details: https://dev.openwrt.org/ticket/10716#comment:4
    if [ -e "${DRIVE}" ]; then
        # force re-read of the partition table
        head -c 1024 "${DRIVE}" >/dev/null
    fi

    if (grep -q "${DRIVE_SUFFIX}" /proc/partitions) then
        #cat /sys/block/"${DRIVE_SUFFIX}"/size
        SIZE=$(cat /sys/block/"${DRIVE_SUFFIX}"/size)
    else
        #echo 0
        SIZE=0
    fi

    if [ $SIZE -ge 600000 ]; then
        log_say "Found a pendrive of size: $(($SIZE / 2 / 1024)) MB"
        return 0
    else
        return 1
    fi 
}

check_valid_drive()
{
    local DRIVE=$1 # The drive we check

    # Check if the DRIVE exists
    if [ -b "$DRIVE" ]; then
        # Get the number of partitions
        local PARTITIONS=$(fdisk -l "$DRIVE" | grep "$DRIVE" | wc -l)

        if [ "$PARTITIONS" -eq 1 ]; then
            log_say "DRIVE $DRIVE is uninitialized (no partitions) so we will erase and partition it."
            return 0
        elif [ "$PARTITIONS" -eq 2 ]; then
            # Get the label of the single partition
            PARTITION_LABEL=$(blkid -s LABEL -o value "$DRIVE"1)

            if [ "$PARTITION_LABEL" = "SETUP" ]; then
                log_say "The single partition on $DRIVE has the label 'SETUP' so we will erase and partition it."
                return 0
                # This is a success
            else
                log_say "The single partition on $DRIVE does not have the label 'SETUP' so we will not erase it."
                return 1
                # This is a failure
            fi
        else
            log_say "DRIVE $DRIVE has $PARTITIONS partitions so we will not erase it."
            return 1
            # This is a failure
        fi
    else
        log_say "DRIVE $DRIVE does not exist."
        return 1
        # This is a failure
    fi

    # Failsafe return
    return 1
}

unmount_drive()
{
    # Get the drive passed to function
    local DRIVE=$1

    # Get a list of all mounted filesystems on ${DRIVE}
    mounted_partitions=$(mount | grep "${DRIVE}" | awk '{print $1}')

    if [ -n "$mounted_partitions" ]; then
        log_say "Unmounting partitions on ${DRIVE}:"
        for partition in $mounted_partitions; do
            umount "$partition"
            log_say "Unmounted: $partition"
        done
    else
        log_say "No partitions on ${DRIVE} are currently mounted."
    fi
}

erase_partitions()
{
    # Get the drive passed to function
    local DRIVE=$1

    # Erase partition table
    dd if=/dev/zero of="${DRIVE}" bs=512 count=1 conv=notrunc
}

set_root_password()
{
    local password=$1
    if [ "$password" == "" ]; then
        # set and forget a random password merely to disable telnet. login will go through ssh keys.
        password=$(</dev/urandom sed 's/[^A-Za-z0-9+_]//g' | head -c 22)
    fi
    #echo "Setting root password to '"$password"'"
    log_say "Setting root password"
    echo -e "$password\n$password\n" | passwd root
}

base_requirements_check()
{
    log_say "Fixing DNS (if needed) and installing required packages for opkg"

    # Domain to check
    domain="privaterouter.com"

    # DNS server to set if domain resolution fails
    dns_server="1.1.1.1"

    # Perform the DNS resolution check
    if ! nslookup "$domain" >/dev/null 2>&1; then
        log_say "Domain resolution failed. Setting DNS server to $dns_server."

        # Update resolv.conf with the new DNS server
        echo "nameserver $dns_server" > /etc/resolv.conf
    else
        log_say "Domain resolution successful."
    fi

    log_say "Updating system time using ntp; otherwise the openwrt.org certificates are rejected as not yet valid."
    ntpd -d -q -n -p 0.openwrt.pool.ntp.org

    # Wait for opkg to be available
    wait_for_opkg

    log_say "Installing opkg packages"
    opkg update
    [ $? -eq 0 ] || { log_say "opkg update failed"; exit 1; }
    opkg install wget-ssl unzip ca-bundle ca-certificates git git-http jq curl bash nano
}

# Force source our REPO variable from /root/.profile
# This way it proliferates into all other scripts this one sources
. /root/.profile

log_say "***[ REPO is set to: ${REPO} ]***"