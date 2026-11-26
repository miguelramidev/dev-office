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

### Con el instalador

En la carpeta del proyecto, corré el instalador. Revisa las herramientas (te ofrece instalar las que faltan), agrega el marketplace, te pregunta lo necesario, instala, configura el proyecto y al final corre el diagnóstico (`/office:doctor`):

```bash
# macOS, Linux o Git Bash
bash <(curl -fsSL https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.sh)
```

```powershell
# Windows (PowerShell): busca el bash de Git for Windows y corre el mismo script
irm https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.ps1 | iex
```

Empieza con un menú:

| Opción | Qué hace |
| --- | --- |
| **Instalar** | Te pregunta para quién (solo vos, por defecto, o todo el equipo), los departamentos (te sugiere según lo que tiene el proyecto), las ramas protegidas, si los documentos van a git y si conectás Jira (con la etiqueta de tu cuenta y el sitio). Si la oficina ya estaba, actualiza lo instalado y suma los departamentos nuevos. |
| **Desinstalar** | Saca de este proyecto los plugins (primero los departamentos, después `office`), la configuración de la oficina (deja las reglas propias del proyecto), sus archivos de trabajo, los scripts que copió y Jira. Pregunta antes de borrar los documentos (por defecto quedan) y las reglas que anotó la oficina. Si después git ve archivos que antes ignoraba la oficina, te ofrece ignorarlos en `.git/info/exclude`, así no aparece nada en un repositorio donde no se puede ver la oficina. Si ya no queda la oficina en ningún proyecto, te ofrece borrar el actualizador del Escritorio, Telegram y el marketplace. |
| **Reinstalar desde 0** | Desinstala y vuelve a instalar, proponiendo lo que tenías (alcance, departamentos, ramas, documentos). Los documentos y la conexión con Jira quedan. |
| **Diagnóstico** | Corre `/office:doctor` desde la terminal. |

Para saltear el menú o alguna pregunta: `bash dev-office.sh install --scope local --departments "backend frontend" --jira trabajo`. `--yes` acepta lo de por defecto en todo; la lista completa, con `--help`.

### A mano

Desde la terminal, en la carpeta del proyecto:

```bash
claude plugin marketplace add miguelramidev/dev-office
claude plugin install office@dev-office --scope local
claude plugin install dept-backend@dev-office --scope local
claude plugin install dept-frontend@dev-office --scope local
claude plugin install dept-database@dev-office --scope local
claude plugin install dept-scraper@dev-office --scope local
claude plugin install dept-devops@dev-office --scope local
claude plugin install dept-research@dev-office --scope local
claude plugin install dept-docs@dev-office --scope local
```

- `--scope local` instala los plugins solo para vos en este proyecto (en `.claude/settings.local.json`, que no va en git). Es el modo local de la oficina, el de por defecto: en un proyecto en equipo, cada uno arma su oficina sin pisar la de otro, y quien no la usa no ve nada.
- Si todo el equipo usa la oficina y quiere la misma configuración, usá `--scope project` (queda en `.claude/settings.json`, en git) y elegí el modo compartido en `office-setup`.
- Instalá solo los departamentos que el proyecto necesita. `office` es obligatorio.
- En otra computadora hay que repetir los comandos `install` (Claude Code no descarga plugins externos solo).

## 3. Preparar el proyecto

1. **Reglas del proyecto.** El proyecto necesita un `CLAUDE.md` en la raíz con lo que los agentes tienen que saber: stack, estructura, comandos y reglas. Los agentes lo leen antes de trabajar.
2. **Configuración inicial.** Abrí Claude Code en el proyecto y ejecutá la skill `office-setup` (escribí `/` y buscala en la lista). La skill:
   - Te pregunta si la querés **local** (por defecto: tu configuración va a `.claude/settings.local.json` y lo que git ignora, a `.git/info/exclude`, así que no cambia ningún archivo del repositorio) o **compartida** (a `.claude/settings.json` y `.gitignore`, en git, igual para todo el equipo).
   - Te pregunta si los **documentos de la oficina** (mapa del proyecto, decisiones, diseños, colecciones de API e investigaciones) van a git, que es lo de por defecto, o quedan solo en tu computadora. Se puede cambiar cuando quieras.
   - Completa los settings con los permisos base de la oficina y el modo `acceptEdits`, y deja al PM como agente por defecto.
   - Hace que git ignore las carpetas de trabajo de la oficina (`.qa/`, `.office/` y el registro de actividad).
   - Revisa que exista `CLAUDE.md` y te avisa si falta.
