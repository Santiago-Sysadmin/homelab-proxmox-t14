# Homelab de infraestructura doméstica con Proxmox VE

> Proyecto personal de administración de sistemas, virtualización, servicios de red y automatización doméstica.
>
> **Estado:** operativo y en evolución · **Entorno:** Cabanes, Comunidad Valenciana · **Última actualización:** octubre de 2026

## Resumen

Diseño, despliegue y migración de un servidor doméstico desde un iMac A1311 con Umbrel OS hacia un Lenovo ThinkPad T14 Gen 2 con Proxmox VE. El objetivo fue centralizar servicios críticos de la red doméstica en una plataforma más eficiente, modular, administrable y preparada para ampliar un laboratorio de redes y sistemas.

La plataforma proporciona filtrado DNS y DHCP a nivel de red, automatización doméstica local con Zigbee, una nube de fotos privada, copias de seguridad automatizadas y verificadas, monitorización con alertas al móvil y acceso remoto privado mediante VPN mesh.

## Objetivos del proyecto

- Sustituir hardware antiguo por una plataforma x86 moderna y de bajo consumo.
- Eliminar la dependencia de Umbrel para servicios que pueden ejecutarse de forma nativa y estándar.
- Separar servicios mediante virtualización para facilitar actualizaciones, snapshots, recuperación y ampliación.
- Mantener la continuidad de Pi-hole, Home Assistant y la red Zigbee ya desplegada.
- Habilitar administración remota privada sin exponer servicios de administración al Internet público.
- Proteger los datos (configuración, máquinas virtuales y fotos) con copias automáticas, cifradas y verificadas.
- Detectar y comunicar problemas (cortes de luz, caídas de red, discos llenos, copias atrasadas) sin tener que mirar el servidor.
- Preparar almacenamiento SMB/NAS y Jellyfin para biblioteca multimedia propia.
- Dejar capacidad disponible para laboratorios de CCNA, MTCNA, Linux y automatización.

## Hardware

| Componente | Especificación |
|---|---|
| Host | Lenovo ThinkPad T14 Gen 2 AMD |
| CPU | AMD Ryzen 5 PRO 5650U · 6 núcleos / 12 hilos |
| Memoria | 16 GB DDR4 · 8 GB soldados + 8 GB SODIMM |
| Ampliación prevista | SODIMM DDR4-3200 de 16 GB (total 24 GB) |
| Almacenamiento host | SSD NVMe interno de 512 GB (LVM thin para los guests) |
| Almacenamiento de copias | Disco USB de 512 GB, independiente del NVMe |
| Red | Ethernet gigabit cableada |
| Coordinador Zigbee | Dongle USB Sonoff Zigbee 3.0 |
| Alimentación | La propia batería del portátil actúa como SAI básico (ver «Resiliencia ante cortes de luz») |
| Refrigeración | Soporte elevado para mantener libres las entradas/salidas de aire |

## Arquitectura

```text
Internet
   │
Router doméstico (DHCP desactivado) / LAN privada
   │
   ├── Proxmox VE — ThinkPad T14 Gen 2
   │   ├── LXC Pi-hole
   │   │   └── DNS, listas de bloqueo y servidor DHCP de toda la red
   │   │
   │   ├── VM Home Assistant OS
   │   │   ├── Automatizaciones domésticas locales
   │   │   ├── Integración ZHA + Matter/Alexa
   │   │   ├── Sonoff Zigbee USB por passthrough
   │   │   └── Alertas del servidor (sensores, avisos al móvil)
   │   │
   │   ├── VM Immich
   │   │   └── Nube de fotos privada (importación desde Google Fotos)
   │   │
   │   ├── VM de laboratorio en red aislada
   │   │   └── Segmentada del resto de la LAN y del host
   │   │
   │   ├── Proxmox Backup Server (en el propio host, datastore en disco USB)
   │   │
   │   ├── VM OpenMediaVault [pendiente]
   │   │   └── NAS / SMB / almacenamiento multimedia mediante disco dedicado
   │   │
   │   └── Laboratorios y servicios futuros
   │       ├── Containerlab / GNS3 / MikroTik CHR
   │       ├── Rocky Linux / Windows Server
   │       ├── Jellyfin
   │       └── Monitorización
   │
   └── Tailscale
       └── Acceso remoto privado a los servicios de casa
```

