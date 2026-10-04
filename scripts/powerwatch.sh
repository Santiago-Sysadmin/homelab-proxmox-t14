#!/bin/bash
[ -f /etc/default/powerwatch ] && . /etc/default/powerwatch
THRESHOLD=${THRESHOLD:-12}
POWER_DIR=${POWER_DIR:-/sys/class/power_supply}
DRYRUN=${DRYRUN:-0}
LOG=${LOG:-/var/log/netwatch.log}
WEBHOOK_FILE=${WEBHOOK_FILE:-/etc/homelab/webhook-id}   # el id del webhook es un secreto: fichero con permisos 600
HA_URL=${HA_URL:-http://HOME_ASSISTANT_HOST:8123}
log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >> "$LOG"; }

# Cuando vuelve la luz: espera a que haya internet y avisa a Home Assistant (webhook -> Telegram).
notify_cut() { # inicio_epoch fin_epoch bateria
  local s=$1 e=$2 cap=$3 t0 now dur j code try
  [ -s "$WEBHOOK_FILE" ] || return 0
  t0=$(date +%s)
  until ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; do
    if [ $(( $(date +%s) - t0 )) -gt 900 ]; then log "aviso Telegram: sin internet tras 15 min, no enviado"; return 0; fi
    sleep 10
  done
  sleep 20
  now=$(date +%s); dur=$(( e - s ))
  j=$(printf '{"fecha":"%s","inicio":"%s","fin":"%s","duracion":"%d min %02d s","internet":"%s","bateria":"%s"}' \
      "$(date -d @$s '+%d/%m/%Y')" "$(date -d @$s '+%H:%M:%S')" "$(date -d @$e '+%H:%M:%S')" $((dur/60)) $((dur%60)) "$(date -d @$now '+%H:%M:%S')" "${cap:-?}")
  for try in 1 2 3; do
    code=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d "$j" "$HA_URL/api/webhook/$(cat "$WEBHOOK_FILE")")
    log "aviso Telegram: intento $try HTTP $code"
    [ "$code" = "200" ] && return 0
    sleep 30
  done
}

ac_prev=""; last_batlog=0; cut_start=""
log "powerwatch iniciado (umbral ${THRESHOLD}%, dryrun=${DRYRUN})"
while true; do
    ac=$(cat "$POWER_DIR"/AC/online 2>/dev/null)
    cap=$(cat "$POWER_DIR"/BAT0/capacity 2>/dev/null)
    if [ -n "$ac" ] && [ "$ac" != "$ac_prev" ]; then
        [ -n "$ac_prev" ] && log "alimentacion: AC online $ac_prev -> $ac (bateria ${cap:-?}%)"
        if [ "$ac" = "0" ]; then cut_start=$(date +%s); fi
        if [ "$ac" = "1" ] && [ -n "$cut_start" ]; then
            ( notify_cut "$cut_start" "$(date +%s)" "$cap" ) &
            cut_start=""
        fi
        ac_prev=$ac; last_batlog=0
    fi
    if [ "$ac" = "0" ]; then
        now=$(date +%s)
        if [ $((now - last_batlog)) -ge 300 ]; then log "en bateria: ${cap:-?}%"; last_batlog=$now; fi
        if [ -n "$cap" ] && [ "$cap" -le "$THRESHOLD" ]; then
            log "BATERIA CRITICA ${cap}% <= ${THRESHOLD}% sin AC: apagado ordenado"
            sync
            if [ "$DRYRUN" = "1" ]; then log "DRYRUN: no se apaga"; sleep 60; continue; fi
            systemctl poweroff
            sleep 300
        fi
    fi
    sleep "${INTERVAL:-15}"
done
