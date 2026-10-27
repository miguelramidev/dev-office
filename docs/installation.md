# Instalar dev-office en un proyecto

## 1. Requisitos

- Claude Code actualizado.
- `git` y `jq` (los usan los hooks).
- `gh` (la herramienta de GitHub para la terminal), si querés que la oficina abra PRs y aplique correcciones de revisión. Después de instalarlo: `gh auth login` (GitHub.com, HTTPS, iniciar sesión con el navegador).

La oficina funciona en **Linux, macOS y Windows**. En Windows podés usarla de forma nativa (PowerShell) o dentro de WSL2: elegí lo que use el resto del proyecto.

| Sistema | Instalar `jq` y `gh` |
| ------- | -------------------- |
| Windows nativo (PowerShell) | `winget install jqlang.jq` y `winget install GitHub.cli` |
| macOS | `brew install jq gh` |
| Ubuntu o WSL | `sudo apt install jq gh` |

### Windows nativo

- Claude Code en Windows usa el bash de **Git for Windows** para correr comandos y hooks: tenés que tenerlo instalado (`winget install Git.Git`).
- Después de instalar `jq` o `gh` con `winget`, **cerrá y abrí la terminal** (y Claude Code) para que los encuentre. Verificá con `jq --version` y `gh --version`.
- Los hooks entienden rutas con barras invertidas (`C:\dev\mi-proyecto`) y el jq de Windows, que escribe finales de línea CRLF.

## 2. Instalar los plugins

Desde la terminal, en la carpeta del proyecto:

```bash
claude plugin marketplace add miguelramidev/dev-office
claude plugin install office@dev-office --scope project
claude plugin install dept-backend@dev-office --scope project
claude plugin install dept-frontend@dev-office --scope project
claude plugin install dept-database@dev-office --scope project
claude plugin install dept-scraper@dev-office --scope project
claude plugin install dept-devops@dev-office --scope project
```

- `--scope project` registra los plugins en `.claude/settings.json` del proyecto. Así queda documentado en git qué departamentos usa el proyecto.
- Instalá solo los departamentos que el proyecto necesita. `office` es obligatorio.
- En otra computadora hay que repetir los comandos `install` (Claude Code no descarga plugins externos solo).

## 3. Preparar el proyecto

1. **Reglas del proyecto.** El proyecto necesita un `CLAUDE.md` en la raíz con lo que los agentes tienen que saber: stack, estructura, comandos y reglas. Los agentes lo leen antes de trabajar.
2. **Configuración inicial.** Abrí Claude Code en el proyecto y ejecutá la skill `office-setup` (escribí `/` y buscala en la lista). La skill:
   - Crea o completa `.claude/settings.json` con los permisos base de la oficina y el modo `acceptEdits`.
   - Agrega a `.gitignore` las carpetas temporales de la oficina (`.qa/` y el registro de actividad).
   - Revisa que exista `CLAUDE.md` y te avisa si falta.
3. **Revisá y commiteá** los cambios de `.claude/settings.json` y `.gitignore`.

Los permisos van en el proyecto porque Claude Code no permite que un plugin los defina.

### Ramas protegidas y Jira

`office-setup` pregunta qué ramas proteger (por ejemplo `main dev`) y las guarda en `OFFICE_PROTECTED_BRANCHES`. Si el equipo usa Jira, también crea `.mcp.json` con el servidor de Atlassian:

```json
{
  "mcpServers": {
    "atlassian": { "type": "http", "url": "https://mcp.atlassian.com/v2/mcp" }
  }
}
```

El servidor tiene que llamarse `atlassian`, porque el PM tiene acceso a las herramientas de ese nombre. Cada persona inicia sesión una vez con `/mcp`: servidor `atlassian`, opción de autenticar.

### Diseños entregados: imágenes y Figma (opcional)

Si los diseños los hace otro (un cliente o un equipo de diseño), el designer de `dept-frontend` no propone pantallas: las traduce a una especificación con la skill `design-intake`. Hay dos formas de pasarle los diseños:

