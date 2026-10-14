---
name: open-pr
description: Abre el pull request de la rama actual - corre las verificaciones del proyecto, elige la rama de destino según el ticket de Jira (su épica, la rama base o producción si es hotfix), arma el título y la descripción con la clave del ticket, se los muestra al CEO y solo con su confirmación sube la rama y abre el PR con gh. Usar cuando el CEO pide abrir o preparar el PR de un trabajo terminado.
argument-hint: "[rama de destino, opcional]"
---

Vas a abrir el pull request de la rama actual. Hablale al CEO en su idioma (si escribe en español, con voseo). Corré los comandos de a uno, sin unirlos con `&&` ni `;`.

Nada sale de la computadora del CEO sin su confirmación: primero le mostrás el PR armado, y recién cuando dice que sí subís la rama y lo abrís. Nunca mergees ni apruebes un PR.

## 1. Leé el flujo de trabajo del proyecto

En el `CLAUDE.md` del proyecto y en `.claude/rules/` buscá:

- La **rama base** (por ejemplo `dev`) y la de **producción** (por ejemplo `main`). Si no lo dice, la base es la rama por defecto del remoto (`git remote show origin`, línea "HEAD branch") y producción es `main`.
- A qué rama va el PR según el tipo de ticket. Si no lo define, usá la tabla de la skill `office:start-ticket`.
- Qué tiene que pasar antes de abrir un PR (lint, typecheck, tests) y qué tiene que decir la descripción (por ejemplo, la compatibilidad con los fronts).
- El formato de los títulos (por ejemplo, Conventional Commits con la clave del ticket al final).

## 2. Revisá que `gh` esté listo

Corré `gh auth status`. Si el comando no existe o no hay sesión, frená y explicale al CEO que `gh` es la herramienta de GitHub para la terminal, y cómo dejarla lista (en Linux o WSL con Ubuntu):

```bash
sudo apt update
sudo apt install gh
gh auth login
```

En `gh auth login`: GitHub.com, HTTPS, usar gh para git, iniciar sesión con el navegador.

## 3. Revisá la rama

1. `git status`. Si hay cambios sin commitear, frená: mostrale qué archivos son y preguntale si los commitea (con su aprobación) o los deja fuera del PR.
2. Anotá la rama actual. Si es la base o la de producción, frená: no se abre un PR desde ahí. Desde una rama de épica solo se abre el PR de la épica completa (paso 4).
3. Buscá la clave del ticket en el nombre de la rama (letras, guion, número: `feature/PROJ-123-...` → `PROJ-123`). Las ramas `chore/` no tienen ticket.
4. Fijate si ya hay un PR abierto para esta rama: `gh pr list --head <rama> --state open`. Si existe, mostrale el enlace al CEO y frená: los cambios nuevos se suben a la misma rama y el PR se actualiza solo.

## 4. Decidí la rama de destino

Si el CEO la dijo en `$ARGUMENTS`, usá esa. Si no:

1. Si hay clave de ticket y están las herramientas de Atlassian, traé el ticket (`getAccessibleAtlassianResources` y `getJiraIssue`): título, tipo, estado, etiquetas y padre. Si es una subtarea, mirá también a su padre.
2. Decidí con la tabla del proyecto (o la de `office:start-ticket`):

   | Caso | El PR va a |
   | --- | --- |
   | Tipo Hotfix, etiqueta `hotfix` o rama `hotfix/` | Producción. Después, un segundo PR de la misma rama a la base |
   | Epic (rama `epic/`) | La base. Solo si la épica está completa: buscá sus hijos con `searchJiraIssuesUsingJql` (`parent = <CLAVE>`) y mostrale al CEO los que no estén terminados |
   | Con épica padre | La rama de esa épica |
   | Sin épica, o rama `chore/` | La base |

3. Sin Jira, deducilo del prefijo de la rama. Si el ticket podría tener épica y no lo podés saber, preguntale al CEO.
4. Comprobá que la rama de destino exista en GitHub: `git ls-remote --heads origin <destino>`. Si es una épica y no existe, el CEO tiene que subirla primero (`git push -u origin <rama-de-la-épica>`).

## 5. Corré las verificaciones

Corré las del proyecto (por ejemplo lint, typecheck y tests), de a una. Si alguna falla, frená: mostrale al CEO qué falló y no abras el PR. Si sos el PM, ofrecé encargarle el arreglo al departamento que corresponde.

