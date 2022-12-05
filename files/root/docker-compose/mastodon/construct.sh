root@PrivateRouter:~# cat /root/docker-compose/pixelfed/construct.sh
#!/usr/bin/env bash

# This file is specific to the docker-compose you are spinning up
# which means you cannot use this as is without modifications in other
# applications you try to spin up.

# Pixelfed config based off of this blog post:
# https://blog.pixelfed.de/2020/05/29/pixelfed-in-docker/

# Get our running directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# We should only be executed in our output directory so we assume we output to the correct directory
wget -O "${SCRIPT_DIR}/env" https://raw.githubusercontent.com/pixelfed/pixelfed/dev/.env.docker

chmod 777 "${SCRIPT_DIR}/env"

# Generate our password for the database
GEN_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c14; echo)

# Edit our .env to replace the password values
sed -i -e "s/MYSQL_PASSWORD=pixelfed_db_pass/MYSQL_PASSWORD=${GEN_PASS}/g" -e "s/DB_PASSWORD=pixelfed_db_pass/DB_PASSWORD=${GEN_PASS}/g" "${SCRIPT_DIR}/env"

#Set our redis password to null so it stops complaining
sed -i "s/REDIS_PASSWORD=redis_password/REDIS_PASSWORD=null/g" "${SCRIPT_DIR}/env"

#Set our mysqld root password
GEN_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c14; echo)
echo "MYSQL_ROOT_PASSWORD=${GEN_PASS}" >> "${SCRIPT_DIR}/env"


# Do our dynamic link just because we have to have it
ln -s "${SCRIPT_DIR}/env" "${SCRIPT_DIR}/.env"

# Delete ourself and exit!
rm -- "$0"
