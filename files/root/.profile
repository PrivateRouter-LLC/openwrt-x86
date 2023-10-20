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

install_packages() {
    # Install packages
    log_say "Installing packages: ${1}"
    local count=$(echo "${1}" | wc -w)
    log_say "Packages to install: ${count}"

    for package in ${1}; do
        if ! opkg list-installed | grep -q "^$package -"; then
            log_say "Installing $package..."
            # use --force-maintainer to preserve the existing config
            opkg install --force-maintainer $package
            if [ $? -eq 0 ]; then
                log_say "$package installed successfully."
            else
                log_say "Failed to install $package."
            fi
        else
            log_say "$package is already installed."
        fi
    done
}

export log_say
export install_packages