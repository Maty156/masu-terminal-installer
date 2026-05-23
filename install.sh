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
CHOSEN_THEME="minimal"
echo -e "${CYAN}Select Your MASU Theme Style:${RESET}"
echo -e "  1) ${GREEN}MASU Minimal${RESET} (Fast, clean)"
echo -e "  2) ${MAGENTA}MASU Cyber  ${RESET} (Cyberpunk style)"
echo -e "  3) ${YELLOW}P10K Default${RESET} (Interactive wizard)"
read -rp "  Selection [1-3, default 1]: " theme_choice

case "$theme_choice" in
    2) CHOSEN_THEME="cyber" ;;
    3) CHOSEN_THEME="default" ;;
    *) CHOSEN_THEME="minimal" ;;
esac

info "Starting installation for theme: ${BOLD}$CHOSEN_THEME${RESET}"

# ─── Root & OS Detection (unchanged) ───────────────────────
# ... [keeping the rest of your original logic here for brevity] ...

# I'll provide the full improved script if you want, but for now here are the **key improved parts**:

# ─── Improved Default Shell Setup ─────────────────────────
step "Setting Default Shell to ZSH"

ZSH_PATH=$(command -v zsh)

if [[ "$OS" = "termux" ]]; then
    echo 'exec zsh' >> ~/.bashrc
    success "Termux: ZSH will start automatically"
else
    CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "unknown")
    
    if [[ "$CURRENT_SHELL" = "$ZSH_PATH" ]]; then
        success "ZSH is already your default shell"
    else
        if sudo usermod -s "$ZSH_PATH" "$USER" 2>/dev/null; then
            success "Default shell changed to ZSH using usermod"
        elif sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
            success "Default shell changed to ZSH using chsh"
        else
            warn "Could not change default shell automatically."
            echo -e "   ${YELLOW}Please run manually after installation:${RESET}"
            echo -e "   sudo usermod -s $(which zsh) \$USER"
            echo -e "   Then log out and log back in."
        fi
    fi
fi

# ─── Improved .zshrc Configuration (with instant prompt fix) ───
# In the FZF and FETCH blocks, we can delay heavy commands

fetch_block='if [[ -o interactive ]]; then
    # Fastfetch moved after instant prompt
    fastfetch --config $HOME/.config/fastfetch/config.jsonc 2>/dev/null || true
fi'

# ... rest of your config blocks ...

success "Installation completed!"

echo -e "\n${GREEN}✓ Open a new terminal to enjoy your MASU setup!${RESET}"
echo -e "${YELLOW}Note: If ZSH doesn't start automatically, check your terminal settings${RESET}"
