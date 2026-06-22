# MASU Terminal Installer

![Linux](https://img.shields.io/badge/platform-Linux-green)
![Bash](https://img.shields.io/badge/language-Bash-blue)
![Version](https://img.shields.io/badge/version-v8.2-blue)
![Open Source](https://img.shields.io/badge/license-MIT-orange)
![Status](https://img.shields.io/badge/status-active-success)

MASU Terminal Installer is a Bash script that automatically installs a modern **ZSH development terminal environment**.

It installs and configures a professional terminal setup used by developers, Linux enthusiasts, and cybersecurity learners.

The script automatically detects your operating system and installs everything required.

---

# Features

✔ **3 Theme Options** — Minimal, Cyber, or P10K interactive wizard
✔ **Fastfetch Startup Choice** — opt in or out during install
✔ **Zero-Config Termux Support** — automatic mobile-optimized theme
✔ **Marker-based Configuration** — safe, re-runnable `.zshrc` updates
✔ **Integrated FZF** — fuzzy history search and navigation
✔ **Custom Fastfetch** — lightweight, compact MASU-themed info
✔ **Per-distro Update Alias** — `update` command works correctly on every OS
✔ **Automatic Nerd Font Install** — MesloLGS NF installed for correct P10K icon rendering
✔ **Retry on Flaky Connections** — all clones retry automatically on network failure
✔ Works on Linux and Termux

---

# Supported Systems

The installer automatically detects your system.

Currently supported systems include:

* Arch Linux / BlackArch / Manjaro
* Ubuntu / Debian / Kali / Parrot
* Fedora / RHEL / Rocky
* OpenSUSE
* Termux

Other distributions may also work if they use compatible package managers.

---

# Installation

## Recommended — Clone and Run

Cloning the repo gives you the full installation including p10k themes and fastfetch configs:

```
git clone https://github.com/Maty156/masu-terminal-installer.git
cd masu-terminal-installer
chmod +x install.sh
./install.sh
```

## Quick Install — One Command

```
bash <(curl -s https://raw.githubusercontent.com/Maty156/masu-terminal-installer/main/install.sh)
```

> **Note:** The curl one-liner skips copying local config files (p10k themes, fastfetch configs) since there are no local files to copy. Theme 1 and 2 will fall back to defaults, and fastfetch will use system defaults. For the full experience use the clone method above.

---

# Theme Selection

During install you will be asked to choose a theme:

| Option | Name | Description |
|--------|------|-------------|
| 1 | MASU Minimal | Fast, clean, mobile-optimized (default) |
| 2 | MASU Cyber | Neon colors, icon-heavy |
| 3 | P10K Wizard | Launches the interactive p10k setup on first ZSH session |

---

# Fastfetch

You will also be asked whether you want fastfetch to show system info every time a terminal opens.

* If you choose **yes**, fastfetch runs automatically on each new terminal.
* If you choose **no**, fastfetch is installed silently. You can run it anytime with:

```
fastfetch-masu
```

To enable it on startup later, add this line to your `~/.zshrc`:

```
fastfetch --config ~/.config/fastfetch/config.jsonc
```

---

# What the Script Installs

* ZSH shell
* Oh My Zsh configuration framework
* Powerlevel10k theme
* ZSH Autosuggestions
* ZSH Syntax Highlighting
* ZSH Completions
* ZSH History Substring Search
* fzf (fuzzy finder with key bindings)
* fastfetch (system info display)
* MesloLGS NF (Nerd Font for P10K icons — skipped on Termux)

---

# Screenshots

### Hyprland / Kitty

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
├── configs
│   ├── zsh
│   │   ├── p10k-termux.zsh     # Minimal Theme
│   │   └── p10k-cyber.zsh      # Cyber Theme
│   └── fastfetch
│       ├── mobile-config.jsonc  # Termux / Minimal
│       └── pc-config.jsonc      # Desktop
└── screenshots
    └── arch.png
```

---

# Why This Project Exists

Setting up a modern ZSH environment manually can take time, especially for new Linux users.

This project automates the entire setup process so anyone can install a professional terminal environment quickly.

---

# Changelog

### v8.2
* Added automatic Nerd Font (MesloLGS NF) installation so P10K icons render correctly out of the box. Skipped on Termux.
* All `git clone` steps (oh-my-zsh, p10k, plugins) now retry up to 3 times with backoff on network failure instead of failing on the first hiccup — useful on slow or unstable connections.

### v8.1
* Fixed `plugin not found` warnings for zsh-autosuggestions, zsh-syntax-highlighting, and zsh-history-substring-search on re-runs. The installer now verifies each plugin's `.plugin.zsh` file (not just the folder) before skipping its clone, and `.zshrc` is written with only the plugins that actually installed successfully.

### v8.0
* BlackArch Edition — multi-distro support, theme selection, fastfetch opt-in/out.

---

# Future Improvements

* loading animations during cloning steps
* more theme presets
* support for additional distributions
* `--repair` mode to re-validate all components, not just plugins

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
