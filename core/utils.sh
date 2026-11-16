#!/usr/bin/env bash
# core/utils.sh - colors, logging, helpers shared by all modules

# Use colors only when output goes to a terminal
if [[ -t 1 ]]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
    BLUE=$'\e[34m'; CYAN=$'\e[36m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; RESET=""
fi

LOG_FILE="${NETWATCH_HOME}/logs/netwatch.log"

# log LEVEL message...  -> appends a timestamped line to the log file
log() {
    local level="$1"; shift
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG_FILE"
}

print_pass() { printf '%s[ PASS ]%s %s\n' "$GREEN"  "$RESET" "$*"; }
print_fail() { printf '%s[ FAIL ]%s %s\n' "$RED"    "$RESET" "$*"; }
print_warn() { printf '%s[ WARN ]%s %s\n' "$YELLOW" "$RESET" "$*"; }
print_info() { printf '%s[ INFO ]%s %s\n' "$CYAN"   "$RESET" "$*"; }

print_header() {
    printf '\n%s%s=== %s ===%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
}

# check_dependencies cmd1 cmd2 ... -> returns 1 if any command is missing
check_dependencies() {
    local missing=() cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        print_fail "Missing required commands: ${missing[*]}"
        log ERROR "Missing commands: ${missing[*]}"
        return 1
    fi
    return 0
}

pause() {
    read -rp "Press Enter to return to the menu..." _ || true
}
