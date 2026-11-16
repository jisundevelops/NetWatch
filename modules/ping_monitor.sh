#!/usr/bin/env bash
# modules/ping_monitor.sh - Feature 2: Ping & Latency Monitor

PING_COUNT=4
PING_TIMEOUT=2                    # seconds to wait for each reply
PING_DEFAULT_TARGET="8.8.8.8"

# validate_host STRING -> exit 0 if it looks like a valid hostname or IPv4
validate_host() {
    local h="$1"
    [[ ${#h} -ge 1 && ${#h} -le 253 ]] || return 1
    [[ "$h" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || return 1
    [[ "$h" != *..* ]] || return 1
    return 0
}

# classify_quality AVG_MS LOSS_PERCENT -> prints Good, Moderate or Poor
classify_quality() {
    awk -v a="$1" -v l="$2" 'BEGIN {
        if (a < 100 && l < 2)       print "Good";
        else if (a < 200 && l < 10) print "Moderate";
        else                        print "Poor";
    }'
}

# ping_target HOST -> runs the ping and sets PING_* globals (used by reports later)
# Return codes: 0 = replies received, 1 = no replies, 2 = DNS failure
ping_target() {
    local target="$1" output rc loss stats min avg max mdev quality
    PING_TARGET="$target"; PING_AVG=""; PING_LOSS=""; PING_QUALITY=""

    print_info "Pinging ${target} (${PING_COUNT} packets) ..."
    output=$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$target" 2>&1)
    rc=$?

    # Case 1: name could not be resolved
    if grep -qiE 'name or service not known|temporary failure in name resolution|unknown host' <<<"$output"; then
        PING_QUALITY="FAIL"
        print_fail "Cannot resolve '${target}' (DNS failure or invalid domain)"
        log ERROR "Ping ${target}: DNS failure"
        return 2
    fi

    # Extract packet loss number, e.g. "0% packet loss" -> 0
    loss=$(grep -oE '[0-9]+(\.[0-9]+)?% packet loss' <<<"$output" | grep -oE '^[0-9]+(\.[0-9]+)?')
    loss="${loss:-100}"
    PING_LOSS="$loss"

    # Extract "min/avg/max/mdev" numbers from the rtt summary line
    stats=$(grep -E '^(rtt|round-trip)' <<<"$output" | awk -F' = ' '{print $2}' | awk '{print $1}')

    # Case 2: no replies at all
    if [[ -z "$stats" ]]; then
        PING_QUALITY="FAIL"
        print_fail "No replies from ${target} (${loss}% packet loss)"
        print_info "The host may be down, or it may block ICMP ping."
        log ERROR "Ping ${target}: no replies (ping exit code ${rc})"
        return 1
    fi

    # Case 3: replies received
    IFS=/ read -r min avg max mdev <<<"$stats"
    PING_AVG="$avg"
    quality=$(classify_quality "$avg" "$loss")
    PING_QUALITY="$quality"

    printf '  Target      : %s\n' "$target"
    printf '  Min / Max   : %s ms / %s ms\n' "$min" "$max"
    printf '  Average     : %s ms\n' "$avg"
    printf '  Jitter      : %s ms\n' "$mdev"
    printf '  Packet loss : %s%%\n' "$loss"

    case "$quality" in
        Good)     print_pass "Connection quality: ${GREEN}Good${RESET}" ;;
        Moderate) print_warn "Connection quality: ${YELLOW}Moderate${RESET}" ;;
        *)        print_fail "Connection quality: ${RED}Poor${RESET}" ;;
    esac
    print_info "Rule: Good <100ms & <2% loss | Moderate <200ms & <10% loss | else Poor"
    log INFO "Ping ${target}: avg=${avg}ms loss=${loss}% quality=${quality}"
    return 0
}

# run_ping_test -> interactive wrapper used by the menu
run_ping_test() {
    print_header "Ping & Latency Test"
    if ! check_dependencies ping; then
        print_info "Install it with: sudo apt install iputils-ping"
        return 1
    fi

    local target attempts=0
    while true; do
        read -rp "Enter host or IP to ping [${PING_DEFAULT_TARGET}]: " target || return 1
        target="${target:-$PING_DEFAULT_TARGET}"
        if validate_host "$target"; then
            break
        fi
        print_fail "Invalid host '${target}'. Use letters, digits, dots and hyphens only."
        attempts=$((attempts + 1))
        if (( attempts >= 3 )); then
            print_warn "Too many invalid entries. Returning to menu."
            return 1
        fi
    done

    ping_target "$target"
}
