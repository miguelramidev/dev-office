#!/usr/bin/env bash
# Script de la skill office-setup de dev-office.
# Prepara un proyecto para trabajar con la oficina: permisos base, modo de permisos,
# zona horaria del registro de actividad y entradas de .gitignore.
# Agrega lo que falta sin borrar lo que el proyecto ya tiene.
#
# Uso:
#   bash setup.sh [--mode acceptEdits|auto|default] [--timezone Zona/Ciudad] [--protected "main dev epic/*"] [--allow "Regla"]...
# Ejemplo:
#   bash setup.sh --mode acceptEdits --timezone America/Bogota --allow "Bash(pnpm test)" --allow "Bash(pnpm test *)"

set -euo pipefail

MODE="acceptEdits"
TIMEZONE=""
PROTECTED=""
EXTRA_ALLOW=()

while [ $# -gt 0 ]; do
  case "$1" in
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

command -v jq >/dev/null 2>&1 || { echo "Falta jq. Instalalo y volvé a ejecutar." >&2; exit 1; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SETTINGS="$PROJECT_DIR/.claude/settings.json"
GITIGNORE="$PROJECT_DIR/.gitignore"

# --- .claude/settings.json ---------------------------------------------------

mkdir -p "$PROJECT_DIR/.claude"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "$SETTINGS no es un JSON válido. Corregilo y volvé a ejecutar." >&2
  exit 1
fi
cp "$SETTINGS" "$SETTINGS.bak"

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
  "Bash(rm -r .qa)"
]'

# Acciones que siempre consulta al CEO, aunque el modo sea automático.
ASK='[
  "Bash(git commit *)", "Bash(git push *)", "Bash(git checkout *)", "Bash(git reset *)",
  "Bash(npm install *)", "Bash(pnpm add *)", "Bash(yarn add *)", "Bash(bun add *)",
  "Bash(aws *)",
  "Bash(gh pr create *)", "Bash(gh pr comment *)", "Bash(gh pr review *)", "Bash(gh api *)"
]'

# Acciones prohibidas: leer secretos, forzar push, saltear hooks, borrados masivos,
# mergear PRs (lo hace el CEO) y borrar repositorios.
# Las reglas con **/ cubren también los .env de subcarpetas (por ejemplo, en un monorepo).
DENY='[
  "Read(./**/.env)", "Read(./**/.env.local)",
  "Read(./**/.env.development)", "Read(./**/.env.development.local)",
  "Read(./**/.env.production)", "Read(./**/.env.production.local)",
  "Read(./**/.env.staging)", "Read(./**/.env.test)", "Read(./**/.env.test.local)",
  "Bash(git push --force *)", "Bash(git push -f *)",
  "Bash(git commit --no-verify *)", "Bash(git push --no-verify *)",
  "Bash(rm -rf *)",
  "Bash(gh pr merge *)", "Bash(gh repo delete *)"
]'

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
  | if $tz != "" then .env.OFFICE_TIMEZONE = $tz else . end
  | if $protected != "" then .env.OFFICE_PROTECTED_BRANCHES = $protected else . end
' "$SETTINGS.bak" > "$SETTINGS"

# --- .gitignore ---------------------------------------------------------------

touch "$GITIGNORE"
# Si el archivo no termina en salto de línea, agregarlo para no pegar las líneas.
if [ -s "$GITIGNORE" ] && [ "$(tail -c1 "$GITIGNORE")" != "" ]; then
  echo >> "$GITIGNORE"
fi
for LINE in ".qa/" ".claude/office-activity.log" ".claude/settings.json.bak"; do
  grep -qxF "$LINE" "$GITIGNORE" || echo "$LINE" >> "$GITIGNORE"
done

# --- Resumen ------------------------------------------------------------------

echo "Listo:"
echo "  - $SETTINGS: permisos base, modo '$MODE'${TIMEZONE:+, zona horaria $TIMEZONE}${PROTECTED:+, ramas protegidas: $PROTECTED}."
echo "  - Copia del archivo anterior: $SETTINGS.bak"
echo "  - $GITIGNORE: .qa/, registro de actividad y la copia de seguridad."
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  echo "  - AVISO: el proyecto no tiene CLAUDE.md. Los agentes lo necesitan para conocer las reglas del proyecto."
fi