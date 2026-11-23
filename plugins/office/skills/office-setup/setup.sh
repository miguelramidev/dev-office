#!/usr/bin/env bash
# Script de la skill office-setup de dev-office.
# Prepara un proyecto para trabajar con la oficina: permisos base, modo de permisos,
# el PM como agente por defecto, zona horaria del registro de actividad y archivos que git ignora.
# Agrega lo que falta sin borrar lo que el proyecto ya tiene.
#
# Dos formas:
#   - Local (por defecto): todo queda solo en tu computadora. La configuración va a
#     .claude/settings.local.json y lo que git tiene que ignorar, a .git/info/exclude (que no
#     se sube). No cambia ningún archivo del repositorio: cada persona arma su oficina.
#   - Compartida (--shared): la configuración va a .claude/settings.json y a .gitignore, en git,
#     igual para todo el equipo.
# Los documentos que genera la oficina (mapa del proyecto, decisiones, diseños, colecciones de
# API, investigaciones) van a git por defecto. Con --docs local quedan solo en tu computadora,
# en las mismas carpetas, ignorados con .git/info/exclude. --docs git lo vuelve atrás.
# --move-to-local pasa a lo local lo que una configuración compartida anterior dejó en git.
# --remove hace lo contrario de todo esto: saca de los dos settings lo que puso la oficina (sus
# permisos base, el modo de permisos, sus variables y el PM por defecto), sus bloques de
# .git/info/exclude y sus líneas de .gitignore. Las reglas propias del proyecto quedan.
#
# Uso:
#   bash setup.sh [--shared] [--docs git|local] [--move-to-local] [--mode acceptEdits|auto|default]
#                 [--timezone Zona/Ciudad] [--protected "main dev epic/*"] [--allow "Regla"]...
#   bash setup.sh --remove
# Ejemplo:
#   bash setup.sh --mode acceptEdits --timezone America/Bogota --allow "Bash(pnpm test)" --allow "Bash(pnpm test *)"

set -euo pipefail

MODE="acceptEdits"
TIMEZONE=""
PROTECTED=""
EXTRA_ALLOW=()
SCOPE="local"
DOCS=""
MOVE=0
REMOVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --shared) SCOPE="shared"; shift ;;
    --local) SCOPE="local"; shift ;;
    --docs) DOCS="$2"; shift 2 ;;
    --move-to-local) MOVE=1; SCOPE="local"; shift ;;
    --remove) REMOVE=1; shift ;;
    --mode) MODE="$2"; shift 2 ;;
    --timezone) TIMEZONE="$2"; shift 2 ;;
    --protected) PROTECTED="$2"; shift 2 ;;
    --allow) EXTRA_ALLOW+=("$2"); shift 2 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done

case "$MODE" in
  acceptEdits | auto | default) ;;
  *) echo "Modo inválido: $MODE (usar acceptEdits, auto o default)." >&2; exit 1 ;;
esac
case "$DOCS" in
  "" | git | local) ;;
  *) echo "--docs inválido: $DOCS (usar git o local)." >&2; exit 1 ;;
esac

