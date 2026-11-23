#!/usr/bin/env bash
# Pruebas del diagnóstico de la oficina (plugins/office/skills/doctor/doctor.sh), con claude,
# gh y agy de mentira: no toca la configuración real de la computadora.
# Uso: bash tests/doctor.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCTOR="$ROOT/plugins/office/skills/doctor/doctor.sh"
SETUP="$ROOT/plugins/office/skills/office-setup/setup.sh"
OA="$ROOT/plugins/office/skills/office-agents/office-agents.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
BIN="$WORK/bin"
MKT="$WORK/market"
mkdir -p "$BIN"

export HOME="$WORK/home"
export CLAUDE_PROJECT_DIR="$PROJ"
export OFFICE_USER_CLAUDE_DIR="$HOME/.claude"
export OFFICE_CLAUDE_JSON="$HOME/.claude.json"
export OFFICE_TELEGRAM_HOME="$HOME/.claude/office-telegram"
export OFFICE_GEMINI_SETTINGS="$HOME/.gemini/antigravity-cli/settings.json"
export OFFICE_GEMINI_CONFIG="$HOME/.gemini/config/config.json"
export OFFICE_CLAUDE_BIN="$BIN/claude"
export PATH="$BIN:$PATH"
unset CLAUDE_CONFIG_DIR

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
has() { printf '%s' "$out" | grep -qF -- "$1"; }
run() { out=$(cd "$PROJ" && bash "$DOCTOR" 2>&1); code=$?; }

# claude de mentira: los plugins instalados salen de $WORK/plugins.json.
cat >"$BIN/claude" <<EOF
#!/usr/bin/env bash
case "\$*" in
  --version) echo "2.1.330 (Claude Code)" ;;
  "plugin list --json") cat "$WORK/plugins.json" 2>/dev/null || echo '[]' ;;
  "plugin marketplace list --json") echo '[{"name":"dev-office","source":"directory","installLocation":"$MKT"}]' ;;
  *) exit 1 ;;
esac
EOF
# gh de mentira: con sesión si existe $WORK/gh-ok.
cat >"$BIN/gh" <<EOF
#!/usr/bin/env bash
[ "\$1 \$2" = "auth status" ] && { [ -f "$WORK/gh-ok" ]; exit; }
exit 0
EOF
chmod +x "$BIN/claude" "$BIN/gh"

plugins() { # plugins <id>:<version>:<scope>[:disabled] ...
  local first=1 id ver scope state
  { printf '['
    for p in "$@"; do
      IFS=: read -r id ver scope state <<<"$p"
      [ $first -eq 1 ] || printf ','
      first=0
      printf '{"id":"%s@dev-office","version":"%s","scope":"%s","enabled":%s,"projectPath":"%s"}' "$id" "$ver" "$scope" "$([ "$state" = disabled ] && echo false || echo true)" "$PROJ"
    done
    printf ']'; } >"$WORK/plugins.json"
}
market() { # market <plugin> <version>
  mkdir -p "$MKT/plugins/$1/.claude-plugin" && echo "{\"version\":\"$2\"}" >"$MKT/plugins/$1/.claude-plugin/plugin.json"
}
fresh() {
  rm -rf "$PROJ" "$HOME" "$MKT" "$WORK/plugins.json" "$WORK/gh-ok" "$BIN/agy"
  mkdir -p "$PROJ" "$HOME/.claude"
  git -C "$PROJ" init -q
  touch "$WORK/gh-ok"
  market office 0.65.0; market dept-frontend 0.9.2
  plugins office:0.65.0:local dept-frontend:0.9.2:local
}
configured() {
  echo "Tests de lo que cambiaste: pnpm vitest related <archivos> --run" >"$PROJ/CLAUDE.md"
  (cd "$PROJ" && bash "$SETUP" --allow "Bash(pnpm test *)" >/dev/null 2>&1)
}

# --- Un proyecto recién instalado, sin office-setup ---------------------------------
fresh
run
expect "sin office-setup: sale con 1" '[ $code -eq 1 ]'
expect "sin office-setup: lo marca como faltante, con el arreglo" 'has "[✗] Configuración del proyecto" && has "→ /office:office-setup"'
expect "sin CLAUDE.md: avisa" 'has "No hay CLAUDE.md"'
expect "sin el PM por defecto: avisa" 'has "claude arranca sin el PM"'
expect "herramientas: git, jq y gh con sesión" 'has "[✓] Herramientas" && has "✓ gh con sesión"'
expect "plugins: versión y alcance de office, y departamentos" 'has "✓ office 0.65.0 (alcance: local)" && has "✓ Departamentos: frontend"'
expect "Jira sin conectar: opcional" 'has "[-] Jira (Atlassian)" && has "No conectado (opcional)"'
expect "resumen con problemas y avisos" 'has "Encontré 1 problema y"'
expect "no crea archivos en el proyecto" '[ -z "$(cd "$PROJ" && git status --porcelain)" ]'