3. **En el modo compartido, revisá y commiteá** los cambios de `.claude/settings.json` y `.gitignore`. En el local no hay nada que commitear.
4. **Comprobá la instalación** con `/office:doctor` (`office-setup` lo corre al final). Es como `flutter doctor`: revisa las herramientas (git, jq, gh), los plugins y sus versiones, la configuración del proyecto, Codex y Gemini si los usás, Jira y lo opcional, y para cada cosa que falta te dice cómo arreglarla:

   ```text
   [✓] Herramientas
       ✓ Claude Code 2.1.330
       ✓ git 2.47.1
       ✓ jq 1.7.1
       ✓ gh con sesión

   [!] Configuración del proyecto
       ✓ CLAUDE.md
       ✓ Modo local: la configuración está solo en tu computadora (.claude/settings.local.json)
       ✓ El PM arranca solo al abrir claude
       ! No hay comandos de tests, lint ni typecheck permitidos: el developer y el tester te van a pedir permiso para cada uno.
         → /office:office-setup (paso de comandos de verificación), o sumá reglas como "Bash(pnpm test *)" a los permisos

   [-] Jira (Atlassian)
       - No conectado (opcional).
         → /office:office-setup (paso de Jira)
   ```

   `[✓]` listo, `[!]` aviso, `[✗]` falta algo que la oficina necesita y `[-]` opcional. El PM te ofrece arreglar lo que puede hacer él, y lo que se corre en tu terminal te lo da listo para copiar.

**Si el proyecto ya tenía la oficina en git** y querés pasarla a local (paso a paso completo en [Migrar la oficina](migration.md)), `office-setup` lo hace por vos: saca del repositorio lo de la oficina (deja las reglas propias del proyecto), lo pasa a tus archivos locales y te dice cómo reinstalar los plugins con `--scope local`. Ese cambio sí se commitea una vez: conviene acordarlo con el equipo.

Los permisos van en los settings del proyecto (los tuyos o los del equipo) porque Claude Code no permite que un plugin los defina.

### Ramas protegidas y Jira

`office-setup` pregunta qué ramas proteger (por ejemplo `main dev`) y las guarda en `OFFICE_PROTECTED_BRANCHES`. Si usás Jira, en el modo local te da el comando para conectarlo solo para vos:

```bash
claude mcp add --transport http --scope local atlassian https://mcp.atlassian.com/v2/mcp
```

En el compartido, crea `.mcp.json` con el servidor de Atlassian:

```json
{
  "mcpServers": {
    "atlassian": { "type": "http", "url": "https://mcp.atlassian.com/v2/mcp" }
  }
}
```

El servidor tiene que llamarse `atlassian`, porque el PM tiene acceso a las herramientas de ese nombre. Cada persona inicia sesión una vez con `/mcp`: servidor `atlassian`, opción de autenticar.

#### Dos cuentas de Atlassian (trabajo y personal)

