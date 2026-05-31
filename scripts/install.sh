#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/holamendi/watergun/refs/heads/main/scripts/install.sh | bash -s <domain> <email> [--register-self]

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
  echo "Usage: curl -sSL https://install.watergun.dev | bash -s <domain> <email> [--register-self]"
}

# constants
SSH_USER="watergun"
SSH_DIR="/home/$SSH_USER/.ssh"
DOKKU_TAG=v0.36.7
DOKKU_APP="watergun"
DOKKU_POSTGRES_SERVICE="watergun-db"
POSTGRES_IMAGE_VERSION=18
WATERGUN_DOCKER_REPO="holamendi/watergun"
WATERGUN_GIT_REPO="https://github.com/holamendi/watergun.git"
WATERGUN_GIT_BRANCH="main"
LETSENCRYPT_PLUGIN_REPO="https://github.com/dokku/dokku-letsencrypt.git"
POSTGRES_PLUGIN_REPO="https://github.com/dokku/dokku-postgres.git"

# args
DOMAIN="${1:-}"
EMAIL="${2:-}"
REGISTER_SELF=false

if [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

if [ -n "${3:-}" ]; then
  if [ "$3" != "--register-self" ]; then
    usage
    exit 1
  fi

  REGISTER_SELF=true
fi

# validate script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "please run as root"
  exit 1
fi

# validate args
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  usage
  exit 1
fi

# validate email format
if ! echo "$EMAIL" | grep -qE "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
  echo "error: invalid email format"
  exit 1
fi

# ensure dependencies are installed
for cmd in curl host jq openssl wget; do
  if ! command_exists "$cmd"; then
    echo "error: $cmd is not installed."
    exit 1
  fi
done

# server info
HOSTNAME=$(hostname)
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

case "$(uname -m)" in
  x86_64 | amd64)
    CPU_TYPE="x86"
    ;;
  aarch64 | arm64)
    CPU_TYPE="arm64"
    ;;
  *)
    CPU_TYPE=$(uname -m)
    ;;
esac

# validate domain resolves to public ip
if ! host "$DOMAIN" | grep -q "$PUBLIC_IP"; then
  echo "error: $DOMAIN does not resolve to $PUBLIC_IP"
  exit 1
fi

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
if ! dokku plugin:list | grep -q "letsencrypt"; then
  if ! dokku plugin:install "$LETSENCRYPT_PLUGIN_REPO"; then
    echo "error: failed to install dokku-letsencrypt plugin"
    exit 1
  fi
fi

# install postgres plugin
if ! dokku plugin:list | grep -q "postgres"; then
  if ! dokku plugin:install "$POSTGRES_PLUGIN_REPO" postgres; then
    echo "error: failed to install dokku-postgres plugin"
    exit 1
  fi
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

# TODO: find a way to install dokku plugins without sudo rights
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
dokku ps:scale "$DOKKU_APP" web=0

# set env vars
dokku config:set "$DOKKU_APP" \
  ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 24) \
  ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 24) \
  ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 24) \
  ACCOUNT_SETUP_TOKEN=$(openssl rand -hex 24) \
  DEFAULT_URL="$DOMAIN" \
  JOB_CONCURRENCY=1 \
  JOB_POLLING_INTERVAL=0.1 \
  RAILS_ENV=production \
  SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --no-restart

# create and link postgres service
if ! dokku postgres:exists "$DOKKU_POSTGRES_SERVICE" >/dev/null 2>&1; then
  if ! dokku postgres:create "$DOKKU_POSTGRES_SERVICE" --image postgres --image-version "$POSTGRES_IMAGE_VERSION"; then
    echo "error: failed to create postgres service $DOKKU_POSTGRES_SERVICE"
    exit 1
  fi
fi

if ! dokku postgres:linked "$DOKKU_POSTGRES_SERVICE" "$DOKKU_APP" >/dev/null 2>&1; then
  if ! dokku postgres:link "$DOKKU_POSTGRES_SERVICE" "$DOKKU_APP" --no-restart; then
    echo "error: failed to link postgres service $DOKKU_POSTGRES_SERVICE to $DOKKU_APP"
    exit 1
  fi
