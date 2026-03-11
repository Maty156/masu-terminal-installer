#!/bin/bash

# MASU Terminal Installer v5

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
echo -e "$CYAN MASU Terminal Installer v5 $RESET"
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

# Install Oh My Zsh
echo -e "${YELLOW}[ RUN ] Installing Oh My Zsh...${RESET}"

RUNZSH=no CHSH=no sh -c \
"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo -e "${GREEN}[ OK ] Oh My Zsh installed${RESET}"

# Install Powerlevel10k
echo -e "${YELLOW}[ RUN ] Installing Powerlevel10k...${RESET}"

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

echo -e "${GREEN}[ OK ] Powerlevel10k installed${RESET}"

# Install plugins
echo -e "${YELLOW}[ RUN ] Installing Zsh plugins...${RESET}"

git clone https://github.com/zsh-users/zsh-autosuggestions \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

echo -e "${GREEN}[ OK ] Plugins installed${RESET}"

# Set default shell
echo -e "${YELLOW}[ RUN ] Setting default shell...${RESET}"

if [ "$OS" = "termux" ]; then

    if ! grep -q "exec zsh" ~/.bashrc; then
        echo 'exec zsh' >> ~/.bashrc
    fi

else
    chsh -s $(which zsh)
fi

echo -e "${GREEN}[ OK ] Zsh enabled${RESET}"

# Matrix option
echo ""
read -p "Enable Matrix animation? (y/n): " matrix

if [[ "$matrix" == "y" ]]; then
    echo -e "${YELLOW}[ RUN ] Launching Matrix...${RESET}"
    cmatrix
fi

echo ""
echo -e "${GREEN}Installation Completed!${RESET}"
echo ""
echo "Restart your terminal or run:"
echo ""
echo "zsh"
echo ""