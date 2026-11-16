#!/usr/bin/env bash
# modules/network_info.sh - Feature 4: Local Network Information

# First global IPv4 address, e.g. 172.20.1.5
get_local_ip() {
    ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1
}

# Default gateway IP from the routing table
get_gateway() {
    ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}'
}

show_network_info() {
    print_header "Local Network Information"
    LOCAL_IP="N/A"; GATEWAY="N/A"

    if ! check_dependencies ip; then
        print_info "Install it with: sudo apt install iproute2"
        return 1
    fi

    local ip_addr gw active
    ip_addr="$(get_local_ip)"
    gw="$(get_gateway)"

    printf '  Hostname        : %s\n' "${HOSTNAME:-unknown}"

    if [[ -n "$ip_addr" ]]; then
        LOCAL_IP="$ip_addr"
        printf '  Local IP        : %s\n' "$LOCAL_IP"
    else
        print_warn "No active IPv4 address found"
    fi

    if [[ -n "$gw" ]]; then
        GATEWAY="$gw"
        printf '  Default gateway : %s\n' "$GATEWAY"
    else
        print_warn "No default gateway found"
    fi

    active=$(ip -brief address show 2>/dev/null | awk '$2 == "UP"' | wc -l)
    printf '  Active ifaces   : %s\n\n' "$active"

    printf '  %-14s %-10s %s\n' "INTERFACE" "STATE" "ADDRESSES"
    ip -brief address show 2>/dev/null \
        | sed 's/@[^ ]*//' \
        | awk '{ addr = $3; for (i = 4; i <= NF; i++) addr = addr ", " $i;
                 printf "  %-14s %-10s %s\n", $1, $2, addr }'

    log INFO "Network info: ip=${LOCAL_IP} gateway=${GATEWAY} active_interfaces=${active}"
    return 0
}
