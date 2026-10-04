#!/bin/bash
# Publica sensores del Proxmox (t14) en Home Assistant con la API REST (/api/states).
# Los lanza ha-sensors.timer cada 2 minutos. Los estados no sobreviven a un reinicio de HA:
# se vuelven a publicar solos en el siguiente ciclo. Usa un token de larga duración leído de un fichero (no lo imprime).
# Valores de ejemplo: ajustar en /etc/default/ha-sensors (el token vive en un fichero con permisos 600, fuera del repo).
[ -f /etc/default/ha-sensors ] && . /etc/default/ha-sensors
HA_URL=${HA_URL:-http://HOME_ASSISTANT_HOST:8123}
TOKEN_FILE=${TOKEN_FILE:-/etc/homelab/ha-token}
[ -s "$TOKEN_FILE" ] || exit 0
exec python3 - "$HA_URL" "$TOKEN_FILE" <<'PY'
import glob, json, os, shutil, subprocess, sys, time, urllib.request

url, token_file = sys.argv[1], sys.argv[2]
token = open(token_file).read().strip()

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        return ""

def push(entity, state, **attrs):
    body = json.dumps({"state": str(state), "attributes": attrs}).encode()
    req = urllib.request.Request(f"{url}/api/states/{entity}", data=body, method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=10).read()
    except Exception as e:
        print("error", entity, e, file=sys.stderr)

def num(path):
    try:
        return float(open(path).read().strip())
    except Exception:
        return None

# Temperaturas (CPU Ryzen = k10temp, disco = nvme)
temps = {}
for d in glob.glob("/sys/class/hwmon/hwmon*"):
    name = (open(d + "/name").read().strip() if os.path.exists(d + "/name") else "")
    t = num(d + "/temp1_input")
    if t is not None and name in ("k10temp", "nvme"):
        temps[name] = round(t / 1000, 1)
if "k10temp" in temps:
    push("sensor.servidor_temperatura_cpu", temps["k10temp"], friendly_name="Servidor temperatura procesador",
         unit_of_measurement="°C", device_class="temperature", icon="mdi:thermometer")
if "nvme" in temps:
    push("sensor.servidor_temperatura_disco", temps["nvme"], friendly_name="Servidor temperatura disco",
         unit_of_measurement="°C", device_class="temperature", icon="mdi:harddisk")

# Bateria y cargador
bat = num("/sys/class/power_supply/BAT0/capacity")
if bat is not None:
    push("sensor.servidor_bateria", int(bat), friendly_name="Servidor batería",
         unit_of_measurement="%", device_class="battery")
ac = num("/sys/class/power_supply/AC/online")
if ac is not None:
    push("binary_sensor.servidor_enchufado", "on" if ac >= 1 else "off",
         friendly_name="Servidor enchufado a la luz", device_class="plug")

# Espacio: discos de las VMs (LVM thin) y USB de copias
dp = sh("lvs --noheadings -o data_percent pve/data").replace(",", ".").strip()
try:
    push("sensor.servidor_espacio_vms_libre", round(100 - float(dp), 1), friendly_name="Servidor espacio libre para VMs",
         unit_of_measurement="%", icon="mdi:harddisk")
except ValueError:
    pass
if os.path.ismount("/mnt/backup"):
    free = shutil.disk_usage("/mnt/backup").free / 1e9
    push("sensor.servidor_espacio_copias_libre", round(free), friendly_name="Servidor espacio libre para copias",
         unit_of_measurement="GB", icon="mdi:usb-flash-drive")
else:
    push("sensor.servidor_espacio_copias_libre", "unavailable", friendly_name="Servidor espacio libre para copias")

# Edad de la ultima copia buena de cada maquina en PBS (peor caso) y de las fotos (restic)
now = time.time()
ages = {}
try:
    content = json.loads(sh("pvesh get /nodes/localhost/storage/pbs-usb/content --output-format json") or "[]")
    for c in content:
        v = c.get("vmid")
        if v is not None and c.get("ctime"):
            ages[v] = min(ages.get(v, 1e9), (now - c["ctime"]) / 3600)
except Exception:
    pass
vm_ids = [101, 102, 200, 201]
worst = max([ages.get(v, 999) for v in vm_ids])
push("sensor.servidor_copia_vms_antiguedad", round(worst, 1), friendly_name="Servidor antigüedad de la copia más vieja",
     unit_of_measurement="h", device_class="duration", icon="mdi:backup-restore",
     **{f"maquina_{v}": round(ages.get(v, 999), 1) for v in vm_ids})

res = sh("systemctl show -p Result --value photos-backup.service")
ts = sh("systemctl show -p ExecMainExitTimestamp --value photos-backup.service")
photo_age = 999.0
if ts:
    epoch = sh(f"date -d '{ts}' +%s")
    if epoch.isdigit():
        photo_age = round((now - int(epoch)) / 3600, 1)
push("sensor.servidor_copia_fotos_antiguedad", photo_age, friendly_name="Servidor antigüedad de la copia de fotos",
     unit_of_measurement="h", device_class="duration", icon="mdi:image-multiple", resultado=res or "desconocido")

if res not in ("success", ""):
    estado = "fallo"
elif worst > 30 or photo_age > 30:
    estado = "atrasada"
else:
    estado = "ok"
push("sensor.servidor_estado_copias", estado, friendly_name="Servidor estado de las copias", icon="mdi:shield-check")
PY
