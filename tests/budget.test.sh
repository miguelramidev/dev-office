#!/usr/bin/env bash
# Pruebas del hook de presupuesto de tokens (plugins/office/scripts/budget.sh).
# Uso: bash tests/budget.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/office/scripts/budget.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
mkdir -p "$PROJ/.office/observer" "$PROJ/.claude"
export CLAUDE_PROJECT_DIR="$PROJ"

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
run() { out=$(bash "$HOOK" <<<'{"hook_event_name":"PreToolUse","tool_name":"Agent"}' 2>&1); code=$?; }
events() { # events <tokens del agente> [tokens del turno del PM]
  {
    echo 'OFFICE_EVENT({"type":"session","t":100});'
    echo "OFFICE_EVENT({\"type\":\"stop\",\"t\":110,\"agent\":\"a1\",\"agent_type\":\"dept-backend:developer\",\"usage\":{\"i\":$1,\"o\":0,\"cw\":0,\"cr\":99999999}});"
    [ -n "${2:-}" ] && echo "OFFICE_EVENT({\"type\":\"turn_end\",\"t\":120,\"usage\":{\"i\":$2,\"o\":0,\"cw\":0}});"
  } >"$PROJ/.office/observer/events.js"
}

# Sin tope no hace nada.
events 5000000
run
expect "sin tope no dice nada" '[ $code -eq 0 ] && [ -z "$out" ]'

echo '{"budget":1000000}' >"$PROJ/.claude/office-agents.json"

events 100000 50000
run
expect "debajo del 80% no dice nada" '[ $code -eq 0 ] && [ -z "$out" ]'

events 700000 120000
run
expect "al 80% avisa sin bloquear" '[ $code -eq 0 ] && printf "%s" "$out" | jq -e ".hookSpecificOutput.additionalContext | contains(\"82%\")" >/dev/null'
expect "el aviso no bloquea" '! printf "%s" "$out" | grep -q permissionDecision'
run
expect "el aviso se da una sola vez por sesión" '[ -z "$out" ]'

events 900000 150000
run
expect "al 100% rechaza el encargo" '[ $code -eq 0 ] && [ "$(printf "%s" "$out" | jq -r .hookSpecificOutput.permissionDecision)" = deny ]'
expect "el rechazo dice cuánto se gastó y cómo subir el tope" 'printf "%s" "$out" | jq -e ".hookSpecificOutput.permissionDecisionReason | contains(\"1.1M de 1.0M\") and contains(\"office-agents.sh budget\")" >/dev/null'

echo '{"budget":2000000}' >"$PROJ/.claude/office-agents.json"
run
expect "subir el tope destraba el encargo" '[ -z "$out" ]'

echo '{"budget":500000}' >"$PROJ/.claude/office-agents.local.json"
run
expect "el tope personal manda sobre el del equipo" 'printf "%s" "$out" | grep -q deny'
rm -f "$PROJ/.claude/office-agents.local.json"

echo '{"budget":"mucho"}' >"$PROJ/.claude/office-agents.json"
run
expect "un tope inválido se ignora" '[ $code -eq 0 ] && [ -z "$out" ]'

echo '{"budget":1000000}' >"$PROJ/.claude/office-agents.json"
rm -f "$PROJ/.office/observer/events.js"
run
expect "sin registro del observer no hace nada" '[ $code -eq 0 ] && [ -z "$out" ]'

echo '{"hooks":1}' >/dev/null
expect "el hook está en hooks.json para Agent y Task" 'jq -e ".hooks.PreToolUse[] | select(.matcher == \"Agent|Task\") | .hooks[] | select(.command | contains(\"scripts/budget.sh\"))" "$ROOT/plugins/office/hooks/hooks.json" >/dev/null'

if [ "$FAILED" -eq 0 ]; then
  echo "Todas las pruebas pasan."
else
  echo "Hay pruebas que fallan."
  exit 1
fi
