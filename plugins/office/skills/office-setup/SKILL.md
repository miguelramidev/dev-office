---
name: office-setup
description: Prepara un proyecto para trabajar con la oficina dev-office - permisos base, modo de permisos, ramas protegidas, zona horaria del registro de actividad, .gitignore, conexión con Jira, colección de Postman de la API, proveedores por rol (Claude, Codex o Gemini) y recomendación de skills de la comunidad según el stack. Usar una vez al instalar la oficina en un proyecto, o para volver a aplicar la configuración base.
disable-model-invocation: true
---

Vas a preparar este proyecto para trabajar con la oficina dev-office. Hablale al CEO en su idioma (si escribe en español, con voseo).

Los cambios los hace el script `setup.sh` que está en la misma carpeta que este archivo. No edites `.claude/settings.json` ni `.gitignore` a mano.

## Pasos

1. **Explicá qué va a pasar**, en pocas líneas:
   - Se agregan a `.claude/settings.json` permisos base: comandos de git y de `gh` de solo lectura permitidos (incluido ver las corridas de GitHub Actions); commit, push, abrir PRs, comentar en GitHub, disparar workflows, aplicar infraestructura, SSH, instalar paquetes y AWS siempre con consulta; leer secretos, forzar push, saltear hooks, mergear PRs, cambiar secretos de GitHub y destruir infraestructura prohibidos.
   - Se define el modo de permisos y las ramas protegidas, donde los agentes no pueden editar ni commitear.
   - Se agregan a `.gitignore` la carpeta temporal de QA, la de trabajo de la oficina (`.office/`), el registro de actividad, la copia de seguridad y la configuración personal de proveedores.
   - No se borra nada de lo que ya existe, y se guarda una copia del archivo anterior.

2. **Revisá `CLAUDE.md`.** Si el proyecto no lo tiene, avisale al CEO que los agentes lo necesitan para conocer las reglas del proyecto, y preguntale si querés seguir igual.

3. **Comandos de verificación.** Buscá en `CLAUDE.md` y en los archivos del proyecto (por ejemplo `package.json`, `Makefile`, `pyproject.toml`) los comandos de tests, typecheck y lint. Proponé una regla `allow` para cada uno, con su variante con argumentos (por ejemplo `Bash(pnpm test)` y `Bash(pnpm test *)`), para que los testers trabajen sin pedir permiso. Mostrale la lista al CEO y esperá su confirmación. Nunca pongas `*` antes del subcomando (por ejemplo, `Bash(pnpm --filter * test)`): aprobaría cualquier opción en esa posición. Usá el nombre exacto del paquete y el `*` solo al final.

4. **Preguntá al CEO:**
   - **Modo de permisos:** `acceptEdits` (recomendado: los agentes editan archivos sin preguntar; los comandos fuera de la lista se consultan), `auto` (un clasificador aprueba los comandos razonables; solo si su cuenta lo tiene disponible) o `default` (todo se consulta).
   - **Zona horaria** del registro de actividad (opcional, por ejemplo `America/Bogota`). Si no responde, se usa la del sistema.
   - **Ramas protegidas:** en cuáles nunca se trabaja directamente. Acepta nombres y patrones, por ejemplo `main dev epic/*` si usan ramas de épica. Si no responde, se protegen `main` y `master`. Mirá las ramas del remoto (`git branch --all --list *`) para proponerle las que correspondan.

5. **Ejecutá el script una sola vez**, con las respuestas. Pasá cada regla extra con su propio `--allow`, entre comillas:

```bash
   bash <carpeta de esta skill>/setup.sh --mode acceptEdits --timezone America/Bogota --protected "main dev epic/*" --allow "Bash(pnpm test)" --allow "Bash(pnpm test *)"
```

Si falla, mostrale el error al CEO tal cual y no intentes arreglar los archivos a mano.

6. **Mostrá el resultado:** corré `git diff .claude/settings.json .gitignore` y explicale los cambios en pocas líneas.

7. **Recomendá skills de la comunidad.** Mirá las dependencias del proyecto (`package.json` y los de cada aplicación si es un monorepo) y recomendá solo las que correspondan a su stack. No las instales vos: mostrale al CEO los comandos para que decida.

   | Si el proyecto usa | Recomendá | Comandos |
   | --- | --- | --- |
   | Postgres (`pg`, `postgres`, `prisma`, `drizzle-orm`, `knex`, `typeorm` con Postgres) | Skills de Postgres de Supabase | `claude plugin marketplace add supabase/agent-skills` y `claude plugin install postgres-best-practices@supabase-agent-skills --scope project` |
   | MongoDB (`mongodb`, `mongoose`) | Skills de MongoDB | `claude plugin marketplace add mongodb/agent-skills` y `claude plugin install mongodb@mongodb-plugins --scope project` |
   | React o Next.js (`react`, `next`) | Skills de Vercel | `npx skills add vercel-labs/agent-skills`, eligiendo `react-best-practices` y `composition-patterns` |
   | React Native (`react-native`) | Skills de Vercel | el mismo comando, eligiendo también `react-native-skills` |
   | Expo (`expo`) | Skills de Expo | `claude plugin marketplace add expo/skills` y `claude plugin install expo@expo-plugins --scope project` |
   | Terraform (archivos `*.tf`) | Skills de HashiCorp | `claude plugin marketplace add hashicorp/agent-skills` y `claude plugin install terraform-code-generation@hashicorp --scope project` |

   Si recomendás el plugin de MongoDB, avisale que trae un servidor MCP que se conecta a la base con `MDB_MCP_CONNECTION_STRING`: si lo configura, que sea solo con una base local o de pruebas y con `MDB_MCP_READ_ONLY=true`, nunca con producción. Sin esa variable, las skills funcionan igual.

