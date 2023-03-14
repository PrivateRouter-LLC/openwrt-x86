#!/usr/bin/env bash
# Stage 3 booster to prepare router for first real boot

# Verify we are connected to the Internet
is_connected() {
    ping -q -c3 1.1.1.1 >/dev/null 2>&1
    return $?
}

# Log to the system log and echo if needed
log_say()
{
    echo "${1}"
    logger "${1}"
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

# Set our router's dns
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# Check and wait for Internet connection
while ! is_connected; do
    log_say "Waiting for Internet connection..."
    sleep 1
done
log_say "Internet connection established"

# Cleanup our auto-provision and prepare for first real boot
[ -d /etc/auto-provision ] && rm -rf /etc/auto-provision
[ -f /etc/rc.local ] && echo "# Empty by design" > /etc/rc.local

# Download our startup.tar.gz with our startup scripts and load them in
log_say "Downloading startup.tar.gz"
wget -q -O /tmp/startup.tar.gz https://github.com/PrivateRouter-LLC/script-repo/raw/main/startup-scripts/startup.tar.gz
log_say "Extracting startup.tar.gz"
tar -xzf /tmp/startup.tar.gz -C /etc
log_say "Enabling our rc.custom startup script"
/etc/init.d/custom disable
/etc/init.d/custom enable
log_say "Running our rc.custom startup script"
bash /etc/rc.custom
log_say "We are done with our first boot and should be setup to run correctly!"

# We are done, remove ourself by script name
rm -- "$0"