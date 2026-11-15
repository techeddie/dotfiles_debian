#!/usr/bin/env bash
# Deploy Debian server dotfiles: fish, nvim, tmux, lf, lazygit (+ fzf, zoxide, eza)
# Usage:
#   ./install.sh                     (can be run from any folder, e.g. a mounted host volume)
#   REPO_DIR=/some/path ./install.sh (override clone target)
# Config repos are always cloned to $REPO_DIR (default ~/opt/dotfiles_debian)
# and linked from there into ~/.config.
# Re-running the script updates repos and tools to the latest versions.
set -euo pipefail

# ---- Configuration ----
GITHUB_USER="techeddie"
REPOS=(fish_debian nvim_debian tmux_debian lf_debian lazygit_debian)
# Config repos are cloned here, independent of where this script lives
REPO_DIR="${REPO_DIR:-$HOME/opt/dotfiles_debian}"
LOCAL_BIN="$HOME/.local/bin"

APT_PACKAGES=(
    fish git curl ca-certificates tree fd-find bat
    tmux ripgrep build-essential unzip file ncdu p7zip-full
)

# ---- Helpers ----
log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# Clone repo if missing, otherwise fast-forward pull
git_sync() {
    local url=$1 dest=$2
    if [[ -d $dest/.git ]]; then
        git -C "$dest" pull --ff-only --quiet
    else
        git clone --quiet "$url" "$dest"
    fi
}

# Latest stable release tag via git (no GitHub API, no rate limit)
latest_tag() {
    git ls-remote --tags --refs --sort=-v:refname "https://github.com/$1.git" \
        | awk -F/ '!found && $3 ~ /^v?[0-9]+\.[0-9]+\.[0-9]+$/ { print $3; found = 1 }'
}

# Symlink src to dst; move an existing real file/dir out of the way first
link() {
    local src=$1 dst=$2
    if [[ -e $dst && ! -L $dst ]]; then
        local bak
        bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
        warn "$dst exists, moving to $bak"
        mv "$dst" "$bak"
    fi
    # -n: replace an existing symlink to a dir instead of creating a link inside it
    ln -sfn "$src" "$dst"
}

# ---- Sanity checks ----
[[ $EUID -ne 0 ]] || die "Run as a normal user, not root (sudo is used where needed)."
command -v apt-get >/dev/null || die "This script needs apt (Debian)."
sudo -v || die "sudo is required."

# Map machine arch to the asset names used by each project
case "$(uname -m)" in
    x86_64)  NVIM_ARCH=x86_64; GO_ARCH=amd64; RUST_ARCH=x86_64 ;;
    aarch64) NVIM_ARCH=arm64;  GO_ARCH=arm64; RUST_ARCH=aarch64 ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---- 1. apt packages ----
log "Installing apt packages"
sudo apt-get update -q
sudo apt-get install -y -q "${APT_PACKAGES[@]}"

# ---- 2. User bin dir and Debian renames ----
log "Setting up $LOCAL_BIN"
mkdir -p "$LOCAL_BIN" "$REPO_DIR" "$HOME/.config" "$HOME/tmp"
export PATH="$LOCAL_BIN:$PATH"
# Debian ships fd as fdfind and bat as batcat
[[ -x /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind "$LOCAL_BIN/fd"
[[ -x /usr/bin/batcat ]] && ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"

# ---- 3. fzf (upstream, apt version too old for 'fzf --fish') ----
log "Installing fzf"
git_sync https://github.com/junegunn/fzf.git "$HOME/.fzf"
"$HOME/.fzf/install" --bin >/dev/null 2>&1 || die "fzf binary download failed"
ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"

# ---- 4. zoxide (upstream, apt version too old) ----
log "Installing zoxide"
ZOXIDE_VER="$(latest_tag ajeetdsouza/zoxide)"
[[ -n $ZOXIDE_VER ]] || die "Could not determine latest zoxide version"
curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_VER}/zoxide-${ZOXIDE_VER#v}-${RUST_ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$LOCAL_BIN" zoxide

# ---- 5. eza (upstream, not in Debian 12) ----
log "Installing eza"
curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${RUST_ARCH}-unknown-linux-gnu.tar.gz" \
    | tar -xz -C "$LOCAL_BIN"

# ---- 6. Neovim (latest stable release to /opt/nvim) ----
log "Installing neovim"
curl -fsSLo "$TMP_DIR/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
sudo rm -rf /opt/nvim
sudo mkdir -p /opt/nvim
sudo tar -xzf "$TMP_DIR/nvim.tar.gz" -C /opt/nvim --strip-components=1
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

# ---- 7. lf (latest release to /usr/local/bin) ----
log "Installing lf"
curl -fsSL "https://github.com/gokcehan/lf/releases/latest/download/lf-linux-${GO_ARCH}.tar.gz" \
    | sudo tar -xz -C /usr/local/bin lf

# ---- 8. Dotfile repos ----
log "Syncing dotfile repos into $REPO_DIR"
for repo in "${REPOS[@]}"; do
    git_sync "https://github.com/$GITHUB_USER/$repo.git" "$REPO_DIR/$repo"
done

# ---- 9. lazygit (installer from lazygit_debian) ----
log "Installing lazygit"
bash "$REPO_DIR/lazygit_debian/install.sh"

# ---- 10. Symlinks ----
log "Linking configs"
link "$REPO_DIR/fish_debian"    "$HOME/.config/fish"
link "$REPO_DIR/nvim_debian"    "$HOME/.config/nvim"
link "$REPO_DIR/tmux_debian"    "$HOME/.config/tmux"
link "$REPO_DIR/lf_debian"      "$HOME/.config/lf"
link "$REPO_DIR/lazygit_debian" "$HOME/.config/lazygit"
# tmux config hardcodes ~/.tmux.conf and ~/.tmux/plugins/tpm
link "$HOME/.config/tmux/.tmux.conf" "$HOME/.tmux.conf"
link "$HOME/.config/tmux/.tmux"      "$HOME/.tmux"

# ---- 11. Neovim plugins (packer, headless) ----
log "Installing neovim plugins (may take a minute)"
if [[ -d $HOME/.local/share/nvim/site/pack/packer/start/packer.nvim ]]; then
    # Packer present: trigger sync explicitly
    timeout 600 nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync' >/dev/null 2>&1 \
        || warn "PackerSync did not finish cleanly, run :PackerSync manually"
else
    # First run: config bootstraps packer and syncs on its own
    timeout 600 nvim --headless -c 'autocmd User PackerComplete quitall' >/dev/null 2>&1 \
        || warn "Packer bootstrap did not finish cleanly, run :PackerSync manually"
fi

# ---- 12. Login shell ----
FISH_BIN="$(command -v fish)"
ME="$(id -un)"
if [[ $(getent passwd "$ME" | cut -d: -f7) != "$FISH_BIN" ]]; then
    log "Setting fish as login shell for $ME"
    sudo chsh -s "$FISH_BIN" "$ME"
fi

# ---- Done ----
log "Done"
printf '%s\n' \
    "fish:    $(fish --version)" \
    "nvim:    $(nvim --version | head -1)" \
    "tmux:    $(tmux -V)" \
    "lf:      $(lf -version)" \
    "lazygit: $(lazygit --version | grep -o 'version=[^,]*')" \
    "fzf:     $(fzf --version | cut -d' ' -f1)" \
    "zoxide:  $(zoxide --version)" \
    "eza:     $(eza --version | sed -n 2p)"
printf '\nHost-specific settings: cp %s/fish_debian/local.fish.example ~/.config/fish/local.fish\n' "$REPO_DIR"
printf 'Start fish now with: exec fish -l\n'
