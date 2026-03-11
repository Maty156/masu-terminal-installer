#!/bin/bash

# ============================================================
# MASU Terminal Installer v7 - BlackArch Edition
# Author: Matyas Abraham | MASU Cyber Learning Project
# Supports: Arch, BlackArch, Ubuntu, Debian, Fedora,
#           OpenSUSE, Kali, Parrot OS, Termux
# ============================================================

set -euo pipefail

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
echo -e "${CYAN}  Terminal Installer v7 — BlackArch Edition${RESET}"
echo -e "${MAGENTA}  By Matyas Abraham | MASU Cyber Learning Project${RESET}"
echo ""

# ─── Root check ────────────────────────────────────────────
if [[ $EUID -eq 0 ]] && [[ -z "${PREFIX:-}" ]]; then
    warn "Running as root is NOT recommended. Plugins may install to /root."
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
            ubuntu|linuxmint|pop)               OS="debian" ;;
            debian|kali|parrot)                 OS="debian" ;;
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

    # Detect BlackArch specifically for extra context
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

# ─── Dependency Check ──────────────────────────────────────
step "Checking Dependencies"

MISSING_DEPS=()
for dep in git curl zsh; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    else
        success "$dep is already installed"
    fi
done

# ─── Package Installation ──────────────────────────────────
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    step "Installing Missing Packages"
    info "Missing: ${MISSING_DEPS[*]}"

    case "$OS" in
        termux)   pkg update -y && pkg install -y zsh git curl ;;
        arch)     sudo pacman -Sy --noconfirm --needed zsh git curl ;;
        debian)   sudo apt-get update -qq && sudo apt-get install -y zsh git curl ;;
        fedora)   sudo dnf install -y zsh git curl ;;
        opensuse) sudo zypper install -y zsh git curl ;;
    esac

    success "Packages installed"
else
    info "All required dependencies are present — skipping install"
fi

# ─── Optional: cmatrix ─────────────────────────────────────
HAVE_CMATRIX=false
if command -v cmatrix &>/dev/null; then
    HAVE_CMATRIX=true
elif [[ "$OS" != "termux" ]]; then
    echo ""
    read -rp "  Install cmatrix for Matrix animation? (y/n): " install_cmatrix
    if [[ "$install_cmatrix" == "y" ]]; then
        case "$OS" in
            arch)     sudo pacman -S --noconfirm cmatrix && HAVE_CMATRIX=true ;;
            debian)   sudo apt-get install -y cmatrix && HAVE_CMATRIX=true ;;
            fedora)   sudo dnf install -y cmatrix && HAVE_CMATRIX=true ;;
            opensuse) sudo zypper install -y cmatrix && HAVE_CMATRIX=true ;;
        esac
    fi
fi

# ─── Backup .zshrc ─────────────────────────────────────────
step "Checking Existing Configuration"

if [[ -f ~/.zshrc ]]; then
    BACKUP_FILE=~/.zshrc.masu.bak.$(date +%Y%m%d_%H%M%S)
    cp ~/.zshrc "$BACKUP_FILE"
    success "Backed up existing .zshrc → $BACKUP_FILE"
else
    info "No existing .zshrc found — fresh install"
fi

# ─── Oh My Zsh ─────────────────────────────────────────────
step "Installing Oh My Zsh"

if [[ -d ~/.oh-my-zsh ]]; then
    warn "Oh My Zsh already installed — skipping"
else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &
    spinner $! "Installing Oh My Zsh..."
    wait
    success "Oh My Zsh installed"
fi

# Make sure .zshrc exists
[[ ! -f ~/.zshrc ]] && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

# ─── Powerlevel10k ─────────────────────────────────────────
step "Installing Powerlevel10k Theme"

THEME_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

if [[ -d "$THEME_DIR" ]]; then
    info "Powerlevel10k already exists — pulling latest..."
    git -C "$THEME_DIR" pull --quiet &
    spinner $! "Updating Powerlevel10k..."
    wait
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR" --quiet &
    spinner $! "Cloning Powerlevel10k..."
    wait
fi

success "Powerlevel10k ready"

# ─── Plugins ───────────────────────────────────────────────
step "Installing ZSH Plugins"

PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

