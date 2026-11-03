---
name: decisions
description: Memoria del proyecto de dev-office - al cerrar un ticket, el PM deja una nota corta en docs/decisions/ con lo que se decidió, por qué y lo que sorprendió, y al empezar una sesión lee solo el índice para no redescubrirlo. Usar cuando se cierra un ticket o una tarea con decisiones que importan, cuando el CEO pide anotar una decisión o "acordate de esto", o al empezar una tarea en un área donde ya hubo trabajo.
argument-hint: "[tema, para buscar notas, o el título de la nota a guardar]"
---

Vas a leer o a escribir la memoria del proyecto. Hablale al CEO en su idioma (si escribe en español, con voseo).

La memoria son notas cortas en `docs/decisions/` (o la carpeta que diga el `CLAUDE.md` del proyecto; en ese caso pasala con `--dir`), con un índice en `README.md`: una línea por nota, la más nueva arriba. El script `decisions.sh`, en la misma carpeta que este archivo, las escribe: no edites a mano el índice.

## Leer (al empezar una tarea)

1. Leé con Read las primeras 30 líneas de `docs/decisions/README.md`, si existe. Solo el índice: es barato.
2. Si alguna línea tiene que ver con lo que te piden (mismo ticket, misma área, mismo tema), abrí **esa** nota y tomala en cuenta. No abras las demás.
3. Si una nota contradice lo que ves ahora en el código, el código manda: decíselo al CEO y proponé corregir la nota.

## Escribir (al cerrar el ticket)

Escribí una nota cuando pasó algo que la próxima sesión no puede sacar de `git log` ni del código:

- una **decisión** con su motivo (qué se eligió, qué se descartó y por qué);
- algo que **sorprendió**: un comportamiento raro, una trampa, un problema que costó encontrar;
- una **regla nueva** que el CEO dio de palabra y no está en el `CLAUDE.md`.

No escribas una nota por cada ticket: si no hay nada de eso, no hay nota. Tampoco: lo que ya está en el código, en el `CLAUDE.md` o en el diseño de `docs/design/`; el resumen de lo que se hizo (eso es el informe); secretos, claves, datos de personas ni valores de entornos reales.

1. Armá el texto, de 3 a 8 líneas, concreto. Por ejemplo: «Se eligió X en vez de Y porque Z. Cuidado: W falla si V.»
2. Guardala (un comando, con el texto por la entrada estándar):

   ```bash
   bash <carpeta de esta skill>/decisions.sh add --title "<título corto>" --ticket PROJ-123 <<'NOTA'
   <el texto>
   NOTA
   ```

   `--ticket` es opcional y `--dir` cambia la carpeta (dentro del proyecto, sin `..`).
3. Decile al CEO qué nota dejaste y de qué trata, en una línea. La nota queda en la rama de trabajo: no la commitees vos. Si el CEO no quiere guardar notas en el repositorio, `docs/decisions/` se puede ignorar en git, y la lectura sigue funcionando en su computadora.

Con el CEO pidiendo "anotá esto", escribí la nota aunque no sea el cierre de un ticket.

## Cuidado

- Las notas pueden quedar viejas. Una nota es una pista, no una orden: si el código dice otra cosa, avisá.
- Si el índice crece más de unas 50 líneas, sugerile al CEO agrupar o archivar las más viejas.
