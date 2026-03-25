# MASU Terminal Installer

![Linux](https://img.shields.io/badge/platform-Linux-green)
![Bash](https://img.shields.io/badge/language-Bash-blue)
![Open Source](https://img.shields.io/badge/license-MIT-orange)
![Status](https://img.shields.io/badge/status-active-success)

MASU Terminal Installer is a Bash script that automatically installs a modern **ZSH development terminal environment**.

It installs and configures a professional terminal setup used by developers, Linux enthusiasts, and cybersecurity learners.

The script automatically detects your operating system and installs everything required.

---

# Features

✔ Automatic Linux distribution detection
✔ Installs ZSH and required dependencies
✔ Installs Oh My Zsh framework
✔ Installs Powerlevel10k theme
✔ Installs ZSH Autosuggestions plugin
✔ Installs ZSH Syntax Highlighting plugin
✔ Optional Matrix animation
✔ Backup of existing `.zshrc` configuration
✔ Works on Linux and Termux

---

# Supported Systems

The installer automatically detects your system.

Currently supported systems include:

* Arch Linux
* Ubuntu
* Debian
* Fedora
* OpenSUSE
* Termux

Other distributions may also work if they use compatible package managers.

---

# One Command Installation

Run the installer directly from GitHub:

```
bash <(curl -s https://raw.githubusercontent.com/Maty156/masu-terminal-installer/main/install.sh)
```

This downloads and runs the installer automatically.

---

# Manual Installation

Clone the repository:

```
git clone https://github.com/Maty156/masu-terminal-installer.git
```

Enter the project directory:

```
cd masu-terminal-installer
```

Make the script executable:

```
chmod +x install.sh
```

Run the installer:

```
./install.sh
```

---

# What the Script Installs

The installer configures a complete terminal environment including:

* ZSH shell
* Oh My Zsh configuration framework
* Powerlevel10k theme
* ZSH Autosuggestions
* ZSH Syntax Highlighting

These tools improve terminal productivity by providing:

* command suggestions
* syntax highlighting
* improved terminal appearance
* faster workflow

---

# Screenshots

### Arch Linux

<p align="center">
  <img src="/screenshots/screenshot-20260325-192838.png" width="700">
</p>

More screenshots from other systems will be added soon.

---

# Project Structure

```
masu-terminal-installer
│
├── install.sh
├── README.md
└── screenshots
    └── arch.png
```

---

# Why This Project Exists

Setting up a modern ZSH environment manually can take time, especially for new Linux users.

This project automates the entire setup process so anyone can install a professional terminal environment quickly.

---

# Future Improvements

Planned improvements for future versions:

* improved installer interface
* loading animations
* better plugin configuration
* more terminal customization
* support for additional distributions

---

# Contributing

Contributions are welcome.

If you want to improve the project:

1. Fork the repository
2. Create a new branch
3. Submit a pull request

---

# License

This project is open source and available under the MIT License.

---

# Author

Created by **Matyas Abraham**

Part of the **MASU Cyber Learning Project**.
