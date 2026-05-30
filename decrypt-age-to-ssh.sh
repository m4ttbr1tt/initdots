#!/usr/bin/env bash
set -euo pipefail

# Decrypt age-encrypted files using password-only symmetric encryption,
# then move the decrypted results into ~/.ssh.
# Usage:
#   ./decrypt-age-to-ssh.sh             # decrypts every *.age file beside this script
#   ./decrypt-age-to-ssh.sh file1.age   # optionally decrypt specific files
#
# age securely prompts for the passphrase for each file.
# Output names remove a trailing .age suffix when present.
# Example: ./id_ed25519.age -> ~/.ssh/id_ed25519

if ! command -v age >/dev/null 2>&1; then
  echo "Error: age is not installed or not on PATH." >&2
  echo "Install age first, then rerun this script." >&2
  exit 1
fi

if ! command -v ssh-agent >/dev/null 2>&1; then
  echo "Error: ssh-agent is not installed or not on PATH." >&2
  exit 1
fi

# Start ssh-agent for this script process.
eval "$(ssh-agent -s)"

ssh_dir="${HOME}/.ssh"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
input_files=("$@")

if [[ ${#input_files[@]} -eq 0 ]]; then
  shopt -s nullglob
  input_files=("${script_dir}"/*.age)
  shopt -u nullglob
fi

if [[ ${#input_files[@]} -eq 0 ]]; then
  echo "Error: no .age files found beside this script." >&2
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

  input_basename="$(basename "$input_file")"
  if [[ "$input_basename" == *.age ]]; then
    output_basename="${input_basename%.age}"
  else
    output_basename="${input_basename}.decrypted"
  fi

  output_file="${ssh_dir}/${output_basename}"

  if [[ -e "$output_file" ]]; then
    read -r -p "Output exists ($output_file). Overwrite? [y/N] " answer
    case "$answer" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "Skipped: $input_file"; continue ;;
    esac
  fi

  tmp_file="$(mktemp "${ssh_dir}/.${output_basename}.tmp.XXXXXX")"
  cleanup() {
    rm -f "$tmp_file"
  }
  trap cleanup EXIT

  echo "Decrypting: $input_file"
  echo "Moving to:   $output_file"
  echo

  # age securely prompts for the passphrase.
  age --decrypt --output "$tmp_file" "$input_file"

  if [[ "$output_basename" == "id_ed25519" ]]; then
    chmod 400 "$tmp_file"
  else
    chmod 600 "$tmp_file"
  fi

  mv -f "$tmp_file" "$output_file"
  trap - EXIT

  echo "Decrypted file moved to: $output_file"
  echo
done

echo "Testing GitHub SSH connection..."
ssh -T git@github.com

repo_parent="${HOME}/git/github/m4ttbr1tt"
repo_dir="${repo_parent}/dotfiles"

mkdir -p "$repo_parent"

if [[ -d "$repo_dir/.git" ]]; then
  echo "Repository already exists: $repo_dir"
else
  echo "Cloning dotfiles repository..."
  git clone git@github.com:m4ttbr1tt/dotfiles.git "$repo_dir"
fi

cd "$repo_dir"

if [[ ! -x ./setup ]]; then
  echo "Error: ./setup is missing or not executable in $repo_dir" >&2
  exit 1
fi

echo "Running dotfiles setup..."
./setup
