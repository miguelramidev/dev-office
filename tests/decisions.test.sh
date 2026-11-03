#!/usr/bin/env bash
# Pruebas de la memoria del proyecto (plugins/office/skills/decisions/decisions.sh).
# Uso: bash tests/decisions.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/office/skills/decisions/decisions.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
mkdir -p "$PROJ"
(cd "$PROJ" && git init -q -b feature/PROJ-123-login)

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
run() { out=$(cd "$PROJ" && bash "$SCRIPT" "$@" 2>&1); code=$?; }
runin() { local body="$1"; shift; out=$(cd "$PROJ" && printf '%s\n' "$body" | bash "$SCRIPT" "$@" 2>&1); code=$?; }

run index
expect "sin notas, el índice avisa que no hay" '[ $code -eq 0 ] && printf "%s" "$out" | grep -q "Todavía no hay notas"'

runin "Decidimos usar sesiones en cookie, no JWT.
Aprendimos: el refresh falla si la hora del servidor se desfasa." add --title "Login con cookies: ¿por qué?" --ticket PROJ-123
DAY=$(date +%F)
F="$PROJ/docs/decisions/$DAY-proj-123-login-con-cookies-por-que.md"
expect "add guarda la nota con fecha, ticket y título en el nombre" '[ $code -eq 0 ] && [ -f "$F" ]'
expect "la nota lleva título, ticket, rama y el texto" 'grep -q "^# Login con cookies: ¿por qué?" "$F" && grep -q "Ticket:\*\* PROJ-123" "$F" && grep -q "Rama:\*\* feature/PROJ-123-login" "$F" && grep -q "sesiones en cookie" "$F"'
expect "el índice tiene una línea con el enlace a la nota" 'grep -q "PROJ-123 · \[Login con cookies: ¿por qué?\]($DAY-proj-123-login-con-cookies-por-que.md)" "$PROJ/docs/decisions/README.md"'

runin "Segunda nota." add --title "Caché de productos"
expect "una nota sin ticket también se guarda" '[ $code -eq 0 ] && ls "$PROJ/docs/decisions" | grep -q "$DAY-cache-de-productos.md"'
expect "la nota más nueva queda arriba en el índice" '[ "$(grep -n "Caché de productos" "$PROJ/docs/decisions/README.md" | cut -d: -f1)" -lt "$(grep -n "Login con cookies" "$PROJ/docs/decisions/README.md" | cut -d: -f1)" ]'
expect "el encabezado del índice se conserva" '[ "$(head -n1 "$PROJ/docs/decisions/README.md")" = "# Decisiones y aprendizajes" ]'

runin "Otra vez." add --title "Caché de productos"
expect "no pisa una nota que ya existe" '[ $code -ne 0 ] && printf "%s" "$out" | grep -q "ya existe"'
runin "" add --title "Vacía"
expect "rechaza una nota vacía" '[ $code -ne 0 ] && printf "%s" "$out" | grep -q "vacía"'
runin "x" add --title "Sin ticket válido" --ticket abc
expect "rechaza un ticket que no es como PROJ-123" '[ $code -ne 0 ]'
runin "x" add
expect "rechaza una nota sin título" '[ $code -ne 0 ]'
runin "x" add --title "Afuera" --dir ../afuera
expect "rechaza una carpeta con .." '[ $code -ne 0 ] && [ ! -d "$WORK/afuera" ]'
runin "x" add --title "Absoluta" --dir /tmp/zzz
expect "rechaza una carpeta absoluta" '[ $code -ne 0 ]'
runin "Nota en otra carpeta." add --title "Propia" --dir docs/notas
expect "acepta otra carpeta dentro del proyecto" '[ $code -eq 0 ] && [ -f "$PROJ/docs/notas/README.md" ]'

run index
expect "index muestra las notas" 'printf "%s" "$out" | grep -q "Caché de productos"'

if [ "$FAILED" -eq 0 ]; then
  echo "Todas las pruebas pasan."
else
  echo "Hay pruebas que fallan."
  exit 1
fi