install_plugin() {
    local name=$1
    local url=$2
    local dir="$PLUGIN_DIR/$name"

    if [[ -d "$dir" ]]; then
        info "$name already exists — pulling latest..."
        git -C "$dir" pull --quiet &
        spinner $! "Updating $name..."
        wait
    else
        git clone "$url" "$dir" --quiet &
        spinner $! "Cloning $name..."
        wait
    fi
    success "$name ready"
}

install_plugin "zsh-autosuggestions"   "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
install_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

# ─── Configure .zshrc ──────────────────────────────────────
step "Configuring .zshrc"

# Set theme
if grep -q "^ZSH_THEME=" ~/.zshrc; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
fi

# Set plugins (handle multi-line safely)
if grep -q "^plugins=(" ~/.zshrc; then
    sed -i '/^plugins=(/,/^)/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)' ~/.zshrc
else
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)' >> ~/.zshrc
fi

# Add P10k instant prompt (speeds up startup)
P10K_INSTANT='# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi'

if ! grep -q "p10k-instant-prompt" ~/.zshrc; then
    # Prepend to top of file
    TMP=$(mktemp)
    { echo "$P10K_INSTANT"; echo ""; cat ~/.zshrc; } > "$TMP"
    mv "$TMP" ~/.zshrc
fi

# Add useful aliases for hacking / dev workflow
ALIASES_BLOCK='
# ─── MASU Aliases ──────────────────────────
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias update="sudo pacman -Syu"          # Change for your distro
alias ports="ss -tulnp"
alias myip="curl -s https://ipinfo.io/ip"
alias cls="clear"
alias zshconf="$EDITOR ~/.zshrc"
alias reload="source ~/.zshrc"
# ───────────────────────────────────────────'

if ! grep -q "MASU Aliases" ~/.zshrc; then
    echo "$ALIASES_BLOCK" >> ~/.zshrc
    success "Added MASU aliases to .zshrc"
fi

success ".zshrc configured"

# ─── Set Default Shell ─────────────────────────────────────
step "Setting Default Shell"

ZSH_PATH=$(which zsh)

if [[ "$OS" = "termux" ]]; then
    if ! grep -q "exec zsh" ~/.bashrc 2>/dev/null; then
        echo 'exec zsh' >> ~/.bashrc
        success "Added 'exec zsh' to ~/.bashrc (Termux)"
    else
        info "Termux already launches zsh"
    fi
else
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        chsh -s "$ZSH_PATH"
        success "Default shell set to zsh ($ZSH_PATH)"
    else
        info "zsh is already the default shell"
    fi
fi

# ─── Nerd Fonts Reminder ───────────────────────────────────
step "Nerd Font Notice"
echo -e "  ${YELLOW}Powerlevel10k requires a Nerd Font for icons to display correctly.${RESET}"
echo -e "  Recommended: ${BOLD}MesloLGS NF${RESET} or any font from https://www.nerdfonts.com"
echo -e "  On Arch/BlackArch: ${CYAN}sudo pacman -S ttf-meslo-nerd${RESET}"
echo -e "  After installing the font, set it in your terminal emulator settings."

# ─── Matrix Demo ───────────────────────────────────────────
echo ""
if [[ "$HAVE_CMATRIX" = true ]]; then
    read -rp "  Enable Matrix animation demo? (y/n): " matrix
    if [[ "$matrix" == "y" ]]; then
        echo -e "${GREEN}Press Ctrl+C to stop${RESET}"
        sleep 1
        timeout 8 cmatrix -s -b -C green || true
    fi
fi

# ─── Done ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║   Installation Complete! ✓           ║"
echo -e "╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}What's installed:${RESET}"
echo -e "    • ZSH + Oh My Zsh"
echo -e "    • Powerlevel10k theme"
echo -e "    • zsh-autosuggestions"
echo -e "    • zsh-syntax-highlighting"
echo -e "    • zsh-history-substring-search  ${GREEN}(new!)${RESET}"
echo -e "    • MASU productivity aliases      ${GREEN}(new!)${RESET}"
echo ""
echo -e "  ${YELLOW}Next steps:${RESET}"
echo -e "    1. Install a Nerd Font in your terminal"
echo -e "    2. Run: ${BOLD}zsh${RESET}"
echo -e "    3. Follow the Powerlevel10k setup wizard"
echo ""
echo -e "  ${MAGENTA}MASU Cyber Learning Project — Stay Sharp!${RESET}"
echo ""