fi

# sync git repo
dokku git:sync "$DOKKU_APP" "$WATERGUN_GIT_REPO" "$WATERGUN_GIT_BRANCH"

# build app
dokku ps:rebuild "$DOKKU_APP"

# pull docker image
# dokku git:from-image "$DOKKU_APP" "$WATERGUN_DOCKER_REPO"

# set app domain
if ! dokku domains:set "$DOKKU_APP" "$DOMAIN"; then
  echo "error: failed to set domain $DOMAIN on $DOKKU_APP"
  exit 1
fi

if ! dokku ps:scale "$DOKKU_APP" web=1 worker=1; then
  echo "error: failed to scale $DOKKU_APP"
  exit 1
fi

if ! dokku letsencrypt:enable "$DOKKU_APP"; then
  echo "error: failed to enable letsencrypt for $DOKKU_APP"
  exit 1
fi

# set up watergun account
SETUP_TOKEN=$(dokku config:get "$DOKKU_APP" ACCOUNT_SETUP_TOKEN)

if [ "$REGISTER_SELF" = true ]; then
  DATABASE_URL=$(dokku config:get "$DOKKU_APP" DATABASE_URL)

  if [ -z "$DATABASE_URL" ]; then
    echo "error: DATABASE_URL is not set on $DOKKU_APP"
    exit 1
  fi

  SETUP_PAYLOAD=$(jq -n \
    --arg server_name "$HOSTNAME" \
    --arg public_ip "$PUBLIC_IP" \
    --arg cpu_type "$CPU_TYPE" \
    --arg email "$EMAIL" \
    --arg domain "$DOMAIN" \
    --arg dokku_app "$DOKKU_APP" \
    --arg postgres_service "$DOKKU_POSTGRES_SERVICE" \
    --arg postgres_version "$POSTGRES_IMAGE_VERSION" \
    --arg database_url "$DATABASE_URL" \
    '{
      server: {name: $server_name, public_ip: $public_ip, cpu_type: $cpu_type},
      user: {email: $email},
      installation: {
        project: {name: "Watergun"},
        app: {name: "Watergun", dokku_id: $dokku_app, builder: "dockerfile"},
        domain: {hostname: $domain, ssl_enabled: true},
        service: {
          name: "Watergun DB",
          dokku_id: $postgres_service,
          service_type: "postgres",
          version: $postgres_version,
          dsn: $database_url
        },
        service_link: {env_name: "DATABASE_URL"}
      }
    }')
else
  SETUP_PAYLOAD=$(jq -n \
    --arg server_name "$HOSTNAME" \
    --arg public_ip "$PUBLIC_IP" \
    --arg cpu_type "$CPU_TYPE" \
    --arg email "$EMAIL" \
    '{
      server: {name: $server_name, public_ip: $public_ip, cpu_type: $cpu_type},
      user: {email: $email}
    }')
fi

SETUP_RESPONSE=$(curl -s -X POST "https://$DOMAIN/api/internal/setups" \
  -H "Authorization: Bearer $SETUP_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$SETUP_PAYLOAD")

if [ $? -ne 0 ]; then
  echo "error: failed to set up watergun account"
  exit 1
fi

FIRST_RUN_URL=$(echo $SETUP_RESPONSE | jq -r '.first_run_url')
PUBLIC_KEY=$(echo $SETUP_RESPONSE | jq -r '.public_key')

echo "$PUBLIC_KEY" > "$SSH_DIR/authorized_keys"

if [ -z "$FIRST_RUN_URL" ] || [ "$FIRST_RUN_URL" = "null" ]; then
  echo "error: invalid response from setup API"
  echo "Response: $SETUP_RESPONSE"
  exit 1
fi

echo "Done!"
echo "Visit $FIRST_RUN_URL to set up your account."
