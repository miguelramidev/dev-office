#!/usr/bin/env bash
# Pruebas de office-setup (plugins/office/skills/office-setup/setup.sh): modo local por
# defecto, modo compartido, documentos locales y el paso de compartido a local.
# Uso: bash tests/office-setup.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$ROOT/plugins/office/skills/office-setup/setup.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
unset CLAUDE_PROJECT_DIR

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
setup() { out=$(cd "$PROJ" && bash "$SETUP" "$@" 2>&1); code=$?; }
fresh() {
  rm -rf "$PROJ"; mkdir -p "$PROJ"
  (cd "$PROJ" && git init -q . && git config user.email t@t && git config user.name t && echo 'node_modules/' >.gitignore && git add -A && git commit -qm init)
}
ex() { cat "$PROJ/.git/info/exclude" 2>/dev/null; }
tracked_changes() { (cd "$PROJ" && git status --porcelain); }

# --- Modo local (por defecto) --------------------------------------------------
fresh
setup --timezone America/Bogota --protected "main dev" --allow "Bash(pnpm test)"
expect "local: termina bien" '[ $code -eq 0 ]'
expect "local: la configuración va a settings.local.json" '[ "$(jq -r .agent "$PROJ/.claude/settings.local.json")" = "office:pm" ] && [ "$(jq -r .env.OFFICE_PROTECTED_BRANCHES "$PROJ/.claude/settings.local.json")" = "main dev" ]'
expect "local: con las reglas base y las extra" 'jq -e ".permissions.allow | index(\"Bash(git status)\") and index(\"Bash(pnpm test)\")" "$PROJ/.claude/settings.local.json" >/dev/null'
expect "local: no crea settings.json" '[ ! -f "$PROJ/.claude/settings.json" ]'
expect "local: no toca .gitignore" '[ "$(cat "$PROJ/.gitignore")" = "node_modules/" ]'
expect "local: ignora con .git/info/exclude" 'ex | grep -qxF ".office/" && ex | grep -qxF ".claude/" && ex | grep -qxF ".mcp.json"'
expect "local: git no ve ningún cambio" '[ -z "$(tracked_changes)" ]'
mkdir -p "$PROJ/.claude/commands" && echo x >"$PROJ/.claude/commands/mio.md" && echo '{}' >"$PROJ/.mcp.json"
expect "local: tampoco ve .mcp.json ni lo nuevo en .claude/" '[ -z "$(tracked_changes)" ]'
rm -rf "$PROJ/.claude/commands" "$PROJ/.mcp.json"
expect "local: los documentos van a git por defecto" '! ex | grep -qxF "docs/decisions/"'
setup
expect "local: correrlo otra vez no duplica el bloque" '[ "$(ex | grep -c "^# >>> dev-office: oficina$")" = 1 ] && [ "$(ex | grep -cxF ".office/")" = 1 ]'

# --- Documentos locales ----------------------------------------------------------
setup --docs local
expect "docs local: ignora las carpetas de documentos" 'ex | grep -qxF "docs/decisions/" && ex | grep -qxF "docs/project-map.md" && ex | grep -qxF "docs/api/"'
mkdir -p "$PROJ/docs/decisions" && echo x >"$PROJ/docs/decisions/0001.md"
expect "docs local: git no ve los documentos nuevos" '[ -z "$(tracked_changes)" ]'
setup --docs local
expect "docs local: sin duplicar" '[ "$(ex | grep -cxF "docs/decisions/")" = 1 ]'
setup --docs git
expect "docs git: saca el bloque" '! ex | grep -qxF "docs/decisions/" && ex | grep -qxF ".office/"'
expect "docs git: los documentos vuelven a verse" 'tracked_changes | grep -q "docs/"'
setup --docs otra
expect "docs: valor inválido" '[ $code -ne 0 ]'

# --- Modo compartido -------------------------------------------------------------
fresh
setup --shared --protected "main"
expect "compartido: la configuración va a settings.json" '[ "$(jq -r .agent "$PROJ/.claude/settings.json")" = "office:pm" ] && [ ! -f "$PROJ/.claude/settings.local.json" ]'
expect "compartido: ignora con .gitignore" 'grep -qxF ".office/" "$PROJ/.gitignore" && grep -qxF "node_modules/" "$PROJ/.gitignore"'
expect "compartido: no escribe .git/info/exclude" '! ex | grep -q "dev-office"'

# --- Un JSON roto no se toca -----------------------------------------------------
fresh
mkdir -p "$PROJ/.claude" && printf '{ roto' >"$PROJ/.claude/settings.json"
setup
expect "settings.json roto: frena sin tocar nada" '[ $code -ne 0 ] && [ "$(cat "$PROJ/.claude/settings.json")" = "{ roto" ] && [ ! -f "$PROJ/.claude/settings.local.json" ]'

