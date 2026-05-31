#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${INSTALL_SMOKE_IMAGE:-ubuntu:24.04}"

if [ "${WATERGUN_INSTALL_SMOKE_IN_CONTAINER:-}" != "1" ]; then
  docker run --rm \
    -e WATERGUN_INSTALL_SMOKE_IN_CONTAINER=1 \
    -v "$ROOT_DIR:/repo:ro" \
    -w /repo \
    "$IMAGE" \
    bash scripts/test-install-smoke.sh
  exit
fi

WORK_DIR="$(mktemp -d)"
STUB_DIR="$WORK_DIR/bin"
mkdir -p "$STUB_DIR"

cat > "$STUB_DIR/dokku" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

log_command() {
  printf "%s" "$1" >> "$INSTALL_SMOKE_LOG"
  shift

  for arg in "$@"; do
    printf " %s" "$arg" >> "$INSTALL_SMOKE_LOG"
  done

  printf "\n" >> "$INSTALL_SMOKE_LOG"
}

log_command dokku "$@"

case "${1:-}" in
  plugin:list)
    exit 0
    ;;
  postgres:exists | postgres:linked)
    exit 1
    ;;
  config:get)
    if [ "${2:-}" = "watergun" ] && [ "${3:-}" = "ACCOUNT_SETUP_TOKEN" ]; then
      printf "setup-token\n"
    elif [ "${2:-}" = "watergun" ] && [ "${3:-}" = "DATABASE_URL" ]; then
      printf "postgres://watergun:secret@dokku-postgres-watergun-db:5432/watergun-db\n"
    fi
    ;;
esac
STUB

cat > "$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf "curl" >> "$INSTALL_SMOKE_LOG"
for arg in "$@"; do
  printf " %s" "$arg" >> "$INSTALL_SMOKE_LOG"
done
printf "\n" >> "$INSTALL_SMOKE_LOG"

case "$*" in
  *checkip.amazonaws.com*)
    printf "203.0.113.10\n"
    ;;
  *api/internal/setups*)
    printf '{"first_run_url":"https://example.com/first-run","public_key":"ssh-ed25519 AAAATEST watergun"}\n'
    ;;
esac
STUB

cat > "$STUB_DIR/host" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf "host" >> "$INSTALL_SMOKE_LOG"
for arg in "$@"; do
  printf " %s" "$arg" >> "$INSTALL_SMOKE_LOG"
done
printf "\n" >> "$INSTALL_SMOKE_LOG"

printf "%s has address 203.0.113.10\n" "${1:-example.com}"
STUB

cat > "$STUB_DIR/openssl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf "openssl" >> "$INSTALL_SMOKE_LOG"
for arg in "$@"; do
  printf " %s" "$arg" >> "$INSTALL_SMOKE_LOG"
done
printf "\n" >> "$INSTALL_SMOKE_LOG"

printf "0123456789abcdef0123456789abcdef\n"
STUB

cat > "$STUB_DIR/jq" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-n" ]; then
  shift

  server_name=""
  public_ip=""
  cpu_type=""
  email=""
  domain=""
  dokku_app=""
  postgres_service=""
  postgres_version=""
  database_url=""
  expression=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --arg)
        key="$2"
        value="$3"
        case "$key" in
          server_name) server_name="$value" ;;
          public_ip) public_ip="$value" ;;
          cpu_type) cpu_type="$value" ;;
          email) email="$value" ;;
          domain) domain="$value" ;;
          dokku_app) dokku_app="$value" ;;
          postgres_service) postgres_service="$value" ;;
          postgres_version) postgres_version="$value" ;;
          database_url) database_url="$value" ;;
        esac
        shift 3
        ;;
      *)
        expression="$1"
        shift
        ;;
    esac
  done

  if [[ "$expression" == *installation* ]]; then
    printf '{"server":{"name":"%s","public_ip":"%s","cpu_type":"%s"},"user":{"email":"%s"},"installation":{"project":{"name":"Watergun"},"app":{"name":"Watergun","dokku_id":"%s","builder":"dockerfile"},"domain":{"hostname":"%s","ssl_enabled":true},"service":{"name":"Watergun DB","dokku_id":"%s","service_type":"postgres","version":"%s","dsn":"%s"},"service_link":{"env_name":"DATABASE_URL"}}}\n' "$server_name" "$public_ip" "$cpu_type" "$email" "$dokku_app" "$domain" "$postgres_service" "$postgres_version" "$database_url"
  else
    printf '{"server":{"name":"%s","public_ip":"%s","cpu_type":"%s"},"user":{"email":"%s"}}\n' "$server_name" "$public_ip" "$cpu_type" "$email"
  fi

  exit
