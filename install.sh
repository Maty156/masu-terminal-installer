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

    # Verify Oh My Zsh actually installed correctly
    if [[ ! -d ~/.oh-my-zsh ]]; then
        error "Oh My Zsh installation failed — check your internet connection"
        exit 1
    fi
    success "Oh My Zsh installed"
fi

# Make sure .zshrc exists — use template if available, create minimal one if not
if [[ ! -f ~/.zshrc ]]; then
    if [[ -f ~/.oh-my-zsh/templates/zshrc.zsh-template ]]; then
        cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
        success "Created .zshrc from template"
    else
        # Fallback: create a minimal working .zshrc manually
        cat > ~/.zshrc << 'RCEOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source $ZSH/oh-my-zsh.sh
RCEOF
        success "Created minimal .zshrc fallback"
    fi
fi

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

# Fix permissions — git clone with & can sometimes set wrong permissions
chmod -R 755 "$THEME_DIR"
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
    # Fix permissions after clone
    chmod -R 755 "$dir"
    success "$name ready"
}

install_plugin "zsh-autosuggestions"   "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
install_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

# ─── Configure .zshrc ──────────────────────────────────────
step "Configuring .zshrc"

# Set ZSH path
if ! grep -q "^export ZSH=" ~/.zshrc; then
    echo 'export ZSH="$HOME/.oh-my-zsh"' >> ~/.zshrc
fi

# Set theme
if grep -q "^ZSH_THEME=" ~/.zshrc; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
fi

# Set plugins — write the full line cleanly, no multiline sed issues
if grep -q "^plugins=(" ~/.zshrc; then
    # Remove the entire plugins=(...) block however many lines it spans
    sed -i '/^plugins=(/,/)/d' ~/.zshrc
fi
# Write a clean single-line plugins entry
echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)' >> ~/.zshrc

# Make sure oh-my-zsh.sh is sourced
if ! grep -q "source \$ZSH/oh-my-zsh.sh" ~/.zshrc; then
    echo 'source $ZSH/oh-my-zsh.sh' >> ~/.zshrc
fi

# Add p10k config source at the BOTTOM of .zshrc
if ! grep -q "\.p10k\.zsh" ~/.zshrc; then
    cat >> ~/.zshrc << 'ZSHEOF'

# ─── Powerlevel10k ─────────────────────────────────────────
# To reconfigure run: p10k configure
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHEOF
    success "Added Powerlevel10k config source to .zshrc"
fi

# Add aliases — distro-aware update command
if ! grep -q "MASU Aliases" ~/.zshrc; then
    case "$OS" in
        arch)     UPDATE_CMD="sudo pacman -Syu" ;;
        debian)   UPDATE_CMD="sudo apt update && sudo apt upgrade" ;;
        fedora)   UPDATE_CMD="sudo dnf upgrade" ;;
        opensuse) UPDATE_CMD="sudo zypper update" ;;
        termux)   UPDATE_CMD="pkg upgrade" ;;
        *)        UPDATE_CMD="echo 'Update command not set for this distro'" ;;
    esac

    cat >> ~/.zshrc << ALIASEOF

# ─── MASU Aliases ──────────────────────────
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias update="$UPDATE_CMD"
alias ports="ss -tulnp"
alias myip="curl -s https://ipinfo.io/ip"
alias cls="clear"
alias reload="source ~/.zshrc"
# ───────────────────────────────────────────
ALIASEOF
    success "Added MASU aliases to .zshrc"
fi

success ".zshrc configured"

# ─── Set Default Shell ─────────────────────────────────────
step "Setting Default Shell"

ZSH_PATH=$(command -v zsh)

if [[ "$OS" = "termux" ]]; then
    if ! grep -q "exec zsh" ~/.bashrc 2>/dev/null; then
        echo 'exec zsh' >> ~/.bashrc
        success "Added 'exec zsh' to ~/.bashrc (Termux)"
    else
        info "Termux already launches zsh"
    fi
else
    # getent is not available on Termux, only run on real Linux
    CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "unknown")
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        chsh -s "$ZSH_PATH" 2>/dev/null && \
            success "Default shell set to zsh ($ZSH_PATH)" || \
            warn "Could not set default shell automatically — run: chsh -s $ZSH_PATH"
    else
        info "zsh is already the default shell"
    fi
fi

# ─── Nerd Font Auto-Install ────────────────────────────────
step "Installing Nerd Font (MesloLGS NF)"

FONT_INSTALLED=false

