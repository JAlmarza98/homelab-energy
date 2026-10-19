# CLAUDE.md — homelab-energy

Contexto para Claude Code. Léelo entero antes de tocar código.

## Qué es este proyecto

Controlador energético del homelab de Joel. Se apoya en **NUT (Network UPS Tools)**
y añade lo que NUT no hace: notificaciones, estado persistente, registro de eventos,
apagado ordenado de equipos sin cliente NUT y métricas propias.

**Decisión de arquitectura (no negociable sin discutirla):**
NUT detecta y decide; homelab-energy orquesta, avisa y registra.

- NO reimplementar en Bash lo que NUT ya hace: detección ONBATT/ONLINE (`upsmon`),
  temporizadores con cancelación (`upssched`), batería baja / FSD, corte final del SAI.
- Punto de entrada: `upssched` llama a `bin/homelab-energy event <evento>` como `CMDSCRIPT`.
- Proxmox se apaga como cliente `secondary` de NUT, no por SSH/API desde este proyecto.

## Topología (estado real, verificado)

| Equipo | IP | Rol NUT | Notas |
|---|---|---|---|
| RP-node2 (Raspberry Pi) | 10.0.0.21 | primary / netserver | SAI por USB. **Aquí corre homelab-energy.** Hostname `RP-node2` (mayúsculas) |
| Proxmox | 10.0.0.10 | secondary (`upsproxmox`) | `SHUTDOWNEXIT -1`, drop-in `Before=pve-guests.service` |
| RP-node1 (Raspberry Pi) | 10.0.0.20 | secondary (`upsrpnode1`) | Nodo de observabilidad (Prometheus/Grafana) |
| SAI | — | `apc@10.0.0.21` | APC Back-UPS 1600, driver `usbhid-ups`, batería de 2020-03 |

Todo (incluidos switch y OpenWRT) está enchufado al SAI.

### RP-node1: stack de observabilidad (ya existía, verificado 2026-10-19)

Prometheus, Grafana, Alertmanager, `node-exporter` (propio) y Uptime Kuma
corren en Docker, gestionados con Arcane (`ghcr.io/getarcaneapp/agent`).
No hace falta desplegar nada desde cero — las plantillas `templates/
docker-compose.observability.yml.example` y `prometheus.yml.example` de
este repo son solo referencia genérica para una instalación nueva.

- Config real de Prometheus: `/home/pi/monitoring-stack/prometheus/prometheus.yml`
  (bind-mount a `/etc/prometheus` dentro del contenedor `prometheus`).
  Jobs existentes: `raspberry` (su propio `node-exporter`, por nombre de
  contenedor Docker, no IP), `proxmox`, `proxmox-pve` (vía un exporter en
  `10.0.0.20:9221`). Añadidos por homelab-energy: `rp_node2`
  (`10.0.0.21:9100`) y `nut` (`10.0.0.21:9199`, `metrics_path: /ups_metrics`).
- Recargar tras editar: el contenedor `prometheus` **no** tiene la
  lifecycle API habilitada (`curl -X POST .../-/reload` falla) — hace
  falta `docker restart prometheus`. No pierde histórico: los datos
  viven en un volumen Docker aparte, no en el bind-mount de config.
