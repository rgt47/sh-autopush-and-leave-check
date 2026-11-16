# Offer to commit uncommitted work when leaving a git repository.
#
# Fires when the repository root changes (cd, pushd, popd, autojump,
# zoxide; anything that changes directory in the current shell) and
# when an interactive shell exits inside a repository. Lists the
# changes and offers `git commit -a`: tracked files only. Untracked
# files are listed but never added.
#
# Silent in non-interactive shells and when stdin or stdout is not a
# terminal, so scripts, make, editors, and agent tools never block.
# Opt out for a shell with GIT_LEAVE_CHECK=0.
#
# Source from ~/.zshrc:  source ~/.config/zsh/git-leave-check.zsh

typeset -g _GIT_LEAVE_LAST_ROOT=""

_git_leave_check() {
  emulate -L zsh
  local root=$1
  [[ "${GIT_LEAVE_CHECK:-1}" == 0 ]] && return
  [[ -o interactive && -t 0 && -t 1 ]] || return
  local -a lines tracked
  lines=(${(f)"$(command git -C "$root" status --porcelain 2>/dev/null)"})
  (( ${#lines} )) || return
  tracked=(${lines:#\?\?*})
  local shown=${root/#$HOME/~}
  print -P "%F{yellow}Leaving ${shown//\%/%%} with uncommitted changes:%f"
  print -rl -- "${(@)lines[1,15]}"
  (( ${#lines} > 15 )) && print -r -- "  ... and $(( ${#lines} - 15 )) more"
  if (( ! ${#tracked} )); then
    print -r -- "Only untracked files; add them explicitly to commit them."
    return
  fi
  local reply msg ask='[c]ommit tracked changes, any other key to skip: '
  read -k 1 "reply?$ask" || return
  print
  [[ $reply == [cC] ]] || return
  read "msg?Commit message: " || return
  if [[ -z ${msg//[[:space:]]/} ]]; then
    print -r -- "Empty message; not committing."
    return
  fi
  command git -C "$root" commit -a -m "$msg"
}

_git_leave_chpwd() {
  emulate -L zsh
  local root prev
  root=$(command git rev-parse --show-toplevel 2>/dev/null)
  [[ "$root" == "$_GIT_LEAVE_LAST_ROOT" ]] && return
  prev=$_GIT_LEAVE_LAST_ROOT
  _GIT_LEAVE_LAST_ROOT=$root
  [[ -n "$prev" ]] && _git_leave_check "$prev"
}

_git_leave_zshexit() {
  emulate -L zsh
  local root
  root=$(command git rev-parse --show-toplevel 2>/dev/null) || return
  _git_leave_check "$root"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _git_leave_chpwd
add-zsh-hook zshexit _git_leave_zshexit
_GIT_LEAVE_LAST_ROOT=$(command git rev-parse --show-toplevel 2>/dev/null)