# --- Configurado con office-setup: listo --------------------------------------------
fresh
configured
run
expect "configurado: modo local, PM por defecto y tests permitidos" 'has "✓ Modo local" && has "✓ El PM arranca solo" && has "✓ Comandos de verificación"'
expect "configurado: tests relacionados y archivos ignorados" 'has "✓ Las reglas dicen cómo correr solo los tests relacionados" && has "✓ git ignora los archivos de trabajo"'
expect "configurado: sale con 0" '[ $code -eq 0 ] && has "[✓] Configuración del proyecto"'
expect "configurado: todos los roles en Claude" 'has "✓ Todos los roles en Claude"'
expect "configurado: menciona las copias .bak" 'has "settings.local.json.bak"'

# --- Herramientas -----------------------------------------------------------------
rm -f "$WORK/gh-ok"
run
expect "gh sin sesión: aviso con gh auth login" 'has "gh está instalado, pero sin sesión" && has "→ gh auth login" && [ $code -eq 0 ]'
touch "$WORK/gh-ok"

# --- Plugins ------------------------------------------------------------------------
market office 0.66.0
run
expect "versión nueva en el marketplace: aviso con /office:update" 'has "office 0.65.0 → 0.66.0" && has "/office:update"'
market office 0.65.0
plugins office:0.65.0:local
run
expect "sin departamentos: aviso" 'has "No hay ningún departamento instalado"'
plugins office:0.65.0:local:disabled dept-frontend:0.9.2:local
run
expect "office desactivada: falta, con el comando" 'has "desactivada" && has "claude plugin enable office@dev-office --scope local"'
plugins office:0.65.0:local office:0.65.0:user dept-frontend:0.9.2:local
run
expect "en dos alcances: aviso" 'has "en más de un alcance"'
plugins office:0.65.0:project dept-frontend:0.9.2:local
run
expect "plugin de equipo con oficina local: aviso con la migración" 'has "--scope project), pero tu oficina es local" && has "migration.md"'
rm -f "$WORK/plugins.json"
run
expect "office sin instalar: falta, con el comando" 'has "La oficina (office) no está instalada" && has "claude plugin install office@dev-office --scope local"'
plugins office:0.65.0:local dept-frontend:0.9.2:local

# --- Proyecto -----------------------------------------------------------------------
cp "$PROJ/.claude/settings.local.json" "$WORK/s.json"
jq '.permissions.allow -= ["Bash(pnpm test *)"]' "$WORK/s.json" >"$PROJ/.claude/settings.local.json"
run
expect "sin comandos de tests permitidos: aviso" 'has "No hay comandos de tests, lint ni typecheck permitidos"'
cp "$WORK/s.json" "$PROJ/.claude/settings.local.json"
echo "# reglas" >"$PROJ/CLAUDE.md"
run
expect "sin tests relacionados: aviso con Comandos rápidos" 'has "no dicen cómo correr solo los tests relacionados" && has "Comandos rápidos"'
echo "Tests de lo que cambiaste: pnpm vitest related <archivos> --run" >"$PROJ/CLAUDE.md"
cp "$WORK/s.json" "$PROJ/.claude/settings.json"
run
expect "en los dos modos: aviso con --move-to-local" 'has "en los dos modos" && has "--move-to-local"'
rm -f "$PROJ/.claude/settings.json"
# Archivos de la oficina que git sigue con la oficina local (git ve la carpeta .claude/ aunque esté
# ignorada si se agregan a la fuerza).
cp "$OA" "$PROJ/.claude/office-agents.sh"
(cd "$PROJ" && git add -f .claude/office-agents.sh && git -c user.email=t@t -c user.name=t commit -qm x)
run
expect "oficina local con scripts en git: aviso con git rm --cached" 'has "git sigue los archivos de la oficina" && has "git rm --cached .claude/office-agents.sh"'
sed -i.orig 's/^# office-agents-version: .*/# office-agents-version: 1/' "$PROJ/.claude/office-agents.sh" && rm -f "$PROJ/.claude/office-agents.sh.orig"
run
expect "copia vieja de un script: aviso con /office:update" 'has "copias viejas de los scripts" && has "office-agents.sh"'
(cd "$PROJ" && git rm -q --cached .claude/office-agents.sh && git -c user.email=t@t -c user.name=t commit -qm y)
rm -f "$PROJ/.claude/office-agents.sh"
# Sin repositorio de git.
rm -rf "$PROJ/.git"
run
expect "sin git: aviso" 'has "no es un repositorio de git"'
git -C "$PROJ" init -q