8. **Jira (si el equipo lo usa).** Preguntale al CEO si gestionan las tareas en Jira. Si dice que sí:
   - Ofrecé crear `.mcp.json` en la raíz con el servidor oficial de Atlassian. El nombre `atlassian` es obligatorio, porque el PM tiene acceso a las herramientas de ese servidor:

     ```json
     {
       "mcpServers": {
         "atlassian": { "type": "http", "url": "https://mcp.atlassian.com/v2/mcp" }
       }
     }
     ```

     Si `.mcp.json` ya existe, agregá solo esa entrada sin tocar las demás.
   - Pedile la clave del proyecto de Jira (por ejemplo `PROJ`), la rama base (por ejemplo `dev`), la de producción (por ejemplo `main`), si usan ramas de épica, si los prefijos por tipo de ticket de `start-ticket` (`epic/`, `feature/`, `task/`, `fix/`, `hotfix/`) le sirven, y **los nombres exactos de los estados** a los que pasa un ticket al empezar (por ejemplo "En curso") y al abrir el PR (por ejemplo "En revisión"): `start-ticket` y `open-pr` mueven el ticket a esos estados sin preguntar. Preguntale también **qué clientes usan la API** (por ejemplo front web y app móvil), **cómo se reconocen sus tickets** (un componente, una etiqueta o un prefijo en el título) y **qué tipo de ticket** usan para el trabajo nuevo: con eso `handoff-ticket` encuentra o crea el ticket de cada equipo cuando cambia la API. Podés listarlos con las herramientas de Atlassian para ofrecérselos. Proponé agregar esos datos a una sección "Flujo de trabajo" del `CLAUDE.md` (o a `.claude/rules/git-workflow.md`) y mostrale el texto antes de escribirlo.
   - Cada persona inicia sesión en Jira una vez con `/mcp`: servidor `atlassian`, opción de autenticar.

9. **Diseños (si hay frontend).** Preguntale al CEO si los diseños de las pantallas los entrega otro (un cliente o un equipo de diseño) y si están en Figma.
   - Si los entrega otro, proponé agregar al `CLAUDE.md` una línea que lo diga y la carpeta de imágenes de referencia (por defecto `docs/design/references/`), y mostrale el texto antes de escribirlo.
   - Si están en Figma, ofrecé agregar a `.mcp.json` el servidor remoto de Figma con el nombre `figma` (obligatorio, porque el designer tiene acceso a las herramientas de ese nombre), sin tocar las otras entradas:

     ```json
     "figma": { "type": "http", "url": "https://mcp.figma.com/mcp" }
     ```

     Avisale que cada persona inicia sesión con `/mcp`, que el servidor solo lee archivos donde tiene acceso de edición (con acceso de solo lectura no sirve), y que con asientos de solo lectura o el plan Starter Figma permite muy pocas llamadas por mes: si no tiene un asiento Dev o Full, conviene trabajar con imágenes exportadas.

10. **Colección de API (si hay backend).** Si el proyecto tiene backend y el plugin `dept-backend` está instalado, explicale al CEO que el departamento mantiene en el repo una colección de Postman con toda la API (REST y GraphQL), para pasársela al frontend, y una por épica con sus flujos y tests, para probarlos con el Collection Runner. Preguntale:
   - Si la quiere. Si dice que no, proponé agregar al `CLAUDE.md` la línea "Este proyecto no usa colección de API".
   - **Carpeta:** por defecto `docs/api/`.
   - **Entornos:** además de `local`, cuáles quiere (por ejemplo `staging`) y su URL base. No propongas uno de producción: si lo pide, avisale que cualquier request que pruebe ahí toca datos reales.
   - **Autorización:** cómo se autentica la API (bearer token, API key, cookie de sesión) y cuál es el endpoint de login, si lo sabe. Si no, el developer lo deduce del código.

   Con las respuestas, proponé una sección "Colección de API" para el `CLAUDE.md` y mostrale el texto antes de escribirlo, por ejemplo:

   ```markdown
   ## Colección de API

   - Carpeta: `docs/api/` (la colección del proyecto y una por épica en `docs/api/epics/`).
   - Entornos: `local` (http://localhost:3000) y `staging` (https://staging.example.com).
   - Autorización: bearer token; el login es `POST /auth/login`.
   ```

   Avisale que la colección se genera completa la primera vez que el backend toque un endpoint, o cuando se la pida al PM ("generá la colección de la API"), y que para revisarla el developer y el tester corren un script con `bash` que puede pedir confirmación la primera vez.

11. **Proveedores por rol (opcional).** Contale al CEO que cada rol de la oficina lo puede hacer Claude, Codex o Gemini (por ejemplo, Codex como developer de backend y dos QA que se validan entre ellos), y que el PM siempre es Claude pero puede consultar a Codex o Gemini como asesores. Preguntale si quiere configurarlo ahora. Si dice que sí, seguí la skill `office:office-agents`. Si no, todo queda en Claude y lo puede cambiar después con `/office:office-agents`.

12. **Cerrá con los próximos pasos:**
   - Revisar los cambios y hacer commit de `.claude/settings.json` y `.gitignore`.
   - Instalar las skills de la comunidad que haya elegido.
   - Si conectó Jira, autenticarse con `/mcp` y probar con `/office:start-ticket <TICKET>`.
   - Para abrir PRs y aplicar correcciones de revisión (`/office:open-pr` y `/office:review-fixes`), instalar `gh` e iniciar sesión con `gh auth login`.
   - Si quiere la colección de API y el proyecto ya tiene endpoints, pedirle al PM que la genere.
   - Borrar `.claude/settings.json.bak` cuando esté conforme.
   - Reiniciar Claude Code para que tome la configuración nueva.
