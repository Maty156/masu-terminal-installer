#!/bin/bash

# ============================================================
# MASU Terminal Installer v7.1 - BlackArch Edition
# Author: Matyas Abraham | MASU Cyber Learning Project
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
echo -e "${CYAN}  Terminal Installer v7.1 — BlackArch Edition${RESET}"
echo -e "${MAGENTA}  By Matyas Abraham | MASU Cyber Learning Project${RESET}"
echo ""

# ─── Script Directory ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Theme Selection ───────────────────────────────────────
CHOSEN_THEME="minimal" # Default
echo -e "${CYAN}Select Your MASU Theme Style:${RESET}"
echo -e "  1) ${GREEN}MASU Minimal${RESET} (Fast, clean, mobile-optimized)"
echo -e "  2) ${MAGENTA}MASU Cyber  ${RESET} (Neon colors, icon-heavy)"
echo -e "  3) ${YELLOW}P10K Default${RESET} (Run interactive wizard)"
read -rp "  Selection [1-3, default 1]: " theme_choice

case "$theme_choice" in
    2) CHOSEN_THEME="cyber" ;;
    3) CHOSEN_THEME="default" ;;
    *) CHOSEN_THEME="minimal" ;;
esac
info "Starting installation for theme: ${BOLD}$CHOSEN_THEME${RESET}"

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
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" || warn "Could not clone oh-my-zsh"
else
    info "Oh My Zsh already installed"
fi

# Powerlevel10k
if [[ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    info "Installing Powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || warn "Could not clone p10k"
else
    info "Powerlevel10k already present"
fi

# Plugins
install_plugin() {
    local repo=$1 dest="$HOME/.oh-my-zsh/custom/plugins/$(basename "$repo" .git)"
    if [[ ! -d "$dest" ]]; then
        git clone --depth=1 "$repo" "$dest" || warn "Failed to clone $repo"
    fi
}
install_plugin https://github.com/zsh-users/zsh-autosuggestions.git
install_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git
install_plugin https://github.com/zsh-users/zsh-completions.git

# Copy selected p10k config
case "$CHOSEN_THEME" in
    cyber)   P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-cyber.zsh" ;;
    minimal) P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ;;
    default) P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-cyber.zsh" ;;
    *)       P10K_SRC="$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ;;
esac
if [[ -f "$P10K_SRC" ]]; then
    cp -f "$P10K_SRC" "$HOME/.p10k.zsh" || warn "Could not copy p10k config"
    success "Powerlevel10k config applied"
fi

# Copy fastfetch config based on environment
if [[ "$OS" = "termux" ]] || [[ "$CHOSEN_THEME" = "minimal" ]]; then
    FF_SRC="$SCRIPT_DIR/configs/fastfetch/mobile-config.jsonc"
else
    FF_SRC="$SCRIPT_DIR/configs/fastfetch/pc-config.jsonc"
fi
if [[ -f "$FF_SRC" ]]; then
    cp -f "$FF_SRC" "$HOME/.config/fastfetch/config.jsonc" || warn "Could not copy fastfetch config"
    success "fastfetch config installed"
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
sed -i "/^alias update=/d" "$HOME/.zshrc" 2>/dev/null || true
echo "alias update='${UPDATE_ALIAS}'" >> "$HOME/.zshrc"


# ─── Improved Default Shell Setup ─────────────────────────
step "Setting Default Shell"

ZSH_PATH=$(command -v zsh)

if [[ "$OS" = "termux" ]]; then
    echo 'exec zsh' >> ~/.bashrc 2>/dev/null || true
    success "Termux configured to use ZSH"
else
    if sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null; then
        success "Default shell set to ZSH (usermod)"
    elif sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
        success "Default shell set to ZSH (chsh)"
    else
        warn "Could not set ZSH as default automatically"
        echo -e "   ${YELLOW}After installation, run:${RESET}"
        echo -e "   sudo usermod -s $(which zsh) \$USER"
        echo -e "   Then log out and log back in."
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

# Base config
insert_marker_block ~/.zshrc "BASE" 'export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-completions)
source $ZSH/oh-my-zsh.sh'

# P10k
insert_marker_block ~/.zshrc "P10K" '[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'

# FZF (Fixed)
insert_marker_block ~/.zshrc "FZF" '[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
[[ -n "${PREFIX:-}" && -f "$PREFIX/share/fzf/key-bindings.zsh" ]] && source "$PREFIX/share/fzf/key-bindings.zsh"'

# Fastfetch (disabled by default; run manually if desired)
insert_marker_block ~/.zshrc "FETCH" '# Fastfetch is installed but disabled by default to avoid
# showing system info on every new terminal. To run manually, use:
#   fastfetch --config ~/.config/fastfetch/config.jsonc
# Or use the provided quick alias:
alias fastfetch-masu="fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || true"'

# Aliases
insert_marker_block ~/.zshrc "ALIASES" 'alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias update="sudo pacman -Syu"  # Change based on OS if needed
alias reload="source ~/.zshrc"'

success ".zshrc configured successfully"

# ─── Final Message ────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║   MASU Installation Complete! ✓      ║"
echo -e "╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}✓${RESET} ZSH + Powerlevel10k + Plugins"
echo -e "  ${GREEN}✓${RESET} Theme: ${BOLD}$CHOSEN_THEME${RESET}"
echo ""
echo -e "${YELLOW}Note:${RESET} If ZSH doesn't start by default, check your terminal settings"
echo -e "      (Edit → Preferences → Command → Uncheck custom command)"
echo ""
echo -e "${MAGENTA}MASU Cyber Learning Project — Stay Sharp!${RESET}"