# Funciona en Linux, macOS y Windows nativo (bash de Git for Windows).
command -v jq >/dev/null 2>&1 || {
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) HINT="En Windows (PowerShell): winget install jqlang.jq, y después reiniciá Claude Code." ;;
    darwin*) HINT="En macOS: brew install jq." ;;
    *) HINT="En Linux: sudo apt install jq (o el gestor de tu distribución)." ;;
  esac
  echo "Falta jq. $HINT Después volvé a ejecutar." >&2
  exit 1
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="${PROJECT_DIR//\\//}"   # C:\dev\app → C:/dev/app (Windows)
SHARED_SETTINGS="$PROJECT_DIR/.claude/settings.json"
LOCAL_SETTINGS="$PROJECT_DIR/.claude/settings.local.json"
SETTINGS="$SHARED_SETTINGS"
[ "$SCOPE" = "local" ] && SETTINGS="$LOCAL_SETTINGS"
GITIGNORE="$PROJECT_DIR/.gitignore"
# .git/info/exclude: lo mismo que .gitignore, pero no se sube. En un worktree, git sabe dónde está.
EXCLUDE=$(cd "$PROJECT_DIR" && git rev-parse --git-path info/exclude 2>/dev/null | tr -d '\r') || EXCLUDE=""
if [ -n "$EXCLUDE" ]; then
  case "$EXCLUDE" in /* | [A-Za-z]:*) ;; *) EXCLUDE="$PROJECT_DIR/$EXCLUDE" ;; esac
fi

# --- settings ------------------------------------------------------------------

[ "$REMOVE" -eq 1 ] || mkdir -p "$PROJECT_DIR/.claude"
for f in "$SHARED_SETTINGS" "$LOCAL_SETTINGS"; do
  if [ -f "$f" ] && ! jq empty "$f" 2>/dev/null; then
    echo "$f no es un JSON válido. Corregilo y volvé a ejecutar." >&2
    exit 1
  fi
done

# Comandos de solo lectura de git y de gh, los que usa start-ticket para crear la
# rama de trabajo y la limpieza de la carpeta de QA.
ALLOW='[
  "Bash(git status)", "Bash(git status *)",
  "Bash(git diff)", "Bash(git diff *)",
  "Bash(git log)", "Bash(git log *)",
  "Bash(git branch)", "Bash(git branch --all --list *)",
  "Bash(git remote show origin)",
  "Bash(git fetch origin)", "Bash(git fetch origin *)",
  "Bash(git switch *)",
  "Bash(git ls-remote --heads origin *)",
  "Bash(gh auth status)",
  "Bash(gh repo view *)",
  "Bash(gh pr view)", "Bash(gh pr view *)",
  "Bash(gh pr list *)", "Bash(gh pr diff *)",
  "Bash(gh pr checks)", "Bash(gh pr checks *)",
  "Bash(gh run list)", "Bash(gh run list *)", "Bash(gh run view *)",
  "Bash(gh workflow list)", "Bash(gh workflow view *)",
  "Bash(rm -r .qa)",
  "Bash(bash .claude/office-agents.sh show)", "Bash(bash .claude/office-agents.sh check)"
]'

# Acciones que siempre consulta al CEO, aunque el modo sea automático.
ASK='[
  "Bash(git commit *)", "Bash(git push *)", "Bash(git checkout *)", "Bash(git reset *)",
  "Bash(npm install *)", "Bash(pnpm add *)", "Bash(yarn add *)", "Bash(bun add *)",
  "Bash(aws *)",
  "Bash(gh pr create *)", "Bash(gh pr comment *)", "Bash(gh pr review *)", "Bash(gh api *)",
  "Bash(gh workflow run *)", "Bash(gh run rerun *)", "Bash(gh run cancel *)",
  "Bash(gh variable set *)", "Bash(gh variable delete *)",
  "Bash(terraform apply *)", "Bash(pulumi up *)", "Bash(cdk deploy *)", "Bash(npx cdk deploy *)",
  "Bash(kubectl *)", "Bash(ssh *)", "Bash(scp *)"
]'

# Acciones prohibidas: leer secretos, forzar push, saltear hooks, borrados masivos,
# mergear PRs (lo hace el CEO), borrar repositorios, tocar secretos de GitHub y
# destruir infraestructura.
# Las reglas con **/ cubren también los .env de subcarpetas (por ejemplo, en un monorepo).
DENY='[
  "Read(./**/.env)", "Read(./**/.env.local)",
  "Read(./**/.env.development)", "Read(./**/.env.development.local)",
  "Read(./**/.env.production)", "Read(./**/.env.production.local)",
  "Read(./**/.env.staging)", "Read(./**/.env.test)", "Read(./**/.env.test.local)",
  "Bash(git push --force *)", "Bash(git push -f *)",
  "Bash(git commit --no-verify *)", "Bash(git push --no-verify *)",
  "Bash(rm -rf *)",
  "Bash(gh pr merge *)", "Bash(gh repo delete *)",
  "Bash(gh secret set *)", "Bash(gh secret delete *)",
  "Bash(terraform destroy *)", "Bash(pulumi destroy *)", "Bash(cdk destroy *)", "Bash(npx cdk destroy *)"
]'

