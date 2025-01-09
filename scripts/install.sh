#!/bin/bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# constants
SSH_USER="watergun"
SSH_DIR="/home/$SSH_USER/.ssh"
DOKKU_TAG=v0.35.12
DOKKU_APP="watergun"
DOKKU_APP_STORAGE_PATH="/var/lib/dokku/data/storage/$DOKKU_APP"
WATERGUN_DOCKER_REPO="holamendi/watergun"
WATERGUN_GIT_REPO="https://github.com/holamendi/watergun.git"
WATERGUN_GIT_BRANCH="pre-release"
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
  echo "Usage: curl -sSL https://install.watergun.dev | bash -s <domain> <email>"
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
for cmd in wget; do
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
    echo "error:failed to download Dokku"
    exit 1
  fi
fi

# set global domain
dokku domains:set-global "$DOMAIN"

# install letsencrypt plugin
if ! dokku plugin:install "$LETSENCRYPT_PLUGIN_REPO"; then
  echo "error: failed to install dokku-letsencrypt plugin"
  exit 1
fi

# set up letsencrypt
dokku letsencrypt:set --global email "$EMAIL"
dokku letsencrypt:cron-job --add

# create user
if ! adduser --disabled-password --gecos "" "$SSH_USER"; then
  echo "error:failed to create user $SSH_USER"
  exit 1
fi

# add user to docker group
usermod -aG docker "$SSH_USER"

# TODO: is there a way to install dokku plugins without sudo?
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/"$SSH_USER"
chmod 440 /etc/sudoers.d/"$SSH_USER"

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
dokku config:set "$DOKKU_APP" \
  RAILS_ENV=production \
  DEFAULT_URL="$DOMAIN" \
  SECRET_KEY_BASE=$(openssl rand -hex 64) \
  ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 24) \
  ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 24) \
  ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 24) \
  JOB_CONCURRENCY=1 \
  JOB_POLLING_INTERVAL=0.1 \
  --no-restart

# mount persistent storage
dokku storage:ensure-directory "$DOKKU_APP" --chown false
dokku storage:mount "$DOKKU_APP" "$DOKKU_APP_STORAGE_PATH:/app/storage"

# sync git repo
dokku git:sync "$DOKKU_APP" "$WATERGUN_GIT_REPO" "$WATERGUN_GIT_BRANCH"

# build app
dokku ps:rebuild "$DOKKU_APP"

# pull docker image
# dokku git:from-image "$DOKKU_APP" "$WATERGUN_DOCKER_REPO"

# set up watergun account
SETUP_RESPONSE=$(dokku run $DOKKU_APP bundle exec rake account:setup $HOSTNAME $PUBLIC_IP $CPU_TYPE $DOMAIN $EMAIL | grep ACCOUNT_DATA | sed 's/ACCOUNT_DATA://')
PUBLIC_KEY=$(echo $SETUP_RESPONSE | jq -r '.public_key')
TOKEN=$(echo $SETUP_RESPONSE | jq -r '.token')

# add public key to ssh user
echo "$PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"

# set app domain
dokku domains:set "$DOKKU_APP" "$DOMAIN"
dokku ps:scale "$DOKKU_APP" web=1 solid_queue=1
dokku letsencrypt:enable "$DOKKU_APP"

echo "Done!"
echo "Visit https://$DOMAIN/first-run/$TOKEN to set your password."
