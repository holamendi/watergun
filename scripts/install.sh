#!/bin/bash

# check if running with sudo or as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# install required dokku plugins
dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git

# create user
adduser --disabled-password --gecos "" watergun
echo "watergun ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/watergun

# create dokku app
dokku apps:create watergun
dokku ps:scale watergun web=0 solid_queue=0

# mount storage
dokku storage:ensure_directory watergun --chown false
dokku storage:mount watergun /var/lib/dokku/data/storage/watergun:/app/storage

# sync git repo
dokku git:sync watergun https://github.com/holamendi/watergun.git main

# build app