> Documentación detallada por servicio en repositorios específicos:
> [`homelab-home-assistant`](https://github.com/Santiago-Sysadmin/homelab-home-assistant) · [`homelab-pihole`](https://github.com/Santiago-Sysadmin/homelab-pihole).
>
> **Política de publicación:** este repositorio no incluye direcciones IP, puertos, MACs, nombres de red Wi-Fi, reglas de firewall, claves ni tokens. Los scripts usan marcadores de posición (`HOME_ASSISTANT_HOST`, etc.) y leen los secretos de ficheros que nunca se suben.

## Tecnologías utilizadas

- Proxmox VE 9 sobre Debian 13 · Proxmox Backup Server
- KVM/QEMU y LXC, memoria dinámica (ballooning) y swap por guest
- Home Assistant OS, ZHA (Zigbee Home Automation), Matter
- Pi-hole v6 (DNS + DHCP)
- Immich, restic (copias cifradas e incrementales)
- Tailscale (subnet routing)
- Firewall, protección frente a fuerza bruta y SSH endurecido
- Linux CLI, Bash, Python 3, APT, systemd (services y timers), sysctl, TLP, `lm-sensors`
- API REST y webhooks de Home Assistant, Telegram/notificaciones móviles
- DNS, DHCP, red IPv4 privada, bridges y redes virtuales aisladas
- USB passthrough a máquinas virtuales
- Snapshot y recuperación de servicios virtualizados
- Próximamente: OpenMediaVault, SMB/CIFS, Jellyfin, Containerlab/GNS3, MikroTik CHR

## Implementación

### 1. Preparación del host

- Instalación de Proxmox VE 9 en el NVMe del ThinkPad.
- Configuración de red cableada de administración en la LAN privada.
- Configuración del repositorio `pve-no-subscription` para un entorno doméstico/laboratorio.
- Revisión de virtualización AMD-V/SVM y parámetros de firmware para un funcionamiento 24/7.
- Configuración de `systemd-logind` para mantener el host encendido con la tapa cerrada.
- Desactivación de suspensión/hibernación no deseada en un uso de servidor.
- Perfil de energía con TLP pensado para servidor: governor `powersave`, boost de CPU solo con corriente, Bluetooth/WWAN/Wi-Fi apagados al arrancar y carga de batería limitada al 75–80 % para alargar su vida ([`config/tlp`](config/tlp/10-t14.conf)).
- Pantalla de la consola apagada tras 1 minuto sin uso ([`systemd/console-blank.service`](systemd/console-blank.service)).
- Servicios innecesarios para un nodo único deshabilitados (`rpcbind`, `spiceproxy`, `pve-ha-lrm`, `pve-ha-crm`, ModemManager, NetworkManager) para liberar ~320 MB de RAM y reducir la superficie de ataque.

### 2. Pi-hole: DNS y DHCP de toda la red

- Exportación de la configuración de la instancia previa mediante Pi-hole Teleporter.
- Despliegue de Pi-hole en un LXC independiente.
- Importación de listas, reglas, servidores DNS upstream y configuración previa.
- Diagnóstico y recuperación del acceso web tras restaurar la configuración de puerto personalizada.
- Validación DNS mediante `nslookup` y verificación de consultas reales desde varios clientes LAN.
- **Migración del DHCP:** el servidor DHCP del router se desactivó y pasó a Pi-hole, con reservas de IP fijas para los equipos de infraestructura (host, guests, malla Wi-Fi). Así cada cliente aparece por nombre en las consultas DNS.
- Orden de arranque (`startup order`) para que Pi-hole y Home Assistant estén disponibles antes que el resto tras un reinicio.

### 3. Migración de Home Assistant y Zigbee

- Creación de backup completo de Home Assistant antes de la migración.
- Despliegue de Home Assistant OS como VM independiente en Proxmox.
- Asignación de recursos iniciales: 2 vCPU y 4 GB de RAM.
- Diagnóstico de DHCP/IPv4 en HAOS mediante `ha network info`.
- Configuración de red de HAOS y validación de conectividad.
- Migración del coordinador Sonoff Zigbee USB mediante USB passthrough por Vendor/Device ID.
- Restauración de la integración ZHA usando el mismo coordinador, preservando los dispositivos emparejados y automatizaciones existentes.
- Integración con Alexa a través de Matter.
- Verificación posterior de entidades y conectividad Zigbee.
- Auditoría de la instalación por línea de comandos (sin token) y limpieza de integraciones y entidades caídas.
- Coexistencia radio: el canal Zigbee se mantiene separado del Wi-Fi de 2,4 GHz para evitar interferencias, y el dongle se aleja de fuentes de ruido (hubs y discos USB 3).

### 4. Acceso remoto seguro

- Instalación de Tailscale en el host Proxmox.
- Configuración de subnet routing para la red doméstica.
- Diagnóstico de advertencias de forwarding.
- Activación persistente de IPv4 forwarding mediante configuración `sysctl`.
- Limpieza de dispositivos antiguos del tailnet y revisión de la caducidad de claves.
- Acceso remoto a servicios de la LAN sin exponer Proxmox, Home Assistant ni el NAS a Internet.
- Verificación de que el móvil fuera de casa llega a los servicios por el túnel y de que la conexión es directa (peer-to-peer) y no por relé.

### 5. Copias de seguridad

Estrategia en capas, con todo automatizado mediante timers de systemd:

| Qué | Cómo | Cuándo | Retención |
|---|---|---|---|
| Máquinas virtuales y contenedor | `vzdump` hacia Proxmox Backup Server (deduplicación incremental) | Diaria | Según política del datastore |
| Configuración del host | Tarball con `/etc`, base de datos de Proxmox, configuración de cada guest y exportación de Pi-hole ([`scripts/cfg-backup.sh`](scripts/cfg-backup.sh)) | Domingos 03:30 | Las 8 últimas |
| Fotos de Immich | `restic` cifrado e incremental ([`scripts/photos-backup.sh`](scripts/photos-backup.sh)) | Diaria 05:00 | 7 diarias, 4 semanales, 6 mensuales |
| Integridad | Verificación del datastore PBS (domingos) y recolección de basura (sábados); `restic check` leyendo el 5 % de los datos (domingos) | Semanal | — |

- Proxmox Backup Server instalado en el propio host con el datastore en un disco USB independiente del NVMe.
- Las copias de fotos excluyen miniaturas y vídeo transcodificado (Immich los regenera) y conservan originales, volcados de la base de datos y perfiles.
- Prueba de restauración real realizada con una de las máquinas virtuales.
- Las unidades systemd están en [`systemd/`](systemd/).
- Pendiente: copia fuera de casa (hoy todas las copias están en el mismo domicilio) — ver «Próximas fases».

### 6. Monitorización y alertas

- Verificación de CPU, memoria, uso de disco, swap y retardo de I/O desde la interfaz Proxmox.
- Sensores del servidor publicados en Home Assistant cada 2 minutos mediante la API REST ([`scripts/ha-sensors.sh`](scripts/ha-sensors.sh)): temperatura de CPU y NVMe, batería, si está enchufado, espacio libre para VMs y copias, y antigüedad de la última copia de cada máquina y de las fotos.
- Integración nativa `proxmoxve` de Home Assistant con un usuario de solo lectura (rol `PVEAuditor`) y token de API dedicado, con el principio de mínimo privilegio.
- Automatizaciones con avisos al móvil: máquina caída o recuperada, memoria o CPU altas, temperatura elevada, poco espacio, copias atrasadas o fallidas y un resumen diario por la mañana.
- Notificaciones nativas de Proxmox VE y PBS (errores de copia, verificación, etc.) enviadas por webhook a Home Assistant.
- Panel «Servidor» en Home Assistant con el estado del servidor de un vistazo.
- Valores térmicos de referencia: CPU ~57–62 °C en uso normal, NVMe ~41–43 °C, consumo de CPU ~9 W.

Estado observado el 4 de octubre de 2026 con 4 guests en marcha:

| Métrica | Resultado |
|---|---:|
| Uptime | casi 3 días sin reinicio, sin servicios fallidos |
| Load average | ~0,03 |
| RAM usada | ~10,6 GiB de 14,5 GiB |
| Almacenamiento de guests (LVM thin) | ~20 % |
| Disco de copias (USB) | ~10 % |

### 7. Resiliencia ante cortes de luz

El portátil funciona como SAI básico. Dos servicios propios en Bash (con `Restart=always`) registran los eventos y actúan:

- [`scripts/powerwatch.sh`](scripts/powerwatch.sh): detecta pérdida y vuelta de corriente por `/sys/class/power_supply`, apaga ordenadamente el servidor si la batería baja del 12 % y, al volver la luz, espera a que haya internet y envía un aviso con la hora de inicio, la duración y la batería.
- [`scripts/netwatch.sh`](scripts/netwatch.sh): registra solo las transiciones de estado (enlace Ethernet, router, malla Wi-Fi, Pi-hole, Home Assistant, internet y resolución DNS) para distinguir un corte de luz de una caída del router o de la línea.
- Pendiente: activar en la BIOS el encendido automático tras un corte de suministro.

### 8. Fotos privadas con Immich

- VM dedicada con Immich como alternativa privada a Google Fotos.
- Importación del histórico de Google Fotos (Takeout) con `immich-go`.
- Dimensionado de memoria con ballooning y swap, ajustado tras observar presión de RAM en el host.
- Copia diaria cifrada de la biblioteca (ver sección 5).

### 9. Hardening y aislamiento

- **Acceso de administración:** SSH con autenticación por clave (sin contraseñas) y protección frente a intentos repetidos de acceso en SSH y en la interfaz web.
- **Segmentación:** las máquinas de laboratorio que no son de confianza viven en una red virtual propia, aislada de la LAN doméstica, con reglas de firewall en el host.
- **Reducción de superficie:** servicios innecesarios deshabilitados y acceso remoto solo mediante VPN mesh.
- **Memoria bajo control:** tras un cuelgue de una VM por falta de RAM se reajustaron los mínimos de ballooning por guest y se añadió swap; se documentó el límite hasta ampliar la memoria física.
- **Secretos fuera del repositorio:** tokens, claves y el identificador del webhook se guardan en ficheros con permisos restringidos en el host.

## Estructura del repositorio

```text
.
├── README.md
├── scripts/       # Scripts propios del host (copias, sensores, vigilancia)
├── systemd/       # Servicios y timers que los ejecutan
└── config/
    └── tlp/       # Perfil de energía del portátil
```

> Los ficheros están saneados: sin IPs, contraseñas, tokens, claves ni identificadores de webhook. Los valores propios de cada instalación se leen de ficheros de configuración locales (`/etc/default/...`, `/etc/homelab/...`) que no forman parte del repositorio.

## Decisiones técnicas destacadas

### Proxmox en lugar de Umbrel

Umbrel era válido para iniciar servicios rápidamente, pero ya no aportaba valor suficiente para los servicios activos. Proxmox permite separar funciones en guests independientes, tomar snapshots, realizar restauraciones selectivas, dimensionar recursos y añadir laboratorios sin rediseñar toda la plataforma.

### Home Assistant OS en VM

Home Assistant OS se desplegó en su propia máquina virtual para mantener compatibilidad completa con el ecosistema de Home Assistant, backups nativos y USB passthrough del coordinador Zigbee.

### Pi-hole en LXC, como DNS y DHCP

Pi-hole requiere recursos mínimos y no necesita una VM completa. El despliegue en LXC reduce sobrecarga manteniendo aislamiento y facilidad de backup. Al ser también el servidor DHCP, cada dispositivo aparece por nombre en el log de consultas y las reservas de IP quedan versionadas en la copia de configuración (Teleporter).

### Tailscale en lugar de exponer servicios

El acceso remoto se resuelve con una red privada mesh. Esto evita publicar puertos de administración al Internet público y reduce la superficie de exposición del homelab.

### Proxmox Backup Server en el mismo host

Se instaló PBS junto a Proxmox VE para obtener copias incrementales con deduplicación, verificación programada y restauración granular sin necesitar otro equipo. Es una decisión consciente de coste: protege contra errores y fallos de software, pero no contra la pérdida física del equipo, por lo que la copia externa figura como siguiente paso.

### Restic para las fotos

Las fotos son el dato más difícil de recuperar. `restic` aporta cifrado, deduplicación y verificación de integridad independientes de Proxmox, de modo que un fallo del datastore de PBS no arrastra las fotos.

### Alertas con lo que ya existe

En lugar de desplegar una pila completa (Prometheus/Grafana) para un servidor pequeño, los sensores se publican en Home Assistant, que ya está en la red y ya notifica al móvil. Reutilizar la herramienta existente reduce el mantenimiento; una pila de monitorización queda como laboratorio futuro.

### NAS independiente con OMV

OpenMediaVault se desplegará como VM dedicada. El sistema operativo usará un disco virtual pequeño en el NVMe; los datos estarán en un disco físico dedicado pasado a la VM. La separación permite mantener, actualizar o restaurar el sistema sin mezclarlo con los datos de usuario.

## Próximas fases

- [x] Copias de seguridad automáticas de máquinas, configuración y fotos, con verificación periódica.
- [x] Monitorización básica con alertas al móvil (Home Assistant + sensores propios).
- [x] Endurecimiento del acceso de administración y segmentación de las VMs de laboratorio.
- [ ] Ampliar la memoria a 24 GB con un SODIMM DDR4-3200 de 16 GB y reajustar los guests.
- [ ] Activar el encendido automático tras corte de luz en la BIOS.
- [ ] Copia de seguridad fuera de casa (regla 3-2-1 completa) y valoración de cifrado del datastore PBS.
- [ ] Prueba de restauración periódica (mensual) y guía de recuperación ante desastres escrita.
- [ ] Desplegar OpenMediaVault como VM independiente.
- [ ] Añadir disco SSD/HDD dedicado al NAS mediante passthrough persistente.
- [ ] Configurar sistema de archivos, usuarios, permisos y recursos SMB/CIFS.
- [ ] Migrar la biblioteca multimedia existente del iMac, incluyendo One Piece, al almacenamiento NAS.
- [ ] Desplegar Jellyfin en un servicio independiente y montar la biblioteca multimedia en modo solo lectura.
- [ ] Integrar métricas de energía con enchufe medidor compatible con Home Assistant.
- [ ] Desplegar Containerlab/GNS3, MikroTik CHR, Rocky Linux y Windows Server para prácticas de CCNA, MTCNA, RHCSA y administración de sistemas.
- [ ] Valorar monitorización avanzada con Grafana, Uptime Kuma, Zabbix o LibreNMS.

## Competencias demostradas

- Administración de Linux y servicios de infraestructura.
- Virtualización con Proxmox, KVM/QEMU y LXC.
- Diseño e implantación de copias de seguridad con Proxmox Backup Server y restic, incluida verificación y prueba de restauración.
- Diagnóstico de red: conectividad IPv4, DHCP, DNS y routing; migración del DHCP del router a Pi-hole.
- Gestión de DNS y DHCP a nivel de red con Pi-hole.
- Automatización doméstica local con Home Assistant, ZHA y Matter.
- Scripting en Bash y Python, servicios y timers de systemd, integración con APIs REST y webhooks.
- Monitorización, alertas y respuesta ante incidencias (cortes de luz, caídas de red, saturación de memoria).
- Hardening de Linux: acceso por clave, protección frente a fuerza bruta, firewall y segmentación de red.
- Gestión de dispositivos USB y seriales en un entorno virtualizado.
- Acceso remoto seguro mediante Tailscale y subnet routing.
- Optimización de recursos y energía en un host Linux 24/7 (TLP, ballooning, swap).
- Diseño modular, documentación técnica y planificación de continuidad.

## Evidencias

Capturas incluidas en el repositorio:

- [`proxmox-resource-overview.png`](proxmox-resource-overview.png): vista de recursos de Proxmox.
- [`pihole-dns-dashboard.png`](pihole-dns-dashboard.png): panel de Pi-hole.

> Antes de añadir más capturas: difuminar o eliminar IPs públicas, dominios, tokens, IDs de Tailscale, direcciones MAC, claves Wi-Fi, credenciales, nombres de dispositivos personales y cualquier información de domótica que revele horarios o presencia en casa.

Capturas sugeridas pendientes:

1. Diagrama de arquitectura creado con draw.io, Excalidraw o Mermaid.
2. Dashboard de Home Assistant (panel «Servidor») con entidades anonimizadas.
3. Tareas de copia y verificación de Proxmox Backup Server.
4. Salida de `sensors` sin información sensible.
5. Captura de Tailscale con nombres e IPs de tailnet ocultos.

## Autor

Técnico de sistemas y redes, orientado a administración de infraestructura, virtualización, redes y automatización. Experiencia práctica con Linux, Docker, Bash, Microsoft 365, Active Directory/Entra ID, VLANs, switching y entornos MikroTik, Huawei, D-Link, Aruba y Cisco.

**Objetivo profesional:** puestos de administración de sistemas, infraestructura, redes y soporte técnico avanzado.
