#!/usr/bin/env bash
# Hook SubagentStart/SubagentStop de dev-office: registra cuándo empieza y termina
# cada agente en .claude/office-activity.log. Nunca bloquea (siempre sale con 0).
# Zona horaria: la del sistema, o la de la variable OFFICE_TIMEZONE si está definida
# (por ejemplo, America/Bogota).

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
EVENT=$(json_get '.hook_event_name // "?"')
AGENT=$(json_get '.agent_type // "?"')

if [ -n "$OFFICE_TIMEZONE" ]; then
  TIME=$(TZ="$OFFICE_TIMEZONE" date '+%Y-%m-%d %H:%M:%S')
else
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
fi

case "$EVENT" in
  SubagentStart) ACTION="empezó" ;;
  SubagentStop) ACTION="terminó" ;;
  *) ACTION="$EVENT" ;;
esac

LOG_DIR="$(norm_path "${CLAUDE_PROJECT_DIR:-.}")/.claude"
mkdir -p "$LOG_DIR"
echo "$TIME  $AGENT $ACTION" >> "$LOG_DIR/office-activity.log"
exit 0