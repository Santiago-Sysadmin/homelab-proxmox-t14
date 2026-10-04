#!/bin/bash
set -u
DEST=/mnt/backup/config-backups
mountpoint -q /mnt/backup || { echo "disco de copias no montado"; exit 1; }
TS=$(date +%Y%m%d-%H%M%S)
WORK=$(mktemp -d)
mkdir -p "$WORK/cfg" "$WORK/guests"
cp -a /etc/network/interfaces /etc/hosts /etc/hostname /etc/fstab "$WORK/cfg/" 2>/dev/null
cp -a /etc/default/powerwatch /usr/local/sbin/netwatch.sh /usr/local/sbin/powerwatch.sh "$WORK/cfg/" 2>/dev/null
cp -a /etc/systemd/system/netwatch.service /etc/systemd/system/powerwatch.service /etc/systemd/system/cfg-backup.* "$WORK/cfg/" 2>/dev/null
# Proxmox Backup Server, TLP, consola, SSH y fail2ban (ajustes de 2026-10-03)
mkdir -p "$WORK/cfg/etc"
for f in /etc/proxmox-backup /etc/tlp.conf /etc/tlp.d /etc/systemd/system/console-blank.service /usr/local/sbin/ha-sensors.sh /etc/systemd/system/ha-sensors.service /etc/systemd/system/ha-sensors.timer /etc/systemd/logind.conf /etc/sysctl.d; do [ -e "$f" ] && cp -a --parents "$f" "$WORK/cfg/etc/" 2>/dev/null; done
# Base de datos de configuracion de Proxmox (consistente, via sqlite3 si esta; si no, copia directa)
if command -v sqlite3 >/dev/null; then sqlite3 /var/lib/pve-cluster/config.db ".backup $WORK/cfg/pve-config.db"; else cp -a /var/lib/pve-cluster/config.db "$WORK/cfg/pve-config.db"; fi
pveversion -v > "$WORK/cfg/pveversion.txt" 2>&1
lsblk -f > "$WORK/cfg/lsblk.txt" 2>&1
pvesm status > "$WORK/cfg/pvesm-status.txt" 2>&1
for id in $(qm list 2>/dev/null | awk 'NR>1{print $1}'); do qm config "$id" > "$WORK/guests/vm-$id.conf" 2>&1; done
for id in $(pct list 2>/dev/null | awk 'NR>1{print $1}'); do pct config "$id" > "$WORK/guests/ct-$id.conf" 2>&1; done
# Exportacion del Pi-hole (Teleporter: listas, DHCP, DNS, reservas)
F=$(pct exec 101 -- sh -c 'cd /tmp && rm -f pi-hole*teleporter*.zip; pihole-FTL --teleporter >/dev/null 2>&1; ls -1 /tmp/pi-hole*teleporter*.zip 2>/dev/null | head -1')
if [ -n "$F" ]; then pct pull 101 "$F" "$WORK/pihole-teleporter.zip" && pct exec 101 -- rm -f "$F"; else echo "aviso: no se pudo exportar el Teleporter del Pi-hole"; fi
tar czf "$DEST/config-$TS.tar.gz" -C "$WORK" .
chmod 600 "$DEST/config-$TS.tar.gz"
# Retencion: las 8 ultimas
ls -1t "$DEST"/config-*.tar.gz 2>/dev/null | tail -n +9 | xargs -r rm -f
rm -rf "$WORK"
echo "copia de configuracion creada: $DEST/config-$TS.tar.gz ($(du -h "$DEST/config-$TS.tar.gz" | cut -f1))"
