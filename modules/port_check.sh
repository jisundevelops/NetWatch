#!/usr/bin/env bash
# modules/port_check.sh - Feature 5: TCP Port Connectivity Checker
# Checks ONE port at a time. No port range scanning.

PORT_RESULTS=()                                   # filled by check_port, used by the report
FULL_CHECK_PORTS=("example.com:80" "example.com:443")   # IANA test domain, safe for demos

# is_ipv4 STRING -> 0 if a valid dotted IPv4 address (each octet 0-255)
is_ipv4() {
    local ip="$1" o
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    local IFS=.
    for o in $ip; do
        (( 10#$o <= 255 )) || return 1
    done
    return 0
}

# validate_port STRING -> 0 if integer between 1 and 65535
validate_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]{1,5}$ ]] || return 1
    (( 10#$p >= 1 && 10#$p <= 65535 ))
}

# is_local_target HOST -> 0 for localhost / loopback / private LAN addresses
is_local_target() {
    local t="$1"
    [[ "$t" == "localhost" ]] && return 0
    is_ipv4 "$t" || return 1
    [[ "$t" =~ ^127\. ]] && return 0
    [[ "$t" =~ ^10\. ]] && return 0
    [[ "$t" =~ ^192\.168\. ]] && return 0
    [[ "$t" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] && return 0
    return 1
}

# check_port HOST PORT -> returns 0 if open, 1 closed/timeout, 2 DNS failure
check_port() {
    local host="$1" port="$2" rc

    if ! is_ipv4 "$host" && [[ "$host" != "localhost" ]]; then
        if ! resolve_domain "$host"; then
            print_fail "Cannot resolve '${host}' - port check skipped (DNS failure)"
            PORT_RESULTS+=("${host}:${port} = DNS FAILURE")
            log ERROR "Port check ${host}:${port}: DNS failure"
            return 2
        fi
    fi

    print_info "Testing TCP ${host}:${port} ..."
    tcp_probe "$host" "$port"
    rc=$?

    case "$rc" in
        0)
            print_pass "Port ${port} on ${host} is OPEN"
            PORT_RESULTS+=("${host}:${port} = OPEN")
            log INFO "Port ${host}:${port} OPEN"
            return 0 ;;
        124)
            print_warn "Port ${port} on ${host}: TIMEOUT (filtered by a firewall, or host is down)"
            PORT_RESULTS+=("${host}:${port} = TIMEOUT")
            log WARN "Port ${host}:${port} TIMEOUT"
            return 1 ;;
        *)
            print_fail "Port ${port} on ${host} is CLOSED (connection refused)"
            PORT_RESULTS+=("${host}:${port} = CLOSED")
            log WARN "Port ${host}:${port} CLOSED"
            return 1 ;;
    esac
}

# run_port_check -> interactive wrapper used by the menu
run_port_check() {
    print_header "TCP Port Connectivity Check"
    local host port answer

    read -rp "Enter target host or IP [localhost]: " host || return 1
    host="${host:-localhost}"
    if ! validate_host "$host"; then
        print_fail "Invalid host '${host}'."
        return 1
    fi

    read -rp "Enter TCP port (1-65535): " port || return 1
    if ! validate_port "$port"; then
        print_fail "Invalid port '${port}'. Enter a whole number from 1 to 65535."
        return 1
    fi
    port=$((10#$port))

    if ! is_local_target "$host"; then
        print_warn "'${host}' is not a local or private address."
        print_info "Only test systems that you own or have permission to test."
        read -rp "Type YES to confirm you are authorized: " answer || return 1
        if [[ "$answer" != "YES" ]]; then
            print_warn "Cancelled. No connection was made."
            log WARN "Port check on ${host}:${port} cancelled (no authorization confirmation)"
            return 1
        fi
    fi

    check_port "$host" "$port"
}
