#!/usr/bin/env bash
# core/report.sh - Feature 6: full check, health score, report generator

REPORT_DIR="${NETWATCH_HOME}/reports"
HEALTH_SCORE=""; HEALTH_STATUS=""

# status_text CODE -> readable text
status_text() {
    case "$1" in
        PASS)     echo "PASS" ;;
        DNS_FAIL) echo "PARTIAL (DNS failure)" ;;
        FAIL)     echo "FAIL" ;;
        *)        echo "NOT TESTED" ;;
    esac
}

# status_color CODE -> prints the ANSI color for that status
status_color() {
    case "$1" in
        PASS|Good|HEALTHY)           printf '%s' "$GREEN" ;;
        Moderate|DEGRADED|DNS_FAIL)  printf '%s' "$YELLOW" ;;
        *)                           printf '%s' "$RED" ;;
    esac
}

# compute_health -> sets HEALTH_SCORE (0-100) and HEALTH_STATUS
# Internet 40 (DNS failure = 20) + DNS 20 + Ping 25 (Moderate = 15) + Ports 15
compute_health() {
    local score=0 open=0 total=${#PORT_RESULTS[@]} entry

    case "$CONNECTIVITY_STATUS" in
        PASS)     score=$((score + 40)) ;;
        DNS_FAIL) score=$((score + 20)) ;;
    esac

    [[ "$DNS_STATUS" == "PASS" ]] && score=$((score + 20))

    case "$PING_QUALITY" in
        Good)     score=$((score + 25)) ;;
        Moderate) score=$((score + 15)) ;;
    esac

    for entry in "${PORT_RESULTS[@]}"; do
        [[ "$entry" == *"= OPEN" ]] && open=$((open + 1))
    done
    if (( total == 0 )); then
        score=$((score + 15))
    else
        score=$((score + 15 * open / total))
    fi

    HEALTH_SCORE="$score"
    if   (( score >= 80 )); then HEALTH_STATUS="HEALTHY"
    elif (( score >= 50 )); then HEALTH_STATUS="DEGRADED"
    else                         HEALTH_STATUS="CRITICAL"
    fi
}

print_summary() {
    compute_health
    local ping_line="N/A"
    [[ -n "$PING_AVG" ]] && ping_line="${PING_AVG} ms (${PING_QUALITY}), loss ${PING_LOSS}%"
    [[ -z "$PING_AVG" && -n "$PING_LOSS" ]] && ping_line="no replies, loss ${PING_LOSS}%"

    print_header "Network Health Summary"
    printf '  Internet      : %s%s%s\n' "$(status_color "$CONNECTIVITY_STATUS")" "$(status_text "$CONNECTIVITY_STATUS")" "$RESET"
    printf '  DNS           : %s%s%s\n' "$(status_color "$DNS_STATUS")" "$(status_text "$DNS_STATUS")" "$RESET"
    printf '  Ping          : %s\n' "$ping_line"
    printf '  Local IP      : %s\n' "${LOCAL_IP:-N/A}"
    printf '  Ports checked : %s\n' "${#PORT_RESULTS[@]}"
    printf '  %sOVERALL HEALTH: %s (%s/100)%s\n' "$(status_color "$HEALTH_STATUS")$BOLD" "$HEALTH_STATUS" "$HEALTH_SCORE" "$RESET"
}

# run_full_check -> runs every check in order and prints the summary
run_full_check() {
    local entry
    CONNECTIVITY_STATUS=""; DNS_STATUS=""; DNS_IP=""; DNS_DOMAIN=""; DNS_TIME_MS=""
    PING_TARGET=""; PING_AVG=""; PING_LOSS=""; PING_QUALITY=""
    LOCAL_IP=""; GATEWAY=""
    PORT_RESULTS=()

    print_header "Full Network Health Check"
    log INFO "Full health check started"

    run_connectivity_check

    print_header "Ping & Latency"
    if check_dependencies ping; then
        ping_target "$PING_DEFAULT_TARGET"
    else
        print_info "Install it with: sudo apt install iputils-ping"
    fi

    print_header "DNS Health"
    dns_check_domain "$DNS_DEFAULT_DOMAIN"

    show_network_info

    print_header "Port Connectivity"
    for entry in "${FULL_CHECK_PORTS[@]}"; do
        check_port "${entry%%:*}" "${entry##*:}"
    done

    print_summary
    log INFO "Full health check finished: ${HEALTH_STATUS} (${HEALTH_SCORE}/100)"
}

