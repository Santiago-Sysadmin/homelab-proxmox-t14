# Homelab de infraestructura doméstica con Proxmox VE

> Proyecto personal de administración de sistemas, virtualización, servicios de red y automatización doméstica.
>
> **Estado:** operativo y en evolución · **Entorno:** Cabanes, Comunidad Valenciana · **Fecha:** agosto de 2026

## Resumen

Diseño, despliegue y migración de un servidor doméstico desde un iMac A1311 con Umbrel OS hacia un Lenovo ThinkPad T14 Gen 2 con Proxmox VE. El objetivo fue centralizar servicios críticos de la red doméstica en una plataforma más eficiente, modular, administrable y preparada para ampliar un laboratorio de redes y sistemas.

La plataforma proporciona filtrado DNS a nivel de red, automatización doméstica local con Zigbee, acceso remoto privado mediante VPN mesh y una base preparada para almacenamiento NAS y servidor multimedia.

## Objetivos del proyecto

- Sustituir hardware antiguo por una plataforma x86 moderna y de bajo consumo.
- Eliminar la dependencia de Umbrel para servicios que pueden ejecutarse de forma nativa y estándar.
- Separar servicios mediante virtualización para facilitar actualizaciones, snapshots, recuperación y ampliación.
- Mantener la continuidad de Pi-hole, Home Assistant y la red Zigbee ya desplegada.
- Habilitar administración remota privada sin exponer puertos al Internet público.
- Preparar almacenamiento SMB/NAS y Jellyfin para biblioteca multimedia propia.
- Dejar capacidad disponible para laboratorios de CCNA, MTCNA, Linux y automatización.

## Hardware

| Componente | Especificación |
|---|---|
| Host | Lenovo ThinkPad T14 Gen 2 AMD |
| CPU | AMD Ryzen 5 PRO 5650U · 6 núcleos / 12 hilos |
| Memoria | 16 GB DDR4 · 8 GB soldados + 8 GB SODIMM |
| Ampliación prevista | Hasta 40 GB mediante SODIMM DDR4-3200 de 32 GB |
| Almacenamiento host | SSD NVMe interno |
| Red | Ethernet gigabit cableada |
| Coordinador Zigbee | Dongle USB Sonoff Zigbee 3.0 |
| Refrigeración | Soporte elevado para mantener libres las entradas/salidas de aire |

## Arquitectura

```text
Internet
   │
Router doméstico / LAN 192.168.0.0/24
   │
   ├── Proxmox VE — ThinkPad T14 Gen 2
   │   ├── LXC Pi-hole
   │   │   └── DNS, listas de bloqueo, resolución para clientes LAN
   │   │
   │   ├── VM Home Assistant OS
   │   │   ├── Automatizaciones domésticas locales
   │   │   ├── Integración ZHA
   │   │   └── Sonoff Zigbee USB por passthrough
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
       └── Acceso remoto privado y subnet routing; sin puertos entrantes públicos
```

## Tecnologías utilizadas

- Proxmox VE 9 sobre Debian 13
- KVM/QEMU y LXC
- Home Assistant OS
- ZHA (Zigbee Home Automation)
- Pi-hole v6
- Tailscale
- Linux CLI, APT, systemd, sysctl, `lm-sensors`
- DNS, DHCP, red IPv4 privada, bridge `vmbr0`
- USB passthrough a máquinas virtuales
- Snapshot y recuperación de servicios virtualizados
- Próximamente: OpenMediaVault, SMB/CIFS, Jellyfin, Containerlab/GNS3, MikroTik CHR

## Implementación

### 1. Preparación del host

- Instalación de Proxmox VE 9 en el NVMe del ThinkPad.
- Configuración de red cableada de administración en la LAN privada.
- Configuración del repositorio `pve-no-subscription` para un entorno doméstico/laboratorio.
- Revisión de virtualización AMD-V/SVM y parámetros de firmware para un funcionamiento 24/7.
- Configuración de umbrales de carga de batería con TLP para evitar que permanezca al 100 % permanentemente.
- Configuración de `systemd-logind` para mantener el host encendido con la tapa cerrada.
- Desactivación de suspensión/hibernación no deseada en un uso de servidor.

### 2. Migración de Pi-hole

- Exportación de la configuración de la instancia previa mediante Pi-hole Teleporter.
- Despliegue de Pi-hole en un LXC independiente.
- Importación de listas, reglas, servidores DNS upstream y configuración previa.
- Diagnóstico y recuperación del acceso web tras restaurar el puerto personalizado `8082`.
- Validación DNS mediante `nslookup` y verificación de consultas reales desde varios clientes LAN.
- Integración como servicio DNS de la red doméstica.

### 3. Migración de Home Assistant y Zigbee

- Creación de backup completo de Home Assistant antes de la migración.
- Despliegue de Home Assistant OS como VM independiente en Proxmox.
- Asignación de recursos iniciales: 2 vCPU y 4 GB de RAM.
- Diagnóstico de DHCP/IPv4 en HAOS mediante `ha network info`.
- Configuración de red de HAOS y validación de conectividad.
- Migración del coordinador Sonoff Zigbee USB mediante USB passthrough por Vendor/Device ID.
- Restauración de la integración ZHA usando el mismo coordinador, preservando los dispositivos emparejados y automatizaciones existentes.
- Verificación posterior de entidades y conectividad Zigbee.

### 4. Acceso remoto seguro

