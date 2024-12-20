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
	[UNPULLED]="⇣"
	[UNPUSHED]="⇡"
	[DIRTY]="*"
	[STASH]="≡")


#### FUNCTIONS ###############################################################

# no unpulled has -0 / no unpushed has +0
_pure_git_unpulled() { [[ "-0" != $(git status --porcelain=2 --branch | grep -Eo "\-[0-9]") ]]; }
_pure_git_unpushed() { [[ "+0" != $(git status --porcelain=2 --branch | grep -Eo "\+[0-9]") ]]; }
_pure_echo_git_remote_status()
{
	# prints the stylized remote status
	_pure_git_unpulled && printf "%s" "${_pure_color[UNPULLED]}${_pure_symbol[UNPULLED]}${_pure_color[RESET]}"
	_pure_git_unpushed && printf "%s" "${_pure_color[UNPUSHED]}${_pure_symbol[UNPUSHED]}${_pure_color[RESET]}"
	printf "\n"
}

# Updates _pure_git_status for use in the prompt.
_pure_git_intree()       { [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == "true" ]]; }
_pure_git_show_current() { git branch --show-current; }
_pure_git_clean()        { git diff --quiet; }
_pure_git_show_remote()  { [[ -n $(git remote show) ]]; }
_pure_update_git_status()
{
	local dirty remote
	if _pure_git_intree
	then
		_pure_git_clean       || dirty=${_pure_symbol[DIRTY]}
		_pure_git_show_remote && remote=$(_pure_echo_git_remote_status)

		_pure_git_status="${_pure_color[STATUS]}$(_pure_git_show_current)$dirty${_pure_color[RESET]} $remote"
	else
		_pure_git_status=""
	fi
}


# if the last command failed, change prompt color by updating _pure_prompt_color
_pure_echo_prompt_color()
{
	[[ $1 = 0 ]] \
		&& printf "%s" "${_pure_user_color}" \
		|| printf "%s" "${_pure_color[FAILED]}"
}
_pure_update_prompt_color() { _pure_prompt_color=$(_pure_echo_prompt_color $?); }


# attempts to detect whether there is a remote session
_pure_remote_session()
{
	   [[ -n "$SSH_CLIENT" ]] \
	|| [[ -n "$SSH_TTY" ]] \
 	|| [[ -n "$SSH_CONNECTION" ]] \
	|| pstree -s $$ | grep -q -E "sshd|wezterm-mux-ser" \
	|| [[ -n "$_pure_test_remote" ]]	
}


#### INITIALIZATION ##########################################################

# save/reset $PROMPT_COMMAND for script idempotence
[[ -z "$_pure_first_time" ]] \
	&& _pure_first_time="false" \
	&& _pure_original_prompt_command=$PROMPT_COMMAND
PROMPT_COMMAND="${_pure_original_prompt_command}"

# Clear colors if tput missing
if ! command -v tput > /dev/null 2>&1
then
    for color in "${!_pure_color_table[@]}"; do
        _pure_color_table[$color]=""
    done
    _pure_color[RESET]=""
fi

# set user color
[[ ${UID} = 0 ]] \
	&& _pure_user_color=${_pure_color[ROOT]} \
	|| _pure_user_color=${_pure_color[USER]}

# set user and host if its a remote session
_pure_remote_session \
	&& _pure_user_host="${_pure_color[PROMPT]}[${_pure_color[HOST]}\u@\h${_pure_color[PROMPT]}] " \
	|| _pure_user_host=""


#### RUN EVERY PROMPT ########################################################

# prompt color update must be first because it checks exit status
PROMPT_COMMAND="_pure_update_prompt_color; ${PROMPT_COMMAND}"

# if git isn't installed when shell launches, git integration isn't activated
command -v git > /dev/null 2>&1 \
	&& PROMPT_COMMAND+="_pure_update_git_status;"


#### SET PROMPT ##############################################################

_pure_first_line="${_pure_user_host}${_pure_color[PROMPT]}\w \$_pure_git_status"
_pure_second_line="\[\${_pure_prompt_color}\]${_pure_symbol[PROMPT]}\[${_pure_color[RESET]}\] "
PS1="\n${_pure_first_line}\n${_pure_second_line}"
PS2="\[${_pure_color[MULTILINE]}\]${_pure_symbol[PROMPT]}\[${_pure_color[RESET]}\]     "
