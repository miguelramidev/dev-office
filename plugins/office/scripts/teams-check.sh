#!/usr/bin/env bash
# Hook SessionStart de dev-office: confirma que el modo equipos quedó activo de verdad.
#
# Si la configuración de la oficina (.claude/office-agents.json, o el local, que manda)
# tiene "teams": true pero Claude Code no arrancó con CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1,
# imprime un aviso. En SessionStart, lo que imprime un hook le llega al modelo: así el PM
# se entera y se lo dice al CEO. Si todo está bien, o el modo está apagado, no imprime nada.
# Nunca bloquea y no llama a ningún modelo.

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"
command -v jq >/dev/null 2>&1 || exit 0

PROJECT=$(norm_path "${CLAUDE_PROJECT_DIR:-$PWD}")

# Modo equipos en la configuración: el archivo personal manda.
TEAMS=$(for f in "$PROJECT/.claude/office-agents.json" "$PROJECT/.claude/office-agents.local.json"; do
  [ -f "$f" ] && jq -c 'if has("teams") then .teams == true else empty end' "$f" 2>/dev/null | tr -d '\r'
done | tail -n1)
[ "$TEAMS" = "true" ] || exit 0

# Claude Code le pasa a los hooks su entorno, con el "env" de los settings ya aplicado.
[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" = "1" ] && exit 0

# El flag está en los settings pero no en esta sesión: falta reiniciar.
FLAG=""
for f in "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json" "$HOME/.claude/settings.json"; do
  [ -f "$f" ] && [ "$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' "$f" 2>/dev/null | tr -d '\r')" = "1" ] && FLAG=1
done

if [ -n "$FLAG" ]; then
  FIX="El flag ya está en los settings, pero esta sesión arrancó antes: hay que reiniciar Claude Code."
else
  FIX="Falta el flag en los settings: hay que correr \"bash .claude/office-agents.sh teams on\" (o con --local) y reiniciar Claude Code."
fi
echo "dev-office: el modo equipos está activado en la configuración de la oficina, pero no quedó activo en esta sesión (falta CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1). $FIX Hasta entonces, la oficina trabaja en el modo de siempre, sin líderes de departamento."
exit 0
