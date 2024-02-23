#!/bin/bash

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo"
  exit
fi

# Install dokku plugins
dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
dokku plugin:install https://github.com/dokku/dokku-redis.git redis

# Add user watergun with groups dokku, docker, and adm
adduser watergun
usermod -aG dokku,docker,adm watergun

# Add watergun public key to authorized_keys
sudo -u watergun mkdir -p /home/watergun/.ssh
echo "$(dokku run watergun bin/rails runner 'puts ServerIdentity.first.public_key')" | sudo -u watergun tee -a /home/watergun/.ssh/authorized_keys
