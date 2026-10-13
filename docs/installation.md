# Instalar dev-office en un proyecto

## 1. Requisitos

- Claude Code actualizado.
- `git` y `jq`.
- `gh` (la herramienta de GitHub para la terminal), si querés que la oficina abra PRs y aplique correcciones de revisión. En Ubuntu o WSL: `sudo apt install gh` y después `gh auth login` (GitHub.com, HTTPS, iniciar sesión con el navegador).
- En Windows: trabajar dentro de WSL2 (Ubuntu), con el proyecto en el sistema de archivos de Linux (por ejemplo `~/dev/mi-proyecto`), no en `C:\`.

## 2. Instalar los plugins

Desde la terminal, en la carpeta del proyecto:

```bash
claude plugin marketplace add miguelramidev/dev-office
claude plugin install office@dev-office --scope project
claude plugin install dept-backend@dev-office --scope project
claude plugin install dept-frontend@dev-office --scope project
claude plugin install dept-database@dev-office --scope project
claude plugin install dept-scraper@dev-office --scope project
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
- **Dashboard visual (opcional):** [agents-observe](https://github.com/simple10/agents-observe), un proyecto de la comunidad, muestra el árbol de agentes y la línea de tiempo en el navegador. Requiere Docker. Se instala por usuario: `claude plugin marketplace add simple10/agents-observe` y `claude plugin install agents-observe`.

## 6. Actualizar

```bash
claude plugin marketplace update dev-office
claude plugin update office@dev-office
```

Dentro de una sesión abierta, `/reload-plugins` aplica los cambios sin reiniciar. Revisá el [registro de cambios](../CHANGELOG.md) antes de actualizar una versión mayor.

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
| `open-pr` o `review-fixes` dicen que falta `gh`                                         | `gh` no está instalado o no tiene sesión                               | `sudo apt install gh` y `gh auth login`                                          |
| Un hook falla con `command not found` (código 127)                                     | Finales de línea de Windows (CRLF) en el script                        | `sed -i 's/\r$//' <archivo>` y trabajar dentro de WSL                            |
| Pide permiso para un comando de tests con `\| tail` o `;`                              | Cada parte de un comando compuesto se revisa por separado              | Que corra los comandos de a uno (ya está en sus instrucciones)                   |
| Advertencia: "Permission allow rule ... has a wildcard before the rest of the command" | Una regla con `*` en el medio aprueba cualquier opción en esa posición | Usar el valor exacto (por ejemplo, el nombre del paquete) y el `*` solo al final |
