TX_ROOT="${TX_ROOT:-$PWD}"
window_root "$TX_ROOT"

new_window "$(basename "$TX_ROOT")"

split_h 92

run_cmd "twff" 1
