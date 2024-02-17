#!/usr/bin/env bash
# navi.tmux: faster navigation between tmux and vim
# Copyright 2021 Maddison Hellstrom <github.com/b0o>, MIT License.

set -euo pipefail

declare pattern="g?(view|n?vim?x?|ssh)(diff)?"
declare interval="0.5"

declare -A state=()

function usage() {
  cat <<EOF
Usage: navi.tmux [-h] [-f] [-k] [-s] [-i interval] [-p pattern]

Options:
  -h        Show this help message
  -f        Run in the foreground
  -k        Kill the running instance
  -s        Get the status of the running instance
  -i        Set the interval in seconds (default: "0.5")
  -p        Set the pattern to match (default: "$pattern")
EOF
}

function get_instance() {
  local -i instance_pid
  instance_pid="$(tmux show-options -gv "@navi-pid" 2>/dev/null)"
  if [[ "$instance_pid" -gt 0 ]] && ps "$instance_pid" &>/dev/null; then
    echo "$instance_pid"
    return 0
  fi
  return 1
}

function onexit() {
  tmux set-option -gu "@navi-pid" &
}

function kill_instance() {
  local -i instance_pid
  if instance_pid="$(get_instance)"; then
    kill "$instance_pid"
    echo "navi: killed $instance_pid"
    return 0
  fi
  echo "navi: not running"
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
function tick() {
  local panes procs
  panes="$(tmux list-panes -aF "#{pane_id}:#{pane_tty}")"
  procs="$(ps a -ostate=,tty=,comm=)"
  while read -r pane; do
    local pane_id tty
    pane_id="${pane%%:*}"
    tty="${pane#*:}"
    tty="${tty#/dev/}"
    if [[ -z "$tty" ]]; then
      continue
    fi
    local -i val
    if grep -iqE "^[^TXZ ]+ ${tty} +(\S+/)?${pattern}\$" <<<"$procs"; then
      val=1
    else
      val=0
    fi
    if [[ -z "${state["$pane_id"]:-}" || "${state["$pane_id"]}" -ne "$val" ]]; then
      state["$pane_id"]=$val
      echo tmux set-option -p -t "$pane_id" "@navi-state" "$val"
      tmux set-option -p -t "$pane_id" "@navi-state" "$val"
    fi
  done <<<"$panes"
}

function loop() {
  while true; do
    tick
    sleep "$interval"
  done
}

function main() {
  if ! [[ "${1:-}" =~ ^-[hfks]$ ]]; then
    if get_instance &>/dev/null; then
      exit 0
    fi
    "${BASH_SOURCE[0]}" -f "$@" &>/dev/null &
    disown
    exit 0
  fi
  local opt OPTARG
  local -i OPTIND
  while getopts ":hfksi:p:" opt "$@"; do
    case "$opt" in
    h)
      usage
      return
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
  if get_instance &>/dev/null; then
    return 1
  fi
  tmux set-option -g "@navi-pid" $$
  loop
  trap "onexit" EXIT
}

main "$@"
