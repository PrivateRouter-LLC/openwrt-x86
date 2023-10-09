#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <commit_id>"
    exit 1
fi

commit_id="$1"

# Check if the commit exists
if git rev-parse --quiet --verify "$commit_id" > /dev/null; then
    # Reset the HEAD to the specified commit
    git reset --hard "$commit_id"
    if [ $? -eq 0 ]; then
        echo "Reset the HEAD to commit $commit_id successfully."
    else
        echo "Failed to reset the HEAD to commit $commit_id."
    fi
else
    echo "Commit $commit_id does not exist."
fi