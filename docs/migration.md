# Migrar la oficina: de compartida a local, y una cuenta de Atlassian por proyecto

Esta guía es para proyectos que ya usan la oficina. Cubre tres casos:

1. [Pasar la oficina de compartida a local](#1-de-compartida-a-local): lo que antes iba en git (`--scope project`, `.claude/settings.json`, `.gitignore`) pasa a tu computadora.
2. [Instalarla en un proyecto donde no se puede ver nada](#2-un-proyecto-donde-no-se-puede-ver-nada-de-la-oficina): por ejemplo, el repositorio de tu trabajo.
3. [Separar cuentas de Atlassian](#3-una-cuenta-de-atlassian-por-proyecto): una del trabajo y otra personal, cada proyecto con la suya.

Para un proyecto nuevo no hace falta migrar nada: seguí [Instalar en un proyecto](installation.md). El modo local ya es el de por defecto.

## Antes de empezar

- Actualizá la oficina: `claude plugin marketplace update dev-office` y después `claude plugin update office@dev-office` con el alcance que tenga (`--scope local` o `--scope project`).
- Cerrá las sesiones de Claude Code de ese proyecto.
- Corré `git status` y commiteá o guardá lo pendiente: la migración cambia archivos que están en git, y conviene que ese cambio vaya solo en su commit.
- Si es un proyecto en equipo, avisales: al sacar la oficina de git, a quien haga pull se le borran esos archivos de su carpeta y cada uno arma su oficina local.

Los comandos `claude ...` andan en PowerShell o en la Terminal. Los de archivos (`rm`, `git rm`) son de bash: en Windows, corrélos en Git Bash.

## 1. De compartida a local

### Qué cambia

| Qué | Compartida (antes) | Local (ahora) |
| --- | --- | --- |
| Plugins instalados | `--scope project`, en `.claude/settings.json` | `--scope local`, en `.claude/settings.local.json` |
| Permisos, ramas protegidas, zona horaria, PM por defecto | `.claude/settings.json` | `.claude/settings.local.json` |
| Proveedores por rol | `.claude/office-agents.json` | `.claude/office-agents.local.json` |
| Archivos que git ignora | `.gitignore` | `.git/info/exclude` (no se sube) |
| Jira y Figma | `.mcp.json` | `claude mcp add --scope local` (en `~/.claude.json` de tu usuario) |
| Reglas del proyecto que propone la oficina | `CLAUDE.md` | `.claude/rules/office-project.md` (ignorado) |
| Documentos (mapa, decisiones, diseños, colecciones de API, investigaciones) | git | git, salvo que elijas `--docs local` |

En el modo local, git ignora `.mcp.json` y todo lo que haya en `.claude/` que no esté ya en git. Lo que el equipo ya subió sigue en git hasta que lo saques.

### Paso a paso

1. **Fijate qué tenés instalado y con qué alcance:**

   ```bash
   claude plugin list
   ```

2. **Pasá cada plugin de `project` a `local`**, uno por uno (los que digan `project` en la lista):

   ```bash
   claude plugin uninstall office@dev-office --scope project
   claude plugin install office@dev-office --scope local
   claude plugin uninstall dept-frontend@dev-office --scope project
   claude plugin install dept-frontend@dev-office --scope local
   ```

   Repetí con cada departamento. Aprovechá para no reinstalar los que no usás: cada departamento suma sus skills a todos los agentes.

3. **Corré `/office:office-setup`** y elegí:
   - **Modo local.**
   - **Pasar a lo local** lo que ya estaba en git (te lo ofrece si encuentra la oficina en `.claude/settings.json` o `.claude/office-agents.json`). Hace esto:
     - saca de `.claude/settings.json` las reglas base de la oficina, el modo de permisos, sus variables y el PM por defecto, y deja las reglas propias del proyecto;
     - pasa sus variables (ramas protegidas, zona horaria) a tus settings;
     - pasa los proveedores de `.claude/office-agents.json` a tu configuración personal (la tuya manda) y borra el del equipo;
     - saca sus líneas de `.gitignore` y las pone en `.git/info/exclude`;
     - te muestra los comandos del paso 2, si quedó algún plugin con `--scope project`.
   - **Documentos:** en git (por defecto) o locales (`--docs local`).

4. **Dejá de seguir en git los archivos de la oficina** que se habían subido. Esto los saca del repositorio sin borrarlos de tu carpeta:

   ```bash
   git rm --cached --ignore-unmatch .mcp.json .claude/office-agents.sh .claude/office-agents.cmd .claude/office-telegram.sh .claude/office-telegram.cmd .claude/update-office.sh .claude/update-office.cmd .claude/update-office.command
   ```

   Sacá `.mcp.json` de la lista si tiene otros servidores que usa el equipo; en ese caso, borrá solo la entrada `atlassian` (y `figma`, si la agregó la oficina).

5. **Conectá Jira solo para vos:** ver [3. Una cuenta de Atlassian por proyecto](#3-una-cuenta-de-atlassian-por-proyecto).

6. **Revisá y commiteá** lo que quedó en `git status`: `.claude/settings.json`, `.gitignore`, los archivos que dejaste de seguir y el borrado de `.claude/office-agents.json`. Es el único commit de la migración.

7. **Comprobá:**

   ```bash
   claude plugin list
   git status
   git check-ignore -v .office .claude/settings.local.json
   ```

   Los plugins de la oficina tienen que decir `local`, `git status` no tiene que mostrar nada de la oficina y `check-ignore` tiene que nombrar `.git/info/exclude`. Al abrir `claude`, el encabezado dice `@office:pm`.

## 2. Un proyecto donde no se puede ver nada de la oficina

Para un repositorio donde la oficina no puede aparecer (el de tu trabajo, por ejemplo), ni siquiera en el `.gitignore`:

1. **Instalá los plugins con `--scope local`:**

   ```bash
   claude plugin install office@dev-office --scope local
   claude plugin install dept-frontend@dev-office --scope local
   ```

2. **Corré `/office:office-setup`** y elegí **modo local** y **documentos locales** (`--docs local`). El mapa, las decisiones, los diseños, las colecciones de API y las investigaciones quedan en tu carpeta, en sus lugares de siempre, pero git no los ve.
3. **Reglas del proyecto:** van a `.claude/rules/office-project.md`. Si te propone tocar el `CLAUDE.md` del proyecto, decile que no; si el proyecto no tiene `CLAUDE.md`, no lo crees.
4. **Jira:** con la etiqueta de la cuenta del trabajo, como en la sección 3.
5. **Comprobá** con `git status` y `git check-ignore -v .office docs/project-map.md`: no tiene que aparecer nada de la oficina, y lo ignorado lo ignora `.git/info/exclude`. El `.gitignore` queda igual.

Lo único que puede llegar a git son tus commits y tus PRs. La oficina no se nombra en ellos. Claude Code sí agrega por su cuenta `Co-Authored-By: Claude` en los commits y "Generated with Claude Code" en los PRs; si tu empresa prefiere que no aparezcan (revisá antes su política sobre el uso de IA), se apagan en `.claude/settings.local.json`:

```json
{ "attribution": { "commit": "", "pr": "" } }
```

## 3. Una cuenta de Atlassian por proyecto

### Por qué se pisaban las cuentas

Claude Code guarda **una sesión de Atlassian por dirección del servidor**, para toda la computadora, aunque el servidor esté configurado solo en un proyecto. Con la dirección de siempre, si te logueás con la cuenta personal en un proyecto, el del trabajo pasa a usarla también.

La solución es que cada cuenta use su propia dirección, agregándole `?cuenta=<etiqueta>`. El servidor se sigue llamando `atlassian`: el PM solo tiene acceso a las herramientas de ese nombre.

### La etiqueta es de la cuenta, no del proyecto

Todos los proyectos que usan la misma cuenta llevan la misma etiqueta y comparten el login: te logueás una vez. Cada cuenta distinta lleva la suya.

| Proyectos | Etiquetas |
| --- | --- |
| Uno personal y uno del trabajo | `personal` y `trabajo` |
| Dos personales y uno del trabajo | los dos personales con `personal`, el del trabajo con `trabajo` |
| Dos del trabajo de la misma empresa y uno personal | los dos del trabajo con `trabajo`, el personal con `personal` |
| Dos empresas distintas | `empresa-a` y `empresa-b` |

Si en un proyecto te logueás con otra cuenta, cambia en todos los que usan esa etiqueta. Por eso conviene que la etiqueta diga de quién es la cuenta.

### Paso a paso

1. **Limpiá lo que había,** en cada proyecto, desde su carpeta:

   ```bash
   claude mcp get atlassian
   ```

   - Con alcance **user**: `claude mcp remove atlassian -s user` (una sola vez; si no, aparece en todos tus proyectos).
   - Desde **`.mcp.json`**: sacá la entrada `atlassian` de ese archivo.
   - Con alcance **local**: `claude mcp remove atlassian -s local`.

2. **Conectá cada proyecto con la etiqueta de su cuenta:**

   ```bash
   # en el proyecto del trabajo
   claude mcp add --transport http --scope local atlassian "https://mcp.atlassian.com/v2/mcp?cuenta=trabajo"
   # en el proyecto personal
   claude mcp add --transport http --scope local atlassian "https://mcp.atlassian.com/v2/mcp?cuenta=personal"
   ```

3. **Logueate en cada uno:** abrí `claude`, corré `/mcp`, elegí `atlassian` → autenticar y entrá en el navegador con la cuenta que corresponde. Si el navegador ya tiene abierta la otra cuenta de Atlassian, cerrá esa sesión o usá una ventana privada.

4. **Anotá el sitio** en las reglas de cada proyecto (`Sitio de Jira: miempresa.atlassian.net`), así el PM usa ese aunque tu cuenta vea varios sitios.

5. **Comprobalo:** en cada proyecto, preguntale al PM "¿con qué cuenta de Atlassian estás conectado?". Tiene que decir el email de esa cuenta. Volvé al primero y confirmá que sigue con la suya, sin pedirte login.

Si `atlassian` está en más de un alcance, Claude Code usa primero el local, después el de `.mcp.json` y por último el de tu usuario. Dejá solo el local.

### Sin navegador: con un token de API

Si el login por navegador no te sirve (por ejemplo, en una máquina sin navegador), cada proyecto se puede conectar con un token de API de su cuenta:

1. Creá un token con alcances en [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens), con la cuenta del proyecto. La organización tiene que tener habilitada la autenticación con token para el servidor MCP de Atlassian: en la del trabajo se lo pedís al administrador; en tu cuenta personal, el administrador sos vos.
2. Buscá el script: `find ~/.claude/plugins -name jira-account.sh`.
3. En la carpeta del proyecto: `bash <la ruta que te dio>`. Te pide el email, el token (no se muestra) y el sitio, comprueba el token y registra `atlassian` solo para ese proyecto.
4. Reiniciá Claude Code. No hace falta `/mcp`.

Con token faltan algunas herramientas de Atlassian (las que piden alcances que un token no puede tener); las de Jira y Confluence están.

## Problemas comunes

| Problema | Por qué pasa | Qué hacer |
| --- | --- | --- |
| `git status` muestra archivos de la oficina | Se habían subido antes del modo local | `git rm --cached` de esos archivos (paso 4 de la sección 1) y commit |
| `office-setup` no ofrece pasar a lo local | La oficina no está en `.claude/settings.json` ni en `.claude/office-agents.json` | No hay nada que pasar: ya está local |
| Un proyecto usa la cuenta de Atlassian de otro | Los dos usan la misma dirección del servidor | Una etiqueta por cuenta (sección 3) |
| `/mcp` vuelve a pedir login al cambiar de proyecto | Los dos proyectos usan la misma etiqueta con cuentas distintas | Cada cuenta con su etiqueta |
| El PM no ve las herramientas de Jira | El servidor no se llama `atlassian` | `claude mcp remove` y volvé a agregarlo con el nombre `atlassian` |
| Aparece `atlassian` en todos los proyectos | Quedó uno con alcance user | `claude mcp remove atlassian -s user` |
