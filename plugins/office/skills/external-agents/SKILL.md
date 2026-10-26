---
name: external-agents
description: Cómo correr un encargo de la oficina con Codex o Gemini en lugar de un agente de Claude - el script run-external.sh que arma el prompt con las instrucciones del rol, corre el CLI con tope de tiempo y revisa lo que cambió (secretos, lockfiles, alcance del rol, commits y rama). La usa el agente puente office:external. Usar solo cuando el PM encarga un rol que .claude/office-agents.json asigna a codex o gemini.
user-invocable: false
---

# Correr un encargo con Codex o Gemini

El script `run-external.sh` está en la misma carpeta que este archivo. Corre un encargo con el CLI del proveedor, en la carpeta del proyecto, y revisa lo que hizo. No deshace nada: lo informa.

## Cómo se usa

1. Creá la carpeta del encargo en `.office/runs/<fecha>-<hora>-<rol>/` (por ejemplo `.office/runs/20261026-1530-backend.developer/`) y escribí el encargo completo del PM en `task.md` adentro.
2. Corré, con un tope de 10 minutos en la herramienta Bash (600000 ms):

   ```bash
   bash <carpeta de esta skill>/run-external.sh --role backend.developer --provider codex --run-dir .office/runs/20261026-1530-backend.developer
   ```

   Con modelo: `--model <modelo>` (por ejemplo `--model pro` para Gemini).

3. El script imprime un resumen (también queda en `summary.txt`): resultado, duración, archivos cambiados y problemas. El reporte del proveedor queda en `output.md` y el registro del CLI en `log.txt`.

## Qué hace

- **Antes:** verifica que el CLI esté instalado y que la rama actual no esté protegida (`OFFICE_PROTECTED_BRANCHES`, por defecto `main` y `master`). Si está protegida, no corre nada.
- **Prompt:** junta las reglas de la oficina para el proveedor, las instrucciones del rol (el archivo del agente en su plugin, o `.claude/agents/<nombre>.md` para `project.<nombre>`), las skills que ese agente precarga y el encargo.
- **Corre:**
  - **Codex:** `codex -a never exec -s workspace-write` (sin red, sin pedir aprobación; `read-only` para el asesor del PM).
  - **Gemini:** `gemini -p ... --approval-mode auto_edit` (edita archivos sin preguntar, pero no corre comandos de la terminal; `default` para el asesor, que solo lee).
  - Se corta a los `OFFICE_EXTERNAL_TIMEOUT` segundos (por defecto 540, para que entre en los 10 minutos de la herramienta Bash).
- **Después:** compara el repositorio antes y después y marca como problema:
  - tocar secretos (`.env`), claves privadas o lockfiles;
  - escribir fuera de lo que permite el rol: el QA solo `.qa/`, los arquitectos y el designer solo `docs/design/`, el asesor del PM nada;
  - hacer un commit o cambiar de rama.

## Códigos de salida

| Código | Qué pasó | Qué hace el puente |
| --- | --- | --- |
| 0 | Terminó bien | Sigue con su verificación |
| 1 | Error de uso (falta el encargo, rol desconocido, plugin no encontrado) | Lo reporta tal cual |
| 2 | Proveedor no disponible: no instalado, sin sesión, sin credenciales o sin cuota | Frena: **PROVEEDOR NO DISPONIBLE** |
| 3 | El proveedor falló o no devolvió reporte | Lo reporta con el final del registro |
| 4 | Se rompió una regla de la oficina, o la rama está protegida | Frena: **REGLAS ROTAS** |
| 5 | Se agotó el tiempo | Reporta lo que alcanzó a cambiar y propone dividir el encargo |

## Variables opcionales

- `OFFICE_EXTERNAL_TIMEOUT`: tope en segundos.
- `OFFICE_CODEX_ARGS` y `OFFICE_GEMINI_ARGS`: opciones extra para cada CLI, por si una versión nueva cambia algo.
- `OFFICE_PLUGINS_DIR`: carpeta donde buscar los plugins de dev-office, si el script no los encuentra solo.

Se configuran en `.claude/settings.json` del proyecto, en `env`.
