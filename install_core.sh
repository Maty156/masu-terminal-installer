#!/bin/bash

# ============================================================
# MASU Terminal Installer — Core Install Logic v9.0
# Author: Matyas Abraham
# Supports: Arch, BlackArch, Ubuntu, Debian, Fedora,
#           OpenSUSE, Kali, Parrot OS, Termux
#
# This is the shared install engine used by both:
#   - install.sh        (standalone bash + fzf/whiptail UI)
#   - masu_installer.py (Textual mouse-driven GUI-style TUI)
#
# Unlike install.sh, this script takes its choices as flags instead of
# showing interactive pickers, and prints machine-readable progress lines
# (PROGRESS:<pct>:<message>) to stdout instead of driving its own whiptail
# gauge — so any frontend (bash or Python) can parse and display them.
# ============================================================

set -eo pipefail

# ─── Flags ─────────────────────────────────────────────────
SKIP_FONTS=false
CHOSEN_THEME="minimal"
FASTFETCH_ON_START=false
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --no-fonts) SKIP_FONTS=true ;;
        --theme=*) CHOSEN_THEME="${arg#*=}" ;;
        --fastfetch=*) [[ "${arg#*=}" == "yes" ]] && FASTFETCH_ON_START=true ;;
        --yes) ASSUME_YES=true ;;
        -h|--help)
            echo "Usage: ./install_core.sh [--theme=minimal|cyber|wizard] [--fastfetch=yes|no] [--no-fonts] [--yes]"
            echo "  --theme=NAME      Theme to install (default: minimal)"
            echo "  --fastfetch=yes   Show fastfetch on every new terminal (default: no)"
            echo "  --no-fonts        Skip the Nerd Font download"
            echo "  --yes             Assume yes to the root-confirmation prompt (for automated/GUI callers)"
            exit 0
            ;;
    esac
done

case "$CHOSEN_THEME" in
    minimal|cyber|wizard) ;;
    *) CHOSEN_THEME="minimal" ;;
esac

# ─── Cleanup Trap ──────────────────────────────────────────
cleanup() {
    local exit_code=$?
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    if [[ $exit_code -ne 0 ]]; then
        echo "PROGRESS:-1:Installation interrupted!"
        [[ -n "${INSTALL_LOG:-}" ]] && echo "LOG_PATH:${INSTALL_LOG}"
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM



# ─── Logging ────────────────────────────────────────────────
# Everything still gets logged in full detail to this file. The on-screen
# whiptail gauge only shows short status lines, so if anything fails you
# can always check exactly what happened here.
INSTALL_LOG="$HOME/.masu-install.log"
: > "$INSTALL_LOG"
log_line() { echo "$(date '+%H:%M:%S') $1" >> "$INSTALL_LOG"; }

info()    { log_line "[INFO] $1"; }
success() { log_line "[ OK ] $1"; }
warn()    { log_line "[WARN] $1"; }
error()   { log_line "[FAIL] $1"; }

# ─── Progress reporting ────────────────────────────────────
# Prints a machine-readable "PROGRESS:<pct>:<message>" line to stdout for
# any frontend (bash fallback or the Python TUI) to parse and display.
# All [INFO]/[OK]/[WARN]/[FAIL] detail still goes to the log file only.
TOTAL_STEPS=6  # Detecting System, Dependencies, OMZ+P10K+Plugins, Fastfetch, Shell, .zshrc
              # (+1 added later for the Nerd Font step, once we know if it'll actually run)
CURRENT_STEP=0

report_progress() {
    local pct="$1" msg="$2"
    log_line "[STEP] ($pct%) $msg"
    echo "PROGRESS:${pct}:${msg}"
}

# step <name> — advances to the next step and reports the new percentage.
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    (( pct > 100 )) && pct=100
    report_progress "$pct" "$1"
}

# gauge_msg <text> — reports a sub-status at the current percentage,
# without advancing the step counter. Used for sub-steps within a longer
# phase (e.g. "Cloning oh-my-zsh..." then "Cloning plugins...").
gauge_msg() {
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    (( pct > 100 )) && pct=100
    report_progress "$pct" "$1"
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
        attempt=$((attempt + 1))
        [[ $attempt -le $max_attempts ]] && sleep "$delay"
    done

    warn "Could not clone $(basename "$repo") after $max_attempts attempts (check your internet connection)"
    return 1
}