# --- Proveedores --------------------------------------------------------------------
(cd "$PROJ" && bash "$OA" set frontend.tester gemini >/dev/null 2>&1)
run
expect "Gemini sin agy: falta, con cómo instalarlo" 'has "[✗] Proveedores" && has "agy" && has "Antigravity"'
cat >"$BIN/agy" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "1.5.9" ;;
  models) echo "gemini-4-argon"; echo "gemini-4-hydrogen"; echo "gemini-3.8-flash" ;;
esac
EOF
chmod +x "$BIN/agy"
run
expect "Gemini listo: ok, con aviso de permisos" 'has "✓ gemini: Antigravity CLI instalado y con sesión" && has "Permisos de Gemini: desactivados" && has "gemini-permissions on"'
(cd "$PROJ" && bash "$OA" gemini-permissions on >/dev/null 2>&1)
run
expect "Gemini con permisos: ok" 'has "✓ Gemini puede correr los comandos seguros"'
(cd "$PROJ" && bash "$OA" reset frontend.tester >/dev/null 2>&1)

# --- Jira ---------------------------------------------------------------------------
jq -n --arg p "$PROJ" '{projects: {($p): {mcpServers: {atlassian: {type: "http", url: "https://mcp.atlassian.com/v2/mcp?cuenta=trabajo"}}}}}' >"$OFFICE_CLAUDE_JSON"
run
expect "Jira local con etiqueta" 'has "✓ Conectado solo en este proyecto, con la cuenta \"trabajo\""'
expect "Jira sin el sitio en las reglas: aviso" 'has "no dicen el sitio de Jira"'
echo "Sitio de Jira: miempresa.atlassian.net" >>"$PROJ/CLAUDE.md"
run
expect "Jira con el sitio: ok" 'has "✓ Las reglas dicen el sitio de Jira" && has "[✓] Jira (Atlassian)"'
# Una ruta de Windows en ~/.claude.json se reconoce igual (C:\ y C:/, mayúsculas).
jq -n '{projects: {"C:\\Users\\Dev\\App": {mcpServers: {atlassian: {type: "http", url: "https://mcp.atlassian.com/v2/mcp"}}}}}' >"$OFFICE_CLAUDE_JSON"
out=$(cd "$PROJ" && bash "$DOCTOR" --project "/c/users/dev/app" 2>&1)
expect "rutas de Windows: reconoce el proyecto" 'has "✓ Conectado solo en este proyecto"'
jq -n '{mcpServers: {atlassian: {type: "http", url: "https://mcp.atlassian.com/v2/mcp"}}}' >"$OFFICE_CLAUDE_JSON"
run
expect "Jira con alcance user: aviso con remove -s user" 'has "Conectado para todos tus proyectos" && has "claude mcp remove atlassian -s user"'
jq -n --arg p "$PROJ" '{projects: {($p): {mcpServers: {jira: {type: "http", url: "https://mcp.atlassian.com/v2/mcp"}}}}}' >"$OFFICE_CLAUDE_JSON"
run
expect "Atlassian con otro nombre: aviso" 'has "con otro nombre (jira)"'
jq -n --arg p "$PROJ" '{projects: {($p): {mcpServers: {atlassian: {type: "http", url: "https://mcp.atlassian.com/v2/mcp", headers: {Authorization: "Basic x"}}}}}}' >"$OFFICE_CLAUDE_JSON"
echo '{"mcpServers":{"atlassian":{"type":"http","url":"https://mcp.atlassian.com/v2/mcp"}}}' >"$PROJ/.mcp.json"
run
expect "Jira con token y también en .mcp.json: ok y aviso de dos alcances" 'has "con un token de API" && has "más de un alcance (local, project)"'
expect "el token no aparece en la salida" '! has "Basic x"'
rm -f "$PROJ/.mcp.json" "$OFFICE_CLAUDE_JSON"

# --- Opcional -----------------------------------------------------------------------
run
expect "opcional: Telegram y Figma sin configurar" 'has "Telegram: sin configurar" && has "Figma: sin conectar"'
mkdir -p "$OFFICE_TELEGRAM_HOME" && echo '{}' >"$OFFICE_TELEGRAM_HOME/config.json"
run
expect "opcional: Telegram configurado" 'has "✓ Telegram: bot configurado"'

# --- Sin jq: lo dice y corta -------------------------------------------------------
NOJQ="$WORK/nojq"; mkdir -p "$NOJQ"
for t in bash git cat grep sed awk tr head dirname pwd mktemp rm; do p=$(command -v "$t") && ln -sf "$p" "$NOJQ/$t"; done
ln -sf "$BIN/claude" "$NOJQ/claude"
out=$(cd "$PROJ" && PATH="$NOJQ" bash "$DOCTOR" 2>&1); code=$?
expect "sin jq: falta, con cómo instalarlo, y corta" '[ $code -eq 1 ] && has "Falta jq" && has "Instalalo y volvé a correr"'

[ "$FAILED" -eq 0 ] && echo "Todas las pruebas pasan." || { echo "Hay pruebas que fallan."; exit 1; }
