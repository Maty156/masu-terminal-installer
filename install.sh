#!/bin/bash

# ============================================================
# MASU Terminal Installer — Launcher v10.0
# Author: Matyas Abraham
# Supports: Arch, BlackArch, Ubuntu, Debian, Fedora,
#           OpenSUSE, Kali, Parrot OS, Termux
#
# This script no longer contains install logic itself. It is a small,
# focused bootstrap that:
#   1. Detects your OS and makes sure Python 3 + venv + pip are available
#   2. Creates (or reuses) a private virtual environment for this project
#   3. Installs the `textual` package into that venv
#   4. Warms up sudo (so the real installer never needs an invisible
#      password prompt behind the TUI)
#   5. Hands off to masu_installer.py — the actual mouse-driven installer
#
# The real install logic lives in install_core.sh, which masu_installer.py
# runs as a subprocess. Nothing here duplicates that logic.
# ============================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR=""
GUI_SCRIPT="$SCRIPT_DIR/masu_installer.py"
VENV_DIR="$SCRIPT_DIR/.masu-venv"

# ─── Colors (this script still talks directly to a real terminal,
#      since it runs entirely BEFORE the TUI takes over the screen) ──
GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; YELLOW="\e[33m"
BLUE="\e[34m"; MAGENTA="\e[35m"; BOLD="\e[1m"; RESET="\e[0m"

info()    { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[ OK ]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[FAIL]${RESET} $1"; }

# ─── Sanity checks ──────────────────────────────────────────
if [[ ! -d "$SCRIPT_DIR" ]] || [[ -z "$SCRIPT_DIR" ]]; then
    error "Could not determine this script's location."
    error "Please clone the repo and run install.sh from inside it, e.g.:"
    echo "    git clone https://github.com/Maty156/masu-terminal-installer.git"
    echo "    cd masu-terminal-installer"
    echo "    ./install.sh"
    exit 1
fi

if [[ ! -f "$GUI_SCRIPT" ]]; then
    error "masu_installer.py not found next to install.sh ($SCRIPT_DIR)."
    error "Make sure the whole repo was cloned/downloaded, not just this file."
    exit 1
fi

# ─── Banner ──────────────────────────────────────────────────
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
echo -e "${CYAN}  Terminal Installer v10.0 — BlackArch Edition${RESET}"
echo -e "${MAGENTA}  By Matyas Abraham | MASU Cyber Learning Project${RESET}"
echo ""
info "Setting things up — this only takes a moment the first time you run it."
echo ""

# ─── OS Detection ────────────────────────────────────────────
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
}
detect_os

if [[ "$OS" = "unknown" ]]; then
    error "Unsupported OS. Cannot continue."
    exit 1
fi

# ─── Determine if we need sudo for package installs ─────────
SUDO_CMD="sudo"
if [[ $EUID -eq 0 ]] || [[ "$OS" = "termux" ]]; then
    SUDO_CMD=""
fi

# ─── Warm up sudo once, up front, before anything else needs it ──
# Both this script's own package installs AND the real installer later
# need sudo. Doing it here means the person only ever sees ONE password
# prompt, asked plainly in a normal terminal — never hidden behind a TUI.
if [[ -n "$SUDO_CMD" ]] && command -v sudo &>/dev/null; then
    info "This installer needs sudo for a few steps — you may be asked for your password now."
    sudo -v || { error "Could not get sudo access. Re-run and enter your password when prompted."; exit 1; }
    ( while true; do sudo -v; sleep 60; done ) &>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    trap '[[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
fi

# ─── Ensure Python 3 + venv + pip are available ─────────────
install_python_stack() {
    case "$OS" in
        termux)
            command -v python3 &>/dev/null && command -v pip3 &>/dev/null && return 0
            info "Installing Python..."
            pkg install -y python &>/dev/null
            ;;
        arch)
            # Arch bundles venv into the `python` package itself — no
            # separate venv package needed, unlike Debian-based distros.
            command -v python3 &>/dev/null && python3 -m venv --help &>/dev/null && return 0
            info "Installing Python..."
            ${SUDO_CMD} pacman -Sy --noconfirm --needed python python-pip &>/dev/null
            ;;
        debian)
            command -v python3 &>/dev/null && python3 -m venv --help &>/dev/null && return 0
            info "Installing Python..."
            ${SUDO_CMD} apt-get update -qq &>/dev/null
            ${SUDO_CMD} apt-get install -y python3 python3-venv python3-pip &>/dev/null
            ;;
        fedora)
            command -v python3 &>/dev/null && python3 -m venv --help &>/dev/null && return 0
            info "Installing Python..."
            ${SUDO_CMD} dnf install -y python3 python3-pip &>/dev/null
            ;;
        opensuse)
            command -v python3 &>/dev/null && python3 -m venv --help &>/dev/null && return 0
            info "Installing Python..."
            ${SUDO_CMD} zypper install -y python3 python3-pip &>/dev/null
            ;;
    esac
}

if ! install_python_stack; then
    warn "Automatic Python setup failed. Please install python3, pip, and venv manually, then re-run."
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    error "python3 still not found after setup. Please install it manually, then re-run."
    exit 1
fi

success "Python is ready"

# ─── Create / reuse a private virtual environment ───────────
# Kept inside the project folder (hidden, .masu-venv) rather than system-
# wide, so this never touches or conflicts with anything else on your
# machine, and re-running install.sh later just reuses it instantly.
VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

if [[ ! -x "$VENV_PYTHON" ]]; then
    info "Creating a private environment for the installer (first run only)..."
    if ! python3 -m venv "$VENV_DIR" 2>/tmp/masu-venv-error.log; then
        error "Could not create a Python virtual environment."
        error "Details: $(tail -n 3 /tmp/masu-venv-error.log 2>/dev/null)"
        exit 1
    fi
    success "Environment created"
else
    info "Reusing existing environment"
fi

# ─── Install textual into the venv ──────────────────────────
NEED_INSTALL=true
if "$VENV_PYTHON" -c "import textual" &>/dev/null; then
    NEED_INSTALL=false
fi

if [[ "$NEED_INSTALL" = true ]]; then
    info "Installing required packages (textual)..."
    if ! "$VENV_PIP" install --quiet --upgrade pip &>/dev/null; then
        warn "Could not upgrade pip in the venv — continuing anyway"
    fi

    INSTALL_OK=false
    if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
        "$VENV_PIP" install --quiet -r "$SCRIPT_DIR/requirements.txt" && INSTALL_OK=true
    else
        "$VENV_PIP" install --quiet textual && INSTALL_OK=true
    fi

    if [[ "$INSTALL_OK" != true ]]; then
        error "Failed to install required Python packages. Check your internet connection and re-run."
        exit 1
    fi
    success "Packages installed"
else
    info "Required packages already present"
fi

# ─── Hand off to the real installer ─────────────────────────
echo ""
success "Setup complete — launching the installer..."
sleep 0.5

exec "$VENV_PYTHON" "$GUI_SCRIPT"