# ─── Script Directory ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR=""
# When run via bash <(curl ...), BASH_SOURCE[0] is a pipe — configs can't be copied.
# In that case, warn the user and skip config copy steps gracefully.
if [[ ! -d "$SCRIPT_DIR" ]] || [[ "$SCRIPT_DIR" == "/" ]]; then
    warn "Running from pipe/curl — local config files (p10k, fastfetch) will be skipped."
    SCRIPT_DIR=""
fi

info "Starting installation for theme: $CHOSEN_THEME"

# ─── Root check ────────────────────────────────────────────
# In core mode, --yes (passed by the Python frontend, which shows its own
# confirmation dialog) skips this; the bash frontend (install.sh) handles
# its own confirmation before ever calling this script with --yes.
if [[ $EUID -eq 0 ]] && [[ -z "${PREFIX:-}" ]] && [[ "$ASSUME_YES" != true ]]; then
    warn "Running as root is NOT recommended."
    read -rp "  Continue as root? (y/n): " rootok
    [[ "$rootok" != "y" ]] && { info "Aborted."; exit 0; }
fi

# ─── Warm up sudo ──────────────────────────────────────────
# Package installs and chsh/usermod later need sudo. If credentials aren't
# cached yet, a password prompt mid-run (especially under the Python TUI,
# which captures this script's output) would be invisible. Skipped when
# already root, on Termux, or sudo doesn't exist.
if [[ $EUID -ne 0 ]] && [[ -z "${PREFIX:-}" ]] && command -v sudo &>/dev/null; then
    echo "NEED_SUDO:This installer needs sudo for a few steps."
    sudo -v || { echo "PROGRESS:-1:Could not get sudo access."; exit 1; }
    # Keep credentials alive in the background for the rest of the run, since
    # a slow/retried install can easily outlast sudo's default cache timeout.
    # Killed automatically by the cleanup trap on exit.
    ( while true; do sudo -v; sleep 60; done ) &>/dev/null &
    SUDO_KEEPALIVE_PID=$!
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

success "Detected: $DISTRO_LABEL"

# Now that OS and --no-fonts are both known, account for the Nerd Font step
# if it will actually run, so the progress bar still reaches 100% exactly.
if [[ "$OS" != "termux" ]] && [[ "$SKIP_FONTS" != true ]]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi

# ─── Install Dependencies & Tools ──────────────────────────
step "Installing Dependencies and core tools"

# Determine if we should prefix commands with sudo.
# -n (non-interactive): by this point the gauge has taken over the screen,
# so a password prompt would be invisible. sudo was already warmed up
# before the gauge started and is kept alive in the background, so this
# should always succeed without prompting; -n just makes failure fast and
# visible (via the log) instead of an invisible hang if it somehow isn't.
SUDO_CMD="sudo -n"
if [[ $EUID -eq 0 ]] || [[ "$OS" = "termux" ]]; then
    SUDO_CMD=""
fi

install_packages() {
    local pkgs=("${@}")
    case "$OS" in
        termux)
            pkg update -y &>>"$INSTALL_LOG"
            pkg install -y "${pkgs[@]}" &>>"$INSTALL_LOG"
            ;;
        arch)
            ${SUDO_CMD} pacman -Sy --noconfirm --needed "${pkgs[@]}" &>>"$INSTALL_LOG"
            ;;
        debian)
            ${SUDO_CMD} apt-get update -qq &>>"$INSTALL_LOG"
            ${SUDO_CMD} apt-get install -y "${pkgs[@]}" &>>"$INSTALL_LOG"
            ;;
        fedora)
            ${SUDO_CMD} dnf install -y "${pkgs[@]}" &>>"$INSTALL_LOG"
            ;;
        opensuse)
            ${SUDO_CMD} zypper install -y "${pkgs[@]}" &>>"$INSTALL_LOG"
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
    gauge_msg "Installing: ${MISSING[*]}..."
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
    gauge_msg "Cloning Oh My Zsh..."
    git_clone_retry https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
else
    info "Oh My Zsh already installed"
fi

