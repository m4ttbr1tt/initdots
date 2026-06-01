#!/usr/bin/env bash
set -euo pipefail

# Unattended archinstall wrapper.
# Prompts once for the install password, stores it in ARCHINSTALL_PASSWORD for
# this process, hashes it, writes archinstall credentials JSON, then runs
# archinstall with the selected config.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-$SCRIPT_DIR/user_configuration.json}"
CREDS="${CREDS:-$SCRIPT_DIR/user_credentials.json}"
USERNAME="${ARCHINSTALL_USERNAME:-matt}"
HOSTNAME="${ARCHINSTALL_HOSTNAME:-archlinux}"

run_as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Error: updating archinstall requires root privileges or sudo." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

read_password() {
  local first second
  while true; do
    read -r -s -p "Arch install password for user '$USERNAME': " first
    echo
    read -r -s -p "Confirm password: " second
    echo

    if [[ -z "$first" ]]; then
      echo "Password cannot be empty." >&2
      continue
    fi

    if [[ "$first" != "$second" ]]; then
      echo "Passwords did not match; try again." >&2
      continue
    fi

    export ARCHINSTALL_PASSWORD="$first"
    unset first second
    break
  done
}

write_credentials_json() {
  local password_hash
  password_hash="$(printf '%s' "$ARCHINSTALL_PASSWORD" | openssl passwd -6 -stdin)"

  umask 077
  python - "$CREDS" "$USERNAME" "$password_hash" <<'PY'
import json
import sys
from pathlib import Path

creds_path = Path(sys.argv[1])
username = sys.argv[2]
password_hash = sys.argv[3]

creds = {
    "users": [
        {
            "username": username,
            "sudo": True,
            "enc_password": password_hash,
        }
    ],
    "root_enc_password": password_hash,
}

creds_path.write_text(json.dumps(creds, indent=2) + "\n")
PY
}

main() {
  if command -v pacman >/dev/null 2>&1; then
    echo "Updating archinstall before running install..."
    run_as_root pacman -Sy --needed --noconfirm archinstall
  fi

  require_cmd archinstall
  require_cmd openssl
  require_cmd python

  if [[ ! -f "$CONFIG" ]]; then
    echo "Missing archinstall config: $CONFIG" >&2
    echo "Create it with: archinstall --dry-run" >&2
    exit 1
  fi

  read_password
  write_credentials_json

  timedatectl set-ntp true || true

  echo "Running archinstall with:"
  echo "  CONFIG=$CONFIG"
  echo "  CREDS=$CREDS"
  echo "  ARCHINSTALL_USERNAME=$USERNAME"
  echo "  ARCHINSTALL_HOSTNAME=$HOSTNAME"

  archinstall --config "$CONFIG" --creds "$CREDS"
}

main "$@"
