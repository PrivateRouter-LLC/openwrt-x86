#!/usr/bin/env bash
# Stage 3 booster to prepare router for first real boot

# Log to the system log and echo if needed
log_say()
{
    SCRIPT_NAME=$(basename "$0")
    echo "${SCRIPT_NAME}: ${1}"
    logger "${SCRIPT_NAME}: ${1}"
}

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

# Command to wait for Internet connection
wait_for_internet() {
    while ! ping -q -c3 1.1.1.1 >/dev/null 2>&1; do
        log_say "Waiting for Internet connection..."
        sleep 1
    done
    log_say "Internet connection established"
}

# Wait for Internet connection
wait_for_internet

wait_for_opkg() {
  while pgrep -x opkg >/dev/null; do
    log_say "Waiting for opkg to finish..."
    sleep 1
  done
  log_say "opkg is released, our turn!"
}

# Wait for opkg to finish
wait_for_opkg

# Cleanup our auto-provision and prepare for first real boot
[ -d /etc/auto-provision ] && rm -rf /etc/auto-provision
[ -f /etc/rc.local ] && echo "# Empty by design" > /etc/rc.local

# If nothing is set for REPO we set it to main
if [ -z "${REPO}" ]; then
    REPO="main"
fi

HASH_STORE="/etc/config/.script-repo"
CURRENT_HASH=$(
    curl \
        --silent "https://api.github.com/repos/PrivateRouter-LLC/script-repo/commits/${REPO}" | \
        jq --raw-output '.sha'
)

# Set our current repo hash to the hash we just got
echo "${CURRENT_HASH}" > "${HASH_STORE}"

# Download our startup.tar.gz with our startup scripts and load them in
log_say "Downloading startup.tar.gz"
wget -q -O /tmp/startup.tar.gz "https://github.com/PrivateRouter-LLC/script-repo/raw/${REPO}/startup-scripts/startup.tar.gz"
# Verify it downloaded successfully
if [ $? -eq 0 ]; then
    log_say "Extracting startup.tar.gz"
    tar -xzf /tmp/startup.tar.gz -C /etc
    rm /tmp/startup.tar.gz
else
    # We did not download our startup, and we NEED TO!
    log_say "We have to reboot because we did not download our startup script successfully!"
    reboot
    exit 1
fi

# Install LXC and related packages
PACKAGES="lxc lxc-attach lxc-auto lxc-autostart lxc-cgroup lxc-checkconfig lxc-common lxc-config lxc-configs lxc-console lxc-copy lxc-create lxc-destroy lxc-device lxc-execute lxc-freeze lxc-hooks lxc-info lxc-init lxc-ls lxc-monitor lxc-monitord lxc-snapshot lxc-start lxc-stop lxc-templates lxc-top lxc-unfreeze lxc-unprivileged lxc-unshare lxc-user-nic lxc-usernsexec lxc-wait liblxc luci-app-lxc luci-i18n-lxc-en rpcd-mod-lxc"

for pkg in $PACKAGES; do
    opkg install $pkg
done

# setup LXC config
mkdir /opt/docker2/compose/lxc
rm /etc/lxc/default.conf
rm /etc/lxc/lxc.conf
touch /etc/lxc/default.conf
touch /etc/lxc/lxc.conf

cat > /etc/lxc/lxc.conf <<EOL
lxc.lxcpath = /opt/docker2/compose/lxc
EOL

cat > /etc/lxc/default.conf <<EOL
#lxc.net.0.type = empty
lxc.net.0.type = veth
lxc.net.0.link = br-lan
lxc.net.0.flags = up
#lxc.net.0.hwaddr = 00:FF:DD:BB:CC:01
EOL

rm /etc/init.d/lxc-auto
touch /etc/init.d/lxc-auto
chmod +x /etc/init.d/lxc-auto
cat > /etc/init.d/lxc-auto <<EOL
#!/bin/bash /etc/rc.common

. /lib/functions.sh

START=99
STOP=00

run_command() {
	local command="$1"
	$command
}

start_container() {
    local cfg="$1"
    local name

    config_get name "$cfg" name
    config_list_foreach "$cfg" command run_command

    if [ -n "$name" ]; then
        local config_path="/opt/docker2/compose/lxc/$name/config"

        # Change permissions so that the script can write to the file
        chmod 664 "$config_path" || echo "Failed to set permissions on $config_path" >> /etc/lxc/error.log

        # Generate a random MAC address
        local MAC=$(od -An -N6 -tx1 /dev/urandom | sed -e 's/  */:/g' -e 's/^://')

        # Debugging: log the MAC address generation
        echo "Debug: Generated MAC $MAC for $name" >> /etc/lxc/error.log

        # Remove existing MAC address setting if it exists
        sed -i "/^lxc.net.0.hwaddr/d" "$config_path"

        # Add new MAC address setting
        echo "lxc.net.0.hwaddr = $MAC" >> "$config_path" || echo "Failed to write MAC address to $config_path" >> /etc/lxc/error.log

        # Start the container
        /usr/bin/lxc-start -n "$name"
    fi
}

max_timeout=0

stop_container() {
	local cfg="$1"
	local name timeout

	config_get name "$cfg" name
	config_get timeout "$cfg" timeout 300

	if [ "$max_timeout" -lt "$timeout" ]; then
		max_timeout=$timeout
	fi

	if [ -n "$name" ]; then
		/usr/bin/lxc-stop -n "$name" -t $timeout &
	fi
}

start() {
	config_load lxc-auto
	config_foreach start_container container
}

stop() {
	config_load lxc-auto
	config_foreach stop_container container
	# ensure e.g. shutdown doesn't occur before maximum timeout on
	# containers that are shutting down
	if [ $max_timeout -gt 0 ]; then
		sleep $max_timeout
	fi
}

#Export systemd cgroups
boot() {
	if [ ! -d /sys/fs/cgroup/systemd ]; then
		mkdir -p /sys/fs/cgroup/systemd
		mount -t cgroup -o rw,nosuid,nodev,noexec,relatime,none,name=systemd cgroup /sys/fs/cgroup/systemd
	fi

	if [ ! -d /run ]; then
		ln -s /var/run /run
	fi

	start
}
EOL

log_say "Removing our script before reboot"
rm -- "$0"

log_say "Reboot to uptake our rc.custom boot script"
reboot
