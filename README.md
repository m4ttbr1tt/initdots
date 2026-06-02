# initdots

Bootstrap a fresh **Fedora** machine by decrypting SSH bootstrap files, cloning the dotfiles repo, and running its Fedora setup.

## Fedora Workstation

Install [Fedora Workstation](https://fedoraproject.org/workstation/). It already includes what you need to clone this repo.

## Usage

Clone this repo over HTTPS:

```bash
git clone https://github.com/m4ttbr1tt/initdots.git
cd initdots
```

Run the decrypt/bootstrap script:

```bash
./decrypt-age-to-ssh.sh
```

The script installs its own runtime dependencies (`age`, `expect`, and OpenSSH client tools) when they are missing.

The script will:

1. Prompt once for the shared `age` passphrase and decrypt every `*.age` file under `./encrypt`.
2. Move decrypted files into `~/.ssh` with safe permissions.
3. Start `ssh-agent` for the script process.
4. Test the GitHub SSH connection with `ssh -T git@github.com`.
5. Clone `git@github.com:m4ttbr1tt/dotfiles.git` into `~/git/github/m4ttbr1tt/dotfiles` if missing.
6. Run the dotfiles Fedora setup with `./setup` inside the dotfiles repo.

After setup, reboot or log out.

## Dotfiles follow-up commands

Base setup is intentionally separate from optional larger apps and repo cloning.

Optional larger apps:

```bash
cd ~/git/github/m4ttbr1tt/dotfiles
./setup packages
```

Clone/update personal repos:

```bash
cd ~/git/github/m4ttbr1tt/dotfiles
./setup clonerepos
```

`wallpapers`, `notes`, and `blog` clone with `--depth 1`.

## Encrypting files

To add or refresh encrypted files:

```bash
./encrypt-with-age.sh path/to/file [another/file]
```

This writes `path/to/file.age` using password-based `age` encryption.
