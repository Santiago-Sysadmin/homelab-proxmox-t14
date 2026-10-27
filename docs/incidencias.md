# Registro de incidencias

Problemas reales encontrados en el sistema, su causa y cómo se resolvieron. Mantenerlo es parte de operar el servidor: las copias y las alertas solo valen si se revisan.

## 2026-10-16 — Caída de la fibra: salida temporal a Internet por datos móviles

| | |
|---|---|
| **Qué pasó** | La fibra del operador dejó de funcionar y la reparación se retrasó cerca de una semana. El router solo hace de ONT y el servidor es el DHCP/DNS de la red, así que sin salida a Internet el servidor, la VM aislada y la VPN se quedaban sin conexión. |
| **Solución temporal** | Un móvil antiguo con una SIM de datos como módem por **USB tethering** conectado al servidor. Se eliminó la ruta por defecto hacia el router sin fibra y se añadió una nueva por la interfaz del móvil (por DHCP). Con **IP forwarding** y **NAT (masquerade)** en `iptables` salieron también el resto de la casa y las VMs, y el DHCP repartió como puerta de enlace al propio servidor. |
| **Verificación** | Ping por IP y por nombre, y comprobación de que la IP pública de salida era la del móvil. Tailscale siguió funcionando sin abrir puertos, pese al CGNAT de la red móvil. |
| **Decisión de diseño** | Todo se hizo **solo en memoria**, sin tocar `/etc/network/interfaces`, para que un reinicio devolviera la configuración guardada. Lo único persistente era la puerta de enlace del DHCP, que había que revertir a mano. |
| **Reversión** | Con la fibra restablecida: quitar la ruta del móvil, restaurar la del router, borrar la regla NAT, liberar la concesión DHCP de la interfaz, devolver la puerta de enlace original en el DHCP y retirar el móvil. El IP forwarding se deja activo porque la VM aislada puede necesitarlo. |
| **Lección** | Un servidor que concentra DHCP y DNS depende de tener una salida a Internet: conviene dejar documentado el procedimiento de failover y de vuelta atrás **antes** de necesitarlo. Durante la caída apareció un trabajo de copia en rojo en Proxmox: conviene revisar su registro con la conexión estable para descartar otra causa. |

## 2026-10-04 — Las copias terminaban cada día con «job errors»

| | |
|---|---|
| **Cómo se detectó** | Al revisar el registro de tareas de Proxmox VE para hacer capturas: los trabajos de copia de las 03:00 y 04:00 aparecían en rojo («Error: job errors»), aunque Proxmox Backup Server mostraba todas las copias como correctas. |
| **Causa** | El usuario de copias de PBS tenía el rol `DatastoreBackup` (solo escribir copias). El último paso de cada trabajo, la **limpieza de copias antiguas según la retención**, exigía además el permiso de poda (`Datastore.Prune`) y fallaba con *permission check failed*. |
| **Impacto** | Las copias sí se creaban y estaban íntegras, pero la retención (7 diarias, 4 semanales) **no se aplicaba** y los trabajos acababan en error todos los días. Con el disco al 10 % no había riesgo inmediato; el peligro real de un trabajo que da error a diario es acostumbrarse a ignorarlo. |
| **Solución** | Asignar el rol `DatastorePowerUser` (copiar + podar, sin administrar) al usuario y a su token solo sobre ese almacén, manteniendo el mínimo privilegio. |
| **Verificación** | Copia de prueba de un contenedor: terminó con *finished successfully* y la poda se ejecutó. |
| **Por qué no lo detectó el sistema de alertas** | El sensor «estado de las copias» mide la **antigüedad** de la última copia, que era correcta. No miraba el resultado del trabajo en Proxmox. |
| **Mejora pendiente** | Añadir al sensor el resultado de la última ejecución de cada trabajo de copia, para que un «job errors» dispare un aviso. |

## 2026-10-04 — `apt update` fallaba con error 401

| | |
|---|---|
| **Causa** | Al instalar Proxmox Backup Server se activó su repositorio *enterprise* (de pago). Sin suscripción devuelve 401 y hace fallar la actualización de paquetes. |
| **Solución** | Deshabilitar `pbs-enterprise.sources`; el repositorio gratuito (`no-subscription`) ya estaba configurado. |
| **Verificación** | `apt-get update` sin errores. |
| **Lección** | Revisar los repositorios después de instalar cualquier componente de Proxmox y comprobar que las actualizaciones automáticas funcionan: un `apt update` roto impide también recibir parches de seguridad. |

## 2026-10-02 — Una VM se colgó por falta de memoria

| | |
|---|---|
| **Causa** | El ballooning había recortado la memoria de la VM a 2 GB y no tenía swap. |
| **Solución** | Mínimo de ballooning de 3 GB, 4 GB de swap en la VM y reparto del recorte con las otras máquinas. |
| **Lección** | Con poca RAM física, dimensionar los mínimos de cada guest y vigilar la memoria del host (hoy hay alertas a partir del 90 %). Pendiente: ampliar la RAM. |