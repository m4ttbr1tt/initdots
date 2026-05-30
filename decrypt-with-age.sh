#!/usr/bin/env bash
set -euo pipefail

# Decrypt an age-encrypted file using password-only symmetric encryption.
# Usage:
#   ./decrypt-with-age.sh [path-to-file.age]
#
# age will securely prompt for the passphrase.
# "In place" means this writes next to the encrypted file, removing a trailing
# .age suffix when present. Example: secret.txt.age -> secret.txt

if ! command -v age >/dev/null 2>&1; then
  echo "Error: age is not installed or not on PATH." >&2
  echo "Install age first, then rerun this script." >&2
  exit 1
fi

input_file="${1:-}"

while [[ -z "$input_file" ]]; do
  read -r -p "File to decrypt: " input_file
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

if [[ "$input_file" == *.age ]]; then
  output_file="${input_file%.age}"
else
  output_file="${input_file}.decrypted"
fi

if [[ "$output_file" == "$input_file" ]]; then
  echo "Error: refusing to decrypt over the input file." >&2
  exit 1
fi

if [[ -e "$output_file" ]]; then
  read -r -p "Output exists ($output_file). Overwrite? [y/N] " answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

tmp_file="$(mktemp "${output_file}.tmp.XXXXXX")"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

echo "Decrypting: $input_file"
echo "Output:     $output_file"
echo

# age will securely prompt for the passphrase.
age --decrypt --output "$tmp_file" "$input_file"

chmod 600 "$tmp_file"
mv -f "$tmp_file" "$output_file"
trap - EXIT

echo
echo "Decrypted file written to: $output_file"
