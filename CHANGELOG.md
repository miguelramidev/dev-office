# Registro de cambios

Todos los cambios importantes de dev-office se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [versionado semántico](https://semver.org/lang/es/):

- **Mayor** (1.0.0 → 2.0.0): cambios que obligan a modificar la configuración de los proyectos que ya usan la oficina.
- **Menor** (0.1.0 → 0.2.0): departamentos o funciones nuevas.
- **Parche** (0.1.0 → 0.1.1): correcciones de instrucciones o hooks.

## [0.8.0] - 2026-10-14

### Agregado

- Plugin `dept-devops` (0.1.0), depende de `office`:
  - Agente `developer` (Sonnet): CI/CD (GitHub Actions y similares), despliegues por entorno, infraestructura como código, contenedores y procesos en servidores, y diagnóstico de pipelines y deploys que fallan leyendo sus logs (`gh run view --log-failed`). Nunca despliega, aplica infraestructura, entra a servidores ni toca valores de secretos: deja todo listo y le dice al CEO qué ejecutar.
  - Agente `tester` (Sonnet): valida sin desplegar ni usar credenciales reales: sintaxis, disparadores, permisos, manejo de secretos, inyección en `run:`, versiones fijadas, build local y scripts.
  - Skill `solid-devops`: lo que nunca se hace, pipelines reproducibles, seguridad de GitHub Actions, despliegues con aprobación y vuelta atrás, migraciones en el despliegue, infraestructura como código, contenedores, procesos en servidores, observabilidad, costos y cómo diagnosticar un pipeline que falla.
- Skills de la comunidad: las de HashiCorp para Terraform y Packer, recomendadas por `office-setup` cuando el proyecto tiene archivos `*.tf`.

### Cambiado

- `pm`: DevOps va al final (o solo, para tareas de pipelines e infraestructura) y diagnostica los deploys y corridas de CI que fallan.
- `office-setup`: permite ver las corridas de GitHub Actions; disparar o re-ejecutar workflows, cambiar variables de GitHub, aplicar infraestructura, `kubectl` y SSH piden confirmación; cambiar secretos de GitHub y destruir infraestructura quedan prohibidos.
- `office` 0.7.0.

## [0.7.0] - 2026-10-14

### Agregado

- `open-pr`: si el flujo del proyecto dice a qué estado pasa el ticket al abrir el PR (por ejemplo "REVIEWING"), lo mueve solo después de abrirlo, avanzando de a un estado si el flujo de Jira lo exige, nunca hacia atrás ni más allá del estado de revisión. Las épicas se siguen consultando. Si el proyecto no lo define, pregunta como antes.

### Cambiado

- `pm`: Jira sigue siendo de solo lectura, salvo los cambios que el flujo del proyecto autoriza a hacer solos.
- `office` 0.6.0.

## [0.6.2] - 2026-10-14

### Cambiado

- dev-office queda independiente de cualquier proyecto: los ejemplos de tickets usan `PROJ-123`, la zona horaria de ejemplo es genérica, y las reglas de dinero de `solid-backend`, `solid-frontend`, `solid-database` y el tester de frontend ya no nombran una moneda ni un país (la moneda y el formato los define el `CLAUDE.md` de cada proyecto).
- `docs/architecture.md` y `CLAUDE.md` del repositorio: la regla de que nada en los plugins se ata a un proyecto.
- Versiones: `office` 0.5.2, `dept-backend` 0.1.2, `dept-frontend` 0.1.2, `dept-database` 0.1.1.

## [0.6.1] - 2026-10-13

### Cambiado

- `start-ticket` y `open-pr`: un ticket de tipo Hotfix se trata como hotfix (sale de producción y el PR va a producción y a la base), igual que uno con la etiqueta `hotfix`. Los tipos Flaw y Defect usan el prefijo `fix/`, como Error y Bug, y el tipo Refactor usa `refactor/`.
- `pm` y `qa`: en un refactor el comportamiento no puede cambiar. El PM se lo avisa a cada departamento, y para QA es bloqueante modificar un test existente, cambiar lo que recibe quien usa el código o agregar una función.
- `open-pr`: en un refactor confirma que no cambió ningún test existente ni lo que recibe quien usa el código, y lo dice en la descripción del PR.
- `open-pr`: solo ofrece mover el ticket a un estado al que el flujo de Jira permite pasar, sin saltear columnas.
- `office` 0.5.1.

## [0.6.0] - 2026-10-13

### Agregado

- Skill `open-pr` en `office`: abre el PR de la rama actual con `gh`. Corre las verificaciones del proyecto, elige el destino según el ticket de Jira (su épica, la rama base o producción si es hotfix), arma el título y la descripción con la clave del ticket y se los muestra al CEO; solo con su confirmación sube la rama y abre el PR. Se usa como `/office:open-pr` o pidiéndoselo al PM.
- Skill `review-fixes` en `office`: lee lo que dejó la revisión de un PR (comentarios sin resolver, reseñas, checks que fallan y los commits que el CEO hizo a mano), arma una lista para que el CEO la confirme y corrige cada punto con el departamento que corresponde y el ciclo de calidad. Commit, push y respuestas en el PR, solo con confirmación. Se usa como `/office:review-fixes` o pidiéndoselo al PM.
- `office-setup`: permite los comandos de `gh` de solo lectura; abrir PRs, comentar y `gh api` piden confirmación; mergear PRs y borrar repositorios quedan prohibidos.

### Cambiado

- `pm`: usa `open-pr` y `review-fixes`, ofrece abrir el PR cuando un ticket queda terminado, y nunca mergea ni aprueba PRs ni publica en GitHub sin que el CEO lo pida.
- `office` 0.5.0.

## [0.5.0] - 2026-10-13

### Agregado

- Hook `branch-guard.sh` en `office`: no deja editar archivos del proyecto, commitear ni mergear sobre las ramas protegidas, ni hacer push hacia ellas. Las ramas se configuran con `OFFICE_PROTECTED_BRANCHES`, con nombres o patrones (por ejemplo `main dev epic/*`); por defecto, `main` y `master`. Pruebas en `tests/branch-guard.test.sh` y en el CI.
- Skill `start-ticket` en `office`: trae un ticket de Jira con el servidor MCP de Atlassian y, según lo que dice el ticket, crea o retoma su rama. El tipo decide el prefijo (`epic/`, `feature/`, `task/`, `fix/`), la épica padre decide de qué rama sale y a dónde va el PR, la etiqueta `hotfix` la hace salir de producción, y las subtareas se trabajan en la rama de su padre. Se usa como `/office:start-ticket DBA-70` o pidiéndoselo al PM.
- `office-setup`: pregunta las ramas protegidas (opción `--protected` de `setup.sh`), permite los comandos de git que usa `start-ticket` y ofrece conectar Jira con `.mcp.json`.

### Cambiado

- `pm`: tiene las herramientas `Skill` y las del servidor `atlassian`. Nunca trabaja sobre una rama protegida, usa `start-ticket` cuando el CEO nombra un ticket, solo lee Jira (los cambios en tickets los decide el CEO) e incluye el ticket y la rama en el informe.
- `office` 0.4.0.

## [0.4.0] - 2026-10-13

### Agregado

- Plugin `dept-database` (0.1.0), depende de `office`:
  - Agente `developer` (Sonnet), el DB manager: esquemas, migraciones, índices, restricciones, seeds y consultas pesadas en Postgres y MongoDB. Nunca ejecuta nada contra bases reales.
  - Agente `tester` (Sonnet): prueba que las migraciones suben, bajan y conservan los datos, que las restricciones rechazan lo inválido y que las consultas usan los índices, solo en la base de pruebas del proyecto.
  - Skill `solid-database`: lo que nunca se hace, migraciones seguras (expandir y contraer, reversibles, copias de datos en lotes), tablas grandes sin bloquear, integridad, tipos, índices y consultas, MongoDB, datos personales y datos de prueba.
- Soporte para skills de la comunidad: las skills oficiales de Supabase (Postgres), MongoDB, Vercel (React, Next.js, React Native) y Expo. Guía en `docs/community-skills.md`.
- `office-setup`: recomienda las skills de la comunidad que corresponden al stack del proyecto, con sus comandos de instalación y el aviso sobre el servidor MCP de MongoDB.

### Cambiado

- Todos los agentes de departamento y el QA tienen la herramienta `Skill`, para usar las skills del proyecto y las de la comunidad. Antes los agentes con `tools` explícito no podían invocarlas.
- `solid-backend`, `solid-frontend` y `solid-database`: sección "Skills de la comunidad" con las recomendadas y la regla de que las de dev-office mandan en seguridad, aprobaciones y límites.
- `pm`: el backend recibe la sección "Cambios en los datos" del reporte de base de datos.
- Versiones: `office` 0.3.0, `dept-backend` 0.1.1, `dept-frontend` 0.1.1, `dept-scraper` 0.1.2.

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
