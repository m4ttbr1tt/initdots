# initdots

Bootstrap a new machine by decrypting the SSH/dotfiles bootstrap files, then cloning and running the dotfiles setup.

## Usage

Clone this repo over HTTPS:

```bash
git clone https://github.com/m4ttbr1tt/initdots.git
cd initdots
```

Run the decrypt/bootstrap script:

The script installs its own runtime dependencies (`age`, `expect`, and OpenSSH client tools) when they are missing. It does not install `git`, because you already need `git` to clone this repo.

```bash
./decrypt-age-to-ssh.sh
```

The script will:

1. Prompt once for the shared `age` passphrase and decrypt every `*.age` file in this repo.
2. Move decrypted files into `~/.ssh` with safe permissions.
3. Start `ssh-agent` for the script process.
4. Test the GitHub SSH connection with `ssh -T git@github.com`.
5. Clone `git@github.com:m4ttbr1tt/dotfiles.git` into `~/git/github/m4ttbr1tt/dotfiles` if missing.
6. Run `./setup` inside the dotfiles repo.

## Encrypting files

To add or refresh encrypted files:

```bash
./encrypt-with-age.sh path/to/file [another/file]
```

This writes `path/to/file.age` using password-based `age` encryption.
