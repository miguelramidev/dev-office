# Registro de cambios

Todos los cambios importantes de dev-office se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [versionado semántico](https://semver.org/lang/es/):

- **Mayor** (1.0.0 → 2.0.0): cambios que obligan a modificar la configuración de los proyectos que ya usan la oficina.
- **Menor** (0.1.0 → 0.2.0): departamentos o funciones nuevas.
- **Parche** (0.1.0 → 0.1.1): correcciones de instrucciones o hooks.

## [0.1.3] - 2026-10-12

### Cambiado

- `qa`: un bloqueante tiene que afectar el alcance actual; los riesgos hipotéticos o futuros se reportan como importantes o mejoras.
- `pm`: regla de proporcionalidad; si dos rondas seguidas no avanzan la tarea principal, consulta al CEO.

## [0.1.2] - 2026-10-12

### Cambiado

- `pm`: la descripción de cada encargo empieza con el rol entre corchetes, para identificar a cada agente en registros y dashboards.
- `qa`: los comandos de ataque nunca usan archivos reales del proyecto como destino o salida; reglas más explícitas sobre qué herramientas usar para leer y buscar.

## [0.1.1] - 2026-10-10

### Corregido

- `office-setup`: ya no propone reglas de permisos con `*` antes del subcomando, que Claude Code marca como inseguras porque aprueban cualquier opción en esa posición.
- Documentación: problema conocido de reglas con comodín en `docs/installation.md`.

## [0.1.0] - 2026-10-10

### Agregado

- Esqueleto del repositorio: marketplace, licencia MIT, README y documentación.
- Plugin `office` (0.1.0):
  - Agente `pm` (Opus): conversa con el CEO en modo reunión o ejecución, activa departamentos y coordina el ciclo de calidad.
  - Agente `qa` (Opus): el enemigo de la app; busca defectos con prueba de reproducción y verifica las reglas del proyecto.
  - Hook `protect.sh`: bloquea la edición de secretos, claves privadas, lockfiles y la carpeta `.git`.
  - Hook `activity.sh`: registra cuándo empieza y termina cada agente en `.claude/office-activity.log`, con zona horaria configurable (`OFFICE_TIMEZONE`).
  - Skill `office-setup`: prepara un proyecto con permisos base, modo de permisos, zona horaria y `.gitignore`, sin borrar la configuración existente.
  - El PM queda como agente predeterminado de la sesión.
- Plugin `dept-scraper` (0.1.0), depende de `office`:
  - Agente `developer` (Sonnet): construye scrapers siguiendo las reglas del proyecto y sus skills propias.
  - Agente `tester` (Sonnet): prueba scrapers con fixtures reales y dependencias falsas, sin red.
  - Skill `responsible-scraping`: fuente, identificación, ritmo, reintentos, bloqueos, costos, fixtures, validación, codificación y dinero.
