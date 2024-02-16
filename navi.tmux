#!/usr/bin/env bash

# Daemon that keeps track of the programs running in tmux panes,
# and decides whether to swatch tmux panes or send keys for navigation within
# the program running in the pane, like vim.
#
# Makes navigation much faster than checking the program running in the pane
# at the time of navigation.
#
# Copyright 2021 Maddison Hellstrom <github.com/b0o>, MIT License.

set -euo pipefail

declare -g self prog name
self="$(realpath -e "${BASH_SOURCE[0]}")"
prog="$(basename "$self")"
name="${prog%.tmux}"

function get_instance() {
  local -i instance_pid
  instance_pid="$(tmux show-options -gv "@$name-pid" 2>/dev/null)"
  if [[ "$instance_pid" -gt 0 ]] && ps "$instance_pid" &>/dev/null; then
    echo "$instance_pid"
    return 0
  fi
  return 1
}

function onexit() {
  tmux set-option -gu "@$name-pid" &
}

function kill_instance() {
  local -i instance_pid
  if instance_pid="$(get_instance)"; then
    kill "$instance_pid"
    echo "$name: killed $instance_pid"
    return 0
  fi
  echo "$name: not running"
  return 1
}

function get_status() {
  local -i instance_pid
  if instance_pid="$(get_instance)"; then
    echo "running: $instance_pid"
    return 0
  fi
  echo "not running"
  return 1
}

declare pattern="g?(view|n?vim?x?|ssh)(diff)?"
declare interval="0.5"
declare path_expr="#{socket_path}-#{session_id}-#{pane_id}-$name"

function tick() {
  local panes procs
  panes="$(tmux list-panes -aF "$path_expr:#{pane_tty}")"
  procs="$(ps a -ostate=,tty=,comm=)"
  while read -r pane; do
    local path tty
    path="${pane%%:*}"
    tty="${pane#*:}"
    tty="${tty#/dev/}"
    if [[ -z "$tty" ]]; then
      continue
    fi
    if grep -iqE "^[^TXZ ]+ ${tty} +(\S+/)?${pattern}\$" <<<"$procs"; then
      echo -n 1 >"$path"
    else
      echo -n 0 >"$path"
    fi
  done <<<"$panes"
}

function check() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    path="$(tmux display-message -p "$path_expr")"
  fi
  if [[ -e "$path" && "$(cat "$path")" -eq 1 ]]; then
    exit 0
  fi
  exit 1
}

function loop() {
  while true; do
    tick
    sleep "$interval"
  done
}

function ensure_not_running() {
  if get_instance &>/dev/null; then
    return 1
  fi
}

function main() {
  if ! [[ "${1:-}" =~ ^-[cCfks]$ ]]; then
    if get_instance &>/dev/null; then
      exit 0
    fi
    "$self" -f "$@" &>/dev/null &
    disown
    exit 0
  fi
  local opt OPTARG
  local -i OPTIND
  local path
  while getopts ":cC:fksi:p:" opt "$@"; do
    case "$opt" in
    C)
      check "$OPTARG"
      ;;
    c)
      check
      ;;
    f)
      # Silently ignore -f
      ;;
    k)
      kill_instance
      return
      ;;
    s)
      get_status
      return
      ;;
    i)
      interval="$OPTARG"
      ;;
    p)
      pattern="$OPTARG"
      ;;
    \?)
      return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))
  ensure_not_running
  tmux set-option -g "@$name-pid" $$
  loop
  trap "onexit" EXIT
}

main "$@"
