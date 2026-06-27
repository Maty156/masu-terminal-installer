#!/usr/bin/env python3
"""
MASU Terminal Installer — Textual GUI-style TUI frontend.

This is the mouse-driven, sidebar-navigation frontend for the MASU
installer. It does NOT contain any install logic itself — all real work
(git clones, package manager calls, file writes) is done by
install_core.sh, which this app runs as a subprocess and streams progress
from. This split means:

  - install.sh         -> standalone bash + fzf/whiptail, no Python needed
  - install_core.sh    -> shared install engine, used by both frontends
  - masu_installer.py  -> this file, the mouse-driven Textual frontend

Requires: Python 3.9+, the `textual` package (pip install textual).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, VerticalScroll
from textual.screen import Screen
from textual.widgets import (
    Button,
    Checkbox,
    Footer,
    Header,
    Label,
    ProgressBar,
    RadioButton,
    RadioSet,
    Static,
)

# ─── Paths ──────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
CORE_SCRIPT = SCRIPT_DIR / "install_core.sh"

MASU_LOGO = r"""
███╗   ███╗ █████╗ ███████╗██╗   ██╗
████╗ ████║██╔══██╗██╔════╝██║   ██║
██╔████╔██║███████║███████╗██║   ██║
██║╚██╔╝██║██╔══██║╚════██║██║   ██║
██║ ╚═╝ ██║██║  ██║███████║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝
""".strip("\n")

PROGRESS_RE = re.compile(r"^PROGRESS:(-?\d+):(.*)$")
SUMMARY_RE = re.compile(r"^SUMMARY:([a-zA-Z_]+):(.*)$")
NEED_SUDO_RE = re.compile(r"^NEED_SUDO:(.*)$")


class InstallState:
    """Shared state collected across screens, used to build the
    install_core.sh command line at the end."""

    def __init__(self) -> None:
        self.theme: str = "minimal"
        self.fastfetch_on_start: bool = False
        self.skip_fonts: bool = False
        self.summary: dict[str, str] = {}


STATE = InstallState()


# ─── Welcome Screen ─────────────────────────────────────────
class WelcomeScreen(Screen):
    """First screen: logo, description, Next button."""

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="welcome-scroll"):
            yield Static(MASU_LOGO, id="logo")
            yield Static("TERMINAL INSTALLER", id="logo-subtitle")
            with Vertical(id="welcome-card"):
                yield Label("Welcome to the MASU Terminal Installer!", id="welcome-title")
                yield Static(
                    "This installer sets up ZSH, Oh My Zsh, Powerlevel10k, and a\n"
                    "curated plugin set — a modern, productive terminal environment.\n\n"
                    "Use your mouse or arrow keys + Enter to navigate. Let's get started!",
                    id="welcome-text",
                )
        with Horizontal(id="welcome-actions"):
            yield Button("Quit", id="quit", variant="error")
            yield Button("Next >", id="next", variant="primary")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "next":
            self.app.push_screen(PackagesScreen())
        elif event.button.id == "quit":
            self.app.exit()


# ─── Packages / Theme Screen ────────────────────────────────
class PackagesScreen(Screen):
    """Theme selection + fastfetch + font choice, mirrors the mockup's
    checkbox-list package picker but mapped onto this project's real
    options (theme is single-select, the rest are toggles)."""

    BINDINGS = [Binding("escape", "go_back", "Back")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="packages-scroll"):
            yield Label("Choose your setup", id="screen-title")
            yield Static(
                "These match what install_core.sh supports today — pick a theme "
                "and the extras you want.",
                id="screen-subtitle",
            )

            yield Label("Theme", classes="section-label")
            with RadioSet(id="theme-radio"):
                yield RadioButton(
                    "MASU Minimal — fast, clean, mobile-optimized", value=True, id="theme-minimal"
                )
                yield RadioButton("MASU Cyber — neon colors, icon-heavy", id="theme-cyber")
                yield RadioButton("P10K Wizard — run the interactive P10K setup", id="theme-wizard")

            yield Label("Extras", classes="section-label")
            yield Checkbox("Show fastfetch on every new terminal", id="cb-fastfetch")
            yield Checkbox(
                "Install Nerd Font (MesloLGS NF) for P10K icons", value=True, id="cb-fonts"
            )
        with Horizontal(id="packages-actions"):
            yield Button("< Back", id="back")
            yield Button("Next >", id="next", variant="primary")
        yield Footer()

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.app.pop_screen()
        elif event.button.id == "next":
            radio = self.query_one("#theme-radio", RadioSet)
            pressed = radio.pressed_button
            theme_map = {
                "theme-minimal": "minimal",
                "theme-cyber": "cyber",
                "theme-wizard": "wizard",
            }
            STATE.theme = theme_map.get(pressed.id if pressed else "theme-minimal", "minimal")
            STATE.fastfetch_on_start = self.query_one("#cb-fastfetch", Checkbox).value
            STATE.skip_fonts = not self.query_one("#cb-fonts", Checkbox).value
            self.app.push_screen(ConfirmScreen())


# ─── Confirm Screen ─────────────────────────────────────────
class ConfirmScreen(Screen):
    """Preview of choices before kicking off the real install — mirrors
    the mockup's "Preview" step."""

    BINDINGS = [Binding("escape", "go_back", "Back")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="confirm-scroll"):
            yield Label("Ready to install", id="screen-title")
            theme_labels = {
                "minimal": "MASU Minimal",
                "cyber": "MASU Cyber",
                "wizard": "P10K Wizard",
            }
            lines = [
                f"Theme:           {theme_labels.get(STATE.theme, STATE.theme)}",
                f"Fastfetch on open: {'Yes' if STATE.fastfetch_on_start else 'No'}",
                f"Nerd Font:        {'Skip' if STATE.skip_fonts else 'Install'}",
            ]
            yield Static("\n".join(lines), id="confirm-summary")
            yield Static(
                "This will install ZSH, Oh My Zsh, Powerlevel10k, plugins, and "
                "configure your shell. You may be asked for your sudo password "
                "in the terminal during installation.",
                id="confirm-note",
            )
        with Horizontal(id="confirm-actions"):
            yield Button("< Back", id="back")
            yield Button("Install", id="install", variant="success")
        yield Footer()

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.app.pop_screen()
        elif event.button.id == "install":
            self.app.push_screen(InstallScreen())