- **Imágenes (funciona siempre).** Exportá cada pantalla y cada estado como PNG a 2x y guardalas en `docs/design/references/<tema>/`. Si las pegás en el chat, el PM las ve pero los agentes no: te va a pedir que las guardes en esa carpeta.
- **Figma.** Agregá el servidor remoto de Figma a `.mcp.json`. Tiene que llamarse `figma`, porque el designer tiene acceso a las herramientas de ese nombre:

  ```json
  {
    "mcpServers": {
      "figma": { "type": "http", "url": "https://mcp.figma.com/mcp" }
    }
  }
  ```

  Cada persona inicia sesión una vez con `/mcp`: servidor `figma`, opción de autenticar. El servidor **solo lee archivos donde tenés acceso de edición**: si te compartieron el archivo solo para ver, responde "you don't have edit access" y hay que usar imágenes. Ojo también con el límite de uso: con un asiento de solo lectura (View o Collab) o en el plan Starter, Figma permite muy pocas llamadas por mes; para trabajar seguido hace falta un asiento Dev o Full en un plan pago. Ver los [límites de Figma](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/). Si el límite no alcanza, usá imágenes.

## 4. Empezar a trabajar

```bash
claude --agent office:pm
```

Al arrancar, el encabezado tiene que mostrar `@office:pm`. Para verificar, preguntale: "¿Qué departamentos tenés disponibles?".

Atajo opcional en `~/.bashrc` o `~/.zshrc`:

```bash
alias oficina='claude --agent office:pm'
```

## 5. Ver qué hace el equipo

- **En la conversación:** cada vez que el PM activa a alguien aparece una fila con el nombre del agente y la tarea.
- **`/tasks`:** lista los agentes en ejecución. Con `Enter` ves el detalle de cada uno.
- **`Ctrl+O`:** muestra el detalle completo de herramientas y modelos.
- **Registro de actividad:** `tail -f .claude/office-activity.log` muestra en vivo cuándo empieza y termina cada agente.
- **Observer, la oficina en pixel art:** `/office:observer` abre en el navegador una página local donde ves la oficina en vivo. El PM camina entre los departamentos, cada empleado muestra qué está haciendo y con qué proveedor (tocá su encargo o su respuesta para leerlos en grande), y abajo están los tokens por agente y por proveedor, los resultados de tester y QA y la actividad. Más abajo está la tienda: cada sesión empieza con una oficina básica y, con los tokens que gasta el equipo, comprás escritorios, plantas, cuadros, muebles y ropa; el nivel sube con los tokens y el catálogo cambia en cada sesión. La página queda en `.office/observer/index.html`: la podés dejar abierta en una pestaña y se actualiza sola, también cuando empezás una sesión nueva, así que no hace falta abrirla cada vez. En WSL abrila con el link que empieza con `file://wsl.localhost/`, que es el que entiende el navegador de Windows. No necesita servidor ni Docker y no gasta tokens. Para apagarlo, `"OFFICE_OBSERVER": "off"` en el `env` de `.claude/settings.json`.

### Un líder por departamento (opcional)

