---
name: start-ticket
description: Empieza el trabajo de un ticket de Jira - lo trae con el servidor MCP de Atlassian y, según lo que diga el ticket (tipo, épica padre, etiquetas), crea o retoma la rama con el prefijo correcto desde la rama que corresponde (la épica, la rama base o la de producción) y dice a qué rama va el PR. Usar cuando el CEO pide trabajar en un ticket (por ejemplo "trabajemos en DBA-70") o antes de cualquier cambio si se está en una rama protegida.
argument-hint: <TICKET, por ejemplo DBA-70>
---

Vas a preparar el trabajo del ticket `$ARGUMENTS`. Hablale al CEO en su idioma (si escribe en español, con voseo). Corré los comandos de a uno, sin unirlos con `&&` ni `;`.

Todo sale de lo que dice el ticket en Jira: su tipo decide el prefijo de la rama, su épica decide de qué rama sale y a dónde va el PR, y un ticket de tipo Hotfix (o con la etiqueta `hotfix`) sale de producción. No adivines: si un dato del ticket no alcanza para decidir, preguntale al CEO.

## 1. Leé el flujo de trabajo del proyecto

En el `CLAUDE.md` del proyecto y en `.claude/rules/` buscá el flujo de trabajo. Si define algo distinto a lo de abajo, manda lo del proyecto:

- **Rama base** (la de integración, por ejemplo `dev`). Si no lo dice, la rama por defecto del remoto (`git remote show origin`, línea "HEAD branch").
- **Rama de producción** (por ejemplo `main`). Si no lo dice, `main`.
- **Prefijos por tipo de ticket.** Si no los define, usá esta tabla:

| Tipo de ticket en Jira | Prefijo |
| --- | --- |
| Epic | `epic/` |
| Feature, Historia, Story | `feature/` |
| Tarea, Task, Request | `task/` |
| Error, Bug, Flaw, Defect | `fix/` |
| Hotfix, o cualquiera con la etiqueta `hotfix` | `hotfix/` |
| Subtarea, Subtask | sin rama propia: se trabaja en la rama de su padre |

Para un tipo que no esté en la tabla, preguntale al CEO qué prefijo usar.

Si `$ARGUMENTS` está vacío, preguntale al CEO qué ticket. Si no tiene el formato de un ticket de Jira (letras, guion, número), preguntale si es correcto antes de seguir.

## 2. Revisá el estado del repositorio

Corré `git status`. Si hay cambios sin commitear, frená: mostrale al CEO qué archivos tienen cambios y preguntale qué hacer (guardarlos en un commit en su rama actual, guardarlos con `git stash` o descartarlos él a mano). Nunca los descartes vos.

## 3. Traé el ticket de Jira

Usá las herramientas del servidor MCP de Atlassian:

1. `getAccessibleAtlassianResources` para obtener el `cloudId` del sitio (si hay varios, el que nombre el proyecto).
2. `getJiraIssue` con ese `cloudId` y la clave del ticket. Necesitás: título, tipo, estado, etiquetas, responsable, descripción y **padre** (el campo `parent`, con su clave y su tipo).

Si las herramientas de Atlassian no están disponibles, decíselo al CEO: tiene que conectar Jira con `/mcp` (servidor `atlassian`, opción de autenticar). Sin Jira no se puede saber el tipo ni la épica del ticket: frená. Si el ticket no existe, decilo y frená.

**Si es una subtarea**, traé también su padre con `getJiraIssue`: el trabajo se hace en la rama del padre. Avisale al CEO y seguí los pasos con el padre como ticket, recordando la subtarea para el informe.

**Si el ticket tiene una épica como padre** (directo, o a través de su padre si era una subtarea), anotá la clave de la épica.

Mostrale al CEO un resumen corto: clave, título, tipo, estado, responsable, épica (si tiene), etiquetas y la descripción (resumida si es larga, con los criterios de aceptación si los tiene).

## 4. Decidí la rama de origen y el destino del PR

| Caso | Sale de | El PR va a |
| --- | --- | --- |
| Hotfix (tipo Hotfix o etiqueta `hotfix`) | `origin/<producción>` | `<producción>`, y después un segundo PR de la misma rama a `<base>` |
| Epic | `origin/<base>` | `<base>`, cuando la épica está completa |
| Con épica padre que ya tiene rama | `origin/epic/<CLAVE-ÉPICA>-...` | esa rama de épica |
| Con épica padre que todavía no tiene rama | preguntale al CEO (ver abajo) | |
| Sin épica | `origin/<base>` | `<base>` |

Para encontrar la rama de la épica: `git fetch origin` y después `git branch --all --list "*epic/<CLAVE-ÉPICA>-*"`. Fijate que la clave sea exacta: `DBA-6-` no es `DBA-67-`.

Si la épica no tiene rama, preguntale al CEO:
- **Crear primero la rama de la épica.** Volvé a correr esta skill con la clave de la épica y después con este ticket.
- **Salir de `<base>`.** El trabajo va directo a la rama base, sin pasar por la épica.

## 5. Creá o retomá la rama

1. Armá el nombre: `<prefijo><CLAVE>-<resumen>`. La clave va tal cual (en mayúsculas) y el resumen es el título en minúsculas, sin acentos ni eñes, solo letras, números y guiones, de 6 palabras como máximo. Ejemplo: Feature DBA-70 "Manejo de productos en el carrito" → `feature/DBA-70-manejo-de-productos-en-el-carrito`.
2. Fijate si ya existe una rama con esa clave: `git branch --all --list "*/<CLAVE>-*"`, con la clave exacta.
   - **Si existe**, cambiate a ella (`git switch <rama>`, sin el `remotes/origin/` si es remota) y avisale al CEO que retomás el trabajo existente. Si su prefijo no coincide con el tipo actual del ticket, avisale, pero no la renombres.
   - **Si no existe**, creala desde la rama de origen del paso 4: `git switch -c <rama> <origen>`.
3. Confirmá con `git status` que quedaste en la rama correcta.

**Push:**
- Las ramas de trabajo no se suben ahora: se suben cuando haya trabajo para revisar y el CEO lo pida.
- **Una rama de épica nueva tiene que estar en GitHub** para que sus features salgan de ella. Las épicas están protegidas, así que no podés subirla vos: dale al CEO el comando para que lo corra él en su terminal (`git push -u origin <rama>`).

## 6. Jira

No cambies el ticket por tu cuenta. Preguntale al CEO si quiere pasarlo a "En curso" o asignárselo; si dice que sí, usá `transitionJiraIssue` (o `editJiraIssue` para el responsable).

## 7. Cerrá

En pocas líneas:

- **Ticket:** clave, tipo y título (y la subtarea, si empezó por una).
- **Épica:** clave y rama, si tiene.
- **Rama:** en la que quedaste, y si es nueva o retomada.
- **El PR va a:** la rama de destino del paso 4.
- **Commits:** con la clave del ticket, para que Jira los vincule.

Si sos el PM, el ticket es el tema de la reunión con el CEO: seguí con tu modo reunión usando la descripción del ticket como punto de partida. Si es una épica, no se programa en su rama: el trabajo se hace en sus tickets hijos.
