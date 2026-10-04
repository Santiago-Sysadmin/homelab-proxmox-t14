# Registro de incidencias

Problemas reales encontrados en el sistema, su causa y cómo se resolvieron. Mantenerlo es parte de operar el servidor: las copias y las alertas solo valen si se revisan.

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