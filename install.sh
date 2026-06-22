#!/bin/bash

# ============================================================
# MASU Terminal Installer v8.2 - BlackArch Edition
# Author: Matyas Abraham
# Supports: Arch, BlackArch, Ubuntu, Debian, Fedora,
#           OpenSUSE, Kali, Parrot OS, Termux
# ============================================================

set -eo pipefail

# ─── Cleanup Trap ──────────────────────────────────────────
cleanup() {
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && error "Installation interrupted! Check errors above."
    exit $exit_code
}
trap cleanup EXIT INT TERM

# ─── Colors ────────────────────────────────────────────────
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
BOLD="\e[1m"
RESET="\e[0m"

# ─── Helpers ───────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[  OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[FAIL]${RESET} $1"; }
step()    { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${RESET}"; }

spinner() {
    local pid=$1
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r  ${CYAN}%s${RESET} %s" "$frame" "$2"
            sleep "$delay"
        done
    done
    printf "\r"
}

# git_clone_retry <repo_url> <dest_dir> [extra git-clone args...]
# Retries a shallow clone up to 3 times with backoff, since flaky/limited
# internet connections are common for this script's users. Returns
# non-zero only after all attempts fail, leaving no partial directory
# behind so callers can safely re-check with [[ -d "$dest" ]].
git_clone_retry() {
    local repo="$1" dest="$2"
    shift 2
    local extra_args=("$@")
    local attempt=1 max_attempts=3 delay=3

    while (( attempt <= max_attempts )); do
        if [[ $attempt -gt 1 ]]; then
            warn "Retrying clone of $(basename "$repo") (attempt $attempt/$max_attempts)..."
        fi
        if git clone --depth=1 "${extra_args[@]}" "$repo" "$dest" 2>/dev/null; then
            return 0
        fi
        rm -rf "$dest"
        ((attempt++))
        [[ $attempt -le $max_attempts ]] && sleep "$delay"
    done

    warn "Could not clone $(basename "$repo") after $max_attempts attempts (check your internet connection)"
    return 1
}

# ─── Banner ────────────────────────────────────────────────
clear
echo -e "${GREEN}${BOLD}"
cat << 'EOF'
███╗   ███╗ █████╗ ███████╗██╗   ██╗
████╗ ████║██╔══██╗██╔════╝██║   ██║
██╔████╔██║███████║███████╗██║   ██║
██║╚██╔╝██║██╔══██║╚════██║██║   ██║
██║ ╚═╝ ██║██║  ██║███████║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝
EOF
echo -e "${CYAN}  Terminal Installer v8.2 — BlackArch Edition${RESET}"
echo -e "${MAGENTA}  By Matyas Abraham | MASU Cyber Learning Project${RESET}"
echo ""

# ─── Script Directory ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR=""
# When run via bash <(curl ...), BASH_SOURCE[0] is a pipe — configs can't be copied.
# In that case, warn the user and skip config copy steps gracefully.
if [[ ! -d "$SCRIPT_DIR" ]] || [[ "$SCRIPT_DIR" == "/" ]]; then
    warn "Running from pipe/curl — local config files (p10k, fastfetch) will be skipped."
    warn "For full setup, clone the repo and run: ./install.sh"
    SCRIPT_DIR=""
fi

# ─── Theme Selection ───────────────────────────────────────
CHOSEN_THEME="minimal" # Default
echo -e "${CYAN}Select Your MASU Theme Style:${RESET}"
echo -e "  1) ${GREEN}MASU Minimal${RESET} (Fast, clean, mobile-optimized)"
echo -e "  2) ${MAGENTA}MASU Cyber  ${RESET} (Neon colors, icon-heavy)"
echo -e "  3) ${YELLOW}P10K Default${RESET} (Run interactive wizard)"
read -rp "  Selection [1-3, default 1]: " theme_choice

case "$theme_choice" in
    2) CHOSEN_THEME="cyber" ;;
    3) CHOSEN_THEME="wizard" ;;
    *) CHOSEN_THEME="minimal" ;;
esac
info "Starting installation for theme: ${BOLD}$CHOSEN_THEME${RESET}"

# ─── Fastfetch on startup preference ──────────────────────
FASTFETCH_ON_START=false
echo ""
read -rp "  Show fastfetch info when a new terminal opens? (y/n, default n): " ff_choice
[[ "$ff_choice" == "y" || "$ff_choice" == "Y" ]] && FASTFETCH_ON_START=true

# ─── Root check ────────────────────────────────────────────
if [[ $EUID -eq 0 ]] && [[ -z "${PREFIX:-}" ]]; then
    warn "Running as root is NOT recommended."
    read -rp "  Continue as root? (y/n): " rootok
    [[ "$rootok" != "y" ]] && { info "Aborted."; exit 0; }