## 6. Armá el PR

Mirá qué se va a integrar:

- `git fetch origin <destino>`
- `git log --oneline origin/<destino>..HEAD`
- `git diff --stat origin/<destino>...HEAD`

Si no hay commits nuevos respecto del destino, frená y decíselo.

**Título:** con el formato de los commits del proyecto y la clave del ticket. Por ejemplo `feat(api): add product handling to cart (PROJ-123)`.

**Descripción**, en el idioma de la documentación del proyecto, corta:

- **Ticket:** la clave y el título (Jira los enlaza solo si el proyecto tiene la integración con GitHub).
- **Qué cambió:** de 3 a 6 puntos, por lo que hace, no por archivo.
- **Cómo probarlo:** los pasos para verificarlo a mano, si aplica.
- **Compatibilidad:** si el proyecto pide algo (por ejemplo, el contrato con los fronts), qué se tocó y cómo se mantiene compatible. Si no se tocó nada de eso, decilo.
- **Verificaciones:** qué se corrió en el paso 5 y el resultado.
- **Refactor:** si el ticket es de tipo Refactor (o la rama es `refactor/`), confirmá que el comportamiento no cambió: que no se modificó ni borró ningún test existente (`git diff --stat origin/<destino>...HEAD` sobre las carpetas de tests) y que no cambió lo que recibe quien usa el código. Decilo en la descripción. Si algo de eso cambió, frená y avisale al CEO: ya no es un refactor.
- **Para revisar:** decisiones que el revisor debería mirar, si las hay.

## 7. Mostráselo al CEO y esperá

Mostrale: rama de origen → destino, título, descripción y la lista de commits. Preguntale si abrís el PR así o quiere cambiar algo. No sigas sin un sí.

## 8. Subí la rama y abrí el PR

1. Si la rama no está en GitHub o tiene commits sin subir (`git status` muestra "ahead"), subila: `git push -u origin <rama>`. Si el proyecto tiene un hook `pre-push` que corre verificaciones y falla, frená y mostrale el error.
2. Abrí el PR pasando la descripción por la entrada estándar, con un heredoc entre comillas simples para que no se interprete nada:

   ```bash
   gh pr create --base <destino> --head <rama> --title "<título>" --body-file - <<'EOF'
   <descripción>
   EOF
   ```

3. **Hotfix:** preguntale al CEO si abrís ahora también el segundo PR, de la misma rama hacia la base, con el mismo título y una línea que diga que es la copia del hotfix.

## 9. Jira

Fijate si el flujo de trabajo del proyecto (`CLAUDE.md` o `.claude/rules/`) dice a qué estado pasa el ticket al abrir el PR (por ejemplo, "al abrir el PR, el ticket pasa a REVIEWING").

**Si lo dice, movelo sin preguntar:** el CEO ya lo autorizó en las reglas del proyecto, y así sabe qué tiene que revisar.

1. Si el ticket ya está en ese estado o en uno posterior (según el orden de estados del proyecto), no lo toques.
2. Mirá a qué estados puede pasar ahora con `listJiraIssueTransitions`. Si el estado de revisión está entre ellos, usá `transitionJiraIssue`.
3. Si no está porque el flujo obliga a pasar por estados intermedios (por ejemplo, el ticket sigue en "por hacer" y primero tiene que pasar por "en curso"), avanzá de a un estado, siempre hacia adelante según el orden del proyecto y sin pasarte del de revisión. Como máximo 3 pasos.
4. Si no podés llegar, no fuerces nada: decile al CEO en qué estado quedó el ticket y por qué no avanzó.
5. Si es el PR de una épica completa, no la muevas sola: preguntale al CEO.
6. En un hotfix, se mueve una sola vez, con el primer PR.

**Si el proyecto no lo dice**, no cambies el ticket por tu cuenta: preguntale al CEO si lo mueve al siguiente estado y, si dice que sí, usá `transitionJiraIssue`.

En ningún caso saltees estados ni muevas un ticket hacia atrás.

## 10. Cerrá

En pocas líneas: el enlace al PR, origen → destino, el ticket y a qué estado pasó en Jira, y que cuando el CEO deje comentarios de revisión, la skill `office:review-fixes` los lee y los corrige.
