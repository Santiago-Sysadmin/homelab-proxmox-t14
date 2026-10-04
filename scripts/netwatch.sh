#!/bin/bash
# Registra cambios de estado de la red (solo transiciones) para distinguir cortes de luz, caidas de enlace y fallos del router.
LOG=/var/log/netwatch.log
declare -A STATE
# Ajustar en /etc/default/netwatch: TARGETS="router:IP_ROUTER dns:IP_PIHOLE ha:IP_HA internet:1.1.1.1", NIC y DNS_SERVER
[ -f /etc/default/netwatch ] && . /etc/default/netwatch
TARGETS=${TARGETS:-"internet:1.1.1.1"}
NIC=${NIC:-eth0}
DNS_SERVER=${DNS_SERVER:-1.1.1.1}
CARRIER_PREV=""
DNS_PREV=""
log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >> "$LOG"; }
log "netwatch iniciado (uptime host: $(uptime -p))"
while true; do
    c=$(cat /sys/class/net/$NIC/carrier 2>/dev/null)
    if [ "$c" != "$CARRIER_PREV" ]; then
        [ -n "$CARRIER_PREV" ] && log "$NIC carrier $CARRIER_PREV -> $c"
        CARRIER_PREV=$c
    fi
    for t in $TARGETS; do
        name=${t%%:*}; ip=${t##*:}
        if ping -c 2 -W 1 -i 0.3 -q "$ip" >/dev/null 2>&1; then s=up; else s=down; fi
        if [ "${STATE[$name]}" != "$s" ]; then
            [ -n "${STATE[$name]}" ] && log "$name ($ip) ${STATE[$name]} -> $s"
            STATE[$name]=$s
        fi
    done
    if command -v dig >/dev/null 2>&1; then
        if dig +time=2 +tries=1 +short @$DNS_SERVER cloudflare.com 2>/dev/null | grep -q .; then d=ok; else d=fail; fi
        if [ "$d" != "$DNS_PREV" ]; then
            [ -n "$DNS_PREV" ] && log "dns pihole $DNS_PREV -> $d"
            DNS_PREV=$d
        fi
    fi
    sleep 5
done
