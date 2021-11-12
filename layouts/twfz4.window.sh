TX_ROOT="${TX_ROOT:-$PWD}"
window_root "$TX_ROOT"

new_window "$(basename "$TX_ROOT")"

split_h 92
split_h 50
split_v 20
select_pane 2
split_v 20
select_pane 2

run_cmd "twff" 1
