# Registro de pruebas de restauración

## 3 de octubre de 2026 — VM de laboratorio

| | |
|---|---|
| **Qué se probó** | Restauración completa de una VM desde Proxmox Backup Server |
| **Origen** | Última copia de la VM de laboratorio en el datastore de PBS (disco USB) |
| **Destino** | VM temporal con un ID nuevo, para no tocar el original |
| **Resultado** | Correcto: la copia restaurada arrancó y se verificó |
| **Limpieza** | La VM temporal se eliminó al terminar |

**Observaciones útiles**

- La primera copia de la VM ocupó ~6,7 GB en el datastore. La segunda, hecha tras activar el seguimiento incremental, transfirió solo ~40 MiB y tardó ~2 s (deduplicación y dirty-bitmap).
- Se restauró a un ID distinto para poder comparar con el original sin riesgo de conflicto.

**Para la próxima prueba**

- [ ] Restaurar la VM de Home Assistant y comprobar que ZHA reconoce el coordinador tras el passthrough.
- [ ] Restaurar una muestra de fotos con `restic` y abrir varios ficheros.
- [ ] Medir el tiempo total (RTO) y anotarlo aquí.

## Plantilla para nuevas pruebas

```text
Fecha:
Qué se restaura:
Copia utilizada (fecha):
Destino (ID/carpeta temporal):
Tiempo total:
Resultado (OK / fallos):
Problemas y lecciones:
Limpieza hecha (sí/no):
```
