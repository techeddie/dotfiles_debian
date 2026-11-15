# dotfiles_debian

One-command shell setup for Debian servers: **fish**, **Neovim**, **tmux**, **lf** and **lazygit**, plus **fzf**, **zoxide** and **eza**.

This repo only contains the installer. Each tool's configuration lives in its own repo. `install.sh` installs the tools, clones the config repos to `~/opt/dotfiles_debian/` and symlinks them into `~/.config/`. Running it again updates repos and tools to the latest versions.

Made for Debian 12 (bookworm) and Debian 13 (trixie) on amd64 and arm64.

## Config repos

| Repo | Linked to | Content |
|---|---|---|
| [fish_debian](https://github.com/techeddie/fish_debian) | `~/.config/fish` | fish config: zoxide, fzf, eza aliases, key bindings |
| [nvim_debian](https://github.com/techeddie/nvim_debian) | `~/.config/nvim` | Neovim config (packer) |
| [tmux_debian](https://github.com/techeddie/tmux_debian) | `~/.config/tmux`, `~/.tmux.conf`, `~/.tmux` | tmux config with tpm and tmux-resurrect |
| [lf_debian](https://github.com/techeddie/lf_debian) | `~/.config/lf` | lf file manager config |
| [lazygit_debian](https://github.com/techeddie/lazygit_debian) | `~/.config/lazygit` | lazygit config and installer |

## Quick start

```bash
# git is not part of minimal Debian images (as root: drop sudo)
sudo apt-get update && sudo apt-get install -y git

# Clone and run the installer
git clone https://github.com/techeddie/dotfiles_debian.git ~/opt/dotfiles_debian
~/opt/dotfiles_debian/install.sh

# Switch to fish in the current session
exec fish -l
```

Works as a normal user with sudo and as root. As root without sudo installed, the installer installs sudo first.

## What gets installed

| Tool | Source | Location |
|---|---|---|
| fish, tmux, git, curl, tree, fd, bat, ripgrep, ncdu, 7z, build-essential | apt | system |
| Neovim | latest GitHub release | `/opt/nvim`, linked to `/usr/local/bin/nvim` |
| lf | latest GitHub release | `/usr/local/bin/lf` |
| lazygit | latest GitHub release (via `lazygit_debian/install.sh`) | `/usr/local/bin/lazygit` |
| fzf | upstream git | `~/.fzf`, linked to `~/.local/bin/fzf` |
| zoxide | latest GitHub release | `~/.local/bin/zoxide` |
| eza | latest GitHub release | `~/.local/bin/eza` |

fzf, zoxide and eza come from upstream because the Debian 12 packages are too old or missing (`fzf --fish` needs fzf 0.48+). Debian's `fdfind` and `batcat` are linked as `fd` and `bat` in `~/.local/bin`.

Latest versions are resolved with `git ls-remote`, not the GitHub API, so there is no rate limit.

## What the installer does

1. Installs apt packages
2. Installs fzf, zoxide, eza, Neovim and lf from upstream
3. Clones or updates the config repos in `~/opt/dotfiles_debian/`
4. Installs lazygit
5. Symlinks the configs into `~/.config/`. An existing real file or folder is moved to `<name>.bak.<timestamp>` first
6. Installs Neovim plugins headless (packer)
7. Sets fish as login shell

## Layout

```
~/opt/dotfiles_debian/
├── install.sh
├── fish_debian/      -> ~/.config/fish
├── nvim_debian/      -> ~/.config/nvim
├── tmux_debian/      -> ~/.config/tmux
├── lf_debian/        -> ~/.config/lf
└── lazygit_debian/   -> ~/.config/lazygit
```

Clone target can be overridden:

```bash
# Clone config repos somewhere else
REPO_DIR=/srv/dotfiles ./install.sh
```

The script can be run from any folder (e.g. a mounted host volume). Config repos always go to `REPO_DIR`.

## Updating

```bash
# Pull all config repos and fetch the latest tool releases
~/opt/dotfiles_debian/install.sh
```

## Host-specific settings

Settings that only apply to one server (aliases, network interfaces, credentials) go into `~/.config/fish/local.fish`. The file is gitignored and sourced at the end of `config.fish`.

```bash
# Start from the example
cp ~/.config/fish/local.fish.example ~/.config/fish/local.fish
```

## Key bindings

**fish**

| Key | Action |
|---|---|
| `Ctrl-g` / `Alt-g` | lazygit |
| `Ctrl-l` / `Alt-l` | lf (replaces clear-screen) |
| `Ctrl-t` | fzf: pick file |
| `Ctrl-r` | fzf: search history |
| `Alt-c` | fzf: jump to directory |
| `cd <part>` | zoxide jump |
| `cdi` | zoxide interactive |

**tmux** (prefix `Ctrl-b`)

| Key | Action |
|---|---|
| `prefix r` | reload config |
| `prefix I` | install plugins (tpm) |
| `prefix S` / `prefix R` | save / restore session (resurrect) |

## Testing in Docker

```bash
# Throwaway Debian container, runs the installer as root
docker run -it --rm debian:bookworm-slim bash -c '
    apt-get update && apt-get install -y git ca-certificates sudo &&
    git clone https://github.com/techeddie/dotfiles_debian.git ~/opt/dotfiles_debian &&
    ~/opt/dotfiles_debian/install.sh &&
    exec fish -l'
```

Use `debian:trixie-slim` for Debian 13.

## Uninstall

```bash
# Remove config symlinks
rm ~/.config/{fish,nvim,tmux,lf,lazygit} ~/.tmux.conf ~/.tmux

# Remove cloned repos
rm -rf ~/opt/dotfiles_debian

# Switch back to bash
sudo chsh -s /bin/bash "$(id -un)"
```

Binaries in `/opt/nvim`, `/usr/local/bin` and `~/.local/bin` are left in place.
