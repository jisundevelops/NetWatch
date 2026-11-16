# NetWatch - Linux Network Connectivity & Monitoring Toolkit

A lightweight Bash toolkit for checking network health from Ubuntu / WSL.
All checks are read-only. No root privileges needed.

## Run
    cd ~/NetWatch
    ./netwatch.sh

## Features
1. Internet connectivity check (distinguishes DNS failure from no connection)
2. Ping and latency test with Good / Moderate / Poor classification
3. DNS health check
4. Local network information (IP, interfaces, gateway)
5. TCP port connectivity check (single port, authorization confirmation for non-local targets)
6. Full network health check with a 0-100 health score
7. TXT report generator (saved in reports/)
8. View latest report

## Structure
    netwatch.sh        main menu
    core/utils.sh      colors, logging, dependency check
    core/report.sh     full check, health score, reports
    modules/           connectivity, ping, dns, network info, port check
    logs/netwatch.log  activity log
    reports/           generated reports
