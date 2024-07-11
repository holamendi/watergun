#!/bin/bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# constants
SSH_USER="watergun"
SSH_DIR="/home/$SSH_USER/.ssh"
DOKKU_TAG=v0.34.6
DOKKU_APP="watergun"
DOKKU_APP_STORAGE_PATH="/var/lib/dokku/data/storage/$DOKKU_APP"
WATERGUN_REPO="https://github.com/holamendi/watergun.git"
WATERGUN_BRANCH="main"
LETSENCRYPT_PLUGIN_REPO="https://github.com/dokku/dokku-letsencrypt.git"

# server info
HOSTNAME=$(hostname)
CPU_TYPE=$(uname -m)
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

# args
DOMAIN="$1"
EMAIL="$2"

# validate script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "please run as root"
  exit 1
fi

# validate args
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <domain> <email> "
  exit 1
fi

# validate email format
if ! echo "$EMAIL" | grep -qE "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
  echo "error: invalid email format"
  exit 1
fi

# validate domain resolves to public ip
if ! host "$DOMAIN" | grep -q "$PUBLIC_IP"; then
  echo "error: $DOMAIN does not resolve to $PUBLIC_IP"
  exit 1
fi

# ensure dependencies are installed
for cmd in jq openssl wget; do
  if ! command_exists "$cmd"; then
    echo "error: $cmd is not installed."
    exit 1
  fi
done

# dokku installation
if ! command_exists "dokku"; then
  wget -NP . "https://dokku.com/install/$DOKKU_TAG/bootstrap.sh"
  if [ -f bootstrap.sh ]; then
    bash bootstrap.sh
  else
    echo "failed to download Dokku"
    exit 1
  fi
fi

# install letsencrypt plugin
if ! dokku plugin:install "$LETSENCRYPT_PLUGIN_REPO"; then
  echo "failed to install dokku-letsencrypt plugin"
  exit 1
fi

dokku letsencrypt:set --global email "$EMAIL"

# create user
if ! adduser --disabled-password --gecos "" "$SSH_USER"; then
  echo "failed to create user $SSH_USER"
  exit 1
fi

# TODO: is there a way to install dokku plugins without sudo?
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/"$SSH_USER"
chmod 440 /etc/sudoers.d/"$SSH_USER"

# create .ssh directoryee
mkdir -p "$SSH_DIR"
chown -R "$SSH_USER:$SSH_USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"
chown "$SSH_USER:$SSH_USER" "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

# create dokku app
dokku apps:create "$DOKKU_APP"
dokku ps:scale "$DOKKU_APP" web=0 solid_queue=0

# set env vars
dokku config:set "$DOKKU_APP" RAILS_ENV=production SECRET_KEY_BASE=$(openssl rand -hex 64) --no-restart

# mount storage
dokku storage:ensure-directory "$DOKKU_APP" --chown false
dokku storage:mount "$DOKKU_APP" "$DOKKU_APP_STORAGE_PATH:/app/storage"

# sync git repo
dokku git:sync "$DOKKU_APP" "$WATERGUN_REPO" "$WATERGUN_BRANCH"

# build app
dokku ps:rebuild "$DOKKU_APP"

# set up watergun account
SETUP_RESPONSE=$(dokku run $DOKKU_APP bundle exec rake account:setup $HOSTNAME $PUBLIC_IP $CPU_TYPE $EMAIL | grep ACCOUNT_DATA | sed 's/ACCOUNT_DATA://')
PUBLIC_KEY=$(echo $SETUP_RESPONSE | jq -r '.public_key')
TOKEN=$(echo $SETUP_RESPONSE | jq -r '.token')

# add public key to ssh user
echo "$PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"

# set domain
dokku domains:set "$DOKKU_APP" "$DOMAIN"
dokku ps:scale "$DOKKU_APP" web=1 solid_queue=1
dokku letsencrypt:enable "$DOKKU_APP"

DOKKU_APP_URL=$(dokku urls "$DOKKU_APP" --quiet | head -n 1)

echo "All set. Visit $DOKKU_APP_URL/first-run/$TOKEN to finish setting up your user account."
