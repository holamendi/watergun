#!/bin/bash

SSH_USER="watergun"
SSH_DIR="/home/$SSH_USER/.ssh"
DOKKU_TAG=v0.34.6
DOKKU_APP="watergun"
DOKKU_APP_STORAGE_PATH="/var/lib/dokku/data/storage/$DOKKU_APP"
WATERGUN_REPO="https://github.com/holamendi/watergun.git"
WATERGUN_BRANCH="main"
LETSENCRYPT_PLUGIN_REPO="https://github.com/dokku/dokku-letsencrypt.git"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "please run as root"
  exit
fi

# check that dokku 0.33 or higher is installed or install it
if ! command_exists dokku; then
  wget -NP . "https://dokku.com/install/$DOKKU_TAG/bootstrap.sh"
  sudo bash bootstrap.sh
fi

# ensure dependencies
for cmd in jq openssl; do
  if ! command_exists "$cmd"; then
    echo "error: $cmd is not installed."
    exit 1
  fi
done

# install required dokku plugins
if ! sudo dokku plugin:install "$LETSENCRYPT_PLUGIN_REPO"; then
  echo "failed to install dokku-letsencrypt plugin"
  exit 1
fi

# create user
if ! adduser --disabled-password --gecos "" "$SSH_USER"; then
  echo "failed to create user $SSH_USER"
  exit 1
fi

# TODO: is there a way to install dokku plugins without sudo?
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/"$SSH_USER"

# create .ssh directory
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
dokku config:set "$DOKKU_APP" RAILS_ENV=production SECRET_KEY_BASE=$(openssl rand -hex 64)

# mount storage
dokku storage:ensure-directory "$DOKKU_APP" --chown false
dokku storage:mount "$DOKKU_APP" "$DOKKU_APP_STORAGE_PATH:/app/storage"

# sync git repo
dokku git:sync "$DOKKU_APP" "$WATERGUN_REPO" "$WATERGUN_BRANCH"

# build app
dokku ps:rebuild "$DOKKU_APP"

# set up watergun account
HOSTNAME=$(hostname)
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
CPU_TYPE=$(uname -m)

SETUP_RESULT=$(dokku run "$DOKKU_APP" bundle exec rake "account:setup[$HOSTNAME,$PUBLIC_IP,$CPU_TYPE]" | grep ACCOUNT_DATA | sed 's/ACCOUNT_DATA://')
PUBLIC_KEY=$(echo $SETUP_RESULT | jq -r '.public_key')
FIRST_SIGNUP_TOKEN=$(echo $SETUP_RESULT | jq -r '.first_signup_token')

# add public key to ssh user
echo "$PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"

DOKKU_APP_URL=$(dokku urls "$DOKKU_APP" --quiet | head -n 1)

dokku ps:scale "$DOKKU_APP" web=1 solid_queue=1

echo "Setup complete. Visit $DOKKU_APP_URL/first-run/$FIRST_SIGNUP_TOKEN to create your first user account."








