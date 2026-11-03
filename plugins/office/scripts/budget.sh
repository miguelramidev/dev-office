#!/usr/bin/env bash
# Hook de presupuesto de tokens de dev-office (PreToolUse de Agent y Task, o sea, cada vez que
# alguien le encarga trabajo a un agente).
#
# Si el proyecto tiene un tope ("budget" en .claude/office-agents.json o en el local, que manda;
# se pone con `office-agents.sh budget 2M`), suma los tokens de la sesión que anota el observer
# (.office/observer/events.js):
#   - al llegar al 80%, una sola vez por sesión, le avisa al PM (sin bloquear);
#   - al llegar al 100%, rechaza el encargo y le explica al PM que frene y le pregunte al CEO.
#
# Sin tope, o con el observer apagado, no hace nada. No llama a ningún modelo: no gasta tokens.
# Los tokens del PM se suman al terminar cada respuesta, así que el conteo va un paso atrás.
# Los de un agente, al terminar su tarea.

. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"
command -v jq >/dev/null 2>&1 || { cat >/dev/null; exit 0; }
cat >/dev/null

PROJECT=$(norm_path "${CLAUDE_PROJECT_DIR:-$PWD}")
EVENTS="$PROJECT/.office/observer/events.js"
[ -s "$EVENTS" ] || exit 0

# El tope: el archivo personal manda sobre el del equipo.
LIMIT=""
for f in "$PROJECT/.claude/office-agents.json" "$PROJECT/.claude/office-agents.local.json"; do
  [ -f "$f" ] || continue
  v=$(jq -r 'if (.budget | type) == "number" and .budget > 0 then (.budget | floor) else empty end' "$f" 2>/dev/null | tr -d '\r')
  [ -n "$v" ] && LIMIT="$v"
done
[ -n "$LIMIT" ] || exit 0

# Tokens de la sesión: el PM (el último turno que informó), los agentes (suma de lo que
# informó cada uno al terminar) y lo que informaron Codex y Gemini. Entrada + salida + caché escrita.
USED=$(sed -n 's/^OFFICE_EVENT(\(.*\));[[:space:]]*$/\1/p' "$EVENTS" | tr -d '\r' | jq -s '
  def tok(u): if u then ((u.i // 0) + (u.o // 0) + (u.cw // 0)) else 0 end;
  ([.[] | select(.type == "turn_end") | tok(.usage) | select(. > 0)] | last // 0)
  + ([.[] | select(.type == "stop") | tok(.usage)] | add // 0)
  + ([.[] | select(.type == "external") | .tokens // 0] | add // 0)' 2>/dev/null | tr -d '\r')
[ -n "$USED" ] || exit 0

PCT=$((USED * 100 / LIMIT))
num() { awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n / 1000000; else if (n >= 1000) printf "%.0fk", n / 1000; else printf "%d", n }'; }

if [ "$PCT" -ge 100 ]; then
  jq -cn --arg r "Presupuesto de tokens agotado: la sesión lleva $(num "$USED") de $(num "$LIMIT") ($PCT%). No se pueden hacer más encargos hasta que el CEO decida. Frená, resumile al CEO qué está hecho, qué falta y cuánto se gastó, y preguntale si sube el tope o cierra acá. Para subirlo, el CEO corre en la terminal: bash .claude/office-agents.sh budget <valor> (por ejemplo 4M), o lo apaga con: bash .claude/office-agents.sh budget off." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
fi

if [ "$PCT" -ge 80 ]; then
  # Un solo aviso por sesión: la sesión se reconoce por el primer evento del registro.
  SESSION=$(head -n1 "$EVENTS" | sed -n 's/^OFFICE_EVENT(\(.*\));[[:space:]]*$/\1/p' | jq -r '.t // 0' 2>/dev/null | tr -d '\r')
  MARK="$PROJECT/.office/observer/budget-warned"
  if [ "$(cat "$MARK" 2>/dev/null)" != "$SESSION" ]; then
    printf '%s\n' "$SESSION" >"$MARK" 2>/dev/null
    jq -cn --arg c "Aviso de presupuesto: la sesión lleva $(num "$USED") de $(num "$LIMIT") tokens ($PCT%). Al 100% se frenan los encargos nuevos. Si lo que falta es grande, avisale al CEO ahora y priorizá lo esencial; no recortes la verificación del tester ni de QA." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  fi
fi
exit 0
