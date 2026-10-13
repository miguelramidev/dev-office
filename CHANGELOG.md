# Registro de cambios

Todos los cambios importantes de dev-office se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [versionado semántico](https://semver.org/lang/es/):

- **Mayor** (1.0.0 → 2.0.0): cambios que obligan a modificar la configuración de los proyectos que ya usan la oficina.
- **Menor** (0.1.0 → 0.2.0): departamentos o funciones nuevas.
- **Parche** (0.1.0 → 0.1.1): correcciones de instrucciones o hooks.

## [0.3.0] - 2026-10-12

### Agregado

- Plugin `dept-frontend` (0.1.0), depende de `office`:
  - Agente `designer` (Sonnet): diseña flujos, pantallas web y móviles, estados, textos y accesibilidad antes de programar, y lo deja en `docs/design/` para que el CEO lo apruebe. Si el arquitecto ya escribió un diseño para la tarea, agrega sus secciones al mismo documento. No escribe código.
  - Agente `developer` (Sonnet): construye pantallas y componentes en Next.js, React y React Native siguiendo el diseño aprobado, sin tocar el backend.
  - Agente `tester` (Sonnet): prueba estados, respuestas raras de la API, formularios, dinero y fechas, interacciones y textos, buscando elementos como los encuentra el usuario.
  - Skill `solid-frontend`: marca y componentes, estados de cada pantalla, datos de la API, formularios, dinero y fechas, accesibilidad, rendimiento, Next.js, React Native, seguridad y textos.

### Cambiado

- `pm` (`office` 0.2.1): el informe al CEO incluye qué pantallas revisar a ojo cuando se tocó una interfaz, porque los agentes no las pueden ver.

## [0.2.0] - 2026-10-12

### Agregado

- Plugin `dept-backend` (0.1.0), depende de `office`:
  - Agente `architect` (Opus): diseña la API, el flujo de datos, los cambios al modelo, la seguridad y los costos antes de programar, y lo deja en `docs/design/` para que el CEO lo apruebe. No escribe código.
  - Agente `developer` (Sonnet): implementa el backend siguiendo el diseño aprobado.
  - Agente `tester` (Sonnet): prueba contratos, entradas caóticas, permisos, dinero y fechas, servicios externos e idempotencia, sin servicios reales.
  - Skill `solid-backend`: contratos y validación, errores, permisos, dinero y fechas, base de datos, servicios externos, seguridad, costos, logs y estructura.
- `pm`: fase de diseño. Para funciones nuevas o cambios grandes activa a los roles de diseño, presenta la propuesta al CEO y no implementa hasta que la apruebe. Los bugs y ajustes chicos van directo al developer.
- Validación automática en GitHub Actions: marketplace, plugins, sintaxis de los scripts y pruebas del hook de protección (`tests/protect.test.sh`).

### Cambiado

- `pm`: orden entre departamentos diseño → base de datos → backend → frontend; el frontend recibe los cambios de la API del reporte del backend.
- `office-setup`: bloquea la lectura de más variantes de `.env` (`.env.staging`, `.env.test`, las `.local`) y también en subcarpetas.

### Corregido

- `office`: la versión del plugin no se había actualizado desde 0.1.1, así que los proyectos instalados no recibían los cambios de 0.1.2 y 0.1.3.
- Hook `protect.sh`: también revisa `NotebookEdit` y los comandos de Bash, para que no se puedan leer ni modificar secretos o claves privadas con `cat`, `sed`, `echo` o `cp`.
- Documentación: `docs/add-departament.md` pasa a `docs/add-department.md`, que es el nombre al que apuntaba el README.
- `dept-scraper` (0.1.1): autor unificado.

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
