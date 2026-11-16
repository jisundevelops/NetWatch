#!/usr/bin/env bash
# modules/connectivity.sh - Feature 1: Internet Connectivity Check

CONNECT_IP_TARGETS=("1.1.1.1" "8.8.8.8")   # raw IPs: tests connectivity without DNS
CONNECT_DNS_DOMAIN="example.com"           # used to test DNS separately
CONNECT_TIMEOUT=3

# tcp_probe HOST PORT -> exit 0 if a TCP connection opens within the timeout.
# Host and port are passed as arguments ($0, $1), never pasted into the string.
tcp_probe() {
    timeout "$CONNECT_TIMEOUT" bash -c 'exec 3<>/dev/tcp/$0/$1' "$1" "$2" 2>/dev/null
}

# Return codes: 0 = PASS, 1 = FAIL (no connectivity), 2 = DNS failure
# Also sets CONNECTIVITY_STATUS for the report module later.
run_connectivity_check() {
    print_header "Internet Connectivity Check"
    local ip reachable_ip=""

    for ip in "${CONNECT_IP_TARGETS[@]}"; do
        print_info "Testing raw connection to ${ip}:443 ..."
        if tcp_probe "$ip" 443; then
            print_pass "Reached ${ip}:443"
            reachable_ip="$ip"
            break
        else
            print_fail "Could not reach ${ip}:443"
        fi
    done

    if [[ -z "$reachable_ip" ]]; then
        CONNECTIVITY_STATUS="FAIL"
        print_fail "Internet connectivity: FAIL (no external IP reachable)"
        print_info "Check Wi-Fi/cable, your router, or the WSL network."
        log ERROR "Connectivity check: FAIL"
        return 1
    fi

    print_info "Testing DNS resolution for ${CONNECT_DNS_DOMAIN} ..."
    if getent hosts "$CONNECT_DNS_DOMAIN" >/dev/null 2>&1; then
        CONNECTIVITY_STATUS="PASS"
        print_pass "DNS resolution works"
        print_pass "Internet connectivity: PASS"
        log INFO "Connectivity check: PASS (via ${reachable_ip})"
        return 0
    fi

    CONNECTIVITY_STATUS="DNS_FAIL"
    print_warn "Internet is reachable by IP, but DNS resolution FAILED"
    print_info "Likely a DNS server problem, not a general connection problem."
    log WARN "Connectivity check: DNS failure (IP reachable via ${reachable_ip})"
    return 2
}
