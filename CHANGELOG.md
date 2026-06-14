# Changelog

All notable changes to this project are documented in this file.

## [Unreleased] - 2026-06-14

- install: improve installer (multi-distro, Termux, oh-my-zsh, p10k, fastfetch)
  - Added robust `install_packages` helper and `SUDO_CMD` handling
  - Improved Termux detection and non-sudo behavior
  - Auto-install Oh My Zsh, Powerlevel10k, and common plugins
  - Copy appropriate `p10k` and `fastfetch` configs from `configs/`
  - Added distro-aware `alias update` in `~/.zshrc`