fi

# ─── OS Detection ──────────────────────────────────────────
step "Detecting System"

detect_os() {
    if [[ -n "${PREFIX:-}" ]] && [[ "$PREFIX" == *"com.termux"* ]]; then
        OS="termux"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        ID_LOWER="${ID,,}"
        case "$ID_LOWER" in
            arch|blackarch|manjaro|endeavouros) OS="arch" ;;
            ubuntu|linuxmint|pop|kali|parrot)  OS="debian" ;;
            debian)                             OS="debian" ;;
            fedora|rhel|centos|rocky)           OS="fedora" ;;
            opensuse*|sles)                     OS="opensuse" ;;
            *)
                if command -v pacman &>/dev/null; then OS="arch"
                elif command -v apt &>/dev/null;    then OS="debian"
                elif command -v dnf &>/dev/null;    then OS="fedora"
                elif command -v zypper &>/dev/null; then OS="opensuse"
                else OS="unknown"
                fi
                ;;
        esac
    else
        OS="unknown"
    fi

    if [[ "$OS" = "arch" ]] && grep -qi "blackarch" /etc/pacman.conf 2>/dev/null; then
        DISTRO_LABEL="BlackArch Linux"
    else
        DISTRO_LABEL="${PRETTY_NAME:-$OS}"
    fi
}

detect_os

if [[ "$OS" = "unknown" ]]; then
    error "Unsupported OS. Cannot continue."
    exit 1
fi

success "Detected: ${BOLD}$DISTRO_LABEL${RESET}"

# ─── Install Dependencies & Tools ──────────────────────────
step "Installing Dependencies and core tools"

# Determine if we should prefix commands with sudo
SUDO_CMD="sudo"
if [[ $EUID -eq 0 ]] || [[ "$OS" = "termux" ]]; then
    SUDO_CMD=""
fi

install_packages() {
    local pkgs=("${@}")
    case "$OS" in
        termux)
            pkg update -y
            pkg install -y "${pkgs[@]}"
            ;;
        arch)
            ${SUDO_CMD} pacman -Sy --noconfirm --needed "${pkgs[@]}"
            ;;
        debian)
            ${SUDO_CMD} apt-get update -qq
            ${SUDO_CMD} apt-get install -y "${pkgs[@]}"
            ;;
        fedora)
            ${SUDO_CMD} dnf install -y "${pkgs[@]}"
            ;;
        opensuse)
            ${SUDO_CMD} zypper install -y "${pkgs[@]}"
            ;;
        *)
            warn "Unknown package manager for OS=$OS. Please install: ${pkgs[*]}"
            return 1
            ;;
    esac
}

# Basic required tools
REQUIRED=(git curl zsh fzf fastfetch)
MISSING=()
for d in "${REQUIRED[@]}"; do
    if ! command -v "$d" &>/dev/null; then
        MISSING+=("$d")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    info "Missing tools: ${MISSING[*]}"
    if ! install_packages "${MISSING[@]}"; then
        warn "Automatic package installation failed. Please install these manually: ${MISSING[*]}"
    else
        success "Dependencies installed"
    fi
else
    success "All dependencies present"
fi

# ─── Oh My Zsh, Powerlevel10k, and plugins ───────────────
step "Installing Oh My Zsh, Powerlevel10k and plugins"

# Ensure HOME is writable and paths exist
mkdir -p "$HOME/.config/fastfetch"

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh"
    git_clone_retry https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
else
    info "Oh My Zsh already installed"
fi