# ─── Install Screen ─────────────────────────────────────────
class InstallScreen(Screen):
    """Runs install_core.sh as a subprocess, parsing PROGRESS:/SUMMARY:/
    NEED_SUDO: lines from stdout into a live progress bar + status log."""

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="install-body"):
            yield Label("Installing...", id="screen-title")
            yield ProgressBar(total=100, id="install-progress", show_eta=False)
            yield Static("Starting...", id="install-status")
            with VerticalScroll(id="install-log-container"):
                yield Static("", id="install-log")
        yield Footer()

    def on_mount(self) -> None:
        self.run_worker(self.run_install(), exclusive=True, thread=False)

    def _sudo_warmup_needed(self) -> bool:
        """True if install_core.sh will need sudo and credentials aren't
        already cached. Mirrors install_core.sh's own check (skip when
        root, on Termux, or sudo doesn't exist) so we only interrupt the
        TUI when a password prompt would actually happen."""
        if os.geteuid() == 0:
            return False
        if os.environ.get("PREFIX", "").find("com.termux") != -1:
            return False
        if shutil.which("sudo") is None:
            return False
        # `sudo -n true` succeeds silently if credentials are already
        # cached, with no prompt and no terminal interaction needed.
        already_cached = subprocess.run(
            ["sudo", "-n", "true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        ).returncode == 0
        return not already_cached

    async def run_install(self) -> None:
        if not CORE_SCRIPT.exists():
            self.query_one("#install-status", Static).update(
                f"[red]install_core.sh not found at {CORE_SCRIPT}[/red]"
            )
            return

        # Textual takes over the whole screen, so a sudo password prompt
        # from inside the subprocess would be invisible / unreachable.
        # If credentials aren't already cached, suspend the TUI now —
        # handing the real terminal back — so the prompt is genuinely
        # visible and typeable, then resume once it's done.
        if self._sudo_warmup_needed():
            status_widget = self.query_one("#install-status", Static)
            status_widget.update("[yellow]Sudo password needed — switching to your terminal...[/yellow]")
            try:
                with self.app.suspend():
                    print("\nMASU Installer needs sudo for a few steps.")
                    warmup = subprocess.run(["sudo", "-v"], timeout=120)
                warmup_ok = warmup.returncode == 0
            except subprocess.TimeoutExpired:
                warmup_ok = False
            except Exception:
                # SuspendNotSupported or any other environment issue — fail
                # safe rather than risk hanging with no visible terminal.
                warmup_ok = False
            if not warmup_ok:
                status_widget.update(
                    "[red]Could not get sudo access. Re-run from a real terminal and "
                    "enter your password when prompted.[/red]"
                )
                self.app.push_screen(FinishScreen(success=False))
                return
            status_widget.update("[green]Sudo access confirmed.[/green] Starting install...")

        args = [
            "bash",
            str(CORE_SCRIPT),
            f"--theme={STATE.theme}",
            f"--fastfetch={'yes' if STATE.fastfetch_on_start else 'no'}",
            "--yes",
        ]
        if STATE.skip_fonts:
            args.append("--no-fonts")

        log_lines: list[str] = []
        log_widget = self.query_one("#install-log", Static)
        status_widget = self.query_one("#install-status", Static)
        progress = self.query_one("#install-progress", ProgressBar)

        process = await self._spawn(args)
        assert process.stdout is not None

        while True:
            line_bytes = await process.stdout.readline()
            if not line_bytes:
                break
            line = line_bytes.decode("utf-8", errors="replace").rstrip("\n")
            if not line:
                continue

            m = PROGRESS_RE.match(line)
            if m:
                pct, msg = int(m.group(1)), m.group(2)
                if pct >= 0:
                    progress.update(progress=pct)
                    status_widget.update(f"[cyan]{pct}%[/cyan]  {msg}")
                else:
                    status_widget.update(f"[red]{msg}[/red]")
                log_lines.append(msg)
                log_widget.update("\n".join(log_lines[-12:]))
                continue

            m = SUMMARY_RE.match(line)
            if m:
                STATE.summary[m.group(1)] = m.group(2)
                continue

            m = NEED_SUDO_RE.match(line)
            if m:
                # By this point credentials should already be cached from
                # the warmup above, so install_core.sh's own sudo calls
                # (now using -n) should succeed silently. This line is
                # mostly informational at this stage.
                log_lines.append(m.group(1))
                log_widget.update("\n".join(log_lines[-12:]))
                continue

            if line == "DONE":
                continue

            # Anything else (rare) just gets appended to the visible log.
            log_lines.append(line)
            log_widget.update("\n".join(log_lines[-12:]))

        returncode = await process.wait()
        if returncode == 0:
            self.app.push_screen(FinishScreen(success=True))
        else:
            self.app.push_screen(FinishScreen(success=False))

    async def _spawn(self, args: list[str]) -> "asyncio.subprocess.Process":
        import asyncio

        return await asyncio.create_subprocess_exec(
            *args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,  # sudo creds are already cached by the warmup above,
                                       # so the subprocess should never need to read a password;
                                       # DEVNULL makes that explicit instead of silently hanging
                                       # if it somehow tried to prompt anyway.
        )


# ─── Finish Screen ──────────────────────────────────────────
class FinishScreen(Screen):
    def __init__(self, success: bool) -> None:
        super().__init__()
        self.success = success

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="finish-body"):
            if self.success:
                yield Label("MASU Installation Complete! ✓", id="finish-title-ok")
                theme = STATE.summary.get("theme", STATE.theme)
                ff = STATE.summary.get("fastfetch_on_start", str(STATE.fastfetch_on_start))
                log_path = STATE.summary.get("log_path", "~/.masu-install.log")
                lines = [
                    "✓ ZSH + Powerlevel10k + Plugins",
                    f"✓ Theme: {theme}",
                ]
                if theme == "wizard":
                    lines.append("→ P10K wizard will run on your first ZSH session")
                if ff in ("true", "True"):
                    lines.append("✓ Fastfetch: runs on terminal open (alias: fastfetch-masu)")
                else:
                    lines.append("→ Fastfetch: manual only — run fastfetch-masu")
                lines += [
                    "",
                    "Next steps:",
                    "  1. Run 'exec zsh' to switch your current session to ZSH now",
                    "  2. Or log out and back in — ZSH will be your default shell",
                    "",
                    f"Full install log: {log_path}",
                ]
                yield Static("\n".join(lines), id="finish-details")
            else:
                yield Label("Installation Failed", id="finish-title-fail")
                log_path = STATE.summary.get("log_path", "~/.masu-install.log")
                yield Static(
                    f"Something went wrong. Check the log for details:\n{log_path}",
                    id="finish-details",
                )
            with Horizontal(id="finish-actions"):
                yield Button("Quit", id="quit", variant="primary")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "quit":
            self.app.exit()


# ─── App ────────────────────────────────────────────────────
class MasuInstallerApp(App):
    """MASU Terminal Installer — Textual frontend."""

    TITLE = "MASU Terminal Installer"
    CSS_PATH = "masu_installer.tcss"

    def on_mount(self) -> None:
        self.push_screen(WelcomeScreen())


def _preflight_check() -> None:
    """Fail fast with a clear message instead of a traceback if something
    basic is missing (bash, the core script, or a real terminal)."""
    if not sys.stdout.isatty():
        print("MASU Installer (Python TUI) needs a real terminal to run.")
        sys.exit(1)
    if shutil.which("bash") is None:
        print("bash was not found on this system — the installer needs it.")
        sys.exit(1)
    if not CORE_SCRIPT.exists():
        print(f"install_core.sh not found next to this script ({SCRIPT_DIR}).")
        print("Make sure masu_installer.py and install_core.sh are in the same folder.")
        sys.exit(1)


if __name__ == "__main__":
    _preflight_check()
    MasuInstallerApp().run()
