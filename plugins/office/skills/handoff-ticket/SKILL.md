---
name: handoff-ticket
description: Avisa en Jira a otro equipo cuando un cambio lo obliga a hacer algo (por ejemplo, el backend cambió la API y el front web o la app móvil se tienen que adaptar) - busca el ticket de ese equipo relacionado con el cambio, le agrega a la descripción una sección con qué cambió y qué tiene que hacer y deja un comentario; si no hay ticket, propone crearlo en la misma épica. Todo con confirmación del CEO, y preguntando a quién se asigna si no tiene responsable. Lo usa open-pr al abrir el PR, o el PM cuando el CEO lo pide.
argument-hint: "[TICKET de origen, opcional, por ejemplo PROJ-123]"
---

Vas a avisar en Jira a los equipos que tienen que hacer algo por un cambio de esta rama. El caso típico: el backend cambió la API y el front web o la app móvil se tienen que adaptar. Varias personas trabajan en el proyecto: el ticket de cada equipo es donde se enteran.

Hablale al CEO en su idioma (si escribe en español, con voseo). Lo que escribas en Jira va en el idioma del proyecto (el de su `CLAUDE.md`).

**Nada se escribe en Jira sin que el CEO lo vea antes.** Le mostrás el ticket elegido y el texto exacto, y recién con su sí lo escribís. Nunca asumas a quién se asigna un ticket: preguntale.

## 1. Juntá qué cambió

Necesitás saber qué cambió para quién lo usa, no cómo se implementó:

- **Ticket de origen:** el de `$ARGUMENTS` o el de la rama actual (la clave en el nombre: `feature/PROJ-123-...` → `PROJ-123`).
- **PR:** el enlace, si ya está abierto (`gh pr list --head <rama> --state all`).
- **Cambios:** si sos el PM o te llamó `open-pr`, usá la sección "Cambios en la API" de los reportes del backend. Si no, leé el diff contra el destino (`git diff --stat origin/<destino>...HEAD`, y en detalle las rutas, los esquemas de validación, el esquema de GraphQL y las colecciones de `docs/api/`).

Para cada cambio, anotá: método y ruta (u operación de GraphQL), si es **nuevo, modificado, obsoleto o eliminado**, qué cambia para quien lo usa (campos, tipos, errores, permisos) y si **rompe** a los clientes actuales.

Si la tarea ya incluyó el cambio en el cliente (por ejemplo, la oficina también hizo el front en esta misma rama), ese cliente no necesita aviso. Si al final no hay nada que avisar, decíselo al CEO y terminá.

## 2. Leé cómo se organiza el proyecto en Jira

En el `CLAUDE.md` del proyecto y en `.claude/rules/` buscá en el flujo de trabajo:

- **Qué clientes hay** (por ejemplo, front web y app móvil) y **cómo se reconocen sus tickets**: un componente (`Frontend`), una etiqueta (`front`, `mobile`) o un prefijo en el título (`[FE]`).
- **Qué tipo de ticket** se usa para el trabajo nuevo de cada cliente (por ejemplo Tarea).

Si no lo dice, preguntale al CEO para este caso y sugerile agregarlo al flujo de trabajo del proyecto (la skill `office:office-setup` lo pregunta).

## 3. Buscá el ticket de cada cliente

Usá las herramientas del servidor MCP de Atlassian (`getAccessibleAtlassianResources` para el `cloudId`, `getJiraIssue` y `searchJiraIssuesUsingJql`). Para cada cliente afectado, buscá en este orden y quedate con los que no estén terminados:

1. **Vinculados al ticket de origen:** sus `issuelinks` y, si es una subtarea, los de su padre.
2. **En la misma épica:** `parent = <ÉPICA> AND statusCategory != Done` más el filtro del cliente (por ejemplo `AND component = "Frontend"`).
3. **Por texto en el proyecto:** `project = <CLAVE> AND statusCategory != Done AND text ~ "<término>"`, con la ruta, el nombre de la función o del recurso. Limitá a 10 resultados.

