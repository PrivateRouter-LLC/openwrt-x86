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

# Wait for opkg to finish
wait_for_opkg

# Update opkg
update_opkg

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

# Verify if /etc/rc.local exists, if so copy it to /etc/rc.local.pr
if [ -f /etc/rc.local.pr ]; then
    cat </etc/rc.local.pr >/etc/rc.local
    rm /etc/rc.local.pr
else
    # Rewrite our rc.local to clean it up
    log_say "Setting a clean rc.local"
    if [ -f /pr-scripts/templates/rc.local.clean ]; then
        cat </pr-scripts/templates/rc.local.clean >/etc/rc.local
    else
        # Just in case!
        echo "" > /etc/rc.local
    fi
fi

# Mark our system as stage3 is already done!
touch /root/.stage3_done

# Reboot to take up the new script
reboot

exit 0