install_nerd_font_manual() {
    # Download MesloLGS NF directly from the Powerlevel10k recommended fonts
    info "Downloading MesloLGS NF fonts..."
    local FONT_DIR="$HOME/.local/share/fonts/MesloLGS"
    mkdir -p "$FONT_DIR"

    local BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local FONTS=(
        "MesloLGS%20NF%20Regular.ttf"
        "MesloLGS%20NF%20Bold.ttf"
        "MesloLGS%20NF%20Italic.ttf"
        "MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    local ALL_OK=true
    for font in "${FONTS[@]}"; do
        local fname="${font//%20/ }"
        if curl -fsSL "$BASE_URL/$font" -o "$FONT_DIR/$fname" 2>/dev/null; then
            success "Downloaded: $fname"
        else
            warn "Failed to download: $fname"
            ALL_OK=false
        fi
    done

    if [[ "$ALL_OK" = true ]]; then
        # Refresh font cache
        if command -v fc-cache &>/dev/null; then
            fc-cache -fv "$FONT_DIR" &>/dev/null
            success "Font cache refreshed"
        fi
        FONT_INSTALLED=true
    else
        warn "Some fonts failed to download — check your internet connection"
    fi
}

case "$OS" in
    arch)
        if sudo pacman -S --noconfirm --needed ttf-meslo-nerd 2>/dev/null; then
            success "MesloLGS Nerd Font installed via pacman"
            FONT_INSTALLED=true
        else
            warn "pacman install failed — trying manual download..."
            install_nerd_font_manual
        fi
        ;;
    debian)
        # Try apt first (available on newer Ubuntu/Kali)
        if sudo apt-get install -y fonts-nerd-font-meslo 2>/dev/null; then
            success "Nerd Font installed via apt"
            FONT_INSTALLED=true
        else
            warn "apt font not available — trying manual download..."
            install_nerd_font_manual
        fi
        ;;
    fedora)
        if sudo dnf install -y levien-inconsolata-fonts 2>/dev/null; then
            install_nerd_font_manual  # fedora has limited nerd fonts, supplement manually
        else
            install_nerd_font_manual
        fi
        ;;
    opensuse)
        install_nerd_font_manual
        ;;
    termux)
        info "Termux: downloading MesloLGS NF font for Termux styling..."
        mkdir -p ~/.termux
        curl -fsSL \
            "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf" \
            -o ~/.termux/font.ttf 2>/dev/null && \
            success "Font set for Termux (~/.termux/font.ttf)" && \
            FONT_INSTALLED=true || \
            warn "Font download failed for Termux"
        ;;
esac

if [[ "$FONT_INSTALLED" = true ]]; then
    echo ""
    if [[ "$OS" = "termux" ]]; then
        echo -e "  ${GREEN}Font applied to Termux automatically.${RESET}"
        echo -e "  Restart Termux for the font to take effect."
    else
        echo -e "  ${YELLOW}⚠ ACTION REQUIRED:${RESET} Font is installed on your system."
        echo -e "  You must ${BOLD}set MesloLGS NF as your terminal's font${RESET} in its settings."
        echo -e "  (e.g. Konsole → Settings → Edit Profile → Appearance → Font)"
    fi
else
    echo -e "  ${YELLOW}Font could not be installed automatically.${RESET}"
    echo -e "  Manually download from: ${CYAN}https://www.nerdfonts.com/font-downloads${RESET}"
    echo -e "  Then set it in your terminal emulator settings."
fi


# ─── First Run Setup ───────────────────────────────────────

# Fix permissions on powerlevel10k and plugins
chmod -R 755 ~/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
chmod -R 755 ~/.oh-my-zsh/custom/plugins/ 2>/dev/null || true

# Write a one-time file that runs the p10k wizard on first zsh open
cat > ~/.masu_first_run.zsh << 'FIRSTRUN'
# MASU first-run — auto-deleted after use
rm -f ~/.masu_first_run.zsh
sed -i '/masu_first_run/d' ~/.zshenv 2>/dev/null
# Run the wizard
[[ ! -f ~/.p10k.zsh ]] && p10k configure
FIRSTRUN

# Hook into .zshenv — sourced by ALL zsh instances on ALL distros including Termux
if ! grep -q "masu_first_run" ~/.zshenv 2>/dev/null; then
    echo '[[ -f ~/.masu_first_run.zsh ]] && source ~/.masu_first_run.zsh' >> ~/.zshenv
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
echo -e "    • MesloLGS Nerd Font         ${GREEN}(auto-installed!)${RESET}"
echo -e "    • zsh-autosuggestions"
echo -e "    • zsh-syntax-highlighting"
echo -e "    • zsh-history-substring-search"
echo -e "    • MASU productivity aliases"
echo ""
echo -e "  ${YELLOW}Remember:${RESET} Set ${BOLD}MesloLGS NF${RESET} as your terminal font to see icons."
echo ""
echo -e "  ${GREEN}${BOLD}✓ Open a new terminal — Powerlevel10k wizard will start automatically!${RESET}"
echo ""
echo -e "  ${MAGENTA}MASU Cyber Learning Project — Stay Sharp!${RESET}"
echo ""
