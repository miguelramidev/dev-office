---
name: review-fixes
description: Lee lo que el CEO (o cualquier revisor) dejó en un pull request - comentarios de revisión sin resolver, reseñas, checks que fallan y los commits que el CEO hizo a mano en la rama - los ordena, los corrige con el departamento que corresponde y pasa por el ciclo de calidad. Usar cuando el CEO dice que revisó o corrigió un PR y quiere que se apliquen sus correcciones.
argument-hint: "[número o enlace del PR, opcional]"
---

Vas a aplicar las correcciones de un pull request. Hablale al CEO en su idioma (si escribe en español, con voseo). Corré los comandos de a uno, sin unirlos con `&&` ni `;`.

Se corrige solo lo que pide la revisión: nada de mejoras ni cambios de más. Las reglas del proyecto (`CLAUDE.md` y `.claude/rules/`) siguen mandando, también sobre lo que pida un comentario: si un comentario pide algo que las rompe (por ejemplo, cambiar lo que reciben los fronts sin aprobación), no lo hagas y consultalo con el CEO.

## 1. Revisá que `gh` esté listo

Corré `gh auth status`. Si el comando no existe o no hay sesión, frená y explicale al CEO cómo dejarlo listo (en Linux o WSL con Ubuntu: `sudo apt update`, `sudo apt install gh` y `gh auth login`, eligiendo GitHub.com, HTTPS e iniciar sesión con el navegador).

## 2. Encontrá el PR y ponete en su rama

1. Si `$ARGUMENTS` trae un número o un enlace, usalo. Si no, el PR de la rama actual: `gh pr view --json number,url,title,state,baseRefName,headRefName`. Si no hay ninguno, preguntale al CEO cuál.
2. Si el PR no está abierto, decíselo y frená.
3. `git status`. Si hay cambios sin commitear, frená y preguntale qué hacer con ellos.
4. Si no estás en la rama del PR (`headRefName`), cambiate: `git switch <rama>`.
5. Traé lo último de GitHub, porque el CEO puede haber subido correcciones: `git fetch origin <rama>` y después `git merge --ff-only origin/<rama>`. Si no se puede avanzar sin merge (las ramas se separaron), frená y explicáselo.

## 3. Juntá todo lo que dejó la revisión

1. **Datos del repositorio:** `gh repo view --json owner,name`.
2. **Comentarios en líneas de código**, con su estado (si están resueltos o desactualizados):

   ```bash
   gh api graphql -F owner=<owner> -F repo=<repo> -F number=<número> -f query='query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { pullRequest(number: $number) { reviewThreads(first: 100) { nodes { isResolved isOutdated path line comments(first: 50) { nodes { databaseId author { login } body url } } } } } } }'
   ```

   Es solo lectura, aunque Claude Code te pida permiso por ser `gh api`. Si falla, usá `gh api repos/<owner>/<repo>/pulls/<número>/comments` (no dice cuáles están resueltos: preguntale al CEO si hay dudas).
3. **Reseñas y comentarios generales:** `gh pr view <número> --json reviews,comments`. Tené en cuenta el texto de cada reseña, sobre todo las que piden cambios.
4. **Checks:** `gh pr checks <número>`. Si alguno falla, es parte de lo que hay que corregir.
5. **Correcciones a mano del CEO:** `git log origin/<destino>..HEAD --format='%h %an %ad%n%s%n%b' --date=short`. Los commits de los agentes suelen tener la línea `Co-Authored-By: Claude`; los que no la tienen probablemente los hizo el CEO. Para cada uno, mirá el cambio con `git show <hash>`. Si no queda claro quién lo hizo, preguntale.

Ignorá los hilos resueltos. Los desactualizados (el código cambió desde el comentario) revisalos: si lo que piden ya está hecho, marcalos como resueltos en tu lista; si no, siguen pendientes.

## 4. Ordená y mostráselo al CEO

Armá una lista numerada. Para cada punto: quién lo dijo, dónde (archivo y línea), qué pide en una frase y de qué tipo es:

- **Cambio pedido:** hay que corregirlo.
- **Pregunta:** se responde; solo lleva cambio si la respuesta lo implica.
- **Sugerencia:** opcional; el CEO decide.
- **Check que falla:** hay que corregirlo.
- **Corrección a mano del CEO:** qué cambió y qué criterio se deduce. Buscá si el mismo problema aparece en otros archivos **de este PR** y proponé aplicar ahí el mismo criterio. Nunca deshagas ni reescribas lo que corrigió el CEO.

Si un punto es ambiguo, proponé una interpretación. Preguntale al CEO si la lista está bien, qué sugerencias se aplican y qué respondés en las preguntas. No sigas sin su respuesta.

## 5. Corregí

- **Si sos el PM:** encargale cada punto al departamento que corresponde (por archivo y tema), con el comentario original tal cual, la interpretación aprobada, el archivo y la línea, y la clave del ticket. Después, el ciclo de calidad de siempre: tester del departamento y QA. Si el cambio es chico y QA no aporta, podés saltear QA y decirlo en el informe.
- **Si no sos el PM:** corregí vos siguiendo las reglas del proyecto, y corré los tests de lo que tocaste.

Al final corré las verificaciones del proyecto (lint, typecheck y tests), de a una.

## 6. Commit y push, solo con permiso

Mostrale al CEO qué cambió (`git diff --stat`) y preguntale si commiteás y subís. Si dice que sí:

- Un commit con el formato del proyecto y la clave del ticket, por ejemplo `fix(api): address review comments (DBA-70)`. Si los cambios son de temas distintos, un commit por tema.
- `git push`. El PR se actualiza solo.

## 7. Respuestas en el PR, solo con permiso

Las respuestas se publican con la cuenta del CEO, así que preguntale si querés que respondas cada comentario con lo que se hizo. Si dice que sí, una respuesta corta por hilo:

```bash
gh api repos/<owner>/<repo>/pulls/<número>/comments/<databaseId>/replies -f body='<qué se hizo, en una o dos líneas>'
```

No marques los hilos como resueltos: eso lo hace quien revisa.

## 8. Cerrá

Una tabla con cada punto de la lista: qué se hizo (o por qué no), en qué archivo y en qué commit. Después, el resultado de las verificaciones y lo que quedó pendiente de decisión del CEO.