# write_report -> saves a TXT report in reports/
write_report() {
    local file entry
    file="${REPORT_DIR}/netwatch_report_$(date '+%Y%m%d_%H%M%S').txt"

    if ! mkdir -p "$REPORT_DIR"; then
        print_fail "Cannot create reports directory: ${REPORT_DIR}"
        return 1
    fi
    compute_health

    {
        echo "========================================"
        echo "  NETWATCH - Network Health Report"
        echo "  Linux Network Monitoring Toolkit"
        echo "========================================"
        echo "Project       : NetWatch"
        echo "Date and time : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Hostname      : ${HOSTNAME:-unknown}"
        echo "Local IP      : ${LOCAL_IP:-N/A}"
        echo "Gateway       : ${GATEWAY:-N/A}"
        echo
        echo "--- Checks ---"
        echo "Internet connectivity : $(status_text "$CONNECTIVITY_STATUS")"
        if [[ "$DNS_STATUS" == "PASS" ]]; then
            echo "DNS status            : PASS (${DNS_DOMAIN} -> ${DNS_IP}, ${DNS_TIME_MS} ms)"
        else
            echo "DNS status            : $(status_text "$DNS_STATUS")"
        fi
        echo "Ping target           : ${PING_TARGET:-N/A}"
        echo "Ping latency (avg)    : ${PING_AVG:-N/A} ms"
        echo "Packet loss           : ${PING_LOSS:-N/A} %"
        echo "Connection quality    : ${PING_QUALITY:-N/A}"
        echo
        echo "--- Port connectivity ---"
        if (( ${#PORT_RESULTS[@]} == 0 )); then
            echo "  (no port checks were run)"
        else
            for entry in "${PORT_RESULTS[@]}"; do
                echo "  - ${entry}"
            done
        fi
        echo
        echo "--- Overall network health ---"
        echo "Status : ${HEALTH_STATUS}"
        echo "Score  : ${HEALTH_SCORE}/100"
        echo
        echo "--- Log summary (entries by level) ---"
        if [[ -s "$LOG_FILE" ]]; then
            awk '{print $3}' "$LOG_FILE" | sort | uniq -c | sort -rn | sed 's/^ */  /'
        else
            echo "  (log is empty)"
        fi
        echo
        echo "Scoring: Internet 40 (DNS failure 20) + DNS 20 + Ping 25 (Moderate 15) + Ports 15."
        echo "HEALTHY >= 80, DEGRADED >= 50, CRITICAL < 50."
    } > "$file" || {
        print_fail "Could not write report file: ${file}"
        log ERROR "Report write failed: ${file}"
        return 1
    }

    print_pass "Report saved: ${file}"
    log INFO "Report saved: ${file}"
    return 0
}

# offer_save_report -> asks the user after a full check
offer_save_report() {
    local ans
    read -rp "Save this result as a report? [y/N]: " ans || return 1
    case "$ans" in
        [Yy]*) write_report ;;
        *)     print_info "Report not saved." ;;
    esac
}

# view_latest_report -> shows the newest report file
view_latest_report() {
    print_header "Latest Report"
    local latest
    latest=$(ls -1t "$REPORT_DIR"/netwatch_report_*.txt 2>/dev/null | head -n1)
    if [[ -z "$latest" ]]; then
        print_warn "No reports found yet. Use option 7 to generate one."
        return 1
    fi
    print_info "File: ${latest}"
    echo
    cat "$latest"
}
