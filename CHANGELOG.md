# Registro de cambios

Todos los cambios importantes de dev-office se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [versionado semántico](https://semver.org/lang/es/):

- **Mayor** (1.0.0 → 2.0.0): cambios que obligan a modificar la configuración de los proyectos que ya usan la oficina.
- **Menor** (0.1.0 → 0.2.0): departamentos o funciones nuevas.
- **Parche** (0.1.0 → 0.1.1): correcciones de instrucciones o hooks.

## [0.18.1] - 2026-10-27

### Corregido

- Modo equipos: el developer y el tester de cada departamento (`dept-backend` 0.3.1, `dept-frontend` 0.4.1, `dept-database` 0.2.1, `dept-scraper` 0.2.1, `dept-devops` 0.3.1) ya no dicen que solo los activa el PM: reciben encargos del PM o del líder de su departamento y le reportan a quien les encargó el trabajo.
- Observer en el modo equipos (`office` 0.16.1): Claude Code identifica al líder como `<área>-lead` (por ejemplo `backend-lead`) en `agent_type` y `from_type`, no como `dept-<área>:lead`. La página ahora reconoce ese formato: con varios líderes activos, el aviso de "reporte listo" se le atribuye a su líder y el PM va a buscarlo, y las herramientas del líder aparecen en su escritorio.
- Resumen de tokens (`token-report.sh` versión 2): reconoce al líder como `<área>-lead`, y cada tarea queda con su líder y su encargo aunque haya varios líderes.
- Pruebas del formato `<área>-lead` en `tests/observer.test.sh`.

## [0.18.0] - 2026-10-26

### Agregado

- **Consumo de tokens en el informe del PM** (`office` 0.16.0): skill `usage` con el script `token-report.sh`. Del registro del observer arma una tabla de tokens por tarea de cada agente (proveedor, tarea, resultado y tokens; en los roles por Codex o Gemini, separa lo del proveedor y lo del puente), el total por agente con el promedio por tarea, y el total de la sesión por proveedor con el PM aparte. No llama a ningún modelo. El PM la agrega al final de cada informe al CEO, y el CEO la puede pedir con `/office:usage` (con `--prev`, la sesión anterior).
- Pruebas del resumen en `tests/observer.test.sh`.

## [0.17.2] - 2026-10-26

### Corregido

- Observer en el modo equipos (`office` 0.15.2): el PM ya no aparece hablando con el developer o el tester de un departamento que tiene líder. Si el encargo al developer o al tester llega de un compañero de equipo que la página no conocía (con un `agent_id` desconocido o sin él), ahora se le atribuye al líder del departamento, igual que el resultado del developer o del tester. El PM solo habla con los líderes; los líderes, con su gente.

## [0.17.1] - 2026-10-26

### Corregido

- `/office:observer` en WSL (`office` 0.15.1): abre la página con el navegador de Windows y da el link que ese navegador puede abrir (`file://wsl.localhost/<distro>/...`, o `file:///C:/...` si el proyecto está en el disco de Windows). Antes daba la ruta `/home/...`, que Windows no encuentra.
- La skill `observer` aclara que no hace falta abrirla en cada sesión: la pestaña puede quedar abierta y toma sola la sesión nueva.

## [0.17.0] - 2026-10-26

### Agregado

- **Modo equipos, opcional: un líder por departamento.** Agente `lead` en cada departamento (`dept-backend` 0.3.0, `dept-frontend` 0.4.0, `dept-database` 0.2.0, `dept-scraper` 0.2.0, `dept-devops` 0.3.0), en Sonnet. El PM le pasa el encargo al líder; el líder lo reparte entre su developer y su tester (por el puente si el rol va en Codex o Gemini), manda las fallas del tester de vuelta al developer (máximo 3 vueltas) y le entrega al PM un reporte en `.office/reports/` con qué se hizo, archivos, calidad, qué necesitan otros departamentos, acciones requeridas y pendientes. Usa los agent teams de Claude Code, que son experimentales y gastan más tokens. Sin activarlo, la oficina trabaja como siempre.
- `office-agents.sh teams on|off` (`office` 0.15.0, script versión 3): activa o desactiva el modo equipos para el equipo o, con `--local`, solo para vos. Anota `"teams"` en la configuración y `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` en el `env` de `.claude/settings.json` (o `settings.local.json`). `show` muestra el modo.
- PM: sección "Modo equipos" (crea a los líderes como compañeros de equipo, lee sus reportes, les responde las aprobaciones, les devuelve los bloqueantes de QA) y las herramientas de equipo (`SendMessage` y las de tareas).
- Observer: anota los encargos de los líderes, los mensajes entre el PM y los líderes, y los eventos TeammateIdle, TaskCreated y TaskCompleted.
- **Observer con más vida:** los líderes en cada departamento; la gente se levanta y camina a hablar con su líder; el tester le lleva la falla al developer, que se rasca la cabeza; quien pasa los tests festeja; el PM va a buscar el reporte a cada departamento que termina; con dos QA o más, debaten sus hallazgos frente a la pizarra; el PM espera en el pasillo, al lado de la puerta de Reuniones, y entra cuando el CEO lo llama (cuando le escribís); en los ratos libres alguien va por un café, se estira o charla con alguien libre de su departamento o de otro, con más de 100 conversaciones distintas. Las animaciones salen solo de los eventos nuevos. La demo muestra el flujo con líderes y el debate de los QA.

### Cambiado

- Observer: los escritorios de cada departamento suben para dejar lugar al líder.
- Arquitectura: los agent teams pasan de "descartados" a modo opcional.

## [0.16.0] - 2026-10-26

### Agregado

- Skill `update` (`office` 0.14.0): `/office:update` deja en `.claude/` del proyecto, y si el CEO quiere en el Escritorio, el script `update-office.sh` con sus lanzadores de doble click: `update-office.cmd` (Windows) y `update-office.command` (macOS). Con un click actualiza el marketplace y todos los plugins de dev-office instalados en la computadora: los de usuario una vez, y los de proyecto en la carpeta de cada proyecto donde estén (los lista `claude plugin list --json`). Saltea los proyectos que ya no existen y no toca plugins de otros marketplaces. Después refresca en cada proyecto los scripts que la oficina copió en `.claude/` si hay una versión más nueva y muestra las versiones antes y después.
- Pruebas: `tests/update-office.test.sh` (con un `claude` falso), también en el CI.

### Cambiado

- `office-setup`: ofrece dejar el botón de actualización al terminar.
- `.gitattributes`: los `.command` van con finales de línea LF.

## [0.15.0] - 2026-10-26

### Agregado

- **Observer en pixel art** (`office` 0.13.0): una página local que muestra la oficina en vivo. Las ocho oficinas con sus empleados en pixel art de 32 bits (cara, peinado, ropa y accesorios por rol, gestos según el estado), el PM caminando hacia el departamento al que le encarga trabajo, y para cada empleado su proveedor (Claude, Codex o Gemini), modelo, tarea, la herramienta que está usando, su resultado y sus tokens. Debajo: tokens totales y por proveedor, quién trabaja, tiempo de la sesión, fallas del tester, el recorrido de la sesión, la ficha del empleado con su retrato y la actividad. Los departamentos sin instalar se ven apagados. Sin actividad, muestra una demo.
- Hook `observer.sh`: anota los eventos de la sesión en `.office/observer/events.js` (encargos, herramientas, veredictos, avisos y tokens exactos leídos de las transcripciones). No imprime nada, no llama a ningún modelo y nunca bloquea. Se apaga con `OFFICE_OBSERVER=off`.
- El puente (`run-external.sh`) anota el inicio y el fin de cada encargo a Codex o Gemini, con los tokens que informe el CLI.
- Skill `observer`: `/office:observer` copia la página al proyecto y la abre en el navegador, en Windows, macOS y Linux.
- Pruebas: `tests/observer.test.sh`, también en el CI.

### Quitado

- La recomendación de agents-observe en la instalación: el observer propio lo reemplaza, sin Docker.

## [0.14.0] - 2026-10-26

### Agregado

- **Proveedores por rol** (`office` 0.12.0): cada rol de la oficina lo puede hacer Claude, Codex o Gemini, con modelo opcional (`codex:gpt-6.1-sol`, `claude:opus`). Se configura por proyecto en `.claude/office-agents.json` (el del equipo) y `.claude/office-agents.local.json` (el personal, que manda rol por rol). Un rol sin configurar sigue en Claude con el modelo de siempre.
- **Modelos a la par de Claude:** cada rol usa en Codex o Gemini el modelo del mismo nivel que su agente de Claude, con razonamiento medio. Nivel Opus (QA, arquitectos y asesores del PM): `gpt-6-astra` y `gemini-4-argon`. Nivel Sonnet (developers, testers y designer): `gpt-6.1-sol` y `gemini-3.8-flash`. El proyecto puede cambiar la tabla y el razonamiento con `office-agents.sh tier`; un rol con modelo propio no la usa.
- **Gemini con Antigravity CLI** (`agy`) y la cuenta de Google, porque Gemini CLI ya no atiende cuentas personales.
- Skill `office-agents`: instala en el proyecto el script de configuración `.claude/office-agents.sh` (menú interactivo y comandos `show`, `roles`, `set`, `reset`, `get`, `models`, `tier`, `model`, `effort` y `check`) y `.claude/office-agents.cmd` para usarlo desde CMD o PowerShell en Windows. `check` verifica que los CLIs estén instalados y con sesión, que Codex sea 0.153.0 o más nuevo si se usa GPT-6 Astra y que la cuenta de Google tenga los modelos de la tabla (`agy models`).
- Agente `external` (Sonnet), el puente a Codex y Gemini, y skill `external-agents` con el script `run-external.sh`:
  - arma el prompt con las reglas de la oficina para el proveedor, las instrucciones del agente del rol, las skills que usa y el encargo;
  - corre `codex exec` (sandbox `workspace-write`, sin pedir aprobación) o `agy -p` (`--mode accept-edits`, leyendo el encargo de un archivo), con el modelo y el razonamiento del nivel del rol y tope de tiempo (`OFFICE_EXTERNAL_TIMEOUT`, 540 segundos);
  - antes, no corre nada en una rama protegida; después, marca si tocó secretos, claves o lockfiles, si escribió fuera de lo que permite el rol, si commiteó (y revisa los archivos del commit) o si cambió de rama;
  - el puente verifica: typecheck, lint y tests en un developer (con una vuelta de corrección como máximo) y el resultado real en un tester.
- **Asesores del PM:** el PM sigue siendo Claude, pero si `pm` tiene proveedores configurados, les pide una segunda opinión (en solo lectura) antes de presentar un plan que no es trivial o un diseño, y le muestra al CEO en qué coinciden y en qué no.
- **QA con varios proveedores:** revisión independiente, una ronda de validación cruzada (confirmado, refutado o sin verificar) y consolidación del PM. Lo refutado con pruebas queda en disputa, nunca es bloqueante y va al CEO con los dos argumentos.
- Guía `docs/providers.md`: qué se puede configurar, el valor por defecto (todo en Claude), los modelos por nivel, cómo instalar y configurar cada proveedor, cómo trabajan el puente, el QA con varios proveedores y los asesores, qué hacer si algo sale mal y los límites.
- Pruebas: `tests/office-agents.test.sh` y `tests/run-external.test.sh` (con CLIs falsos de `codex` y `agy`), también en el CI.

### Cambiado

- `pm`: lee la configuración de proveedores antes de encargar, activa al puente para Codex y Gemini, frena y le pregunta al CEO si un proveedor no está disponible o si rompió una regla, e incluye los proveedores en el plan y en el informe.
- `qa`: modo validación para revisar los hallazgos de otro QA.
- Todos los agentes de Claude declaran `effort: medium`, para que el razonamiento quede parejo con Codex y Gemini aunque la sesión use otro nivel. Claude Code lee ese campo en los agentes, pero todavía no lo documenta. Versiones: `dept-backend` 0.2.2, `dept-frontend` 0.3.1, `dept-database` 0.1.2, `dept-scraper` 0.1.3, `dept-devops` 0.2.1.
- `office-setup`: ofrece configurar los proveedores por rol, agrega `.office/` y la configuración personal a `.gitignore` y permite `office-agents.sh show` y `check`.

## [0.13.0] - 2026-10-22

### Agregado

- Skill `handoff-ticket` en `office` (0.11.0): cuando un cambio obliga a otro equipo a adaptarse (por ejemplo, el backend cambió la API y el front web o la app móvil no se tocaron en esa rama), busca en Jira el ticket de cada equipo afectado: los vinculados al ticket de origen, los de la misma épica con el componente, etiqueta o prefijo del equipo, y por texto. Al elegido le agrega a la descripción una sección "Cambios de API desde PROJ-123" (qué cambió, endpoints, qué tiene que hacer el equipo, compatibilidad y colecciones de Postman) y un comentario corto, y lo vincula con el de origen. Si no hay ticket, propone crearlo en la misma épica. Antes de escribir le muestra el texto al CEO y, si el ticket no tiene responsable, le pregunta a quién se asigna. No cambia el estado de esos tickets. Se usa como `/office:handoff-ticket` o desde `open-pr`.

### Cambiado

- `open-pr`: después de abrir el PR, si la rama cambia algo que usa otro equipo, avisa con `handoff-ticket`. No lo hace en el PR de una épica completa ni en el segundo PR de un hotfix.
- `pm`: avisar a los otros equipos es la tercera excepción a "en Jira solo leés", siempre con confirmación del CEO; el informe dice qué equipos tienen que adaptarse.
- `office-setup`: en la parte de Jira pregunta qué clientes usan la API, cómo se reconocen sus tickets y qué tipo de ticket usan.
- `developer` (`dept-backend` 0.2.1): la sección "Cambios en la API" de su reporte dice, por endpoint, qué cambia para quien lo usa, si rompe a los clientes actuales y qué tienen que hacer.

## [0.12.0] - 2026-10-22

### Agregado

- `dept-backend` (0.2.0): skill `api-collection`. Colecciones de Postman (formato v2.1) en `docs/api/` o la carpeta que diga el `CLAUDE.md` del proyecto, con entornos compartidos (`environments/`), autorización a nivel colección, un script de login que guarda los tokens y un README para importarlas:
  - **La del proyecto**, una sola, con toda la API (REST y GraphQL) ordenada por recurso, variables para encadenar requests y ejemplos de respuesta. Si no existe, se genera completa leyendo el código; después se actualiza solo lo que cambia.
  - **Una por épica** (`docs/api/epics/PROJ-100-<resumen>.postman_collection.json`), con los flujos de la épica en orden, cada paso encadenado al siguiente y con su test, para correrlos con el Collection Runner. Se crea con el primer ticket de la épica que toca endpoints y, cuando la épica se integra, queda como prueba de regresión.
  - Cuando cambia un endpoint, se actualizan la del proyecto, la de la épica del ticket y cualquier otra que lo use.
  - WebSocket, gRPC, SSE y subscriptions quedan documentados en el README.
- Script `check-collection.sh` (en la skill): revisa la colección del proyecto y las de épica: que haya una sola del proyecto, el formato v2.1, un `_postman_id` distinto por colección, nombres repetidos, URLs sin `{{baseUrl}}`, secretos escritos (variables, autorizaciones, headers `Authorization` y JWT pegados), que cada paso de una épica tenga su script de test y que las variables estén declaradas en todos los entornos. Con `--fix` deja un formato fijo (claves ordenadas, sangría de 2, LF) para que los diffs entre ramas sean chicos. Pruebas en `tests/api-collection.test.sh` y en el CI.

### Cambiado

- `developer` (backend): si toca endpoints, operaciones de GraphQL o la autenticación, actualiza las colecciones (la del proyecto, la de la épica y las que usen el endpoint) en el mismo encargo y lo informa en su reporte.
- `tester` (backend): revisa las colecciones con el script, las compara con el código y lee los flujos de la épica de punta a punta; que falte un endpoint es una falla.
- `architect` (backend): avisa en el diseño si cambia la autenticación o hacen falta variables nuevas, describe los flujos principales de la épica e incluye las colecciones en el plan.
- `pm` (`office` 0.10.0): las colecciones son parte del criterio de terminado de todo encargo que toque endpoints; le pasa la épica del ticket al backend, le da al frontend las rutas de las colecciones, puede encargar la del proyecto completa cuando el CEO la pide y las incluye en el informe.
- `qa`: revisa que las colecciones no tengan secretos ni datos reales, que coincidan con los contratos y que los tests de los flujos fallen cuando el flujo se rompe.
- `office-setup`: pregunta si el proyecto quiere las colecciones, su carpeta, entornos y autorización, y propone la sección "Colección de API" del `CLAUDE.md`.

## [0.11.0] - 2026-10-20

### Cambiado

- `start-ticket` (`office` 0.9.0): al crear o retomar la rama, pasa el ticket a "en curso" en Jira sin preguntar (el estado que defina el flujo del proyecto, o el primero de la categoría "en curso"). No lo mueve si ya está en ese estado o en uno posterior, si es una épica o si está asignado a otra persona (en ese caso avisa).
- `open-pr`: al abrir el PR, pasa el ticket a revisión sin preguntar aunque el proyecto no defina el estado: busca uno de revisión por su nombre. Si no lo encuentra o hay más de uno, no pregunta: lo dice en el cierre.
- `pm`: las dos transiciones automáticas son la excepción a "en Jira solo leés".
- `office-setup`: pregunta los nombres exactos de los estados de "en curso" y de revisión para dejarlos en el flujo del proyecto.

## [0.10.0] - 2026-10-17

### Agregado

- `dept-frontend` (0.3.0): skill `design-intake`. Lee un diseño que ya existe (imágenes en `docs/design/references/` o links de Figma) y lo convierte en una especificación con textos exactos, estilos asociados a los tokens del proyecto (lo aproximado, marcado) y la lista de lo que el diseño no define.
- `designer`: distingue entre diseño propio y diseño entregado; con diseño entregado traduce sin proponer otra experiencia. Puede leer Figma con las herramientas de solo lectura del servidor MCP `figma`, cuidando el límite de llamadas.
- `developer` (frontend): compara lo que construye con las imágenes de referencia de la especificación.
- `pm` (`office` 0.8.0): si el CEO pega imágenes de diseño en el chat, le pide guardarlas en el proyecto antes de activar al designer, porque los agentes no ven las imágenes del chat.
- `office-setup`: pregunta si los diseños los entrega otro y ofrece conectar el servidor remoto de Figma en `.mcp.json`.

### Cambiado

- Soporte para **Windows nativo** (bash de Git for Windows, sin WSL):
  - Los hooks normalizan rutas de Windows (`C:\dev\app`) antes de compararlas, y en Windows comparan sin distinguir mayúsculas.
  - Los hooks y `setup.sh` toleran el jq de Windows, que escribe finales de línea CRLF. Sin esto, `protect.sh` dejaba editar `.env` en Windows.
  - Funciones comunes de los hooks en `scripts/lib.sh`.
  - Instrucciones para instalar `jq` y `gh` en Windows (`winget`), macOS (`brew`) y Linux (`apt`) en la documentación, `office-setup`, `open-pr` y `review-fixes`.
- Tests de rutas de Windows, jq con CRLF y falta de jq.

## [0.9.1] - 2026-10-15

### Cambiado

- `pm` (`office` 0.7.2): un ticket nuevo se crea solo cuando el CEO lo pide, y antes se le pregunta a quién se asigna o si queda sin asignar.

## [0.9.0] - 2026-10-15

### Agregado

- `dept-devops` (0.2.0): agente `architect` (Opus). Diseña entornos, pipelines de CI/CD, estrategia de despliegue y de vuelta atrás, credenciales y secretos, infraestructura, migraciones en el despliegue, observabilidad y costos en `docs/design/`, con la lista de acciones que tiene que hacer el CEO. Puede leer las corridas de GitHub Actions; no escribe código ni configuración.
- `dept-frontend` (0.2.0): agente `architect` (Opus). Diseña la parte técnica del front (estructura, rutas, estado, datos y caché, código compartido entre web y móvil, rendimiento, errores y sin conexión, seguridad del cliente) partiendo del diseño de experiencia del designer.

### Cambiado

- `pm` (`office` 0.7.1): fase de diseño con el orden arquitecto de backend → designer → arquitecto de frontend → arquitecto de DevOps, cada uno con los diseños anteriores. Definir o cambiar cómo se despliega el proyecto pasa por diseño.
- `designer`: define la experiencia; la parte técnica es del arquitecto de frontend.

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