# Powerlevel10k
if [[ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    info "Installing Powerlevel10k"
    git_clone_retry https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
else
    info "Powerlevel10k already present"
fi

# Plugins
install_plugin() {
    local repo=$1
    local name="$(basename "$repo" .git)"
    local dest="$HOME/.oh-my-zsh/custom/plugins/$name"

    # A plugin only counts as "installed" if its main .plugin.zsh file exists.
    # An empty/partial dir (from a prior interrupted run) must be re-cloned,
    # otherwise oh-my-zsh will report "plugin not found" even though the
    # folder exists.
    if [[ -d "$dest" ]] && [[ ! -f "$dest/${name}.plugin.zsh" ]]; then
        warn "$name looks incomplete — removing and re-cloning"
        rm -rf "$dest"
    fi

    if [[ ! -d "$dest" ]]; then
        info "Cloning $name"
        if git_clone_retry "$repo" "$dest"; then
            success "$name installed"
        else
            warn "$name will be unavailable"
        fi
    else
        info "$name already installed"
    fi
}
install_plugin https://github.com/zsh-users/zsh-autosuggestions.git
install_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git
install_plugin https://github.com/zsh-users/zsh-history-substring-search.git

# Build the final plugin list from what actually installed successfully,
# so .zshrc never references a plugin dir that isn't really there.
ZSH_PLUGINS=(git)
for p in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    if [[ -f "$HOME/.oh-my-zsh/custom/plugins/$p/$p.plugin.zsh" ]]; then
        ZSH_PLUGINS+=("$p")
    else
        warn "$p not available — skipping it in .zshrc plugins list"
    fi
done

# Copy selected p10k config
# For "wizard" theme, skip copying — p10k will auto-launch its interactive wizard
# on the first ZSH session when ~/.p10k.zsh does not exist.
if [[ "$CHOSEN_THEME" != "wizard" ]]; then
    case "$CHOSEN_THEME" in
        cyber)   P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-cyber.zsh" ;;
        minimal) P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ;;
        *)       P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ;;
    esac
    if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$P10K_SRC" ]]; then
        cp -f "$P10K_SRC" "$HOME/.p10k.zsh" || warn "Could not copy p10k config"
        success "Powerlevel10k config applied"
    elif [[ -z "$SCRIPT_DIR" ]]; then
        warn "Skipping p10k config copy (curl install — no local files)"
    else
        warn "p10k config not found at: $P10K_SRC"
    fi
else
    # Remove any existing .p10k.zsh so the wizard triggers cleanly
    rm -f "$HOME/.p10k.zsh"
    info "P10K wizard will launch automatically on your first ZSH session"
fi

# ─── Nerd Font (MesloLGS NF) ───────────────────────────────
# Powerlevel10k's icons/glyphs render as broken boxes without this font.
# Skipped on Termux — there's no desktop font manager to register it with,
# and Termux's own font is set separately via its own settings.
if [[ "$OS" != "termux" ]]; then
    step "Installing Nerd Font (MesloLGS NF)"
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"

    declare -A FONT_FILES=(
        ["MesloLGS NF Regular.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        ["MesloLGS NF Bold.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        ["MesloLGS NF Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        ["MesloLGS NF Bold Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    FONT_OK=true
    for fname in "${!FONT_FILES[@]}"; do
        fdest="$FONT_DIR/$fname"
        if [[ -s "$fdest" ]]; then
            continue
        fi
        if ! curl -fsSL --retry 3 --retry-delay 2 -o "$fdest" "${FONT_FILES[$fname]}"; then
            warn "Could not download font: $fname"
            rm -f "$fdest"
            FONT_OK=false
        fi
    done

    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$FONT_DIR" &>/dev/null || true
    fi

    if [[ "$FONT_OK" = true ]]; then
        success "MesloLGS NF installed"
        info "Set your terminal's font to 'MesloLGS NF' for icons to render correctly"
    else
        warn "Font install incomplete — set your terminal font manually if icons look broken"
        warn "Download: https://github.com/romkatv/powerlevel10k#manual-font-installation"
    fi
fi

# Copy fastfetch config based on environment
if [[ -n "$SCRIPT_DIR" ]]; then
    if [[ "$OS" = "termux" ]] || [[ "$CHOSEN_THEME" = "minimal" ]]; then
        FF_SRC="$SCRIPT_DIR/configs/fastfetch/mobile-config.jsonc"
    else
        FF_SRC="$SCRIPT_DIR/configs/fastfetch/pc-config.jsonc"
    fi
    if [[ -f "$FF_SRC" ]]; then
        cp -f "$FF_SRC" "$HOME/.config/fastfetch/config.jsonc" || warn "Could not copy fastfetch config"
        success "fastfetch config installed"
    else
        warn "fastfetch config not found at: $FF_SRC"
    fi
else
    warn "Skipping fastfetch config copy (curl install — no local files)"
fi

# Alias for update per distro
case "$OS" in
    arch)   UPDATE_ALIAS='sudo pacman -Syu' ;;
    debian) UPDATE_ALIAS='sudo apt update && sudo apt upgrade -y' ;;
    fedora) UPDATE_ALIAS='sudo dnf upgrade --refresh -y' ;;
    opensuse) UPDATE_ALIAS='sudo zypper refresh && sudo zypper update -y' ;;
    termux) UPDATE_ALIAS='pkg up -y' ;;
    *)      UPDATE_ALIAS='echo "Please update your system manually"' ;;
esac
# update alias is set inside the ALIASES marker block below


# ─── Improved Default Shell Setup ─────────────────────────
step "Setting Default Shell"

ZSH_PATH=$(command -v zsh)