- Instalación de Tailscale en el host Proxmox.
- Configuración de subnet routing para la red doméstica `192.168.0.0/24`.
- Diagnóstico de advertencias de forwarding.
- Activación persistente de IPv4 forwarding mediante configuración `sysctl`.
- Acceso remoto a servicios de la LAN sin abrir puertos en el router ni exponer Proxmox, Home Assistant o NAS a Internet.

### 5. Validación y observabilidad

- Verificación de CPU, memoria, uso de disco, swap y retardo de I/O desde la interfaz Proxmox.
- Estado observado después de la migración base:

| Métrica | Resultado observado |
|---|---:|
| CPU del host | ~0,39 % de 12 hilos |
| Load average | ~0,27 / 0,26 / 0,20 |
| RAM usada | ~3,81 GiB de 14,46 GiB utilizables |
| Swap usada | 0 B de 8 GiB |
| Retardo de I/O | 0,00 % |
| Espacio raíz usado | ~5,50 GiB de 93,93 GiB |

- Monitorización de sensores térmicos con `lm-sensors`.
- Valores iniciales registrados: CPU ~57 °C, GPU integrada ~49 °C, NVMe ~43 °C y CPU package power ~9 W.
- Confirmación de una colocación física correcta: soporte elevado y rejillas libres.

## Decisiones técnicas destacadas

### Proxmox en lugar de Umbrel

Umbrel era válido para iniciar servicios rápidamente, pero ya no aportaba valor suficiente para los servicios activos. Proxmox permite separar funciones en guests independientes, tomar snapshots, realizar restauraciones selectivas, dimensionar recursos y añadir laboratorios sin rediseñar toda la plataforma.

### Home Assistant OS en VM

Home Assistant OS se desplegó en su propia máquina virtual para mantener compatibilidad completa con el ecosistema de Home Assistant, backups nativos y USB passthrough del coordinador Zigbee.

### Pi-hole en LXC

Pi-hole requiere recursos mínimos y no necesita una VM completa. El despliegue en LXC reduce sobrecarga manteniendo aislamiento y facilidad de backup.

### Tailscale en lugar de port forwarding

El acceso remoto se resuelve con una red privada mesh. Esto evita publicar puertos de administración al Internet público y reduce la superficie de exposición del homelab.

### NAS independiente con OMV

OpenMediaVault se desplegará como VM dedicada. El sistema operativo usará un disco virtual pequeño en el NVMe; los datos estarán en un disco físico dedicado pasado a la VM. La separación permite mantener, actualizar o restaurar el sistema sin mezclarlo con los datos de usuario.

## Próximas fases

- [ ] Desplegar OpenMediaVault como VM independiente.
- [ ] Añadir disco SSD/HDD dedicado al NAS mediante passthrough persistente.
- [ ] Configurar sistema de archivos, usuarios, permisos y recursos SMB/CIFS.
- [ ] Migrar la biblioteca multimedia existente del iMac, incluyendo One Piece, al almacenamiento NAS.
- [ ] Desplegar Jellyfin en un servicio independiente y montar la biblioteca multimedia en modo solo lectura.
- [ ] Configurar copias de seguridad 3-2-1 para datos del NAS, Pi-hole y Home Assistant.
- [ ] Integrar métricas de energía con enchufe medidor compatible con Home Assistant.
- [ ] Desplegar Containerlab/GNS3, MikroTik CHR, Rocky Linux y Windows Server para prácticas de CCNA, MTCNA, RHCSA y administración de sistemas.
- [ ] Añadir monitorización con Grafana, Uptime Kuma, Zabbix o LibreNMS.

## Competencias demostradas

- Administración de Linux y servicios de infraestructura.
- Virtualización con Proxmox, KVM/QEMU y LXC.
- Diagnóstico de red: conectividad IPv4, DHCP, DNS y routing.
- Migración de servicios conservando configuración y continuidad operativa.
- Gestión de DNS a nivel de red con Pi-hole.
- Automatización doméstica local con Home Assistant y ZHA.
- Gestión de dispositivos USB y seriales en un entorno virtualizado.
- Acceso remoto seguro mediante Tailscale y subnet routing.
- Análisis de recursos, sensores y estado térmico de un host Linux.
- Diseño modular, documentación técnica y planificación de backups.

## Evidencias sugeridas para el repositorio

> Antes de publicar: difuminar o eliminar IPs públicas, dominios, tokens, IDs de Tailscale, direcciones MAC, claves Wi-Fi, credenciales, nombres de dispositivos personales y cualquier información de domótica que revele horarios o presencia en casa.

Añadir únicamente capturas saneadas:

1. Vista general de Proxmox con las VMs/LXC, nombres genéricos y sin IPs sensibles.
2. Dashboard de Pi-hole con consultas y listas activas, sin nombres de clientes.
3. Diagrama de arquitectura creado con draw.io, Excalidraw o Mermaid.
4. Dashboard de Home Assistant con entidades anonimizadas.
5. Salida de `sensors` sin información sensible.
6. Captura de Tailscale con nombres e IPs de tailnet ocultos.

## Autor

Técnico de sistemas y redes, orientado a administración de infraestructura, virtualización, redes y automatización. Experiencia práctica con Linux, Docker, Bash, Microsoft 365, Active Directory/Entra ID, VLANs, switching y entornos MikroTik, Huawei, D-Link, Aruba y Cisco.

**Objetivo profesional:** puestos de administración de sistemas, infraestructura, redes y soporte técnico avanzado.
