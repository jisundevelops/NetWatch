#!/usr/bin/env bash
# netwatch.sh - NetWatch: Linux Network Connectivity & Monitoring Toolkit

NETWATCH_VERSION="1.0"
NETWATCH_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWATCH_HOME
mkdir -p "$NETWATCH_HOME/logs" "$NETWATCH_HOME/reports"

# shellcheck source=/dev/null
source "$NETWATCH_HOME/core/utils.sh"
source "$NETWATCH_HOME/modules/connectivity.sh"
source "$NETWATCH_HOME/modules/ping_monitor.sh"
source "$NETWATCH_HOME/modules/dns_checker.sh"
source "$NETWATCH_HOME/modules/network_info.sh"
source "$NETWATCH_HOME/modules/port_check.sh"
source "$NETWATCH_HOME/core/report.sh"

show_menu() {
    clear
    printf '%s%s========================================%s\n' "$BOLD" "$CYAN" "$RESET"
    printf '%s%s             NETWATCH%s\n' "$BOLD" "$GREEN" "$RESET"
    printf '%s Linux Network Monitoring Toolkit%s\n' "$CYAN" "$RESET"
    printf '%s%s========================================%s\n\n' "$BOLD" "$CYAN" "$RESET"
    printf ' %s[1]%s Check Internet Connectivity\n'      "$YELLOW" "$RESET"
    printf ' %s[2]%s Ping & Latency Test\n'              "$YELLOW" "$RESET"
    printf ' %s[3]%s DNS Health Check\n'                 "$YELLOW" "$RESET"
    printf ' %s[4]%s Show Local Network Information\n'   "$YELLOW" "$RESET"
    printf ' %s[5]%s TCP Port Connectivity Check\n'      "$YELLOW" "$RESET"
    printf ' %s[6]%s Full Network Health Check\n'        "$YELLOW" "$RESET"
    printf ' %s[7]%s Generate Network Report\n'          "$YELLOW" "$RESET"
    printf ' %s[8]%s View Latest Report\n'               "$YELLOW" "$RESET"
    printf ' %s[0]%s Exit\n\n'                           "$RED"    "$RESET"
}

main() {
    if ! check_dependencies timeout getent date awk sed grep sort uniq cut head tr ls cat wc; then
        echo "Install the missing commands and run NetWatch again."
        exit 1
    fi
    log INFO "NetWatch started (version ${NETWATCH_VERSION})"

    local choice
    while true; do
        show_menu
        read -rp "Select an option: " choice || break   # Ctrl+D exits cleanly
        case "$choice" in
            1) run_connectivity_check; pause ;;
            2) run_ping_test; pause ;;
            3) run_dns_check; pause ;;
            4) show_network_info; pause ;;
            5) run_port_check; pause ;;
            6) run_full_check; offer_save_report; pause ;;
            7) run_full_check; write_report; pause ;;
            8) view_latest_report; pause ;;
            0)
                log INFO "NetWatch exited by user"
                printf '%sGoodbye!%s\n' "$GREEN" "$RESET"
                break ;;
            *)
                print_fail "Invalid option '${choice}'. Enter a number from 0 to 8."
                sleep 1 ;;
        esac
    done
}

main "$@"
