#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/holamendi/watergun/refs/heads/main/scripts/uninstall.sh | bash

SSH_USER="watergun"
DOKKU_APP="watergun"
DOKKU_APP_STORAGE_PATH="/var/lib/dokku/data/storage/$DOKKU_APP"

# validate script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "please run as root"
  exit 1
fi

# destroy dokku app
dokku apps:destroy watergun --force

# remove storage
rm -rf "$DOKKU_APP_STORAGE_PATH"

# delete user
deluser --remove-home "$SSH_USER"


