#!/usr/bin/env bash
# Hook SessionStart de dev-office: deja al PM como agente por defecto en tus settings.
#
# Hasta ahora, el settings.json del plugin office ponía "agent": "office:pm", así que
# "claude" a secas ya arrancaba con el PM. Claude Code dejó ese campo como deprecado para
# los plugins: va a dejar de aplicarse y, mientras tanto, muestra un aviso al arrancar.
# Este hook escribe "agent": "office:pm" en tus settings, una sola vez por proyecto, en el
# mismo lugar donde está instalada la oficina:
#   - instalada en el proyecto (--scope project): .claude/settings.json;
#   - instalada solo para vos en el proyecto (--scope local): .claude/settings.local.json;
#   - instalada para tu usuario: ~/.claude/settings.json.
# Si ya tenés un "agent" en cualquiera de esos archivos, no toca nada. Si después lo borrás,
# no lo vuelve a poner (queda anotado en .office/default-agent). Se apaga con la variable
# de entorno OFFICE_DEFAULT_AGENT=off. Nunca bloquea y no llama a ningún modelo.

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"
cat >/dev/null 2>&1
[ "${OFFICE_DEFAULT_AGENT:-}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

PROJECT=$(norm_path "${CLAUDE_PROJECT_DIR:-$PWD}")
USER_HOME="${OFFICE_USER_CLAUDE_DIR:-$HOME/.claude}"
MARK="$PROJECT/.office/default-agent"
[ -f "$MARK" ] && exit 0

PROJ_SETTINGS="$PROJECT/.claude/settings.json"
LOCAL_SETTINGS="$PROJECT/.claude/settings.local.json"
USER_SETTINGS="$USER_HOME/settings.json"

mark() { mkdir -p "$PROJECT/.office" 2>/dev/null && printf '%s\n' "$1" >"$MARK"; }

# Ya hay un agente elegido en tus settings: es tuyo, no se toca.
for f in "$PROJ_SETTINGS" "$LOCAL_SETTINGS" "$USER_SETTINGS"; do
  if [ -f "$f" ] && [ -n "$(jq -r '.agent // empty' "$f" 2>/dev/null | tr -d '\r')" ]; then
    mark "ya estaba en $f"
    exit 0
  fi
done

# Dónde está instalada la oficina.
office_on() { [ -f "$1" ] && [ "$(jq -r '[.enabledPlugins // {} | to_entries[] | select((.key | startswith("office@")) and .value == true)] | length' "$1" 2>/dev/null | tr -d '\r')" -gt 0 ] 2>/dev/null; }
TARGET=""; WHERE=""
if office_on "$PROJ_SETTINGS"; then TARGET="$PROJ_SETTINGS"; WHERE=".claude/settings.json (commitealo junto con tu próximo cambio)"
elif office_on "$LOCAL_SETTINGS"; then TARGET="$LOCAL_SETTINGS"; WHERE=".claude/settings.local.json"
elif office_on "$USER_SETTINGS"; then TARGET="$USER_SETTINGS"; WHERE="~/.claude/settings.json"
fi
[ -n "$TARGET" ] || exit 0
jq empty "$TARGET" >/dev/null 2>&1 || exit 0

tmp="$TARGET.office-tmp"
if jq --indent 2 '.agent = "office:pm"' "$TARGET" 2>/dev/null | tr -d '\r' >"$tmp" && [ -s "$tmp" ]; then
  mv "$tmp" "$TARGET"
  mark "agregado en $TARGET"
  echo "dev-office: dejé al PM como agente por defecto (\"agent\": \"office:pm\") en $WHERE, porque Claude Code va a dejar de aplicar el que traía el plugin. Contáselo al CEO en una línea: no cambia nada en cómo trabaja la oficina, y si prefiere arrancar Claude Code sin el PM, lo saca de ese archivo."
else
  rm -f "$tmp"
fi
exit 0
