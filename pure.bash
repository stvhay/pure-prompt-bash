#!/bin/bash

# pure prompt on bash
#
# Pretty, minimal BASH prompt, inspired by sindresorhus/pure(https://github.com/sindresorhus/pure)
#
# Author: Hiroshi Krashiki(Krashikiworks)
# released under MIT License, see LICENSE
#
# Modified:
# - Cleaned up namespace a bit
# - Did some refactoring
# - Added host detection
# - Added color configuration (by editing script)
# - Indents PS2 four spaces
# - Improved the compatibility of the grep command for BSD and Linux
#
# Author: Steve Hay (stvhay)


#### CONSTANTS ###############################################################

# tput color table
declare -A _pure_color_table=(
	[BLACK]=$(tput setaf 0)
	[RED]=$(tput setaf 1)
	[GREEN]=$(tput setaf 2)
	[YELLOW]=$(tput setaf 3)
	[BLUE]=$(tput setaf 4)
	[MAGENTA]=$(tput setaf 5)
	[CYAN]=$(tput setaf 6)
	[WHITE]=$(tput setaf 7)
	[BRIGHT_BLACK]=$(tput setaf 8)
	[BRIGHT_RED]=$(tput setaf 9)
	[BRIGHT_GREEN]=$(tput setaf 10)
	[BRIGHT_YELLOW]=$(tput setaf 11)
	[BRIGHT_BLUE]=$(tput setaf 12)
	[BRIGHT_MAGENTA]=$(tput setaf 13)
	[BRIGHT_CYAN]=$(tput setaf 14)
	[BRIGHT_WHITE]=$(tput setaf 15)
)

declare -A _pure_global
# git_status              / stores the text to display for git status
# first_time              / blank if first run of script
# original_prompt_command / saved before script runs
# user_color              / tracks the color of the user
# prompt_color            / tracks the color of the prompt
# prompt_text			  / tracks the text of the prompt
# user_host               / text to display for user and host
# first_line              / text for first line of prompt
# second_line             / text for second line of prompt


#### CONFIGURATION ###########################################################

# color configuration
declare -A _pure_color=(
	[UNPULLED]=${_pure_color_table[BRIGHT_RED]}
	[UNPUSHED]=${_pure_color_table[BRIGHT_BLUE]}
	[STATUS]=${_pure_color_table[BRIGHT_BLACK]}
	[USER]=${_pure_color_table[BRIGHT_MAGENTA]}
	[ROOT]=${_pure_color_table[BRIGHT_YELLOW]}
	[FAILED]=${_pure_color_table[RED]}
	[PROMPT]=${_pure_color_table[CYAN]}
	[HOST]=${_pure_color_table[WHITE]}
	[MULTILINE]=${_pure_color_table[BLUE]}
	[RESET]=$(tput sgr0)
)

# symbol configuration
declare -A _pure_symbol=(
	[PROMPT]="❯"
	[PROMPT_FAIL]="⚠"
	[UNPULLED]="⇣"
	[UNPUSHED]="⇡"
	[DIRTY]="*"
	[STASH]="≡")


#### FUNCTIONS ###############################################################

# no unpulled has -0 / no unpushed has +0
_pure_git_lines()    { git status --porcelain=2 --branch | grep -Eo "\$1[0-9]"; }
_pure_git_unpulled() { [[ "-0" != $(_pure_git_lines "-") ]]; }
_pure_git_unpushed() { [[ "+0" != $(_pure_git_lines "+") ]]; }
_pure_echo_git_remote_status()
{
	# prints the stylized remote status
	_pure_git_unpulled \
		&& printf "%s" "${_pure_color[UNPULLED]}${_pure_symbol[UNPULLED]}${_pure_color[RESET]}"
	_pure_git_unpushed \
		&& printf "%s" "${_pure_color[UNPUSHED]}${_pure_symbol[UNPUSHED]}${_pure_color[RESET]}"
	printf "\n"
}

