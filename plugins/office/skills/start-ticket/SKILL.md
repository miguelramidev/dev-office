---
name: start-ticket
description: Empieza el trabajo de un ticket de Jira - lo trae con el servidor MCP de Atlassian, se lo muestra al CEO y crea (o retoma) la rama de trabajo con el nombre del ticket desde la rama base del proyecto. Usar cuando el CEO pide trabajar en un ticket (por ejemplo "trabajemos en DBA-70") o antes de cualquier cambio si se está en una rama protegida.
argument-hint: <TICKET, por ejemplo DBA-70>
---

Vas a preparar el trabajo del ticket `$ARGUMENTS`. Hablale al CEO en su idioma (si escribe en español, con voseo). Corré los comandos de a uno, sin unirlos con `&&` ni `;`.

## 1. Leé el flujo de trabajo del proyecto

En el `CLAUDE.md` del proyecto (y en `.claude/rules/`, si existe) buscá:

- **Rama base:** de dónde salen las ramas de trabajo. Si no lo dice, usá la rama por defecto del remoto (`git remote show origin`, línea "HEAD branch").
- **Formato del nombre de la rama.** Si no lo dice, usá `<TICKET>-<resumen>`, por ejemplo `DBA-70-alertas-cuando-un-scraper-falla`.
- **Proyecto de Jira** y su sitio, si los nombra.

Si `$ARGUMENTS` está vacío, preguntale al CEO qué ticket. Si no tiene el formato de un ticket de Jira (letras, guion, número), preguntale si es correcto antes de seguir.

## 2. Revisá el estado del repositorio

Corré `git status`. Si hay cambios sin commitear, frená: mostrale al CEO qué archivos tienen cambios y preguntale qué hacer (guardarlos en un commit en su rama actual, guardarlos con `git stash` o descartarlos él a mano). Nunca los descartes vos.

## 3. Traé el ticket de Jira

Usá las herramientas del servidor MCP de Atlassian:

1. `getAccessibleAtlassianResources` para obtener el `cloudId` del sitio (si hay varios, el que nombre el proyecto).
2. `getJiraIssue` con ese `cloudId` y la clave del ticket.

Mostrale al CEO un resumen corto: clave, título, tipo, estado, responsable y la descripción (resumida si es larga, con los criterios de aceptación si los tiene).

Si las herramientas de Atlassian no están disponibles, decíselo al CEO: tiene que conectar Jira con `/mcp` (servidor `atlassian`, opción de autenticar). Ofrecé seguir igual: él te dice el título del ticket y armás la rama con eso.

Si el ticket no existe, decilo y frená.

## 4. Creá o retomá la rama

1. Armá el nombre: la clave del ticket tal cual (en mayúsculas) y un resumen del título en minúsculas, sin acentos ni eñes, solo letras, números y guiones, de 6 palabras como máximo. Ejemplo: "Alertas cuando un scraper falla o trae 0 productos" → `DBA-70-alertas-cuando-un-scraper-falla`.
2. `git fetch origin`.
3. Fijate si ya existe una rama con esa clave: `git branch --all --list "*<TICKET>*"`.
   - **Si existe**, cambiate a ella (`git switch <rama>`) y avisale al CEO que retomás el trabajo existente.
   - **Si no existe**, creala desde la rama base actualizada: `git switch -c <rama> origin/<rama base>`.
4. Confirmá con `git status` que quedaste en la rama nueva.

No hagas push: la rama se sube cuando haya trabajo para revisar y el CEO lo pida.

## 5. Jira

No cambies el ticket por tu cuenta. Preguntale al CEO si quiere pasarlo a "En curso" o asignárselo; si dice que sí, usá `transitionJiraIssue` (o `editJiraIssue` para el responsable).

## 6. Seguí con el trabajo

Cerrá con una línea: la rama en la que quedaste y el ticket. Si sos el PM, el ticket es el tema de la reunión con el CEO: seguí con tu modo reunión usando la descripción del ticket como punto de partida.