# Lo que la oficina genera mientras trabaja y tu configuración personal.
WORK_FILES=(".qa/" ".office/" ".claude/office-activity.log" ".claude/settings.json.bak" ".claude/settings.local.json.bak" ".claude/office-agents.local.json")
# En el modo local, toda la carpeta .claude/ que no esté ya en git (los settings, los scripts que
# copia la oficina, las reglas locales) y .mcp.json: es configuración de cada persona. Lo que el
# equipo ya subió a git sigue en git.
LOCAL_FILES=(".claude/" ".mcp.json")
# Los documentos que genera la oficina, si el proyecto los quiere locales.
DOC_FILES=("docs/project-map.md" "docs/project-map/" "docs/decisions/" "docs/design/" "docs/api/" "docs/research/")

# Saca de un settings lo que puso la oficina: sus reglas base, el modo de permisos, sus
# variables y el PM por defecto. Las reglas propias del proyecto quedan.
strip_office() {
  local f="$1"
  [ -f "$f" ] || return 0
  cp "$f" "$f.bak"
  jq --argjson allow "$ALLOW" --argjson ask "$ASK" --argjson deny "$DENY" '
    def drop($l; $x): if $l == null then null else ($l - $x) end;
    .permissions.allow = drop(.permissions.allow; $allow)
    | .permissions.ask = drop(.permissions.ask; $ask)
    | .permissions.deny = drop(.permissions.deny; $deny)
    | del(.permissions.defaultMode)
    | .permissions |= with_entries(select(.value != null and .value != []))
    | if (.permissions | length) == 0 then del(.permissions) else . end
    | if .env then .env |= with_entries(select(.key | test("^(OFFICE_|CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS$)") | not)) else . end
    | if (.env // {}) == {} then del(.env) else . end
    | if .agent == "office:pm" then del(.agent) else . end
  ' "$f.bak" | tr -d '\r' > "$f"
}

# Escribe un bloque con marcas en un archivo de ignorados, reemplazando el anterior.
# $1: archivo; $2: nombre del bloque; el resto: las líneas (sin líneas, solo borra el bloque).
ignore_block() {
  local file="$1" name="$2"; shift 2
  local begin="# >>> dev-office: $name" end="# <<< dev-office: $name"
  [ $# -eq 0 ] && [ ! -f "$file" ] && return 0
  mkdir -p "$(dirname "$file")"
  touch "$file"
  awk -v b="$begin" -v e="$end" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$file" > "$file.tmp"
  if [ $# -gt 0 ]; then
    if [ -s "$file.tmp" ] && [ "$(tail -c1 "$file.tmp")" != "" ]; then echo >> "$file.tmp"; fi
    { echo "$begin"; printf '%s\n' "$@"; echo "$end"; } >> "$file.tmp"
  fi
  mv "$file.tmp" "$file"
}

# Saca de .gitignore las líneas de la oficina. Devuelve 0 si cambió algo.
strip_gitignore() {
  [ -f "$GITIGNORE" ] || return 1
  local args=() l
  for l in "${WORK_FILES[@]}"; do args+=(-e "$l"); done
  grep -vxF "${args[@]}" "$GITIGNORE" > "$GITIGNORE.tmp" || true
  if ! cmp -s "$GITIGNORE" "$GITIGNORE.tmp"; then mv "$GITIGNORE.tmp" "$GITIGNORE"; return 0; fi
  rm -f "$GITIGNORE.tmp"; return 1
}

# --- Sacar la oficina del proyecto (--remove) ------------------------------------------

if [ "$REMOVE" -eq 1 ]; then
  echo "Saqué la configuración de la oficina:"
  for f in "$LOCAL_SETTINGS" "$SHARED_SETTINGS"; do
    [ -f "$f" ] || continue
    strip_office "$f"
    echo "  - ${f#"$PROJECT_DIR"/}: permisos base, modo de permisos, variables y el PM por defecto (copia: ${f#"$PROJECT_DIR"/}.bak)."
  done
  if [ -n "$EXCLUDE" ] && [ -f "$EXCLUDE" ] && grep -q '^# >>> dev-office: ' "$EXCLUDE"; then
    ignore_block "$EXCLUDE" "oficina"
    ignore_block "$EXCLUDE" "documentos locales"
    echo "  - .git/info/exclude: los bloques de la oficina."
  fi
  strip_gitignore && echo "  - .gitignore: las líneas de la oficina."
  [ -f "$SHARED_SETTINGS" ] && echo "  Las reglas propias del proyecto quedan. Si .claude/settings.json o .gitignore están en git, revisá el cambio y commitealo."
  exit 0
fi

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak"

if [ ${#EXTRA_ALLOW[@]} -gt 0 ]; then
  EXTRA=$(printf '%s\n' "${EXTRA_ALLOW[@]}" | jq -R . | jq -s .)
else
  EXTRA='[]'
fi

jq \
  --argjson allow "$ALLOW" \
  --argjson extra "$EXTRA" \
  --argjson ask "$ASK" \
  --argjson deny "$DENY" \
  --arg mode "$MODE" \
  --arg tz "$TIMEZONE" \
  --arg protected "$PROTECTED" '
  # Agrega a una lista los elementos que todavía no tiene, sin cambiar el orden.
  def add_missing($current; $new): ($current // []) + ($new - ($current // []));

  .permissions.allow = add_missing(.permissions.allow; $allow + $extra)
  | .permissions.ask = add_missing(.permissions.ask; $ask)
  | .permissions.deny = add_missing(.permissions.deny; $deny)
  | .permissions.defaultMode = $mode
  # El PM como agente por defecto: "claude" a secas arranca con la oficina. Si el proyecto
  # ya eligió otro agente, queda el suyo.
  | if (.agent // "") == "" then .agent = "office:pm" else . end
  | if $tz != "" then .env.OFFICE_TIMEZONE = $tz else . end
  | if $protected != "" then .env.OFFICE_PROTECTED_BRANCHES = $protected else . end
' "$SETTINGS.bak" | tr -d '\r' > "$SETTINGS"
# (tr: el jq de Windows escribe finales de línea CRLF; el archivo queda con LF.)

# --- Pasar a lo local lo que dejó una configuración compartida anterior ---------------

MOVED=""
if [ "$MOVE" -eq 1 ] && [ -f "$SHARED_SETTINGS" ]; then
  # Del archivo del equipo salen solo las cosas de la oficina; las reglas del proyecto quedan.
  strip_office "$SHARED_SETTINGS"
  # Las variables de la oficina que tenía el equipo pasan a las tuyas, si no las tenías.
  jq -s '.[0] as $mine | .[1] as $team
    | $mine | .env = (($team.env // {} | with_entries(select(.key | test("^(OFFICE_|CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS$)")))) + (.env // {}))
    | if .env == {} then del(.env) else . end' "$SETTINGS" "$SHARED_SETTINGS.bak" | tr -d '\r' > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  MOVED="$MOVED .claude/settings.json"
  # La configuración de proveedores del equipo pasa a la tuya (la tuya manda) y se borra.
  OA="$PROJECT_DIR/.claude/office-agents.json"; OAL="$PROJECT_DIR/.claude/office-agents.local.json"
  if [ -f "$OA" ] && jq empty "$OA" 2>/dev/null; then
    [ -f "$OAL" ] || echo '{}' > "$OAL"
    jq -s '.[0] * .[1]' "$OA" "$OAL" | tr -d '\r' > "$OAL.tmp" && mv "$OAL.tmp" "$OAL" && rm -f "$OA"
    MOVED="$MOVED .claude/office-agents.json"
  fi
  # Las líneas de la oficina en .gitignore pasan a .git/info/exclude (más abajo).
  strip_gitignore && MOVED="$MOVED .gitignore"
fi

# --- Archivos que git ignora ------------------------------------------------------

IGNORED_IN=""
if [ "$SCOPE" = "local" ]; then
  if [ -n "$EXCLUDE" ]; then
    ignore_block "$EXCLUDE" "oficina" "${WORK_FILES[@]}" "${LOCAL_FILES[@]}"
    IGNORED_IN=".git/info/exclude"
  else
    echo "AVISO: no es un repositorio de git, así que no hay nada que ignorar." >&2
  fi
else
  touch "$GITIGNORE"
  # Si el archivo no termina en salto de línea, agregarlo para no pegar las líneas.
  if [ -s "$GITIGNORE" ] && [ "$(tail -c1 "$GITIGNORE")" != "" ]; then
    echo >> "$GITIGNORE"
  fi
  for LINE in "${WORK_FILES[@]}"; do
    grep -qxF "$LINE" "$GITIGNORE" || echo "$LINE" >> "$GITIGNORE"
  done
  IGNORED_IN=".gitignore"
fi

DOCS_NOTE=""
if [ -n "$DOCS" ] && [ -n "$EXCLUDE" ]; then
  if [ "$DOCS" = "local" ]; then
    ignore_block "$EXCLUDE" "documentos locales" "${DOC_FILES[@]}"
    DOCS_NOTE="los documentos de la oficina quedan solo en tu computadora (.git/info/exclude). Lo que ya estaba en git sigue en git."
  else
    ignore_block "$EXCLUDE" "documentos locales"
    DOCS_NOTE="los documentos de la oficina van a git."
  fi
fi

# --- Resumen ------------------------------------------------------------------

echo "Listo:"
if [ "$SCOPE" = "local" ]; then
  echo "  - Modo local: nada de esto se sube al repositorio."
else
  echo "  - Modo compartido: la configuración va en git, igual para todo el equipo."
fi
echo "  - $SETTINGS: permisos base, modo '$MODE', el PM como agente por defecto${TIMEZONE:+, zona horaria $TIMEZONE}${PROTECTED:+, ramas protegidas: $PROTECTED}."
echo "  - Copia del archivo anterior: $SETTINGS.bak"
[ -n "$IGNORED_IN" ] && echo "  - $IGNORED_IN: .qa/, .office/, el registro de actividad, las copias de seguridad y tu configuración personal$( [ "$SCOPE" = "local" ] && echo ', más la carpeta .claude/ y .mcp.json (lo que ya está en git sigue en git)')."
[ -n "$DOCS_NOTE" ] && echo "  - Documentos: $DOCS_NOTE"
if [ -n "$MOVED" ]; then
  echo "  - Pasé a lo local lo que la oficina tenía en:$MOVED. Revisá esos cambios y commitealos: así la oficina deja de estar en el repositorio."
  PLUGINS=$(jq -r '.enabledPlugins // {} | keys[] | select(endswith("@dev-office"))' "$SHARED_SETTINGS" 2>/dev/null | tr -d '\r')
  if [ -n "$PLUGINS" ]; then
    echo "  - Los plugins de la oficina siguen instalados para el proyecto. Para pasarlos a solo vos, en la terminal:"
    for p in $PLUGINS; do echo "      claude plugin uninstall $p --scope project"; echo "      claude plugin install $p --scope local"; done
  fi
fi
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  echo "  - AVISO: el proyecto no tiene CLAUDE.md. Los agentes lo necesitan para conocer las reglas del proyecto."
fi
