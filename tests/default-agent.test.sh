#!/usr/bin/env bash
# Pruebas del PM como agente por defecto: el hook de migración
# (plugins/office/scripts/default-agent.sh) y lo que escribe office-setup.
# Uso: bash tests/default-agent.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/office/scripts/default-agent.sh"
SETUP="$ROOT/plugins/office/skills/office-setup/setup.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
export CLAUDE_PROJECT_DIR="$PROJ"
export OFFICE_USER_CLAUDE_DIR="$WORK/home/.claude"
unset OFFICE_DEFAULT_AGENT

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
run() { out=$(bash "$HOOK" <<<'{"hook_event_name":"SessionStart"}' 2>&1); code=$?; }
fresh() { rm -rf "$PROJ" "$WORK/home"; mkdir -p "$PROJ/.claude" "$OFFICE_USER_CLAUDE_DIR"; }
agent() { jq -r '.agent // empty' "$1" 2>/dev/null; }

# Instalada en el proyecto: va a .claude/settings.json, sin tocar lo demás.
fresh
echo '{"enabledPlugins":{"office@dev-office":true},"permissions":{"allow":["Bash(git status)"]}}' >"$PROJ/.claude/settings.json"
run
expect "proyecto: agrega el PM en .claude/settings.json" '[ $code -eq 0 ] && [ "$(agent "$PROJ/.claude/settings.json")" = "office:pm" ]'
expect "proyecto: no toca el resto" '[ "$(jq -r ".permissions.allow[0]" "$PROJ/.claude/settings.json")" = "Bash(git status)" ] && [ "$(jq -r ".enabledPlugins[\"office@dev-office\"]" "$PROJ/.claude/settings.json")" = "true" ]'
expect "proyecto: le avisa al PM, que se lo cuenta al CEO" 'printf "%s" "$out" | grep -q "office:pm" && printf "%s" "$out" | grep -q "commitealo"'
expect "proyecto: lo anota para no repetirlo" '[ -f "$PROJ/.office/default-agent" ]'
expect "proyecto: sin CRLF" '! grep -q $'"'"'\r'"'"' "$PROJ/.claude/settings.json"'
jq 'del(.agent)' "$PROJ/.claude/settings.json" >"$WORK/s" && mv "$WORK/s" "$PROJ/.claude/settings.json"
run
expect "si después lo sacás, no lo vuelve a poner" '[ -z "$(agent "$PROJ/.claude/settings.json")" ] && [ -z "$out" ]'

# Instalada solo para vos en el proyecto: va a settings.local.json.
fresh
echo '{"permissions":{}}' >"$PROJ/.claude/settings.json"
echo '{"enabledPlugins":{"office@dev-office":true}}' >"$PROJ/.claude/settings.local.json"
run
expect "local: va a .claude/settings.local.json" '[ "$(agent "$PROJ/.claude/settings.local.json")" = "office:pm" ] && [ -z "$(agent "$PROJ/.claude/settings.json")" ]'

# Instalada para el usuario: va a ~/.claude/settings.json.
fresh
echo '{"enabledPlugins":{"office@dev-office":true,"otro@x":true}}' >"$OFFICE_USER_CLAUDE_DIR/settings.json"
run
expect "usuario: va a ~/.claude/settings.json" '[ "$(agent "$OFFICE_USER_CLAUDE_DIR/settings.json")" = "office:pm" ]'

# Ya había un agente elegido: no se toca.
fresh
echo '{"enabledPlugins":{"office@dev-office":true}}' >"$PROJ/.claude/settings.json"
echo '{"agent":"otro:agente"}' >"$PROJ/.claude/settings.local.json"
run
expect "con otro agente ya elegido, no toca nada" '[ -z "$(agent "$PROJ/.claude/settings.json")" ] && [ "$(agent "$PROJ/.claude/settings.local.json")" = "otro:agente" ] && [ -z "$out" ]'

# La oficina desactivada o sin settings: no hace nada.
fresh
echo '{"enabledPlugins":{"office@dev-office":false}}' >"$PROJ/.claude/settings.json"
run
expect "con la oficina desactivada, no hace nada" '[ -z "$(agent "$PROJ/.claude/settings.json")" ] && [ ! -f "$PROJ/.office/default-agent" ]'

# Un settings roto no se toca.
fresh
printf '{"enabledPlugins":{"office@dev-office":true},' >"$PROJ/.claude/settings.json"
run
expect "un settings roto queda igual" '[ $code -eq 0 ] && [ "$(cat "$PROJ/.claude/settings.json")" = "{\"enabledPlugins\":{\"office@dev-office\":true}," ]'

# Apagado con OFFICE_DEFAULT_AGENT=off.
fresh
echo '{"enabledPlugins":{"office@dev-office":true}}' >"$PROJ/.claude/settings.json"
out=$(OFFICE_DEFAULT_AGENT=off bash "$HOOK" </dev/null 2>&1)
expect "OFFICE_DEFAULT_AGENT=off lo apaga" '[ -z "$(agent "$PROJ/.claude/settings.json")" ]'

# office-setup deja al PM por defecto, salvo que el proyecto ya tenga otro agente.
fresh
(cd "$PROJ" && git init -q . && bash "$SETUP" --mode acceptEdits >/dev/null 2>&1)
expect "setup: agrega el PM como agente por defecto" '[ "$(agent "$PROJ/.claude/settings.json")" = "office:pm" ]'
fresh
echo '{"agent":"otro:agente"}' >"$PROJ/.claude/settings.json"
(cd "$PROJ" && git init -q . && bash "$SETUP" --mode acceptEdits >/dev/null 2>&1)
expect "setup: respeta otro agente ya elegido" '[ "$(agent "$PROJ/.claude/settings.json")" = "otro:agente" ]'

echo
if [ "$FAILED" -eq 0 ]; then echo "Todas las pruebas pasan."; else echo "Hay pruebas que fallan."; fi
exit "$FAILED"
