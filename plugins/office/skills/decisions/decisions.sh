#!/usr/bin/env bash
# Memoria del proyecto de dev-office: una nota corta por ticket con lo que se decidió y lo que
# se aprendió, para que la próxima sesión no lo redescubra.
#
# Uso (desde la carpeta del proyecto):
#   bash decisions.sh add --title "<título>" [--ticket PROJ-123] [--dir docs/decisions] <<'NOTA'
#   <texto de la nota>
#   NOTA
#   bash decisions.sh index [--dir docs/decisions]     imprime el índice (una línea por nota)
#
# `add` escribe <dir>/<fecha>-<ticket>-<título>.md con el texto que llega por stdin y agrega una
# línea al índice <dir>/README.md (la más nueva arriba). Solo escribe dentro del proyecto: la
# carpeta tiene que ser relativa y sin "..". No llama a ningún modelo. Funciona en Linux, macOS
# (bash 3.2) y Windows con el bash de Git for Windows.

die() { echo "$*" >&2; exit 1; }

PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT="${PROJECT//\\//}"

cmd="${1:-}"; [ -n "$cmd" ] && shift
DIR="docs/decisions"; TITLE=""; TICKET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --ticket) TICKET="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    *) die "opción desconocida: $1" ;;
  esac
done

case "$DIR" in
  "" | /* | [A-Za-z]:* | *..*) die "la carpeta tiene que ser relativa al proyecto y sin '..': $DIR" ;;
esac
DIR="${DIR%/}"
INDEX="$PROJECT/$DIR/README.md"

case "$cmd" in
  index)
    [ -f "$INDEX" ] && cat "$INDEX" || echo "Todavía no hay notas en $DIR."
    ;;
  add)
    [ -n "$TITLE" ] || die "falta --title."
    case "$TICKET" in "" | [A-Z]*-[0-9]*) ;; *) die "el ticket tiene que ser como PROJ-123: $TICKET" ;; esac
    BODY=$(cat)
    [ -n "$(printf '%s' "$BODY" | tr -d '[:space:]')" ] || die "la nota está vacía: pasá el texto por stdin."
    # Nombre del archivo: fecha, ticket y título sin tildes ni símbolos.
    SLUG="$TITLE"
    for pair in "á:a" "é:e" "í:i" "ó:o" "ú:u" "ü:u" "ñ:n" "Á:a" "É:e" "Í:i" "Ó:o" "Ú:u" "Ü:u" "Ñ:n"; do
      SLUG="${SLUG//${pair%%:*}/${pair##*:}}"
    done
    SLUG=$(printf '%s' "$SLUG" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-50)
    [ -n "$SLUG" ] || SLUG="nota"
    DAY=$(date +%F)
    NAME="$DAY${TICKET:+-$(printf '%s' "$TICKET" | tr '[:upper:]' '[:lower:]')}-$SLUG.md"
    mkdir -p "$PROJECT/$DIR" || die "no pude crear $DIR."
    FILE="$PROJECT/$DIR/$NAME"
    [ -e "$FILE" ] && die "ya existe $DIR/$NAME: usá otro título."
    BRANCH=$(git -C "$PROJECT" branch --show-current 2>/dev/null | tr -d '\r')
    {
      printf '# %s\n\n' "$TITLE"
      printf -- '- **Fecha:** %s\n' "$DAY"
      [ -n "$TICKET" ] && printf -- '- **Ticket:** %s\n' "$TICKET"
      [ -n "$BRANCH" ] && printf -- '- **Rama:** %s\n' "$BRANCH"
      printf '\n%s\n' "$BODY"
    } >"$FILE"
    # El índice: una línea por nota, la más nueva arriba.
    if [ ! -f "$INDEX" ]; then
      printf '%s\n' "# Decisiones y aprendizajes" "" \
        "Una línea por nota, la más nueva arriba. La oficina lee este índice al empezar y abre solo las notas que vienen al caso." "" >"$INDEX"
    fi
    LINE="- $DAY${TICKET:+ · $TICKET} · [$TITLE]($NAME)"
    tmp="$INDEX.tmp"
    # La línea nueva va después del encabezado (las primeras 4 líneas).
    { head -n 4 "$INDEX"; printf '%s\n' "$LINE"; tail -n +5 "$INDEX"; } >"$tmp" && mv "$tmp" "$INDEX"
    echo "Nota guardada: $DIR/$NAME"
    ;;
  *)
    sed -n '2,13p' "${BASH_SOURCE[0]//\\//}" | sed 's/^# \{0,1\}//'
    ;;
esac
