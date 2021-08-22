#!/usr/bin/env bash

# Watches your tmux configuration file and automatically reloads it on change.
# Add the following line at the end of your tmux configuration file:
# run-shell "/path/to/autoreload.sh"
#
# Copyright 2021 Maddison Hellstrom <github.com/b0o>, MIT License.

set -euo pipefail

# Fork and exit
if [[ "${1:-}" != "-f" ]]; then
  "$0" -f &> /dev/null &
  disown
  exit 0
fi

tmux_autoreload_pid="$(tmux show-options -gv @tmux-autoreload-pid)"
if [[ -n "$tmux_autoreload_pid" ]] && ps "$tmux_autoreload_pid" &> /dev/null; then
  exit 0
fi

mapfile -t config_files < <(tmux display-message -p "#{config_files}")

function onexit() {
  local -i code=$?
  {
    if [[ $code -ne 0 ]]; then
      tmux display-message "tmux-autoreload exited with code $code"
      # XXX: `tmux display-message -c` is broken in v3.2a
      # https://github.com/tmux/tmux/issues/2737#issuecomment-898861216
      # while read -r client; do
      #   echo tmux display-message -c "$client" "tmux-autoreload exited with code $code"
      # done < <(tmux list-clients -F '#{client_name}')
    fi
    kill "$entr_pid"
    tmux set-option -gu @tmux-autoreload-pid
  } || true
}

trap 'onexit' EXIT
tmux set-option -g @tmux-autoreload-pid $$

entr -np tmux source "${config_files[@]}" ';' display-message "Reloaded tmux.conf" 2>&1 <<< "${config_files[@]}" &
entr_pid=$!
wait