if [[ "$OS" = "termux" ]]; then
    # Remove any existing exec zsh line to avoid duplicates, then add it
    sed -i '/^exec zsh/d' ~/.bashrc 2>/dev/null || true
    echo 'exec zsh' >> ~/.bashrc
    success "Termux configured to use ZSH"
else
    SHELL_CHANGED=false
    if sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null; then
        success "Default shell set to ZSH (usermod) — takes effect on next login"
        SHELL_CHANGED=true
    elif sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
        success "Default shell set to ZSH (chsh) — takes effect on next login"
        SHELL_CHANGED=true
    else
        warn "Could not set ZSH as default shell automatically"
        warn "Run this manually then log out and back in:"
        echo -e "   sudo usermod -s $ZSH_PATH \$USER"
    fi

    # Regardless of whether usermod worked, switch the current session to ZSH now
    if [[ "$SHELL_CHANGED" = true ]]; then
        info "To switch your current session to ZSH now without logging out, run: exec zsh"
    fi
fi

# ─── .zshrc Configuration with Instant Prompt Fix ─────────
step "Configuring .zshrc"

insert_marker_block() {
    local file=$1 name=$2 content=$3
    local start="# MASU-${name}-START"
    local end="# MASU-${name}-END"
    sed -i "/$start/,/$end/d" "$file" 2>/dev/null || true
    {
        echo "$start"
        echo "$content"
        echo "$end"
    } >> "$file"
}

# Instant prompt — MUST be first in .zshrc before any output-producing code.
# This is required by Powerlevel10k to avoid the console output warning.
insert_marker_block ~/.zshrc "INSTANT_PROMPT" 'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi'

# Base config
# zsh-completions is loaded via fpath, NOT the plugins array — adding it to
# plugins causes the "plugin not found" + extend_glob errors from OMZ.
# ZSH_PLUGINS is built earlier from what actually cloned successfully, so
# .zshrc never lists a plugin whose folder isn't really there.
insert_marker_block ~/.zshrc "BASE" "export ZSH=\"\$HOME/.oh-my-zsh\"
ZSH_THEME=\"powerlevel10k/powerlevel10k\"
plugins=(${ZSH_PLUGINS[*]})
source \$ZSH/oh-my-zsh.sh"

# P10k
insert_marker_block ~/.zshrc "P10K" '[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'

# FZF (Fixed)
insert_marker_block ~/.zshrc "FZF" '[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
[[ -n "${PREFIX:-}" && -f "$PREFIX/share/fzf/key-bindings.zsh" ]] && source "$PREFIX/share/fzf/key-bindings.zsh"'

# Fastfetch — either run on startup or just install alias
if [[ "$FASTFETCH_ON_START" = true ]]; then
    insert_marker_block ~/.zshrc "FETCH" 'alias fastfetch-masu="fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true"
fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true'
else
    insert_marker_block ~/.zshrc "FETCH" '# Fastfetch is installed but runs only when you call it manually.
# Run:  fastfetch-masu
# To enable on every terminal open, add this to your .zshrc:
#   fastfetch --config ~/.config/fastfetch/config.jsonc
alias fastfetch-masu="fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true"'
fi

# Aliases — update alias uses the distro-correct command resolved above
insert_marker_block ~/.zshrc "ALIASES" "alias ll=\"ls -lah --color=auto\"
alias la=\"ls -A --color=auto\"
alias update='${UPDATE_ALIAS}'
alias reload=\"source ~/.zshrc\""

success ".zshrc configured successfully"

# ─── Final Message ────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║   MASU Installation Complete! ✓      ║"
echo -e "╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}✓${RESET} ZSH + Powerlevel10k + Plugins"
echo -e "  ${GREEN}✓${RESET} Theme: ${BOLD}$CHOSEN_THEME${RESET}"
if [[ "$CHOSEN_THEME" = "wizard" ]]; then
    echo -e "  ${CYAN}→${RESET} P10K wizard will run on your first ZSH session"
fi
if [[ "$FASTFETCH_ON_START" = true ]]; then
    echo -e "  ${GREEN}✓${RESET} Fastfetch: runs on terminal open (alias: fastfetch-masu)"
else
    echo -e "  ${CYAN}→${RESET} Fastfetch: manual only — run ${BOLD}fastfetch-masu${RESET}"
fi
echo ""
echo -e "${YELLOW}Next steps:${RESET}"
echo -e "  1. Run ${BOLD}exec zsh${RESET} to switch your current session to ZSH now"
echo -e "  2. Or log out and back in — ZSH will be your default shell"
if [[ "$CHOSEN_THEME" = "wizard" ]]; then
    echo -e "  3. The P10K wizard will launch automatically on your first ZSH session"
fi
echo ""
echo -e "${MAGENTA}MASU Cyber Learning Project — Stay Sharp!${RESET}"
