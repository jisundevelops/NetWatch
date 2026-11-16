#!/usr/bin/env bash
# modules/dns_checker.sh - Feature 3: DNS Health Checker

DNS_DEFAULT_DOMAIN="google.com"

# resolve_domain DOMAIN -> sets DNS_IP, returns 0 on success, 1 on failure
resolve_domain() {
    local domain="$1" ip
    DNS_IP=""
    ip=$(getent ahostsv4 "$domain" 2>/dev/null | awk 'NR==1 {print $1}')
    [[ -n "$ip" ]] || return 1
    DNS_IP="$ip"
    return 0
}

# dns_check_domain DOMAIN -> non-interactive check, sets DNS_STATUS / DNS_TIME_MS
dns_check_domain() {
    local domain="$1" start end elapsed_ms servers
    DNS_STATUS=""; DNS_TIME_MS=""; DNS_DOMAIN="$domain"

    servers=$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    if [[ -n "$servers" ]]; then
        print_info "DNS server(s): ${servers}"
    else
        print_warn "No nameserver found in /etc/resolv.conf"
    fi

    print_info "Resolving ${domain} ..."
    start=$(date +%s%N)
    if resolve_domain "$domain"; then
        end=$(date +%s%N)
        elapsed_ms=$(( (end - start) / 1000000 ))
        DNS_STATUS="PASS"
        DNS_TIME_MS="$elapsed_ms"
        print_pass "${domain} -> ${DNS_IP} (${elapsed_ms} ms)"
        if (( elapsed_ms > 500 )); then
            print_warn "DNS response is slow (over 500 ms)"
        fi
        log INFO "DNS ${domain} -> ${DNS_IP} in ${elapsed_ms}ms"
        return 0
    fi

    DNS_STATUS="FAIL"
    print_fail "Could not resolve ${domain}"
    print_info "Check the domain spelling or your DNS server settings."
    log ERROR "DNS check failed for ${domain}"
    return 1
}

# run_dns_check -> interactive wrapper used by the menu
run_dns_check() {
    print_header "DNS Health Check"
    local domain attempts=0
    while true; do
        read -rp "Enter domain to resolve [${DNS_DEFAULT_DOMAIN}]: " domain || return 1
        domain="${domain:-$DNS_DEFAULT_DOMAIN}"
        if validate_host "$domain"; then
            break
        fi
        print_fail "Invalid domain '${domain}'."
        attempts=$((attempts + 1))
        if (( attempts >= 3 )); then
            print_warn "Too many invalid entries. Returning to menu."
            return 1
        fi
    done
    dns_check_domain "$domain"
}