Con `bash .claude/office-agents.sh teams on`, cada departamento tiene un líder que reparte el trabajo entre su developer y su tester y le entrega al PM un reporte con las acciones requeridas. Usa los agent teams de Claude Code (experimentales) y gasta más tokens. Se desactiva con `teams off`. Detalle en [Arquitectura: modo equipos](architecture.md#modo-equipos-un-líder-por-departamento).

### Codex y Gemini en algunos roles (opcional)

Por defecto todos los roles son Claude. Si querés que Codex o Gemini hagan algunos (por ejemplo, Codex como developer de backend o dos QA que se validan entre ellos), instalá su CLI, iniciá sesión y corré `/office:office-agents`. Todo el detalle está en la guía [Claude, Codex o Gemini en cada rol](providers.md).

## 6. Actualizar

**Con un doble click.** Corré `/office:update` una vez: deja en `.claude/` del proyecto (y, si querés, en el Escritorio) un script para actualizar la oficina:

- **Windows:** doble click en `update-office.cmd`.
- **macOS:** doble click en `update-office.command` (la primera vez, si macOS lo bloquea: click derecho → Abrir).
- **Desde la terminal:** `bash .claude/update-office.sh`.

Actualiza el marketplace y todos los plugins de dev-office **en todos los proyectos** donde estén instalados, cada uno en su scope, refresca los scripts de la oficina de cada proyecto y te muestra las versiones antes y después.

**A mano**, en la carpeta de cada proyecto:

```bash
claude plugin marketplace update dev-office
claude plugin update office@dev-office --scope project
```

(y lo mismo con cada departamento instalado).

En los dos casos, reiniciá Claude Code en los proyectos abiertos o usá `/reload-plugins`. Revisá el [registro de cambios](../CHANGELOG.md) antes de actualizar una versión mayor.

## 7. Desactivar un departamento en un proyecto

En `.claude/settings.json` del proyecto:

```json
"enabledPlugins": {
  "dept-scraper@dev-office": false
}
```

Para desactivarlo solo para vos, poné lo mismo en `.claude/settings.local.json`. `office` no se puede desactivar mientras haya departamentos activos, porque dependen de él.

## 8. Problemas comunes

| Síntoma                                                                                | Causa                                                                  | Solución                                                                         |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| El PM no ve a los departamentos                                                        | La sesión se abrió antes de instalarlos                                | `/reload-plugins` o reiniciar Claude Code                                        |
| Pide permiso para escribir en `/tmp` u otra carpeta                                    | `acceptEdits` solo aprueba dentro del proyecto                         | Rechazalo y pedile que trabaje dentro del proyecto                               |
| Pide permiso para escribir en `.claude/` o `.git/`                                     | Son rutas protegidas de Claude Code                                    | Es lo esperado: aprobalo solo si corresponde                                     |
| "no se edita el código en la rama protegida"                                         | Estás en una rama protegida (por ejemplo `dev`)                         | Pedile al PM que trabaje en un ticket o creá una rama con `git switch -c`         |
| El PM no puede traer el ticket de Jira                                                 | Jira no está conectado o no iniciaste sesión                           | `/mcp`, servidor `atlassian`, autenticar                                         |
| `open-pr` o `review-fixes` dicen que falta `gh`                                         | `gh` no está instalado o no tiene sesión                               | Instalarlo según tu sistema (sección 1) y `gh auth login`                        |
| "falta 'jq'" y se bloquea todo                                                         | `jq` no está instalado o la terminal no lo encuentra                   | Instalarlo según tu sistema (sección 1) y reiniciar la terminal y Claude Code    |
| Un hook falla con `command not found` (código 127)                                     | Finales de línea de Windows (CRLF) en el script del plugin            | Reinstalar el plugin; si persiste, revisar que git no tenga `core.autocrlf` forzando CRLF en `.sh` |
| Windows: un hook falla con "bash: command not found"                                   | Falta Git for Windows o su bash no está en el PATH                     | `winget install Git.Git` y reiniciar la terminal                                 |
| Pide permiso para un comando de tests con `\| tail` o `;`                              | Cada parte de un comando compuesto se revisa por separado              | Que corra los comandos de a uno (ya está en sus instrucciones)                   |
| Advertencia: "Permission allow rule ... has a wildcard before the rest of the command" | Una regla con `*` en el medio aprueba cualquier opción en esa posición | Usar el valor exacto (por ejemplo, el nombre del paquete) y el `*` solo al final |
| El PM dice "PROVEEDOR NO DISPONIBLE" | El CLI de Codex o Gemini no está instalado, no tiene sesión o se quedó sin cuota | `bash .claude/office-agents.sh check` y seguir lo que indique |
| El PM dice "REGLAS ROTAS" | Codex o Gemini tocó un archivo prohibido, commiteó o cambió de rama | Revisá `git status` y `.office/runs/` y decidí vos qué deshacer |
| Codex o Gemini se cortan con "tiempo agotado" | El encargo tardó más de 540 segundos | Pedile al PM que lo divida, o subí `OFFICE_EXTERNAL_TIMEOUT` (sin pasar de 590) |
