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
echo -e "$CYAN MASU Terminal Installer v3 $RESET"
echo ""

print_ok() {
echo -e "$GREEN[ OK ]$RESET $1"
}

print_run() {
echo -e "$CYAN[ RUN ]$RESET $1"
}

print_fail() {
echo -e "$RED[ FAIL ]$RESET $1"
}

sleep 1

print_run "Detecting system..."

if [[ "$PREFIX" == *"com.termux"* ]]; then
    distro="termux"

elif [ -f /etc/debian_version ]; then
    distro="debian"

elif [ -f /etc/arch-release ]; then
    distro="arch"

elif [ -f /etc/fedora-release ]; then
    distro="fedora"

elif [ -f /etc/SuSE-release ]; then
    distro="opensuse"

else
    distro="unknown"
fi

print_ok "Detected: $distro"

sleep 1

print_run "Installing dependencies..."

if [ "$distro" = "termux" ]; then

    pkg update -y
    pkg install -y zsh git curl

elif [ "$distro" = "debian" ]; then

    sudo apt update
    sudo apt install -y zsh git curl

elif [ "$distro" = "arch" ]; then

    sudo pacman -S --noconfirm zsh git curl

elif [ "$distro" = "fedora" ]; then

    sudo dnf install -y zsh git curl

elif [ "$distro" = "opensuse" ]; then

    sudo zypper install -y zsh git curl

else
    print_fail "Unsupported system"
    exit
fi

print_ok "Dependencies installed"

sleep 1

print_run "Backing up existing .zshrc..."

if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.bak
    print_ok ".zshrc backup created"
else
    print_ok "No existing .zshrc found"
fi

sleep 1

print_run "Installing Oh My Zsh..."

RUNZSH=no CHSH=no sh -c \
"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

print_ok "Oh My Zsh installed"

sleep 1

print_run "Installing Powerlevel10k..."

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

print_ok "Powerlevel10k installed"

sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

print_ok "Theme configured"

sleep 1

print_run "Installing plugins..."

git clone https://github.com/zsh-users/zsh-autosuggestions \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

print_ok "Plugins installed"

sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

print_ok "Plugins enabled"

sleep 1

if [ "$distro" = "termux" ]; then
    echo "exec zsh" >> ~/.bashrc
    print_ok "Zsh enabled for Termux"
else
    chsh -s $(which zsh)
    print_ok "Default shell changed to Zsh"
fi

echo ""

read -p "Enable Matrix animation? (y/n): " matrix

if [ "$matrix" = "y" ]; then

print_run "Installing cmatrix..."

if [ "$distro" = "termux" ]; then
pkg install cmatrix -y

elif [ "$distro" = "debian" ]; then
sudo apt install cmatrix -y

elif [ "$distro" = "arch" ]; then
sudo pacman -S cmatrix --noconfirm

fi

print_ok "Launching Matrix..."

cmatrix -b

fi

echo ""
echo -e "$GREEN Installation Completed! $RESET"
echo ""
echo "Restart your terminal or run:"
echo ""
echo "zsh"
echo ""