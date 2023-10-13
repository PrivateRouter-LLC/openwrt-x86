#!/bin/bash
# Run this on the actual device to check packages you place in the variable

# List of packages space-delimited
PACKAGES=""

# Variable to keep track of not installed packages
NOT_INSTALLED=""

# Iterate over each package and check if it's installed
for pkg in $PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        # Add to the list of not installed packages
        NOT_INSTALLED="$NOT_INSTALLED $pkg"
    fi
done

# Output the result
if [ -n "$NOT_INSTALLED" ]; then
    echo "The following packages are not installed:"
    echo $NOT_INSTALLED
else
    echo "All packages are installed."
fi