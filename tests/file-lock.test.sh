#!/usr/bin/env bash
# Pruebas del hook de reservas de archivos (plugins/office/scripts/file-lock.sh).
# Uso: bash tests/file-lock.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/office/scripts/file-lock.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
mkdir -p "$PROJ/src"
export CLAUDE_PROJECT_DIR="$PROJ"
unset OFFICE_FILE_LOCKS OFFICE_LOCK_TTL

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
# edit <agente> <tipo> <archivo> [herramienta]
edit() {
  out=$(jq -cn --arg a "$1" --arg t "$2" --arg f "$3" --arg tool "${4:-Edit}" \
    '{hook_event_name: "PreToolUse", tool_name: $tool, agent_id: (if $a == "" then null else $a end), agent_type: $t, tool_input: {file_path: $f}}' | bash "$HOOK" 2>&1); code=$?
}
stop() { out=$(jq -cn --arg a "$1" '{hook_event_name: "SubagentStop", agent_id: $a}' | bash "$HOOK" 2>&1); code=$?; }
start() { out=$(echo '{"hook_event_name":"SessionStart"}' | bash "$HOOK" 2>&1); code=$?; }

start
edit a1 dept-backend:developer "$PROJ/src/orders.ts"
expect "el primer agente reserva el archivo" '[ $code -eq 0 ] && grep -q "^src/orders.ts	a1	dept-backend:developer	" "$PROJ/.office/locks.tsv"'
edit a1 dept-backend:developer "$PROJ/src/orders.ts"
expect "el mismo agente sigue editándolo" '[ $code -eq 0 ] && [ "$(grep -c "^src/orders.ts	" "$PROJ/.office/locks.tsv")" = 1 ]'
edit a2 dept-frontend:developer "$PROJ/src/orders.ts" Write
expect "otro agente queda bloqueado" '[ $code -eq 2 ] && printf "%s" "$out" | grep -q "src/orders.ts lo está editando otro agente" && printf "%s" "$out" | grep -q "dept-backend:developer"'
expect "le dice qué hacer" 'printf "%s" "$out" | grep -q "decilo en tu reporte"'
edit a2 dept-frontend:developer "src/cart.ts"
expect "otro archivo, con ruta relativa: sin problema" '[ $code -eq 0 ] && grep -q "^src/cart.ts	a2	" "$PROJ/.office/locks.tsv"'
edit "" "" "$PROJ/src/orders.ts"
expect "la sesión principal no reserva ni se bloquea" '[ $code -eq 0 ]'
edit a2 dept-frontend:developer "$PROJ/.qa/notas.md"
expect ".qa/ no se reserva" '[ $code -eq 0 ] && ! grep -q "^.qa/" "$PROJ/.office/locks.tsv"'
edit a2 dept-frontend:developer "$WORK/afuera.txt"
expect "fuera del proyecto no se reserva" '[ $code -eq 0 ] && ! grep -q "afuera" "$PROJ/.office/locks.tsv"'

stop a1
expect "al terminar, el agente libera sus archivos" '! grep -q "	a1	" "$PROJ/.office/locks.tsv" && grep -q "	a2	" "$PROJ/.office/locks.tsv"'
edit a2 dept-frontend:developer "$PROJ/src/orders.ts"
expect "liberado, otro agente lo puede editar" '[ $code -eq 0 ]'

# Una reserva vencida no bloquea.
printf 'src/viejo.ts\ta9\tdept-backend:tester\t1\n' >>"$PROJ/.office/locks.tsv"
edit a3 dept-backend:developer "$PROJ/src/viejo.ts"
expect "una reserva vencida no bloquea" '[ $code -eq 0 ] && grep -q "^src/viejo.ts	a3	" "$PROJ/.office/locks.tsv" && ! grep -q "	a9	" "$PROJ/.office/locks.tsv"'

# Un mutex que quedó de un hook cortado no traba todo para siempre.
mkdir -p "$PROJ/.office/locks.mutex"
edit a3 dept-backend:developer "$PROJ/src/otro.ts"
expect "un mutex abandonado se recupera" '[ $code -eq 0 ] && grep -q "^src/otro.ts	a3	" "$PROJ/.office/locks.tsv" && [ ! -d "$PROJ/.office/locks.mutex" ]'

start
expect "una sesión nueva empieza sin reservas" '[ ! -f "$PROJ/.office/locks.tsv" ]'

# Dos agentes a la vez sobre el mismo archivo: solo uno lo consigue.
start
for i in 1 2 3 4; do
  ( jq -cn --arg a "p$i" '{hook_event_name: "PreToolUse", tool_name: "Edit", agent_id: $a, agent_type: "x", tool_input: {file_path: "src/race.ts"}}' | bash "$HOOK" >/dev/null 2>&1; echo $? >"$WORK/rc$i" ) &
done
wait
wins=$(cat "$WORK"/rc* | grep -c '^0$')
expect "en una carrera, uno solo reserva el archivo" '[ "$wins" = 1 ] && [ "$(grep -c "^src/race.ts	" "$PROJ/.office/locks.tsv")" = 1 ]'

OFFICE_FILE_LOCKS=off bash "$HOOK" <<<'{"hook_event_name":"PreToolUse","agent_id":"z","tool_input":{"file_path":"src/race.ts"}}' >/dev/null 2>&1; code=$?
expect "OFFICE_FILE_LOCKS=off lo apaga" '[ $code -eq 0 ] && ! grep -q "	z	" "$PROJ/.office/locks.tsv"'

echo
if [ "$FAILED" -eq 0 ]; then echo "Todas las pruebas pasan."; else echo "Hay pruebas que fallan."; fi
exit "$FAILED"