No hace falta encontrar uno perfecto: el CEO elige.

## 4. Proponé y esperá la confirmación

Mostrale al CEO, por cada cliente:

- **Candidatos:** hasta 5, con clave, título, estado y responsable, y por qué creés que es el relacionado. Marcá el que recomendás.
- **Opciones:** usar uno de esos, **crear un ticket nuevo**, o **no avisar** a ese cliente.
- **El texto exacto** de la sección para la descripción y del comentario (ver paso 5).
- **Responsable:** si el ticket elegido no tiene, o si se crea uno nuevo, preguntale a quién se asigna o si queda sin asignar. Para ofrecerle opciones, listá los usuarios asignables del proyecto con las herramientas de Atlassian. Si el ticket ya tiene responsable, no lo cambies.

Si el ticket elegido está asignado a otra persona, está bien: es justamente a quien hay que avisarle.

No escribas nada hasta que el CEO responda. Si cambia el texto, usá el suyo.

## 5. El texto

**Sección de la descripción**, que se agrega al final, sin tocar el resto:

```markdown
## Cambios de API desde PROJ-123

- **Origen:** PROJ-123 <título> · PR: <enlace>
- **Qué cambió:** <una o dos frases>
- **Endpoints:**
  - `POST /orders` — nuevo — <qué hace>
  - `GET /orders/:id` — modificado — <qué cambia: campos, tipos, errores>
  - `GET /cart` — obsoleto — usar `GET /orders/:id`; se elimina en <cuándo, si se sabe>
- **Qué tiene que hacer este equipo:** <lo concreto, por ejemplo "mostrar el nuevo campo status y manejar el error ORDER_LOCKED">
- **Compatibilidad:** <rompe a los clientes actuales o no; si rompe, desde cuándo>
- **Para probar:** colecciones de Postman en `docs/api/` (la del proyecto y la de la épica), en la rama `<rama>` hasta que se integre en `<destino>`.
```

Si el ticket ya tiene una sección "Cambios de API desde" **del mismo ticket de origen**, reemplazala en lugar de agregar otra. Si es de otro ticket de origen, dejala y agregá la nueva debajo.

Al editar, conservá la descripción existente completa: traela con `getJiraIssue`, agregá la sección y guardá todo con `editJiraIssue`.

**Comentario**, corto, para que se entere quien sigue el ticket:

> Cambió la API en PROJ-123 (<enlace al PR>): <resumen en una o dos líneas>. Detalle en la descripción, sección "Cambios de API desde PROJ-123".

## 6. Escribí en Jira

Con la confirmación del CEO, para cada cliente:

- **Ticket existente:** editá la descripción (`editJiraIssue`), agregá el comentario con la herramienta de comentarios del servidor de Atlassian (según la versión, `addCommentToJiraIssue` o `addOrEditJiraIssueComment`) y, si el CEO lo eligió, asignalo.
- **Ticket nuevo:** crealo con `createJiraIssue` en el proyecto de Jira del flujo, con el tipo del paso 2, la misma épica que el ticket de origen como padre, el componente o la etiqueta del cliente, el responsable que eligió el CEO, un título claro (por ejemplo "Adaptar el front a los cambios de pedidos (PROJ-123)", con el prefijo del cliente si el proyecto usa uno) y la sección del paso 5 como descripción. No hace falta comentario.
- **Vinculá** el ticket del cliente con el de origen (tipo "relates to", o el que use el proyecto). Si el servidor no tiene una herramienta directa para vincular, buscá la operación con `discover`; si no existe, alcanza con la clave del origen en la descripción.

Si una escritura falla, no la reintentes en bucle ni pruebes otra forma de escribir: decile al CEO qué falló y qué quedó hecho.

No cambies el estado de esos tickets ni toques sus otros campos.

## 7. Cerrá

En pocas líneas, por cliente: el ticket (nuevo o existente), su responsable, qué se escribió (descripción, comentario, vínculo) y el enlace. Si algún cliente quedó sin aviso porque el CEO lo eligió, decilo.
