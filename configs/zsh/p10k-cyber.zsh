# MASU Powerlevel10k — Cyber Edition (Neon)
# Generated for MASU Terminal Installer
# High-contrast, icon-heavy, and neon themed.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extend_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)'

  # Zsh prompt configuration.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon                 # OS logo
    context                 # user@hostname
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code
    command_execution_time  # last command duration
    background_jobs         # presence of bg jobs
    ram                     # memory usage
    load                    # cpu load
    battery                 # battery status
    time                    # current time
  )

  # Basic Look & Feel
  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate
  
  # Connect colors
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=
  
  # Neon Theme Colors (Cyan & Magenta)
  local cyan=51
  local magenta=201
  local yellow=226
  local red=196
  local green=46

  # OS Icon
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=$cyan

  # Context (user@host)
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=$yellow
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_FOREGROUND=$magenta
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'

  # Directory
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=$cyan
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$cyan
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  # Prompt Char
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIREPLACE}_FOREGROUND=$green
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIREPLACE}_FOREGROUND=$red
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIREPLACE}_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIREPLACE}_CONTENT_EXPANSION='❯'

  # Git
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=$green
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=$yellow
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=$magenta

  # RAM & CPU
  typeset -g POWERLEVEL9K_RAM_FOREGROUND=$magenta
  typeset -g POWERLEVEL9K_LOAD_FOREGROUND=$cyan
  
  # Battery
  typeset -g POWERLEVEL9K_BATTERY_LOW_FOREGROUND=$red
  typeset -g POWERLEVEL9K_BATTERY_CHARGING_FOREGROUND=$green
  typeset -g POWERLEVEL9K_BATTERY_DISCHARGING_FOREGROUND=$yellow

  # Time
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=244
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'

  # Status
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=$red

  # Instant Prompt
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
