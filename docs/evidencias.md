# Evidencias: salida real del sistema

Salidas reales del servidor, tomadas el **4 de octubre de 2026** en solo lectura. Se han omitido identificadores internos (PIDs, direcciones) y los nombres de los hosts y se ha generalizado el nombre de la VM de laboratorio; no se ha modificado ningún resultado.

## Máquinas en ejecución

```text
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB)
       102 haos18-2             running    4096              32.00
       200 lab-vm            running    4096              40.00
       201 immich               running    5120              20.00

VMID       Status     Lock         Name
101        running                 pihole
```

## Almacenamiento

```text
Name               Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
local               dir     active        98497780         8280104        85168128    8.41%
local-lvm       lvmthin     active       365760512        73517862       292242649   20.10%
pbs-usb             pbs     active       491134172        50841936       435274788   10.35%
```

## Copias en Proxmox Backup Server (resumen por guest)

```text
101  2 copias; última 2026-10-04 04:00  tamaño   1.1 GB
102  2 copias; última 2026-10-04 04:00  tamaño  34.4 GB
200  3 copias; última 2026-10-04 03:00  tamaño  43.0 GB
201  2 copias; última 2026-10-04 04:00  tamaño  21.5 GB
```

Las copias se ejecutan solas cada día; las del día 4 se hicieron sin intervención.

## Temporizadores de systemd

```text
NEXT                           LEFT     LAST                           PASSED   UNIT
Sun 2026-10-04 23:30:30 CEST   1min     Sun 2026-10-04 23:28:30 CEST   2s ago   ha-sensors.timer
Mon 2026-10-05 05:00:36 CEST   5h 32min Sun 2026-10-04 05:04:32 CEST   18h ago  photos-backup.timer
Sun 2026-10-11 03:30:00 CEST   6 days   Sun 2026-10-04 03:30:01 CEST   19h ago  cfg-backup.timer
```

Resultado de la última ejecución de cada trabajo:

```text
cfg-backup:    success  (2026-10-04 03:30:08)
photos-backup: success  (2026-10-04 05:06:10)
```

## Fotos: instantáneas de restic (cifradas e incrementales)

```text
ID        Time                 Host    Tags    Size
-----------------------------------------------------------
7ed11367  2026-10-02 02:27:57  immich  immich  52 B        (prueba inicial)
5d93d2b6  2026-10-02 05:02:33  immich  immich  21.690 GiB
134b56fa  2026-10-03 05:01:33  immich  immich  21.731 GiB
877fd613  2026-10-04 05:04:33  immich  immich  21.756 GiB
-----------------------------------------------------------
4 snapshots
```

## Disco de copias

```text
/dev/sda1   469G   49G   416G   11%   /mnt/backup
```

## Servicios propios y de seguridad activos

`tlp`, `fail2ban`, `tailscaled`, `proxmox-backup`, `powerwatch` y `netwatch`: todos en estado `active`.

## Copias de configuración semanales

```text
config-20261004-033001.tar.gz
config-20261002-013855.tar.gz
config-20261002-013224.tar.gz
```