- Dashboard de Grafana para NUT: ID `19308` ("Prometheus NUT Exporter for
  DRuggeri"), importado tal cual desde grafana.com.

## Comportamiento de NUT ya medido (no asumir otra cosa)

- Batería baja (LB) configurada en el SAI: `battery.runtime.low=1200`, `battery.charge.low=30`.
- `ups.delay.shutdown=180`: el SAI espera 180 s tras la orden final antes de cortar salida.
- **El primary solo espera ~60 s a los secondary** tras el FSD, aunque `HOSTSYNC=300`:
  un secondary que inicia su apagado deja de sondear y `upsd` lo desconecta por inactividad.
  El margen real para Proxmox lo da `ups.delay.shutdown`, no `HOSTSYNC`.
- Tras una prueba de FSD hay que limpiar en orden: en RP-node2 `rm -f /etc/killpower` y
  reiniciar `nut-driver@apc nut-server nut-monitor`; DESPUÉS reiniciar `nut-monitor` en los
  secondary (si se reinician con FSD activo, entran en modo apagado y no vuelven a sondear).
- La config de NUT no acepta caracteres no ASCII (sin tildes en mensajes).
- NUT 2.8.1 en ambos lados.
- **`upssched-cmd` no sirve como `NOTIFYCMD` en este NUT 2.8.1**: su reenvío
  vía pipe a un daemon `upssched` persistente (pensado para `START-TIMER`/
  `CANCEL-TIMER`) no hace nada — sin log, sin error, sin invocar `CMDSCRIPT`.
  `NOTIFYCMD /usr/sbin/upssched` directo sí funciona (verificado con corte
  real en RP-node2, 2026-10-19): `upsmon` pone `UPSNAME`/`NOTIFYTYPE` como
  variables de entorno (sin argumentos de línea de comandos) y `upssched`
  procesa las reglas `AT` de inmediato. Como `upssched.conf` aquí solo usa
  `EXECUTE` inmediato (sin temporizadores), el daemon/pipe de `upssched-cmd`
  no aporta nada de todas formas. `PIPEFN`/`LOCKFN` siguen siendo
  obligatorios en `upssched.conf` aunque no se use ningún temporizador.
- El usuario que invoca `NOTIFYCMD` es el proceso `upsmon` con privilegios
  reducidos (`nut` en este Pi, separado del proceso root que hace el
  apagado real), no `pi`. Dos consecuencias verificadas: (1) `chmod 700`
  en `/home/pi` bloquea el tránsito aunque todo lo de dentro sea legible —
  hace falta `chmod g+x` en el home y meter a `nut` en el grupo `pi`; (2)
  `/etc/homelab-energy/secrets.env` tiene que ser propiedad de `nut`
  (`config.sh` rechaza cargarlo si cualquier otro usuario puede leerlo,
  y eso incluye al propietario del checkout si no es el que invoca).
  `bin/homelab-energy-cmdscript` fija `STATE_DIR=/var/lib/homelab-energy`
  por el mismo motivo (el `state/` del propio checkout no es escribible
  por `nut`).
- `nut_exporter` (DRuggeri, no es parte de NUT) sirve las métricas de UPS
  en `/ups_metrics`, no en `/metrics` (eso son las métricas internas del
  propio exporter). `--web.listen-address` solo existe como flag de CLI,
  no tiene variable de entorno equivalente (verificado contra su
  `--help` real, v3.3.0) — a diferencia de `--nut.server`, que sí la
  tiene (`NUT_EXPORTER_SERVER`). `--nut.vars_enable` **sustituye** la
  lista por defecto, no la amplía — hay que escribirla completa si se
  quiere añadir algo (`battery.runtime` añadido para el dashboard de
  Grafana, confirmado disponible con `upsc apc@localhost`).
- El SAI (APC Back-UPS RS 1600MI) solo reporta `ups.realpower.nominal`
  (960, vatiaje nominal fijo de fábrica), nunca `ups.realpower` en vivo —
  normal en la gama Back-UPS, que no mide consumo real instantáneo. Un
  panel de Grafana atado a `ups.realpower` se queda sin datos siempre,
  no es un fallo de configuración.

## Reglas de seguridad (obligatorias)

- Nunca ejecutar `shutdown`, `poweroff`, `reboot`, `upscmd`, `upsdrvctl`, `upsmon -c fsd`
  ni `upsrw -s` fuera de un modo `--dry-run` explícito.
- Los tests no pueden tener efectos sobre hardware real: simular `upsc`, `upscmd`, etc.
  con stubs en un `PATH` temporal.
- Secretos (contraseñas NUT, tokens de notificación, API de Proxmox) nunca en Git:
  `.env` fuera del repo o `/etc/homelab-energy/secrets.env` con permisos 600.
- Fallar de forma segura: un error de notificación no puede bloquear ni retrasar un apagado.

## Convenciones del código

- Bash, `shellcheck` limpio, `shfmt` con la config de `.editorconfig` (indentación 4).
- Una responsabilidad por módulo en `lib/`. API pública sin prefijo; funciones privadas `_modulo_*`.
- Las librerías NO hacen `set -Eeuo pipefail` ni cargan otras librerías: eso lo hace
  `lib/bootstrap.sh` o el ejecutable de `bin/`.
- Rutas siempre derivadas de `PROJECT_ROOT` o de rutas de sistema configuradas; nunca relativas
  al directorio de trabajo (systemd).
- Config: formato `CLAVE=valor`, parseado (nunca `source`), capas
  `defaults.conf` → `energy.conf` → `hosts/$(hostname).conf`.
- Conventional Commits, commits pequeños. `make check` debe pasar antes de cada commit.
- La documentación refleja el código real, no planes.

## Bugs de v0.1.1 (corregidos — ver docs/roadmap.md para el detalle)

Todos corregidos. Lista conservada como referencia histórica de qué se
saneó antes de construir sobre ello:

1. ~~`.github/workflows/quality.yml`: `make format-ckeck` (errata) y el CI no ejecuta tests.~~
2. ~~`make test` usa `find -exec` y nunca falla aunque falle un test.~~
3. ~~`lib/test.sh`: `assert_false` es copia de `assert_success` (pasa si el comando tiene éxito).~~
4. ~~`format` usa `shfmt -i 4` y `format-check` no: diferencias perpetuas.~~
5. ~~Las librerías ejecutan `set -Eeuo pipefail` al cargarse.~~
6. ~~`lib/logger.sh`: `LOGGER_FILE_PATH` relativo; `LOG_LEVEL=INFO` de la config no se mapea al nivel numérico.~~
7. ~~`lib/config.sh` hace `source` de los `.conf` y usa `hosts.conf` en lugar de `hosts/<hostname>.conf`.~~
8. ~~`docs/roadmap.md` desfasado; `docs/coding-standarts.md` → `coding-standards.md`.~~

## Hoja de ruta

Ver `docs/roadmap.md` para el desglose completo de qué entrega cada
versión y qué queda pendiente de instalación manual en hardware real.

| Versión | Objetivo | Estado |
|---|---|---|
| v0.1.1 | Saneamiento: bugs anteriores, CI ejecutando `make check` completo | ✅ |
| v0.2.0 | `bootstrap.sh` + `config.sh` (parser, capas, validación int/bool, errores claros) + logger configurable | ✅ |
| v0.3.0 | `notify.sh` (un proveedor primero; secretos fuera de Git) + `nut.sh` (wrapper de `upsc`, solo lectura) | ✅ |
| v0.4.0 | `bin/homelab-energy event` enganchado a `upssched` → **primer uso en producción: avisos de corte/vuelta/batería baja** | ✅ verificado en RP-node2 con corte real (2026-10-19), notificaciones por Telegram |
| v0.5.0 | `state.sh`: JSON con `jq`, escritura atómica (tmp + `mv`), lock con `flock` | ✅ |
| v0.6.0 | Shutdown engine para equipos sin NUT (etapas configurables, timeouts, idempotencia, `--dry-run`) | ✅ (sin host real aún que lo necesite) |
| v0.7.0 | Observabilidad: `nut_exporter` en RP-node2, métricas propias vía textfile de node_exporter, Prometheus/Grafana en RP-node1 | ✅ completo y verificado en real (2026-10-19): `node_exporter`+textfile, `nut_exporter`, scrapeado por el Prometheus ya existente en RP-node1, dashboards de Grafana con datos reales |
| v0.8.0 | NAS (TrueNAS como secondary NUT nativo) y nuevos nodos | 🚫 bloqueado — no hay NAS real en la topología todavía |
| v1.0.0 | Prueba real con corte de red, runbook documentado | ✅ runbook (`docs/runbook.md`), ⏳ la prueba física queda pendiente |

**Backlog sin planificar** (ver `docs/roadmap.md` → "Backlog (not scheduled)"
para el detalle): reglas de Alertmanager sobre las métricas propias de
homelab-energy (`homelab_energy_last_event_timestamp` desfasado,
`notifications_failed_total` subiendo) — ya hay Alertmanager corriendo en
RP-node1, coste marginal bajo, no depende de v0.8.0/el NAS.

## Flujo de trabajo

- Desarrollo en el Mac (`brew install shellcheck shfmt jq flock`), `make check` en local.
  `flock` no viene de serie en macOS; el formula de Homebrew (discoteq/flock) es
  compatible con el `flock` de util-linux de Raspberry Pi para el uso que hace
  `lib/state.sh`, pero `-w 0` se comporta distinto entre ambos (evitarlo).
- Pruebas de integración en RP-node2 con `git pull` en `/home/pi/Projects/homelab-energy`.
- Instalación en producción: configuración en `/etc/homelab-energy/`, estado en
  `/var/lib/homelab-energy/`, logs vía journald.
