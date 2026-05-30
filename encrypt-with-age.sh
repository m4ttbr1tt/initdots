#!/usr/bin/env bash
set -euo pipefail

# Encrypt a local file with age using password-only symmetric encryption.
# Usage:
#   ./encrypt-with-age.sh [path-to-file]
#
# age will securely prompt for the passphrase; the passphrase is not accepted
# as an argument so it does not appear in shell history or process lists.

if ! command -v age >/dev/null 2>&1; then
  echo "Error: age is not installed or not on PATH." >&2
  echo "Install age first, then rerun this script." >&2
  exit 1
fi

input_file="${1:-}"

while [[ -z "$input_file" ]]; do
  read -r -p "File to encrypt: " input_file
done

# Expand a leading ~/ without using eval.
if [[ "$input_file" == ~/* ]]; then
  input_file="${HOME}/${input_file#~/}"
fi

if [[ ! -e "$input_file" ]]; then
  echo "Error: file does not exist: $input_file" >&2
  exit 1
fi

if [[ ! -f "$input_file" ]]; then
  echo "Error: not a regular file: $input_file" >&2
  exit 1
fi

if [[ ! -r "$input_file" ]]; then
  echo "Error: file is not readable: $input_file" >&2
  exit 1
fi

output_file="${input_file}.age"

if [[ -e "$output_file" ]]; then
  read -r -p "Output exists ($output_file). Overwrite? [y/N] " answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

echo "Encrypting: $input_file"
echo "Output:     $output_file"
echo

# -p/--passphrase uses symmetric password-based encryption and prompts safely.
age --passphrase --armor --output "$output_file" "$input_file"

chmod 600 "$output_file"
echo
echo "Encrypted file written to: $output_file"
echo "Decrypt with: age --decrypt --output '${input_file}.decrypted' '$output_file'"
