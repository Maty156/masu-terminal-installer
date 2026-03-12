#!/bin/bash

# MASU Terminal Installer v7

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

clear

echo -e "$GREEN"
echo "███╗   ███╗ █████╗ ███████╗██╗   ██╗"
echo "████╗ ████║██╔══██╗██╔════╝██║   ██║"
echo "██╔████╔██║███████║███████╗██║   ██║"
echo "██║╚██╔╝██║██╔══██║╚════██║██║   ██║"
echo "██║ ╚═╝ ██║██║  ██║███████║╚██████╔╝"
echo "╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝"
echo -e "$CYAN MASU Terminal Installer v7 $RESET"
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

    elif grep -qi "suse" /etc/os-release 2>/dev/null; then
        OS="opensuse"

    elif [ -f /etc/os-release ]; then
        OS="debian"

    else
        OS="unknown"
    fi
}

echo -e "${YELLOW}[ RUN ] Detecting system...${RESET}"
detect_os
echo -e "${GREEN}[ OK ] Detected: $OS${RESET}"

# Install packages
install_packages() {

    if [ "$OS" = "termux" ]; then
        pkg update -y
        pkg install zsh git curl cmatrix -y
    fi

    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm zsh git curl cmatrix
    fi

    if [ "$OS" = "debian" ]; then
        sudo apt update
        sudo apt install zsh git curl cmatrix -y
    fi

    if [ "$OS" = "fedora" ]; then
        sudo dnf install zsh git curl cmatrix -y
    fi

    if [ "$OS" = "opensuse" ]; then
        sudo zypper install zsh git curl cmatrix -y
    fi
}

echo -e "${YELLOW}[ RUN ] Installing dependencies...${RESET}"
install_packages
echo -e "${GREEN}[ OK ] Dependencies installed${RESET}"

# Backup config
if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.backup
    echo -e "${GREEN}[ OK ] Backup created ~/.zshrc.backup${RESET}"
fi

# Install Oh My Zsh
echo -e "${YELLOW}[ RUN ] Installing Oh My Zsh...${RESET}"

RUNZSH=no CHSH=no sh -c \
"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo -e "${GREEN}[ OK ] Oh My Zsh installed${RESET}"

# Install Powerlevel10k
echo -e "${YELLOW}[ RUN ] Installing Powerlevel10k...${RESET}"

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k 2>/dev/null

# Install plugins
echo -e "${YELLOW}[ RUN ] Installing plugins...${RESET}"

git clone https://github.com/zsh-users/zsh-autosuggestions \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null

# Configure theme
if grep -q "ZSH_THEME=" ~/.zshrc; then
sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
fi

# Configure plugins safely
if grep -q "plugins=(" ~/.zshrc; then
sed -i 's/plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
fi

# Set shell
echo -e "${YELLOW}[ RUN ] Setting default shell...${RESET}"

if [ "$OS" = "termux" ]; then

    if ! grep -q "exec zsh" ~/.bashrc; then
        echo 'exec zsh' >> ~/.bashrc
    fi

else
    chsh -s $(which zsh)
fi

echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

echo ""
read -p "Enable Matrix animation demo? (y/n): " matrix

if [[ "$matrix" == "y" ]]; then
    timeout 5 cmatrix
fi

echo ""
echo -e "${GREEN}Installation Completed!${RESET}"
echo ""
echo "Restart your terminal or run:"
echo "zsh"
