#!/usr/bin/env bash
# Abre el observer de dev-office (.office/observer/index.html) en el navegador.
# Si la página todavía no está en el proyecto, o es de una versión anterior, la copia
# desde el plugin. Funciona en Windows (Git Bash), macOS y Linux.
#
# Uso: bash open-observer.sh [--no-open]
#   --no-open  solo copia la página y dice dónde quedó.

NO_OPEN=0
[ "${1:-}" = "--no-open" ] && NO_OPEN=1

HERE="$(cd "$(dirname "${BASH_SOURCE[0]//\\//}")" && pwd)"
SRC="$HERE/../../observer/index.html"
PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT="${PROJECT//\\//}"
DIR="$PROJECT/.office/observer"
PAGE="$DIR/index.html"

if [ ! -f "$SRC" ]; then
  echo "No encontré la página del observer en el plugin ($SRC)." >&2
  exit 1
fi
mkdir -p "$DIR" || exit 1
cmp -s "$SRC" "$PAGE" || cp "$SRC" "$PAGE" || exit 1
[ -f "$DIR/events.js" ] || : >"$DIR/events.js"

echo "Observer: $PAGE"
[ "$NO_OPEN" -eq 1 ] && exit 0

case "${OSTYPE:-}" in
  msys* | cygwin* | win32*)
    WIN_PAGE=$(cygpath -w "$PAGE" 2>/dev/null || printf '%s' "$PAGE")
    cmd //c start "" "$WIN_PAGE" >/dev/null 2>&1 || explorer.exe "$WIN_PAGE" >/dev/null 2>&1
    ;;
  darwin*) open "$PAGE" ;;
  *)
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$PAGE" >/dev/null 2>&1 &
    else
      echo "Abrilo en el navegador: file://$PAGE"
    fi
    ;;
esac
exit 0