# Powerlevel10k
if [[ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    info "Installing Powerlevel10k"
    gauge_msg "Cloning Powerlevel10k theme..."
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
        gauge_msg "Cloning plugin: $name..."
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
if [[ "$OS" != "termux" ]] && [[ "$SKIP_FONTS" != true ]]; then
    step "Installing Nerd Font (MesloLGS NF)"
    info "Optional — only affects icon rendering, never required for the shell to work"
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"

    declare -A FONT_FILES=(
        ["MesloLGS NF Regular.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        ["MesloLGS NF Bold.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        ["MesloLGS NF Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        ["MesloLGS NF Bold Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    FONT_OK=true
    FONT_NET_DEAD=false
    for fname in "${!FONT_FILES[@]}"; do
        fdest="$FONT_DIR/$fname"
        if [[ -s "$fdest" ]]; then
            continue
        fi
        if [[ "$FONT_NET_DEAD" = true ]]; then
            FONT_OK=false
            continue
        fi
        info "Downloading $fname"
        # --connect-timeout / --max-time cap EACH attempt so a slow or stalled
        # connection can never hang the installer — it just fails fast and
        # moves on, instead of sitting there looking frozen.
        if ! curl -fsSL --connect-timeout 5 --max-time 10 --retry 1 --retry-delay 1 \
                -o "$fdest" "${FONT_FILES[$fname]}"; then
            warn "Could not download $fname (timed out or unreachable) — skipping fonts"
            rm -f "$fdest"
            FONT_OK=false
            # If the very first download can't even connect, the network is
            # almost certainly unreachable right now — don't make the user
            # wait through 3 more identical timeouts for the other font files.
            FONT_NET_DEAD=true
        fi
    done

    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$FONT_DIR" &>/dev/null || true
    fi

    if [[ "$FONT_OK" = true ]]; then
        success "MesloLGS NF installed"
        info "Set your terminal's font to 'MesloLGS NF' for icons to render correctly"
    else
        warn "Font install incomplete — this is cosmetic only, your shell will work fine without it"
        warn "Set it up later: https://github.com/romkatv/powerlevel10k#manual-font-installation"
    fi
elif [[ "$SKIP_FONTS" = true ]]; then
    info "Skipping Nerd Font install (--no-fonts) — icons won't render but everything else works"
fi

# Copy fastfetch config based on environment
step "Configuring Fastfetch"
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

ZSH_PATH=$(command -v zsh || true)

if [[ -z "$ZSH_PATH" ]]; then
    warn "zsh was not found on this system — skipping default shell change"
    warn "Install zsh manually, then re-run, or set it as your shell yourself"
elif [[ "$OS" = "termux" ]]; then
    # Remove any existing exec zsh line to avoid duplicates, then add it
    sed -i '/^exec zsh/d' ~/.bashrc 2>/dev/null || true
    echo 'exec zsh' >> ~/.bashrc
    success "Termux configured to use ZSH"
else
    SHELL_CHANGED=false
    # -n / --non-interactive: never prompt for a password here. The gauge
    # has already taken over the screen, so a password prompt would be
    # invisible and look like a hang. sudo was already warmed up earlier
    # (and is kept alive in the background) — if it's somehow not cached
    # by now, fail fast and tell the user instead of hanging silently.
    if sudo -n usermod -s "$ZSH_PATH" "$USER" &>>"$INSTALL_LOG"; then
        success "Default shell set to ZSH (usermod) — takes effect on next login"
        SHELL_CHANGED=true
    elif sudo -n chsh -s "$ZSH_PATH" "$USER" &>>"$INSTALL_LOG"; then
        success "Default shell set to ZSH (chsh) — takes effect on next login"
        SHELL_CHANGED=true
    else
        warn "Could not set ZSH as default shell automatically"
        warn "Run this manually then log out and back in: sudo usermod -s $ZSH_PATH \$USER"
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
# SUMMARY: lines are machine-readable for the Python frontend; the plain
# text below is for when this script is run standalone for debugging.
report_progress 100 "Done!"
echo "SUMMARY:theme:${CHOSEN_THEME}"
echo "SUMMARY:fastfetch_on_start:${FASTFETCH_ON_START}"
echo "SUMMARY:log_path:${INSTALL_LOG}"
echo "DONE"

echo ""
echo "=== MASU Installation Complete ==="
echo "Theme: $CHOSEN_THEME"
[[ "$CHOSEN_THEME" = "wizard" ]] && echo "-> P10K wizard will run on your first ZSH session"
if [[ "$FASTFETCH_ON_START" = true ]]; then
    echo "Fastfetch: runs on terminal open (alias: fastfetch-masu)"
else
    echo "Fastfetch: manual only -- run fastfetch-masu"
fi
echo ""
echo "Next steps:"
echo "  1. Run 'exec zsh' to switch your current session to ZSH now"
echo "  2. Or log out and back in -- ZSH will be your default shell"
[[ "$CHOSEN_THEME" = "wizard" ]] && echo "  3. The P10K wizard will launch automatically on your first ZSH session"
echo ""
echo "Full install log: ${INSTALL_LOG}"