fi

cat >/dev/null

case "$*" in
  *first_run_url*)
    printf "https://example.com/first-run\n"
    ;;
  *public_key*)
    printf "ssh-ed25519 AAAATEST watergun\n"
    ;;
  *)
    exit 1
    ;;
esac
STUB

for command in adduser chmod chown tee usermod wget; do
  cat > "$STUB_DIR/$command" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

name="$(basename "$0")"
printf "%s" "$name" >> "$INSTALL_SMOKE_LOG"
for arg in "$@"; do
  printf " %s" "$arg" >> "$INSTALL_SMOKE_LOG"
done
printf "\n" >> "$INSTALL_SMOKE_LOG"

if [ "$name" = "tee" ]; then
  cat >/dev/null
fi
STUB
done

chmod +x "$STUB_DIR"/*
export PATH="$STUB_DIR:$PATH"

run_install() {
  local name="$1"
  shift

  INSTALL_SMOKE_LOG="$WORK_DIR/$name.commands.log" \
    bash scripts/install.sh "$@" >"$WORK_DIR/$name.out" 2>"$WORK_DIR/$name.err"
}

assert_log_contains() {
  local log_file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$log_file"; then
    echo "expected installer to call: $expected"
    echo
    cat "$log_file"
    exit 1
  fi
}

assert_log_not_contains() {
  local log_file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$log_file"; then
    echo "expected installer not to call: $unexpected"
    echo
    cat "$log_file"
    exit 1
  fi
}

line_number_for() {
  local log_file="$1"
  local pattern="$2"

  grep -nF "$pattern" "$log_file" | head -n 1 | cut -d: -f1
}

assert_before() {
  local log_file="$1"
  local before="$2"
  local after="$3"
  local before_line
  local after_line

  before_line="$(line_number_for "$log_file" "$before")"
  after_line="$(line_number_for "$log_file" "$after")"

  if [ -z "$before_line" ] || [ -z "$after_line" ] || [ "$before_line" -ge "$after_line" ]; then
    echo "expected call order:"
    echo "  before: $before"
    echo "  after:  $after"
    echo
    cat "$log_file"
    exit 1
  fi
}

DEFAULT_LOG="$WORK_DIR/default.commands.log"
REGISTER_LOG="$WORK_DIR/register.commands.log"

run_install default example.com admin@example.com
run_install register example.com admin@example.com --register-self

if run_install invalid example.com admin@example.com --unknown-flag; then
  echo "expected unknown install flag to fail"
  exit 1
fi

grep -Fq "Usage: curl -sSL https://install.watergun.dev | bash -s <domain> <email> [--register-self]" "$WORK_DIR/invalid.out"

for log_file in "$DEFAULT_LOG" "$REGISTER_LOG"; do
  assert_log_contains "$log_file" "dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres"
  assert_log_contains "$log_file" "dokku postgres:exists watergun-db"
  assert_log_contains "$log_file" "dokku postgres:create watergun-db --image postgres --image-version 18"
  assert_log_contains "$log_file" "dokku postgres:linked watergun-db watergun"
  assert_log_contains "$log_file" "dokku postgres:link watergun-db watergun --no-restart"
  assert_log_contains "$log_file" "dokku config:get watergun ACCOUNT_SETUP_TOKEN"
  assert_log_not_contains "$log_file" "dokku storage:ensure-directory"
  assert_log_not_contains "$log_file" "dokku storage:mount"
  assert_before "$log_file" "dokku postgres:link watergun-db watergun --no-restart" "dokku git:sync watergun https://github.com/holamendi/watergun.git main"
done

assert_log_not_contains "$DEFAULT_LOG" '"installation"'
assert_log_contains "$REGISTER_LOG" "dokku config:get watergun DATABASE_URL"
assert_log_contains "$REGISTER_LOG" '"installation"'
assert_log_contains "$REGISTER_LOG" '"dokku_id":"watergun"'
assert_log_contains "$REGISTER_LOG" '"dokku_id":"watergun-db"'
assert_log_contains "$REGISTER_LOG" '"dsn":"postgres://watergun:secret@dokku-postgres-watergun-db:5432/watergun-db"'

echo "install smoke test passed"