# Updates git_status for use in the prompt.
_pure_git_intree()       { [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == "true" ]]; }
_pure_git_show_current() { git branch --show-current; }
_pure_git_clean()        { git diff --quiet; }
_pure_git_show_remote()  { [[ -n $(git remote show) ]]; }
_pure_update_git_status()
{
	local dirty remote
	if _pure_git_intree
	then
		_pure_git_clean \
			|| dirty=${_pure_symbol[DIRTY]}
		_pure_git_show_remote \
			&& remote=$(_pure_echo_git_remote_status)
		_pure_global[git_status]="${_pure_color[STATUS]}$(_pure_git_show_current)$dirty${_pure_color[RESET]} $remote"
	else
		_pure_global[git_status]=""
	fi
}

# if the last command failed, change prompt color and text
_pure_update_prompt() 
{ 
	if [[ $? = 0 ]]
	then
		_pure_global[prompt_text]=${_pure_symbol[PROMPT]}
		_pure_global[prompt_color]=${_pure_global[user_color]}
	else
		_pure_global[prompt_text]=${_pure_symbol[PROMPT_FAIL]}
		_pure_global[prompt_color]=${_pure_color[FAILED]}
	fi
}

_pure_save_prompt_command()
{
	[[ -z "${_pure_global[first_time]}" ]] \
		&& _pure_global[first_time]="false" \
		&& _pure_global[original_prompt_command]="${PROMPT_COMMAND}"
}

_pure_clear_colors()
{
    for color in "${!_pure_color_table[@]}"
	do
        _pure_color_table[$color]=""
    done
    _pure_color[RESET]=""
}

_pure_set_user_color()
{
	[[ ${UID} = 0 ]] \
		&& _pure_global[user_color]=${_pure_color[ROOT]} \
		|| _pure_global[user_color]=${_pure_color[USER]}
}


# attempts to detect whether there is a remote session
_pure_set_remote_session()
{
	if     [[ -n "$SSH_CLIENT" ]] \
		|| [[ -n "$SSH_TTY" ]] \
 		|| [[ -n "$SSH_CONNECTION" ]] \
		|| command -v pstree > /dev/null 2>&1 && pstree -s $$ | grep -q -E "sshd|wezterm-mux-ser" \
		|| [[ -n "$_pure_test_remote" ]]
	then
		_pure_global[user_host]="${_pure_color[PROMPT]}[${_pure_color[HOST]}\u@\h${_pure_color[PROMPT]}] "
	else
		_pure_global[user_host]=""
	fi
}


#### INITIALIZATION ##########################################################

_pure_save_prompt_command

command -v tput > /dev/null 2>&1 \
	|| _pure_clear_colors

_pure_set_user_color
_pure_set_remote_session

PROMPT_COMMAND="${_pure_global[original_prompt_command]}" # preserve previous PROMPT_COMMAND
PROMPT_COMMAND=${PROMPT_COMMAND:+${PROMPT_COMMAND%;};}    # ensure PROMPT_COMMAND ends in ;
PROMPT_COMMAND="_pure_update_prompt; ${PROMPT_COMMAND}"   # _pure_update_prompt must be first
command -v git > /dev/null 2>&1 \
	&& PROMPT_COMMAND+=" _pure_update_git_status;"

# Note: Variables that are updated/dynamic need to be escaped with a backslash.
_pure_global[first_line]="${_pure_global[user_host]}${_pure_color[PROMPT]}\w \${_pure_global[git_status]}"
_pure_global[second_line]="\[\${_pure_global[prompt_color]}\]\${_pure_global[prompt_text]}\[${_pure_color[RESET]}\] "
PS1="\n${_pure_global[first_line]}\n${_pure_global[second_line]}"
PS2="\[${_pure_color[MULTILINE]}\]${_pure_symbol[PROMPT]}\[${_pure_color[RESET]}\]     "
