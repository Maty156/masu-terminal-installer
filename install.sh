#!/bin/bash

# ============================================================
# MASU Terminal Installer v7 - BlackArch Edition
# Author: Matyas Abraham | MASU Cyber Learning Project
# Supports: Arch, BlackArch, Ubuntu, Debian, Fedora,
#           OpenSUSE, Kali, Parrot OS, Termux
# ============================================================

set -eo pipefail  # Fixed: Removed 'u' to prevent unbound variable errors

# ─── Cleanup Trap ──────────────────────────────────────────
cleanup() {
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && error "Interrupted! Check the errors above."
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
echo -e "${CYAN}  Terminal Installer v7 — BlackArch Edition${RESET}"
echo -e "${MAGENTA}  By Matyas Abraham | MASU Cyber Learning Project${RESET}"
echo ""

# ─── Script Directory ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Theme Selection ───────────────────────────────────────
CHOSEN_THEME="minimal" # Default
echo -e "${CYAN}Select Your MASU Theme Style:${RESET}"
echo -e "  1) ${GREEN}MASU Minimal${RESET} (Fast, clean, mobile-optimized)"
echo -e "  2) ${MAGENTA}MASU Cyber  ${RESET} (Neon colors, icon-heavy, cyberpunk)"
echo -e "  3) ${YELLOW}P10K Default${RESET} (Run interactive wizard later)"
read -rp "  Selection [1-3, default 1]: " theme_choice

case "$theme_choice" in
    2) CHOSEN_THEME="cyber" ;;
    3) CHOSEN_THEME="default" ;;
    *) CHOSEN_THEME="minimal" ;;
esac
info "Starting installation for theme: ${BOLD}$CHOSEN_THEME${RESET}"

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

# Rest of the script remains the same until the FZF block...

# ─── (All middle sections unchanged) ───────────────────────

# ... [Oh My Zsh, Powerlevel10k, Plugins, Backup, etc.] ...

# ─── Configure .zshrc ──────────────────────────────────────
step "Configuring .zshrc"

# Helper for marker-based insertion
insert_marker_block() {
    local file=$1
    local name=$2
    local content=$3
    local start_marker="# MASU-${name}-START"
    local end_marker="# MASU-${name}-END"

    sed -i "/$start_marker/,/$end_marker/d" "$file" 2>/dev/null || true

    {
        echo "$start_marker"
        echo "$content"
        echo "$end_marker"
    } >> "$file"
}

# 1. Base ZSH Configuration
ZSH_BASE_CONFIG="export ZSH=\"\$HOME/.oh-my-zsh\"
ZSH_THEME=\"powerlevel10k/powerlevel10k\"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-completions)
source \$ZSH/oh-my-zsh.sh"

insert_marker_block ~/.zshrc "BASE" "$ZSH_BASE_CONFIG"

# 2. Powerlevel10k Source
p10k_source_block="[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh"
insert_marker_block ~/.zshrc "P10K" "$p10k_source_block"

# 3. FZF Integration — FIXED
fzf_block='[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
# Termux FZF (safe check)
[[ -n "${PREFIX:-}" && -f "$PREFIX/share/fzf/key-bindings.zsh" ]] && source "$PREFIX/share/fzf/key-bindings.zsh"'

insert_marker_block ~/.zshrc "FZF" "$fzf_block"

# 4. Fastfetch
fetch_block="if [[ -o interactive ]]; then
    fastfetch --config \$HOME/.config/fastfetch/config.jsonc
fi"
insert_marker_block ~/.zshrc "FETCH" "$fetch_block"

# 5. MASU Aliases
case "$OS" in
    arch)     UPDATE_CMD="sudo pacman -Syu" ;;
    debian)   UPDATE_CMD="sudo apt update && sudo apt upgrade" ;;
    fedora)   UPDATE_CMD="sudo dnf upgrade" ;;
    opensuse) UPDATE_CMD="sudo zypper update" ;;
    termux)   UPDATE_CMD="pkg upgrade" ;;
    *)        UPDATE_CMD="echo 'Update command not set for this distro'" ;;
esac

