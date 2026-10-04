# Guía de recuperación ante desastres

Procedimientos para restaurar cada parte del homelab. Los marcadores (`<ID>`, `<RUTA>`, `IP_PIHOLE`…) se sustituyen por los valores de cada instalación. Está escrita para poder seguirla con el servidor en mal estado y sin acordarse de nada.

> **Antes de restaurar nada:** restaurar siempre a un ID o carpeta **nuevos** y comprobar el resultado, en lugar de sobrescribir lo que queda. Solo se sobrescribe cuando ya se ha verificado la copia.

## Mapa de lo que se protege

| Dato | Dónde está la copia | Frecuencia | Cómo se restaura |
|---|---|---|---|
| VMs y contenedor (disco de sistema) | Proxmox Backup Server (disco USB) | Diaria | [Escenario A](#a-restaurar-una-vm-o-contenedor) |
| Fotos (originales y base de datos) | Repositorio `restic` cifrado (disco USB) | Diaria | [Escenario B](#b-restaurar-las-fotos) |
| Configuración del host y de Pi-hole | Tarball semanal (disco USB) | Semanal | [Escenario C](#c-restaurar-pi-hole-o-la-configuración-del-host) |
| Home Assistant | Copias propias + VM completa en PBS | Diaria | [Escenario A](#a-restaurar-una-vm-o-contenedor) |
| Host Proxmox entero | Reinstalación + tarball de configuración | — | [Escenario D](#d-el-host-no-arranca-o-el-disco-interno-falla) |

**Lo imprescindible para poder restaurar**

- La contraseña del repositorio `restic` (sin ella las fotos son ilegibles). Se guarda en un gestor de contraseñas, nunca en el servidor únicamente.
- Acceso al disco USB de copias.
- Este documento.

## A. Restaurar una VM o contenedor

1. Comprobar que el almacenamiento de copias está disponible: `pvesm status`.
2. Listar las copias disponibles del guest: `pvesm list <STORAGE_PBS> --vmid <ID>`.
3. Restaurar a un **ID nuevo** (por ejemplo 900) para no pisar el original:
   - VM: `qmrestore <STORAGE_PBS>:backup/vm/<ID>/<FECHA> 900 --storage <STORAGE_DESTINO>`
   - Contenedor: `pct restore 900 <STORAGE_PBS>:backup/ct/<ID>/<FECHA> --storage <STORAGE_DESTINO>`
4. Arrancar la copia **sin red** o con una red aislada para evitar conflictos de IP con el original.
5. Verificar: arranca, los servicios responden y los datos esperados están.
6. Si todo es correcto, parar y retirar el original, y reconfigurar el ID/red de la restaurada (o restaurar encima con el mismo ID).
7. Borrar los restos de la prueba.

Notas:

- El disco de fotos de la VM de Immich **no** entra en el backup de la VM (se excluye a propósito); se recupera con `restic` (escenario B). Primero restaurar la VM, luego las fotos.
- Orden recomendado de arranque tras una recuperación completa: DNS (Pi-hole) → Home Assistant → Immich → resto.

## B. Restaurar las fotos

1. Tener la contraseña de `restic` a mano.
2. Ver las instantáneas: `restic -r <RUTA_REPO> snapshots`.
3. Restaurar **primero a una carpeta temporal**: `restic -r <RUTA_REPO> restore latest --tag immich --target <RUTA_TEMPORAL>`.
4. Comprobar que los ficheros se abren (muestreo de fotos recientes y antiguas).
5. Copiar a la ubicación definitiva de la VM de fotos y reiniciar Immich.
6. Immich regenerará miniaturas y vídeos transcodificados (están excluidos de la copia a propósito); puede tardar horas.
7. Comprobar la integridad del repositorio: `restic -r <RUTA_REPO> check`.

## C. Restaurar Pi-hole o la configuración del host

**Pi-hole (listas, DHCP, reservas, DNS):**

1. Extraer `pihole-teleporter.zip` del último tarball de configuración.
2. En la interfaz de Pi-hole: *Ajustes → Teleporter → Importar*.
3. Comprobar con `dig +short @IP_PIHOLE dominio`.
4. Si el DHCP del router estuviera desactivado y Pi-hole no volviera a arrancar, reactivar el DHCP del router mientras tanto para no dejar la red sin direccionamiento.

**Configuración del host:** el tarball contiene los ficheros de `/etc` modificados, la base de datos de Proxmox y la configuración de cada guest. Extraerlo en una carpeta temporal y copiar solo lo necesario; no sobrescribir `/etc` entero.

## D. El host no arranca o el disco interno falla

1. Reinstalar Proxmox VE en el disco nuevo (misma versión mayor).
2. Reconfigurar la red y el almacenamiento de copias (montar el USB).
3. Volver a añadir el almacenamiento de Proxmox Backup Server.
4. Restaurar cada guest como en el escenario A.
5. Recuperar scripts y temporizadores desde el repositorio y los ficheros del tarball de configuración.
6. Revisar el passthrough USB del coordinador Zigbee en la VM de Home Assistant.
7. Verificar las copias automáticas el día siguiente.

## E. Cortes de luz y arranque tras apagado

- El portátil actúa como SAI básico; si la batería baja del umbral, apaga el sistema de forma ordenada.
- Tras volver la luz, el servidor debe arrancar solo si la BIOS tiene activado el encendido automático al recuperar corriente (pendiente de activar en este equipo).
- El orden de arranque de los guests está definido (`startup order`) para que el DNS esté listo antes que el resto.

## Prueba periódica

Una copia que no se ha probado no es una copia. Plan:

- **Mensual:** restaurar un guest a un ID temporal, arrancarlo aislado, comprobarlo y borrarlo. Último registro en [`prueba-restauracion.md`](prueba-restauracion.md).
- **Trimestral:** restaurar una muestra de fotos y ejecutar `restic check` completo.
- Tras cualquier cambio importante: revisar que el siguiente ciclo de copias termina bien.

## Limitación conocida

Todas las copias están en el mismo domicilio que los datos. Un robo, incendio o sobretensión podría afectar a todo. La mitigación pendiente es una copia cifrada fuera de casa (regla 3-2-1 completa).
