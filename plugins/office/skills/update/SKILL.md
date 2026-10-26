---
name: update
description: Deja lista la actualización de la oficina dev-office con un doble click - copia al proyecto (y si el CEO quiere, al Escritorio) el script update-office, que actualiza el marketplace y todos los plugins de dev-office en todos los proyectos donde estén instalados, en su scope, y refresca los scripts de la oficina en cada proyecto. También puede correr la actualización en el momento. Usar cuando el CEO quiere actualizar la oficina o tener un botón para hacerlo.
---

Vas a dejarle al CEO la actualización de la oficina a un doble click. Hablale en su idioma (si escribe en español, con voseo).

Los archivos están en la misma carpeta que este archivo:

- `update-office.sh`: hace el trabajo. Actualiza el marketplace `dev-office` y cada plugin de dev-office instalado en esta computadora: los de usuario una vez, y los de proyecto en la carpeta de cada proyecto (el CLI de Claude Code los lista a todos, así que un solo click actualiza todos los proyectos). Después refresca en cada proyecto los scripts que la oficina copió en `.claude/` y muestra las versiones antes y después.
- `update-office.cmd`: el doble click en Windows (abre el `.sh` con el bash de Git for Windows).
- `update-office.command`: el doble click en macOS (desde el Finder).

## Pasos

1. **Copiá los tres archivos a `.claude/` del proyecto**, si no están o son de una versión anterior (la línea `# update-office-version:` del principio):

   ```bash
   cp <carpeta de esta skill>/update-office.sh .claude/update-office.sh
   cp <carpeta de esta skill>/update-office.cmd .claude/update-office.cmd
   cp <carpeta de esta skill>/update-office.command .claude/update-office.command
   ```

   En macOS y Linux, dejá ejecutables el `.sh` y el `.command` (`chmod +x`).

2. **Preguntale si quiere un acceso en el Escritorio**, para no tener que entrar a la carpeta oculta `.claude`. Si dice que sí, copiá ahí los mismos tres archivos (los tres juntos: el lanzador usa el `.sh` de su misma carpeta):
   - Windows: la carpeta del Escritorio es la de `cygpath -D` (o `$USERPROFILE/Desktop`).
   - macOS: `~/Desktop`.
   - Linux: `xdg-user-dir DESKTOP` (o `~/Desktop`).

   Es una carpeta fuera del proyecto: Claude Code le va a pedir permiso.

3. **Explicale cómo se usa**, en pocas líneas:
   - **Windows:** doble click en `update-office.cmd`.
   - **macOS:** doble click en `update-office.command`. La primera vez, si macOS lo bloquea, click derecho → Abrir.
   - **Cualquier sistema, desde la terminal:** `bash .claude/update-office.sh`.
   - Actualiza todos los proyectos donde tenga la oficina, no solo este.
   - Al terminar, hay que reiniciar Claude Code en los proyectos abiertos (o usar `/reload-plugins`).

4. **Si quiere actualizar ahora**, corré `bash .claude/update-office.sh --yes` y mostrale el resumen de versiones. Avisale que la sesión actual sigue con la versión vieja hasta que reinicie.

Si el proyecto lo comparte con el equipo, puede hacer commit de los tres archivos de `.claude/` para que todos tengan el botón.
