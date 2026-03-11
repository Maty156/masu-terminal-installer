#!/bin/bash

# MASU Terminal Installer v3

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

clear

echo -e "$GREEN"
echo "███╗   ███╗ █████╗ ███████╗██╗   ██╗"
echo "████╗ ████║██╔══██╗██╔════╝██║   ██║"
echo "██╔████╔██║███████║███████╗██║   ██║"
echo "██║╚██╔╝██║██╔══██║╚════██║██║   ██║"
echo "██║ ╚═╝ ██║██║  ██║███████║╚██████╔╝"
echo "╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝"
echo -e "$CYAN MASU Terminal Installer v4 $RESET"
echo ""

# Detect OS
detect_os() {
    if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
        OS="termux"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
    elif [ -f /etc/SuSE-release ] || [ -f /etc/os-release ] && grep -qi "suse" /etc/os-release; then
        OS="opensuse"
    else
        OS="unknown"
    fi
}

echo -e "${YELLOW}[ RUN ] Detecting system...${RESET}"
detect_os
echo -e "${GREEN}[ OK ] Detected: $OS${RESET}"

# ===============================
# TERMUX INSTALLATION
# ===============================

if [ "$OS" = "termux" ]; then

    echo -e "${YELLOW}[ RUN ] Updating packages...${RESET}"
    pkg update -y && pkg upgrade -y

    echo -e "${YELLOW}[ RUN ] Installing dependencies...${RESET}"
    pkg install zsh git curl cmatrix -y

    echo -e "${GREEN}[ OK ] Packages installed${RESET}"

    # Make ZSH default shell
    if ! grep -q "exec zsh" ~/.bashrc; then
        echo 'exec zsh' >> ~/.bashrc
        echo -e "${GREEN}[ OK ] Zsh set as default shell${RESET}"
    fi

    echo ""
    read -p "Enable Matrix animation? (y/n): " matrix

    if [[ "$matrix" == "y" ]]; then
        echo -e "${YELLOW}[ RUN ] Launching Matrix...${RESET}"
        cmatrix
    fi

fi

# ===============================
# ARCH INSTALLATION
# ===============================

if [ "$OS" = "arch" ]; then

    echo -e "${YELLOW}[ RUN ] Installing packages...${RESET}"
    sudo pacman -S --noconfirm zsh git curl cmatrix

    echo -e "${GREEN}[ OK ] Packages installed${RESET}"

    echo -e "${YELLOW}[ RUN ] Changing default shell...${RESET}"
    chsh -s $(which zsh)

    echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

fi

# ===============================
# DEBIAN / UBUNTU / KALI
# ===============================

if [ "$OS" = "debian" ]; then

    echo -e "${YELLOW}[ RUN ] Installing packages...${RESET}"
    sudo apt update
    sudo apt install zsh git curl cmatrix -y

    echo -e "${GREEN}[ OK ] Packages installed${RESET}"

    echo -e "${YELLOW}[ RUN ] Changing default shell...${RESET}"
    chsh -s $(which zsh)

    echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

fi

# ===============================
# FEDORA
# ===============================

if [ "$OS" = "fedora" ]; then

    echo -e "${YELLOW}[ RUN ] Installing packages...${RESET}"
    sudo dnf install zsh git curl cmatrix -y

    echo -e "${GREEN}[ OK ] Packages installed${RESET}"

    echo -e "${YELLOW}[ RUN ] Changing default shell...${RESET}"
    chsh -s $(which zsh)

    echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

fi

# ===============================
# OPENSUSE
# ===============================

if [ "$OS" = "opensuse" ]; then

    echo -e "${YELLOW}[ RUN ] Installing packages...${RESET}"
    sudo zypper install zsh git curl cmatrix -y

    echo -e "${GREEN}[ OK ] Packages installed${RESET}"

    echo -e "${YELLOW}[ RUN ] Changing default shell...${RESET}"
    chsh -s $(which zsh)

    echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

fi

echo ""
echo -e "${GREEN}Installation Completed!${RESET}"
echo ""
echo "Restart your terminal or run:"
echo ""
echo "zsh"
echo ""