#!/usr/bin/env bash
set -euo pipefail

# Encrypt one or more local files with age using password-only symmetric encryption.
# Usage:
#   ./encrypt-with-age.sh file1 [file2 ...]
#
# If no files are passed, you will be prompted to enter files one at a time.
# age securely prompts for the passphrase for each file.

if ! command -v age >/dev/null 2>&1; then
  echo "Error: age is not installed or not on PATH." >&2
  echo "Install age first, then rerun this script." >&2
  exit 1
fi

input_files=("$@")

if [[ ${#input_files[@]} -eq 0 ]]; then
  echo "Enter files to encrypt, one per line. Press Enter on a blank line when done."
  while true; do
    read -r -p "File to encrypt: " input_file
    [[ -z "$input_file" ]] && break
    input_files+=("$input_file")
  done
fi

if [[ ${#input_files[@]} -eq 0 ]]; then
  echo "Error: no files provided." >&2
  exit 1
fi

expand_path() {
  local path="$1"
  if [[ "$path" == ~/* ]]; then
    printf '%s\n' "${HOME}/${path#~/}"
  else
    printf '%s\n' "$path"
  fi
}

for input_file in "${input_files[@]}"; do
  input_file="$(expand_path "$input_file")"

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
      *) echo "Skipped: $input_file"; continue ;;
    esac
  fi

  echo "Encrypting: $input_file"
  echo "Output:     $output_file"
  echo

  # -p/--passphrase uses symmetric password-based encryption and prompts safely.
  age --passphrase --armor --output "$output_file" "$input_file"

  chmod 600 "$output_file"
  echo "Encrypted file written to: $output_file"
  echo
done