# --- De compartido a local --------------------------------------------------------
fresh
mkdir -p "$PROJ/.claude"
echo '{"enabledPlugins":{"office@dev-office":true,"otro@x":true}}' >"$PROJ/.claude/settings.json"
echo '{"roles":{"qa":["codex"]}}' >"$PROJ/.claude/office-agents.json"
setup --shared --protected "main dev" --timezone America/Bogota --allow "Bash(pnpm test)"
(cd "$PROJ" && git add -A && git commit -qm office)
echo '{"roles":{"pm":["gemini"]}}' >"$PROJ/.claude/office-agents.local.json"
setup --move-to-local
S="$PROJ/.claude/settings.json"; L="$PROJ/.claude/settings.local.json"
expect "mover: termina bien" '[ $code -eq 0 ]'
expect "mover: saca de settings.json lo de la oficina" '[ "$(jq -r ".agent // empty" "$S")" = "" ] && [ "$(jq -r ".env // empty" "$S")" = "" ] && [ "$(jq -r ".permissions.defaultMode // empty" "$S")" = "" ] && ! jq -e ".permissions.allow | index(\"Bash(git status)\")" "$S" >/dev/null'
expect "mover: deja en settings.json lo propio del proyecto" 'jq -e ".permissions.allow == [\"Bash(pnpm test)\"] and .enabledPlugins[\"otro@x\"] == true" "$S" >/dev/null'
expect "mover: las variables de la oficina pasan a las tuyas" '[ "$(jq -r .env.OFFICE_PROTECTED_BRANCHES "$L")" = "main dev" ] && [ "$(jq -r .env.OFFICE_TIMEZONE "$L")" = "America/Bogota" ] && [ "$(jq -r .agent "$L")" = "office:pm" ]'
expect "mover: los proveedores del equipo pasan a los tuyos (los tuyos mandan)" '[ ! -f "$PROJ/.claude/office-agents.json" ] && jq -e ".roles.qa == [\"codex\"] and .roles.pm == [\"gemini\"]" "$PROJ/.claude/office-agents.local.json" >/dev/null'
expect "mover: saca las líneas de la oficina de .gitignore" '[ "$(cat "$PROJ/.gitignore")" = "node_modules/" ]'
expect "mover: y las pone en .git/info/exclude" 'ex | grep -qxF ".office/"'
expect "mover: dice cómo pasar los plugins a local" 'printf "%s" "$out" | grep -q "claude plugin install office@dev-office --scope local" && ! printf "%s" "$out" | grep -q "otro@x"'
expect "mover: el diff queda para commitear" 'tracked_changes | grep -q ".claude/settings.json" && tracked_changes | grep -q ".claude/office-agents.json"'

# --- Jira con una cuenta por proyecto (jira-account.sh) -----------------------------
JIRA="$ROOT/plugins/office/skills/office-setup/jira-account.sh"
FB="$WORK/fakebin"; mkdir -p "$FB"
cat >"$FB/claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG"
[ "${FAKE_ADD_FAIL:-}" = 1 ] && [ "$2" = add ] && exit 1
exit 0
FAKE
cat >"$FB/curl" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG.curl"
printf '%s' "${FAKE_HTTP:-200}"
FAKE
chmod +x "$FB/claude" "$FB/curl"
export FAKE_LOG="$WORK/claude.log"
jira() { rm -f "$FAKE_LOG" "$FAKE_LOG.curl"; out=$(cd "$PROJ" && PATH="$FB:$PATH" OFFICE_JIRA_EMAIL="$1" OFFICE_JIRA_TOKEN="$2" OFFICE_JIRA_SITE="$3" bash "$JIRA" 2>&1); code=$?; }
fresh
jira yo@trabajo.com 'tok-secreto-123' miempresa.atlassian.net
B64=$(printf '%s' 'yo@trabajo.com:tok-secreto-123' | base64 | tr -d '\n')
expect "jira: termina bien" '[ $code -eq 0 ]'
expect "jira: saca la conexión anterior del proyecto" 'grep -qx "mcp remove atlassian -s local" "$FAKE_LOG"'
expect "jira: registra atlassian solo para el proyecto, con el token en la cabecera" 'grep -qxF "mcp add --transport http --scope local --header Authorization: Basic $B64 atlassian https://mcp.atlassian.com/v2/mcp" "$FAKE_LOG"'
expect "jira: comprueba el token contra el sitio" 'grep -q "https://miempresa.atlassian.net/rest/api/3/myself" "$FAKE_LOG.curl"'
expect "jira: nunca muestra el token" '! printf "%s" "$out" | grep -q "tok-secreto-123" && ! printf "%s" "$out" | grep -qF "$B64"'
expect "jira: dice qué anotar en las reglas" 'printf "%s" "$out" | grep -q "Sitio de Jira: miempresa.atlassian.net"'
FAKE_HTTP=401 jira yo@trabajo.com malo https://miempresa.atlassian.net/
expect "jira: si Jira rechaza el token, no registra nada" '[ $code -ne 0 ] && [ ! -f "$FAKE_LOG" ] && printf "%s" "$out" | grep -q "rechazó"'
jira yo@personal.com 'otro' ''
expect "jira: sin sitio, no comprueba y registra igual" '[ $code -eq 0 ] && [ ! -f "$FAKE_LOG.curl" ] && grep -q "mcp add" "$FAKE_LOG"'
jira sin-arroba 'x' ''
expect "jira: email inválido" '[ $code -ne 0 ] && [ ! -f "$FAKE_LOG" ]'
FAKE_ADD_FAIL=1 jira yo@personal.com 'otro' ''
expect "jira: si claude mcp add falla, lo dice sin mostrar el token" '[ $code -ne 0 ] && printf "%s" "$out" | grep -q "falló" && ! printf "%s" "$out" | grep -q "otro@\|b3Ry"'

echo
if [ "$FAILED" -eq 0 ]; then echo "Todas las pruebas pasan."; else echo "Hay pruebas que fallan."; fi
exit "$FAILED"
