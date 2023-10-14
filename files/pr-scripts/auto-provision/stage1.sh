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

# If you already have the file /etc/config/tgdocker then we assume you have already run the setup
# If we run anything else again then we run the chance of overwriting a users configuration which we do not want to do
if [ ! -f /etc/config/tgdocker ]; then
    # Change our system hostname
    uci set system.@system[0].hostname='PrivateRouter'
    uci commit system

    # Set our PrivateRouter IP
    uci set network.lan.ipaddr='192.168.70.1'
    uci commit network

    # Set our PrivateRouter default password
    set_root_password "torguard"
fi

cat << EOF > /etc/rc.local
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

# Run Stage2 Script
bash /pr-scripts/auto-provision/stage2.sh

exit 0
EOF

touch /root/.stage1_done

reboot

exit 0