MASU_ALIASES="alias ll=\"ls -lah --color=auto\"
alias la=\"ls -A --color=auto\"
alias update=\"$UPDATE_CMD\"
alias ports=\"ss -tulnp\"
alias myip=\"curl -s https://ipinfo.io/ip\"
alias cls=\"clear\"
alias reload=\"source ~/.zshrc\""

insert_marker_block ~/.zshrc "ALIASES" "$MASU_ALIASES"

# First-Run Hook
if [[ "$OS" != "termux" ]]; then
    FIRST_RUN_HOOK="[[ -f ~/.masu_first_run.zsh ]] && source ~/.masu_first_run.zsh"
    insert_marker_block ~/.zshrc "FIRST-RUN" "$FIRST_RUN_HOOK"
fi

success ".zshrc configured with Marker Blocks"

# ─── Rest of the script (Nerd Font, Fastfetch config, Theme, etc.) ───
# [The rest remains unchanged from your original script]

# Setup Fastfetch config
mkdir -p ~/.config/fastfetch
if [[ "$OS" = "termux" ]]; then
    FETCH_FILE="mobile-config.jsonc"
else
    FETCH_FILE="pc-config.jsonc"
fi

if [[ -f "$SCRIPT_DIR/configs/fastfetch/$FETCH_FILE" ]]; then
    cp "$SCRIPT_DIR/configs/fastfetch/$FETCH_FILE" ~/.config/fastfetch/config.jsonc
    success "MASU Fetch config ($FETCH_FILE) applied"
else
    warn "Fastfetch config $FETCH_FILE not found in $SCRIPT_DIR/configs/fastfetch/"
fi

step "Applying Theme: $CHOSEN_THEME"
case "$CHOSEN_THEME" in
    minimal)
        if [[ -f "$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ]]; then
            cp "$SCRIPT_DIR/configs/zsh/p10k-termux.zsh" ~/.p10k.zsh
            success "MASU Minimal theme applied"
        fi
        ;;
    cyber)
        if [[ -f "$SCRIPT_DIR/configs/zsh/p10k-cyber.zsh" ]]; then
            cp "$SCRIPT_DIR/configs/zsh/p10k-cyber.zsh" ~/.p10k.zsh
            success "MASU Cyber theme applied"
        fi
        ;;
    *)
        cat > ~/.masu_first_run.zsh << 'FIRSTRUN'
# MASU first-run — auto-deleted after use
rm -f ~/.masu_first_run.zsh
sed -i '/MASU-FIRST-RUN-START/,/MASU-FIRST-RUN-END/d' ~/.zshrc 2>/dev/null
[[ ! -f ~/.p10k.zsh ]] && p10k configure
FIRSTRUN
        
        FIRST_RUN_HOOK="[[ -f ~/.masu_first_run.zsh ]] && source ~/.masu_first_run.zsh"
        insert_marker_block ~/.zshrc "FIRST-RUN" "$FIRST_RUN_HOOK"
        ;;
esac

# Remove old hooks
[[ -f ~/.zshenv ]] && sed -i '/masu_first_run/d' ~/.zshenv 2>/dev/null || true
[[ -f ~/.masu_first_run.zsh ]] && [[ "$CHOSEN_THEME" != "default" ]] && rm ~/.masu_first_run.zsh

# ─── Done ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo -e "║   Installation Complete! ✓           ║"
echo -e "╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}What's installed:${RESET}"
echo -e "    • ZSH + Oh My Zsh + P10k"
echo -e "    • Theme: ${BOLD}$CHOSEN_THEME${RESET}"
echo -e "    • MesloLGS Nerd Font"
echo -e "    • Plugins: autosuggestions, syntax, completions"
echo -e "    • fzf + Fastfetch + MASU aliases"
echo ""
echo -e "  ${YELLOW}Remember:${RESET} Set ${BOLD}MesloLGS NF${RESET} as your terminal font."
echo ""
if [[ "$CHOSEN_THEME" = "default" ]]; then
    echo -e "  ${GREEN}${BOLD}✓ Open a new terminal — Powerlevel10k wizard will start!${RESET}"
else
    echo -e "  ${GREEN}${BOLD}✓ Open a new terminal to see your new MASU setup!${RESET}"
fi
echo ""
echo -e "  ${MAGENTA}MASU Cyber Learning Project — Stay Sharp!${RESET}"
echo ""
