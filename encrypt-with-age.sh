#!/usr/bin/env bash
set -euo pipefail

# Encrypt files or folders with age using password-only symmetric encryption.
# Usage:
#   ./encrypt-with-age.sh file1 [file2 ...]
#   ./encrypt-with-age.sh folder1 [folder2 ...]
#
# If no paths are passed, ./encrypt is processed by default.
# Prompts once for the shared age passphrase, then reuses it for every file.
# Output names append .age beside each input file.

if ! command -v age >/dev/null 2>&1; then
  echo "Error: age is not installed or not on PATH." >&2
  echo "Install age first, then rerun this script." >&2
  exit 1
fi

if ! command -v expect >/dev/null 2>&1; then
  echo "Error: expect is not installed or not on PATH." >&2
  echo "Install expect first, then rerun this script." >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
input_paths=("$@")

if [[ ${#input_paths[@]} -eq 0 ]]; then
  input_paths=("${script_dir}/encrypt")
fi

expand_path() {
  local path="$1"
  if [[ "$path" == ~/* ]]; then
    printf '%s\n' "${HOME}/${path#~/}"
  else
    printf '%s\n' "$path"
  fi
}

input_files=()
for input_path in "${input_paths[@]}"; do
  input_path="$(expand_path "$input_path")"

  if [[ ! -e "$input_path" ]]; then
    echo "Error: path does not exist: $input_path" >&2
    exit 1
  fi

  if [[ -d "$input_path" ]]; then
    while IFS= read -r -d '' found_file; do
      input_files+=("$found_file")
    done < <(find "$input_path" -type f ! -name '*.age' ! -name '.gitkeep' -print0 | sort -z)
  elif [[ -f "$input_path" ]]; then
    input_files+=("$input_path")
  else
    echo "Error: not a regular file or directory: $input_path" >&2
    exit 1
  fi
done

if [[ ${#input_files[@]} -eq 0 ]]; then
  echo "Error: no files found to encrypt." >&2
  exit 1
fi

read -r -s -p "age passphrase: " age_passphrase
echo
read -r -s -p "Confirm age passphrase: " age_passphrase_confirm
echo

if [[ "$age_passphrase" != "$age_passphrase_confirm" ]]; then
  echo "Error: passphrases did not match." >&2
  exit 1
fi
unset age_passphrase_confirm

encrypt_with_passphrase() {
  INITDOTS_AGE_PASSPHRASE="$age_passphrase" \
  INITDOTS_AGE_INPUT_FILE="$INITDOTS_AGE_INPUT_FILE" \
  INITDOTS_AGE_OUTPUT_FILE="$INITDOTS_AGE_OUTPUT_FILE" \
  expect <<'EOF'
set timeout -1
set passphrase $env(INITDOTS_AGE_PASSPHRASE)
set input_file $env(INITDOTS_AGE_INPUT_FILE)
set output_file $env(INITDOTS_AGE_OUTPUT_FILE)
spawn age --passphrase --armor --output $output_file $input_file
expect {
  -nocase -re "passphrase" {
    send -- "$passphrase\r"
    exp_continue
  }
  eof
}
set status [lindex [wait] 3]
exit $status
EOF
}

for input_file in "${input_files[@]}"; do
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

  tmp_file="$(mktemp "${output_file}.tmp.XXXXXX")"
  cleanup() {
    rm -f "$tmp_file"
  }
  trap cleanup EXIT

  echo "Encrypting: $input_file"
  echo "Output:     $output_file"
  echo

  INITDOTS_AGE_INPUT_FILE="$input_file" \
  INITDOTS_AGE_OUTPUT_FILE="$tmp_file" \
  encrypt_with_passphrase

  chmod 600 "$tmp_file"
  mv -f "$tmp_file" "$output_file"
  trap - EXIT

  echo "Encrypted file written to: $output_file"
  echo
done

unset age_passphrase INITDOTS_AGE_INPUT_FILE INITDOTS_AGE_OUTPUT_FILE
