# This is where we designate the branch to use from our script repos
# main is production and we can set others for testing.
REPO=main
export REPO

# Source our base OpenWRT functions
. /lib/functions.sh

# Log to the system log and echo if needed
log_say()
{
    echo "Log Say: ${1}"
    logger -s "Log Say: ${1}"
    echo "${1}" >> "/tmp/console_log_say.log"
}

export -f log_say