El paso a paso completo, con ejemplos y problemas comunes, está en [Migrar la oficina](migration.md#3-una-cuenta-de-atlassian-por-proyecto).

Claude Code guarda **una sesión de Atlassian por dirección del servidor**, para toda la computadora. Con la dirección de siempre, si te logueás con la cuenta personal en un proyecto, el del trabajo pasa a usarla también. La salida es que cada cuenta use su propia dirección, agregándole `?cuenta=<etiqueta>`, sin cambiar el nombre del servidor (tiene que seguir siendo `atlassian`):

1. **Si ya tenías Atlassian conectado,** fijate dónde con `claude mcp get atlassian` y sacalo: `claude mcp remove atlassian -s user` (o `-s local`), o la entrada `atlassian` de `.mcp.json`.
2. **En cada proyecto,** desde su carpeta, conectalo con la etiqueta de su cuenta:

   ```bash
   # proyecto del trabajo
   claude mcp add --transport http --scope local atlassian "https://mcp.atlassian.com/v2/mcp?cuenta=trabajo"
   # proyecto personal
   claude mcp add --transport http --scope local atlassian "https://mcp.atlassian.com/v2/mcp?cuenta=personal"
   ```

3. **Logueate en cada uno:** abrí `claude`, corré `/mcp` → `atlassian` → autenticar, y entrá en el navegador con la cuenta que corresponde. Si el navegador ya tiene abierta la otra cuenta, cerrá esa sesión o usá una ventana privada.
4. **Comprobalo:** preguntale al PM "¿con qué cuenta de Atlassian estás conectado?" en cada proyecto.

**La etiqueta es de la cuenta, no del proyecto.** Con dos proyectos personales y uno del trabajo, los dos personales usan `?cuenta=personal` y comparten el login (te logueás una vez), y el del trabajo usa `?cuenta=trabajo`. Con dos cuentas de trabajo distintas, cada una lleva la suya (`?cuenta=empresa-a`, `?cuenta=empresa-b`). Si te logueás con otra cuenta en un proyecto, cambia en todos los que usan esa etiqueta.

Anotá el sitio en las reglas de cada proyecto (`Sitio de Jira: miempresa.atlassian.net`), así el PM usa ese aunque tu cuenta vea varios.

**Sin navegador, con token.** Si el login por navegador no te sirve, cada proyecto se puede conectar con un token de API de su cuenta: creá el token en [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens) y corré en la carpeta del proyecto `bash <carpeta de la skill office-setup>/jira-account.sh` (te pide el email, el token sin mostrarlo y el sitio, y lo registra solo para ese proyecto). La organización tiene que tener habilitada la autenticación con token, y con token faltan algunas herramientas de Atlassian (Jira y Confluence están).

En el modo local, git ignora `.mcp.json` y lo que no esté en git dentro de `.claude/`: son configuración de cada persona.

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

`office-setup` deja al PM como agente por defecto (`"agent": "office:pm"` en tus settings), así que `claude` a secas también arranca con la oficina. Al arrancar, el encabezado tiene que mostrar `@office:pm`. Para verificar, preguntale: "¿Qué departamentos tenés disponibles?".

Atajo opcional en `~/.bashrc` o `~/.zshrc`:

```bash
alias oficina='claude --agent office:pm'
```

### Varios tickets a la vez

Si le pedís al PM dos tickets que no dependen entre sí (por ejemplo, dos de la misma épica: "hagamos PROJ-123 y PROJ-124"), los trabaja a la vez, en la misma copia del proyecto y cada uno en su rama. Antes revisa que salgan de la misma rama, que ninguno necesite al otro y que toquen archivos distintos; si no, te dice por qué y los hace en orden. Al cerrar, con tu confirmación, commitea cada ticket en su rama, prueba cada rama por separado y abre un PR por ticket. Un hook evita que dos agentes editen el mismo archivo a la vez. Ver [Trabajo en paralelo](architecture.md#trabajo-en-paralelo).

## 5. Ver qué hace el equipo

- **En la conversación:** cada vez que el PM activa a alguien aparece una fila con el nombre del agente y la tarea.
- **`/tasks`:** lista los agentes en ejecución. Con `Enter` ves el detalle de cada uno.
- **`Ctrl+O`:** muestra el detalle completo de herramientas y modelos.
- **Registro de actividad:** `tail -f .claude/office-activity.log` muestra en vivo cuándo empieza y termina cada agente.
- **Observer, la oficina en pixel art 3D:** `/office:observer` abre en el navegador una página local donde ves la oficina en vivo, en 3D (necesita WebGL; si no hay, o desde "Ajustes", se ve la vista clásica). Cada empleado tiene un nombre; el CEO toma tu nombre de pila de `git config user.name`. El PM camina entre los departamentos, cada empleado muestra qué está haciendo y con qué proveedor (tocá su encargo o su respuesta para leerlos en grande), y los botones de arriba a la derecha abren el equipo, la actividad, los tokens por agente y por proveedor y la tienda, sin scroll: la oficina se ajusta a la pantalla. En la tienda, cada sesión empieza con una oficina básica y, con los tokens que gasta el equipo, comprás escritorios, plantas, cuadros, muebles, cosas para el pasillo y ropa; el nivel sube con los tokens y el catálogo cambia en cada sesión. La página queda en `.office/observer/index.html`: la podés dejar abierta en una pestaña y se actualiza sola, también cuando empezás una sesión nueva, así que no hace falta abrirla cada vez. En WSL abrila con el link que empieza con `file://wsl.localhost/`, que es el que entiende el navegador de Windows. No necesita servidor ni Docker y no gasta tokens. Para apagarlo, `"OFFICE_OBSERVER": "off"` en el `env` de `.claude/settings.json`.

### Un líder por departamento (opcional)

Con `bash .claude/office-agents.sh teams on`, cada departamento tiene un líder que reparte el trabajo entre su developer y su tester y le entrega al PM un reporte con las acciones requeridas. Usa los agent teams de Claude Code (experimentales) y gasta más tokens. Se desactiva con `teams off`. Detalle en [Arquitectura: modo equipos](architecture.md#modo-equipos-un-líder-por-departamento).

### Emojis en la consola (opcional)

Con `bash .claude/office-agents.sh emojis on --local`, el PM usa emojis en sus respuestas también en la consola (✅ listo, ❌ falló, ⚠️ riesgo, ❓ decisión pendiente), como hace siempre en Telegram. Son pocos y nunca van en código, commits, PR ni tickets. Si tu terminal muestra cuadraditos (pasa en consolas viejas de Windows), usá Windows Terminal o apagalos con `emojis off --local`.

### Tope de tokens por sesión (opcional)

Con `bash .claude/office-agents.sh budget 2M` la oficina cuenta los tokens de la sesión (los que anota el observer) y frena antes de gastar de más: al 80% el PM avisa y prioriza, y al 100% se rechazan los encargos nuevos hasta que decidas subir el tope (`budget 4M`) o apagarlo (`budget off`). Con `--local` el tope es solo tuyo. Necesita el observer encendido; el conteo va un paso atrás porque los tokens del PM se suman al terminar cada respuesta.

### Codex y Gemini en algunos roles (opcional)

Por defecto todos los roles son Claude. Si querés que Codex o Gemini hagan algunos (por ejemplo, Codex como developer de backend o dos QA que se validan entre ellos), instalá su CLI, iniciá sesión y corré `/office:office-agents`. Todo el detalle está en la guía [Claude, Codex o Gemini en cada rol](providers.md).

### La oficina desde el celular (opcional)

Con `/office:telegram` conectás un bot de Telegram: el último mensaje del PM te llega al chat, le respondés desde el celular y la oficina sigue trabajando en tu computadora, y los permisos se aprueban con botones. La sesión de Claude Code tiene que quedar abierta. Todo el detalle está en la guía [La oficina remota por Telegram](telegram.md).

## 6. Actualizar

**Con un doble click.** Corré `/office:update` una vez: deja en `.claude/` del proyecto (y, si querés, en el Escritorio) un script para actualizar la oficina:

- **Windows:** doble click en `update-office.cmd`.
- **macOS:** doble click en `update-office.command` (la primera vez, si macOS lo bloquea: click derecho → Abrir).
- **Desde la terminal:** `bash .claude/update-office.sh`.

Actualiza el marketplace y todos los plugins de dev-office **en todos los proyectos** donde estén instalados, cada uno en su scope, refresca los scripts de la oficina de cada proyecto y te muestra las versiones antes y después.

**A mano**, en la carpeta de cada proyecto:

```bash
claude plugin marketplace update dev-office
claude plugin update office@dev-office --scope local
```

(y lo mismo con cada departamento instalado; con `--scope project` si los instalaste para el equipo).

En los dos casos, reiniciá Claude Code en los proyectos abiertos o usá `/reload-plugins`, y corré `/office:doctor` para ver si la versión nueva pide algo (por ejemplo, una versión más nueva de Antigravity). Revisá el [registro de cambios](../CHANGELOG.md) antes de actualizar una versión mayor.

## 7. Desinstalar

Con el instalador (sección 2), opción **Desinstalar**: saca la oficina de este proyecto y pregunta antes de borrar los documentos. Para volver a empezar, **Reinstalar desde 0**.

### Desactivar un departamento en un proyecto

En tus settings del proyecto (`.claude/settings.local.json`; en el modo compartido, `.claude/settings.json`):

```json
"enabledPlugins": {
  "dept-scraper@dev-office": false
}
```

En el modo compartido, para desactivarlo solo para vos, poné lo mismo en `.claude/settings.local.json`. `office` no se puede desactivar mientras haya departamentos activos, porque dependen de él.

## 8. Problemas comunes

Antes de mirar la tabla, corré `/office:doctor`: encuentra la mayoría de estos problemas y te dice cómo arreglarlos.

| Síntoma                                                                                | Causa                                                                  | Solución                                                                         |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| El PM no ve a los departamentos                                                        | La sesión se abrió antes de instalarlos                                | `/reload-plugins` o reiniciar Claude Code                                        |
| Pide permiso para escribir en `/tmp` u otra carpeta                                    | `acceptEdits` solo aprueba dentro del proyecto                         | Rechazalo y pedile que trabaje dentro del proyecto                               |
| Pide permiso para escribir en `.claude/` o `.git/`                                     | Son rutas protegidas de Claude Code                                    | Es lo esperado: aprobalo solo si corresponde                                     |
| "no se edita el código en la rama protegida"                                         | Estás en una rama protegida (por ejemplo `dev`)                         | Pedile al PM que trabaje en un ticket o creá una rama con `git switch -c`         |
| El PM no puede traer el ticket de Jira                                                 | Jira no está conectado o no iniciaste sesión                           | `/mcp`, servidor `atlassian`, autenticar                                         |
| Un proyecto usa la cuenta de Atlassian de otro                                          | Los dos usan la misma dirección del servidor, y la sesión es una por dirección | Una etiqueta por cuenta (`?cuenta=...`): [Dos cuentas de Atlassian](#dos-cuentas-de-atlassian-trabajo-y-personal) |
| `open-pr` o `review-fixes` dicen que falta `gh`                                         | `gh` no está instalado o no tiene sesión                               | Instalarlo según tu sistema (sección 1) y `gh auth login`                        |
| "falta 'jq'" y se bloquea todo                                                         | `jq` no está instalado o la terminal no lo encuentra                   | Instalarlo según tu sistema (sección 1) y reiniciar la terminal y Claude Code    |
| Un hook falla con `command not found` (código 127)                                     | Finales de línea de Windows (CRLF) en el script del plugin            | Reinstalar el plugin; si persiste, revisar que git no tenga `core.autocrlf` forzando CRLF en `.sh` |
| Windows: un hook falla con "bash: command not found"                                   | Falta Git for Windows o su bash no está en el PATH                     | `winget install Git.Git` y reiniciar la terminal                                 |
| Pide permiso para un comando de tests con `\| tail` o `;`                              | Cada parte de un comando compuesto se revisa por separado              | Que corra los comandos de a uno (ya está en sus instrucciones)                   |
| Advertencia: "Permission allow rule ... has a wildcard before the rest of the command" | Una regla con `*` en el medio aprueba cualquier opción en esa posición | Usar el valor exacto (por ejemplo, el nombre del paquete) y el `*` solo al final |
| El PM dice "PROVEEDOR NO DISPONIBLE" | El CLI de Codex o Gemini no está instalado, no tiene sesión o se quedó sin cuota | `bash .claude/office-agents.sh check` y seguir lo que indique |
| El PM dice "REGLAS ROTAS" | Codex o Gemini tocó un archivo prohibido, commiteó o cambió de rama | Revisá `git status` y `.office/runs/` y decidí vos qué deshacer |
| Codex o Gemini se cortan con "tiempo agotado" | El encargo tardó más de 30 minutos | Pedile al PM que lo divida, o subí `OFFICE_EXTERNAL_TIMEOUT` (en segundos) |
| Un agente termina su trabajo y queda "trabajando" sin avanzar | Un comando que no termina solo (un servidor, un test en modo watch) o un proveedor que no se cierra | La oficina frena esos comandos y el puente cierra al proveedor que no sale. Si igual pasa, cortalo con Esc y pasale al PM el último comando que se ve |
