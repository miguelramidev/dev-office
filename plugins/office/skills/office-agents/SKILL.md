---
name: office-agents
description: Configura qué proveedor de IA hace cada rol de la oficina dev-office - Claude, Codex o Gemini (con Antigravity CLI), con el modelo equivalente al nivel de cada rol o uno propio - por ejemplo Codex como developer de backend, Gemini como developer de front, dos QA que se validan entre ellos, o asesores para el PM. Instala en el proyecto el script de configuración (office-agents.sh y office-agents.cmd para Windows) y verifica que los CLIs estén instalados y con sesión. Usar cuando el CEO quiere cambiar quién hace un rol o ver cómo está configurado.
argument-hint: "[rol proveedor, por ejemplo backend.developer codex]"
---

Vas a configurar qué proveedor hace cada rol de la oficina. Si el CEO quiere leer el detalle, la guía está en `docs/providers.md` del repositorio de dev-office (https://github.com/miguelramidev/dev-office/blob/main/docs/providers.md). Hablale al CEO en su idioma (si escribe en español, con voseo).

Los archivos `office-agents.sh` y `office-agents.cmd` están en la misma carpeta que este archivo. No edites los JSON de configuración a mano: usá siempre el script.

## Cómo funciona

- **Configuración del equipo:** `.claude/office-agents.json`, va en git.
- **Configuración personal:** `.claude/office-agents.local.json` (con `--local`), no va en git. Manda rol por rol: sirve para quien no tiene Codex o Gemini, o quiere probar otro.
- **Por rol:**
  - `pm`: el PM es siempre Claude, porque es la sesión de Claude Code. Lo que se configura son sus **asesores** (codex, gemini o los dos): les pide una segunda opinión sobre los planes y los diseños.
  - `qa`: uno o varios. Con varios, revisan por separado y después se validan entre ellos.
  - El resto (`backend.developer`, `frontend.designer`, `devops.tester`, los agentes propios del proyecto como `project.<nombre>`...): un solo proveedor.
  - Formato: `claude`, `codex` o `gemini`, con modelo opcional después de `:` (`gemini:gemini-3.1-pro-preview`, `claude:opus`). Para Claude, los modelos son `opus`, `sonnet` o `haiku`.
  - Un rol sin configurar usa Claude con el modelo de siempre.
- **Niveles:** cada rol tiene el nivel de su agente de Claude: PM, QA y arquitectos en Opus; developers, testers y el designer en Sonnet. Un rol en Codex o Gemini usa el modelo de ese mismo nivel en ese proveedor, con razonamiento medio:

  | Nivel | Claude | Codex | Gemini |
  | --- | --- | --- | --- |
  | Opus | Opus | `gpt-6-astra` | `gemini-4-argon` |
  | Sonnet | Sonnet | `gpt-6.1-sol` | `gemini-3.8-flash` |

  La tabla es la de dev-office; el proyecto la puede cambiar con `tier` (por ejemplo, si un modelo cambia de nombre o la cuenta no lo tiene). `models` muestra la tabla efectiva.
- **Gemini se usa con Antigravity CLI** (`agy`), el CLI de Google para cuentas personales, con la cuenta de Google del CEO. Gemini CLI ya no atiende cuentas personales.

## Pasos

1. **Instalá o actualizá el script en el proyecto.** Fijate si existe `.claude/office-agents.sh` y qué versión tiene (la línea `# office-agents-version:` del principio). Si no existe o es más vieja que la de esta skill, copiá los dos archivos a `.claude/`:

   ```bash
   cp <carpeta de esta skill>/office-agents.sh .claude/office-agents.sh
   cp <carpeta de esta skill>/office-agents.cmd .claude/office-agents.cmd
   ```

   Así el CEO y el resto del equipo lo pueden correr desde la terminal del proyecto: `bash .claude/office-agents.sh` (macOS, Linux y Git Bash) o `.claude\office-agents.cmd` (CMD o PowerShell en Windows).

2. **Mostrá cómo está:** `bash .claude/office-agents.sh show`.

3. **Cambiá lo que pida el CEO.** Si vino con `$ARGUMENTS` (por ejemplo `backend.developer codex`), usalo. Si no, preguntale qué roles quiere cambiar. Corré un `set` por rol:

   ```bash
   bash .claude/office-agents.sh set backend.developer codex
   bash .claude/office-agents.sh set frontend.developer gemini:gemini-3.1-pro-preview
   bash .claude/office-agents.sh set qa claude codex
   bash .claude/office-agents.sh set pm codex
   ```

   Agregá `--local` si es solo para él. Para volver un rol a Claude: `reset <rol>`.

   Para cambiar la tabla de modelos o el razonamiento:

   ```bash
   bash .claude/office-agents.sh models
   bash .claude/office-agents.sh tier gemini opus gemini-3.1-pro-preview
   bash .claude/office-agents.sh tier codex effort high
   bash .claude/office-agents.sh tier codex opus default
   ```

   Si pide más razonamiento, avisale que gasta más tokens y tarda más.

   **Modo equipos** (un líder por departamento, que coordina a su developer y su tester y le entrega el reporte al PM):

   ```bash
   bash .claude/office-agents.sh teams on
   bash .claude/office-agents.sh teams off
   bash .claude/office-agents.sh teams
   ```

   Con `--local` queda solo para él. Activa los agent teams de Claude Code (experimentales) en el `env` de `.claude/settings.json` (o `settings.local.json`). Avisale que cada líder es una sesión más de Claude (Sonnet), así que gasta más tokens, y que tiene que reiniciar Claude Code. Los líderes son siempre Claude: no se configuran con `set`.

   Antes de confirmar, contale lo que cambia:
   - Codex y Gemini **no pasan por los hooks de la oficina** (protección de secretos y de ramas). La oficina los corre con su sandbox y revisa todo después, pero la protección es más débil que con Claude.
   - **Gemini (Antigravity) corre en modo `accept-edits`:** edita archivos sin preguntar, pero no corre comandos de la terminal; la oficina corre las verificaciones después. Por eso como tester o QA rinde menos que Codex o Claude.
   - **Si quiere que Gemini corra comandos** de lectura y de verificación (git de lectura, listar carpetas, lint, typecheck y tests), ofrecele `bash .claude/office-agents.sh gemini-permissions on`. También le deja borrar y mover archivos del repo con `git rm` y `git mv`: Antigravity no tiene otra forma de borrar. Contale que agrega reglas a `~/.gemini/config/config.json`, que valen para toda su computadora, que lo demás (commits, push, instalar, borrar, red, comandos encadenados) se sigue rechazando y que se deshace con `off`. No le propongas `--dangerously-skip-permissions`.
   - Cada rol en Codex o Gemini sigue usando un poco de Claude (Sonnet) para el puente que le pasa el encargo y revisa el resultado.

4. **Verificá los proveedores:** `bash .claude/office-agents.sh check`. Si algo falta, mostrale cómo arreglarlo según su sistema:

   | | Instalar | Iniciar sesión |
   | --- | --- | --- |
   | Codex | `npm install -g @openai/codex` (en macOS también `brew install --cask codex`) | `codex login` con su plan de ChatGPT, o una API key |
   | Gemini (con Antigravity CLI, `agy`) | macOS y Linux: `curl -fsSL https://antigravity.google/cli/install.sh \| bash`. Windows (PowerShell): `irm https://antigravity.google/cli/install.ps1 \| iex` | Correr `agy` una vez e iniciar sesión con tu cuenta de Google. El modelo de nivel Opus (Gemini 4 Argon) depende de tu plan: mirá los tuyos con `agy models` |

   En Windows, después de instalar, hay que cerrar y abrir la terminal y Claude Code para que los encuentre. GPT-6 Astra necesita Codex CLI 0.153.0 o más nuevo. `check` también avisa si la cuenta de Google no tiene alguno de los modelos de la tabla.

5. **Cerrá:** mostrale `show` otra vez y recordale:
   - Hacer commit de `.claude/office-agents.json`, `.claude/office-agents.sh` y `.claude/office-agents.cmd` para que el resto del equipo use la misma configuración.
   - El PM lee la configuración cada vez que encarga algo: no hace falta reiniciar.
