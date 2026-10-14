#!/usr/bin/env bash
# Hook PreToolUse de dev-office: no deja trabajar sobre ramas protegidas.
# Recibe el JSON de la herramienta por stdin. Sale con 2 para bloquear (el mensaje
# de stderr le llega al agente) y con 0 para permitir.
#
# Ramas protegidas: las de la variable OFFICE_PROTECTED_BRANCHES, separadas por
# espacios. Acepta nombres exactos y patrones (por ejemplo "main dev epic/*").
# Si no está definida, se protegen "main" y "master". Si está definida pero
# vacía, la guardia no hace nada.
#
# - Edit, Write y NotebookEdit: bloquea editar archivos del proyecto si la rama
#   actual está protegida (salvo la carpeta temporal de QA, .qa/).
# - Bash: bloquea commit, merge, cherry-pick, revert y am sobre una rama
#   protegida, y cualquier push hacia una rama protegida.

# Sin expansión de comodines contra archivos: "epic/*" es un patrón de rama.
set -f

PROTECTED="${OFFICE_PROTECTED_BRANCHES-main master}"
[ -z "${PROTECTED// /}" ] && exit 0

# Sin jq no se puede leer la entrada; protect.sh ya bloquea y avisa en ese caso.
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Rama actual. Fuera de un repositorio git o con HEAD suelto, no hay nada que cuidar.
BRANCH=$(git -C "$PROJECT" symbolic-ref --short -q HEAD 2>/dev/null) || exit 0

is_protected() {
  local name="${1#refs/heads/}"
  local p
  for p in $PROTECTED; do
    # shellcheck disable=SC2254 # $p es un patrón a propósito
    case "$name" in
      $p) return 0 ;;
    esac
  done
  return 1
}

block() {
  {
    echo "dev-office: $1"
    echo "Las ramas protegidas de este proyecto son: $PROTECTED."
    echo "Trabajá en una rama propia: usá la skill office:start-ticket con el ticket (por ejemplo, PROJ-123) o creala con 'git switch -c <rama>' desde la rama base."
  } >&2
  exit 2
}

# --- Edit, Write y NotebookEdit -----------------------------------------------

if [ "$TOOL" != "Bash" ]; then
  is_protected "$BRANCH" || exit 0

  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
  [ -z "$FILE_PATH" ] && exit 0
  case "$FILE_PATH" in
    /*) ;;
    *) FILE_PATH="$PROJECT/$FILE_PATH" ;;
  esac

  # Solo cuidan los archivos del proyecto; la carpeta de QA es temporal.
  case "$FILE_PATH" in
    "$PROJECT"/.qa/*) exit 0 ;;
    "$PROJECT"/*) block "no se edita el código en la rama protegida '$BRANCH'." ;;
  esac
  exit 0
fi

# --- Bash -----------------------------------------------------------------------

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# Se revisa cada comando por separado (separados por ; && || | o salto de línea).
SEGMENTS=$(printf '%s' "$COMMAND" | sed -E 's/(\&\&|\|\||;|\|)/\n/g')

while IFS= read -r SEGMENT; do
  read -r -a TOKENS <<<"$SEGMENT"
  N=${#TOKENS[@]}

  # Buscar "git" y su subcomando, salteando opciones globales como -C <dir>.
  i=0
  while [ $i -lt $N ] && [ "${TOKENS[$i]}" != "git" ]; do i=$((i + 1)); done
  [ $i -ge $N ] && continue
  i=$((i + 1))
  SUB=""
  while [ $i -lt $N ]; do
    case "${TOKENS[$i]}" in
      -C | -c | --git-dir | --work-tree) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) SUB="${TOKENS[$i]}"; i=$((i + 1)); break ;;
    esac
  done

  case "$SUB" in
    commit | merge | cherry-pick | revert | am)
      is_protected "$BRANCH" && block "no se hace '$SUB' sobre la rama protegida '$BRANCH'."
      ;;
    push)
      ARGS=()
      while [ $i -lt $N ]; do
        case "${TOKENS[$i]}" in
          --all | --mirror) block "no se hace push de todas las ramas: incluiría las protegidas." ;;
          -*) ;;
          *) ARGS+=("${TOKENS[$i]}") ;;
        esac
        i=$((i + 1))
      done
      # git push / git push origin: sube la rama actual.
      if [ ${#ARGS[@]} -le 1 ]; then
        is_protected "$BRANCH" && block "no se hace push desde la rama protegida '$BRANCH'."
      fi
      # Cada refspec: origen:destino, o una rama sola.
      for REF in "${ARGS[@]:1}"; do
        REF="${REF#+}"
        DEST="${REF##*:}"
        [ "$DEST" = "HEAD" ] && DEST="$BRANCH"
        is_protected "$DEST" && block "no se hace push hacia la rama protegida '${DEST#refs/heads/}'."
      done
      ;;
  esac
done <<<"$SEGMENTS"

exit 0
