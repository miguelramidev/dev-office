---
name: office-agents
description: Configura qué proveedor de IA hace cada rol de la oficina dev-office - Claude, Codex o Gemini, con modelo opcional - por ejemplo Codex como developer de backend, Gemini como developer de front, dos QA que se validan entre ellos, o asesores para el PM. Instala en el proyecto el script de configuración (office-agents.sh y office-agents.cmd para Windows) y verifica que los CLIs estén instalados y con sesión. Usar cuando el CEO quiere cambiar quién hace un rol o ver cómo está configurado.
argument-hint: "[rol proveedor, por ejemplo backend.developer codex]"
---

Vas a configurar qué proveedor hace cada rol de la oficina. Hablale al CEO en su idioma (si escribe en español, con voseo).

Los archivos `office-agents.sh` y `office-agents.cmd` están en la misma carpeta que este archivo. No edites los JSON de configuración a mano: usá siempre el script.

## Cómo funciona

- **Configuración del equipo:** `.claude/office-agents.json`, va en git.
- **Configuración personal:** `.claude/office-agents.local.json` (con `--local`), no va en git. Manda rol por rol: sirve para quien no tiene Codex o Gemini, o quiere probar otro.
- **Por rol:**
  - `pm`: el PM es siempre Claude, porque es la sesión de Claude Code. Lo que se configura son sus **asesores** (codex, gemini o los dos): les pide una segunda opinión sobre los planes y los diseños.
  - `qa`: uno o varios. Con varios, revisan por separado y después se validan entre ellos.
  - El resto (`backend.developer`, `frontend.designer`, `devops.tester`, los agentes propios del proyecto como `project.<nombre>`...): un solo proveedor.
  - Formato: `claude`, `codex` o `gemini`, con modelo opcional después de `:` (`gemini:pro`, `claude:opus`). Para Claude, los modelos son `opus`, `sonnet` o `haiku`.
  - Un rol sin configurar usa Claude con el modelo de siempre.

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
   bash .claude/office-agents.sh set frontend.developer gemini:pro
   bash .claude/office-agents.sh set qa claude codex
   bash .claude/office-agents.sh set pm codex
   ```

   Agregá `--local` si es solo para él. Para volver un rol a Claude: `reset <rol>`.

   Antes de confirmar, contale lo que cambia:
   - Codex y Gemini **no pasan por los hooks de la oficina** (protección de secretos y de ramas). La oficina los corre con su sandbox y revisa todo después, pero la protección es más débil que con Claude.
   - **Gemini en modo no interactivo no corre comandos:** edita archivos y la oficina corre las verificaciones después. Por eso como tester o QA rinde menos que Codex o Claude.
   - Cada rol en Codex o Gemini sigue usando un poco de Claude (Sonnet) para el puente que le pasa el encargo y revisa el resultado.

4. **Verificá los proveedores:** `bash .claude/office-agents.sh check`. Si algo falta, mostrale cómo arreglarlo según su sistema:

   | | Instalar | Iniciar sesión |
   | --- | --- | --- |
   | Codex | `npm install -g @openai/codex` (en macOS también `brew install --cask codex`) | `codex login` con su plan de ChatGPT, o una API key |
   | Gemini | `npm install -g @google/gemini-cli` (en macOS también `brew install gemini-cli`) | Una API key en `GEMINI_API_KEY` (variable de entorno o `~/.gemini/.env`), Vertex AI o un asiento de Code Assist |

   En Windows, después de instalar, hay que cerrar y abrir la terminal y Claude Code para que los encuentre.

5. **Cerrá:** mostrale `show` otra vez y recordale:
   - Hacer commit de `.claude/office-agents.json`, `.claude/office-agents.sh` y `.claude/office-agents.cmd` para que el resto del equipo use la misma configuración.
   - El PM lee la configuración cada vez que encarga algo: no hace falta reiniciar.
