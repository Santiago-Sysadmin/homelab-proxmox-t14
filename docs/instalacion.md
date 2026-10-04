# Cómo adaptar y desplegar los scripts

Los scripts de [`scripts/`](../scripts) y las unidades de [`systemd/`](../systemd) son los que ejecuta el servidor. Se han saneado: no contienen IPs ni secretos, sino marcadores de posición y lectura de ficheros de configuración locales.

## Requisitos

- Proxmox VE 9 (Debian 13) con acceso `root`.
- Para las copias: un disco montado (aquí en `/mnt/backup`), `restic` y `sshfs`.
- Para los sensores y avisos: Home Assistant con un token de larga duración y un webhook propio.
- Utilidades: `bash`, `python3`, `curl`, `dig` (paquete `dnsutils`), `sqlite3`.

## Ficheros de configuración locales (no se suben al repositorio)

| Fichero | Contenido | Usado por |
|---|---|---|
| `/etc/default/ha-sensors` | `HA_URL`, `TOKEN_FILE` | `ha-sensors.sh` |
| `/etc/default/photos-backup` | `VM_HOST`, `VM_USER`, `SSH_KEY` | `photos-backup.sh` |
| `/etc/default/netwatch` | `TARGETS`, `NIC`, `DNS_SERVER` | `netwatch.sh` |
| `/etc/default/powerwatch` | `THRESHOLD`, `HA_URL`, `WEBHOOK_FILE` | `powerwatch.sh` |
| `/etc/homelab/ha-token` | Token de Home Assistant (permisos `600`) | `ha-sensors.sh` |
| `/etc/homelab/webhook-id` | Identificador del webhook (permisos `600`) | `powerwatch.sh` |
| `/etc/homelab/restic-password` | Contraseña del repositorio restic (permisos `600`) | `photos-backup.sh` |

Crear la carpeta de secretos con permisos restrictivos:

```bash
install -d -m 700 /etc/homelab
install -m 600 /dev/null /etc/homelab/ha-token
```

## Despliegue

```bash
# Scripts
install -m 755 scripts/*.sh /usr/local/sbin/

# Unidades
install -m 644 systemd/* /etc/systemd/system/
systemctl daemon-reload

# Servicios y temporizadores
systemctl enable --now powerwatch.service netwatch.service
systemctl enable --now cfg-backup.timer photos-backup.timer ha-sensors.timer
```

Antes de activarlo, probar cada script a mano y revisar la salida:

```bash
/usr/local/sbin/cfg-backup.sh
systemctl start photos-backup.service && journalctl -u photos-backup -n 20 --no-pager
```

## Notas por script

- **`powerwatch.sh`**: se puede probar sin apagar el servidor con `DRYRUN=1`.
- **`ha-sensors.sh`**: si no existe el fichero de token, termina sin hacer nada.
- **`photos-backup.sh`**: monta la carpeta de fotos de la VM por `sshfs` en solo lectura; el usuario de la VM necesita permiso `sudo` para el servidor SFTP.
- **`cfg-backup.sh`**: conserva las 8 últimas copias; ajustar la ruta de destino si el disco de copias se monta en otro sitio.

## Calidad

Los scripts se analizan automáticamente con ShellCheck en cada cambio ([`.github/workflows/shellcheck.yml`](../.github/workflows/shellcheck.yml)).
