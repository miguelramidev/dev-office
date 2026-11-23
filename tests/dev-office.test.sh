#!/usr/bin/env bash
# Pruebas del instalador interactivo (dev-office.sh, en la raíz del repositorio): instalar,
# desinstalar y reinstalar desde 0, contestando las preguntas por la entrada estándar o con --yes.
# Usa un "claude" de mentira que guarda los plugins, el marketplace y Jira en archivos, y que
# toma el plugin office de este repositorio: el setup y el diagnóstico son los reales.
# Uso: bash tests/dev-office.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/dev-office.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
BIN="$WORK/bin"
STATE="$WORK/state"
mkdir -p "$BIN"

export HOME="$WORK/home"
export OFFICE_CLAUDE_JSON="$HOME/.claude.json"
export OFFICE_CLAUDE_BIN="$BIN/claude"
export OFFICE_USER_CLAUDE_DIR="$HOME/.claude"
export OFFICE_TELEGRAM_HOME="$HOME/.claude/office-telegram"
export OFFICE_INSTALL_STDIN=1
export NO_COLOR=1
export PATH="$BIN:$PATH"
unset CLAUDE_PROJECT_DIR CLAUDE_CONFIG_DIR

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | tail -n 40 | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
has() { printf '%s' "$out" | grep -qF -- "$1"; }
called() { grep -qF -- "$1" "$STATE/calls.log" 2>/dev/null; }
plugins() { jq -r '.[] | "\(.id)|\(.scope)"' "$STATE/plugins.json" | sort | tr '\n' ' '; }
# run <respuestas> <argumentos...>: corre el script en el proyecto, con esas respuestas.
run() { local answers="$1"; shift; out=$(cd "$PROJ" && printf '%b' "$answers" | bash "$SCRIPT" "$@" 2>&1); code=$?; }

# claude de mentira.
cat >"$BIN/claude" <<EOF
#!/usr/bin/env bash
S="$STATE"; R="$REPO"; CJ="\$OFFICE_CLAUDE_JSON"
echo "\$*" >>"\$S/calls.log"
[ -f "\$S/plugins.json" ] || echo '[]' >"\$S/plugins.json"
[ -f "\$CJ" ] || echo '{}' >"\$CJ"
case "\$1 \$2 \$3" in
  "--version  ") echo "2.1.330 (Claude Code)" ;;
  "plugin list --json") cat "\$S/plugins.json" ;;
  "plugin marketplace list") if [ -f "\$S/market" ]; then printf '[{"name":"dev-office","installLocation":"%s"}]\n' "\$R"; else echo '[]'; fi ;;
  "plugin marketplace add") touch "\$S/market" ;;
  "plugin marketplace update") [ -f "\$S/market" ] ;;
  "plugin marketplace remove") rm -f "\$S/market" ;;
  "plugin install "*)
    id="\$3"; scope="\$5"; name="\${id%@*}"
    v=\$(jq -r .version "\$R/plugins/\$name/.claude-plugin/plugin.json")
    jq --arg id "\$id" --arg s "\$scope" --arg v "\$v" --arg p "\$(pwd -P)" --arg ip "\$R/plugins/\$name" \
      '. + [{id: \$id, scope: \$s, version: \$v, enabled: true, installPath: \$ip} + (if \$s == "user" then {} else {projectPath: \$p} end)]' \
      "\$S/plugins.json" >"\$S/p.tmp" && mv "\$S/p.tmp" "\$S/plugins.json" ;;
  "plugin update "*) ;;
  "plugin uninstall "*)
    jq --arg id "\$3" --arg s "\$5" 'map(select((.id == \$id and .scope == \$s) | not))' "\$S/plugins.json" >"\$S/p.tmp" && mv "\$S/p.tmp" "\$S/plugins.json" ;;
  "mcp add --transport")
    url="\${!#}"; jq --arg p "\$(pwd -P)" --arg u "\$url" '.projects[\$p].mcpServers.atlassian = {type: "http", url: \$u}' "\$CJ" >"\$CJ.tmp" && mv "\$CJ.tmp" "\$CJ" ;;
  "mcp remove atlassian")
    jq --arg p "\$(pwd -P)" 'del(.projects[\$p].mcpServers.atlassian)' "\$CJ" >"\$CJ.tmp" && mv "\$CJ.tmp" "\$CJ" ;;
  *) exit 1 ;;
esac
EOF
cat >"$BIN/gh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN/claude" "$BIN/gh"

fresh() {
  rm -rf "$PROJ" "$HOME" "$STATE"
  mkdir -p "$PROJ" "$HOME/.claude" "$STATE"
  git -C "$PROJ" init -q
  echo '{"dependencies":{"next":"15.0.0","drizzle-orm":"0.30.0"}}' >"$PROJ/package.json"
  echo "# reglas" >"$PROJ/CLAUDE.md"
}
excl() { cat "$PROJ/.git/info/exclude" 2>/dev/null; }

# --- Instalar, contestando las preguntas ---------------------------------------------
fresh
# alcance 1 (local), departamentos sugeridos (Enter), ramas "main dev", documentos locales (s),
# Jira sí con la etiqueta trabajo y el sitio.
run '1\n\nmain dev\ns\ns\ntrabajo\nmiempresa.atlassian.net\n' install
expect "instalar: agrega el marketplace" 'called "plugin marketplace add miguelramidev/dev-office"'
expect "instalar: sugiere departamentos según el proyecto" 'has "te sugiero: frontend database"'
expect "instalar: office y los departamentos sugeridos, con alcance local" '[ "$(plugins)" = "dept-database@dev-office|local dept-frontend@dev-office|local office@dev-office|local " ]'
expect "instalar: configura el proyecto en modo local" 'jq -e ".agent == \"office:pm\" and .env.OFFICE_PROTECTED_BRANCHES == \"main dev\"" "$PROJ/.claude/settings.local.json" >/dev/null'
expect "instalar: no toca .gitignore ni settings.json" '[ ! -f "$PROJ/.gitignore" ] && [ ! -f "$PROJ/.claude/settings.json" ]'
expect "instalar: documentos locales" 'excl | grep -qxF "# >>> dev-office: documentos locales"'
expect "instalar: Jira con la etiqueta, solo en el proyecto" 'jq -e --arg p "$PROJ" ".projects[\$p].mcpServers.atlassian.url == \"https://mcp.atlassian.com/v2/mcp?cuenta=trabajo\"" "$OFFICE_CLAUDE_JSON" >/dev/null'
expect "instalar: anota el sitio de Jira en las reglas locales" 'grep -qxF "Sitio de Jira: miempresa.atlassian.net" "$PROJ/.claude/rules/office-project.md"'
expect "instalar: corre el diagnóstico" 'has "Oficina dev-office: diagnóstico" && has "Las reglas dicen el sitio de Jira"'
expect "instalar: termina con los próximos pasos" 'has "/office:office-setup" && [ $code -eq 0 ]'
expect "instalar: git no ve nada de la oficina" '[ "$(cd "$PROJ" && git status --porcelain | grep -v -e package.json -e CLAUDE.md)" = "" ]'

# --- Volver a correrlo: actualizar y sumar un departamento ----------------------------
: >"$STATE/calls.log"
run '1\n1 2 3\n\n\nn\n' install
expect "ya instalada: muestra lo que hay y ofrece actualizar" 'has "Ya está instalada" && has "Reinstalar desde 0"'
expect "ya instalada: actualiza el marketplace, no lo vuelve a agregar" 'called "plugin marketplace update dev-office" && ! called "marketplace add"'
expect "ya instalada: actualiza lo instalado e instala lo nuevo" 'called "plugin update office@dev-office --scope local" && called "plugin install dept-backend@dev-office --scope local" && ! called "plugin install office@"'
expect "ya instalada: propone las ramas que ya tenía y los documentos locales" 'has "[main dev]" && has "[S/n]"'

# --- Desinstalar --------------------------------------------------------------------
mkdir -p "$PROJ/.office" "$PROJ/.qa" "$PROJ/docs/decisions"
echo "# mapa" >"$PROJ/docs/project-map.md"
echo "x" >"$PROJ/docs/decisions/0001.md"
cp "$REPO/plugins/office/skills/office-agents/office-agents.sh" "$PROJ/.claude/office-agents.sh"
jq '.permissions.allow += ["Bash(pnpm test *)"]' "$PROJ/.claude/settings.local.json" >"$WORK/s" && mv "$WORK/s" "$PROJ/.claude/settings.local.json"
: >"$STATE/calls.log"
# confirmar (s), no borrar documentos (n), borrar archivos (s), no borrar reglas (n), sacar Jira (s),
# no sacar el marketplace (n), agregar a exclude lo que git ve (s).
run 's\nn\ns\nn\ns\nn\ns\n' uninstall
expect "desinstalar: saca los departamentos antes que office" '[ "$(grep -n "plugin uninstall dept-" "$STATE/calls.log" | tail -n1 | cut -d: -f1)" -lt "$(grep -n "plugin uninstall office@" "$STATE/calls.log" | cut -d: -f1)" ]'
expect "desinstalar: no queda ningún plugin" '[ "$(plugins)" = "" ]'
expect "desinstalar: saca la configuración de la oficina y deja la del proyecto" 'jq -e "(.permissions.allow == [\"Bash(pnpm test *)\"]) and (has(\"agent\") | not) and (.env == null)" "$PROJ/.claude/settings.local.json" >/dev/null'
expect "desinstalar: borra los archivos de trabajo y los scripts copiados" '[ ! -e "$PROJ/.office" ] && [ ! -e "$PROJ/.qa" ] && [ ! -e "$PROJ/.claude/office-agents.sh" ]'
expect "desinstalar: los documentos quedan, y siguen fuera de git" '[ -f "$PROJ/docs/project-map.md" ] && excl | grep -qxF "docs/project-map.md" && excl | grep -qxF "docs/decisions/"'
expect "desinstalar: las reglas del proyecto quedan" '[ -f "$PROJ/.claude/rules/office-project.md" ]'
expect "desinstalar: saca Jira del proyecto" '! jq -e --arg p "$PROJ" ".projects[\$p].mcpServers.atlassian" "$OFFICE_CLAUDE_JSON" >/dev/null'
expect "desinstalar: el marketplace queda" '[ -f "$STATE/market" ]'
expect "desinstalar: lo que git veía de nuevo queda ignorado" '[ "$(cd "$PROJ" && git status --porcelain | grep -v -e package.json -e CLAUDE.md)" = "" ]'
expect "desinstalar: sin el bloque de la oficina en exclude" '! excl | grep -qxF "# >>> dev-office: oficina"'

run '' uninstall --yes
expect "desinstalar de nuevo: no queda nada" 'has "No queda nada de la oficina en este proyecto."'

# --- Modo equipo, con --yes ----------------------------------------------------------
fresh
run '' install --yes --scope project --departments "backend 4 nada"
expect "equipo: instala con alcance project, por nombre y por número" '[ "$(plugins)" = "dept-backend@dev-office|project dept-scraper@dev-office|project office@dev-office|project " ]'
expect "equipo: avisa del departamento que no existe" 'has "No existe el departamento nada"'
expect "equipo: la configuración va a settings.json y .gitignore" 'jq -e ".agent == \"office:pm\"" "$PROJ/.claude/settings.json" >/dev/null && grep -qxF ".office/" "$PROJ/.gitignore"'
expect "equipo: --yes no conecta Jira" '! called "mcp add"'
echo "dist/" >>"$PROJ/.gitignore"
jq '.permissions.allow += ["Bash(make test)"]' "$PROJ/.claude/settings.json" >"$WORK/s" && mv "$WORK/s" "$PROJ/.claude/settings.json"
run '' uninstall --yes --delete-docs
expect "equipo: desinstalar saca las líneas de .gitignore y deja las del proyecto" '! grep -qxF ".office/" "$PROJ/.gitignore" && grep -qxF "dist/" "$PROJ/.gitignore"'
expect "equipo: desinstalar deja las reglas del proyecto en settings.json" 'jq -e ".permissions.allow == [\"Bash(make test)\"] and (has(\"agent\") | not)" "$PROJ/.claude/settings.json" >/dev/null'
expect "equipo: con --yes no saca el marketplace" '[ -f "$STATE/market" ]'

# --- Reinstalar desde 0 --------------------------------------------------------------
fresh
run '' install --yes --departments "frontend" --docs local --protected "main dev" --jira personal --jira-site sitio.atlassian.net
mkdir -p "$PROJ/docs" && echo "# mapa" >"$PROJ/docs/project-map.md"
mkdir -p "$PROJ/.office" && echo x >"$PROJ/.office/events.js"
: >"$STATE/calls.log"
run '' reinstall --yes
expect "reinstalar: desinstala y vuelve a instalar" 'called "plugin uninstall office@dev-office --scope local" && called "plugin install office@dev-office --scope local"'
expect "reinstalar: mantiene los departamentos, el alcance, las ramas y los documentos locales" '[ "$(plugins)" = "dept-frontend@dev-office|local office@dev-office|local " ] && jq -e ".env.OFFICE_PROTECTED_BRANCHES == \"main dev\"" "$PROJ/.claude/settings.local.json" >/dev/null && excl | grep -qxF "# >>> dev-office: documentos locales"'
expect "reinstalar: borra los archivos de trabajo, deja los documentos y Jira" '[ ! -e "$PROJ/.office/events.js" ] && [ -f "$PROJ/docs/project-map.md" ] && ! called "mcp remove" && jq -e --arg p "$PROJ" ".projects[\$p].mcpServers.atlassian" "$OFFICE_CLAUDE_JSON" >/dev/null'

out=""
# --- Respuestas que no corresponden: vuelve a preguntar ------------------------------
fresh
run '1\nn\nfrontend\nn\nmain\nn\nn\n' install
expect "un departamento que no existe: vuelve a preguntar" 'has "No existe: n." && [ "$(plugins)" = "dept-frontend@dev-office|local office@dev-office|local " ]'
expect "una rama que es s o n: vuelve a preguntar" 'has "Escribí los nombres de las ramas" && jq -e ".env.OFFICE_PROTECTED_BRANCHES == \"main\"" "$PROJ/.claude/settings.local.json" >/dev/null'

# --- Menú y requisitos ---------------------------------------------------------------
run '5\n'
expect "menú: muestra las opciones y sale" 'has "1) Instalar" && has "3) Reinstalar desde 0" && [ $code -eq 0 ]'
run '4\n'
expect "menú: el diagnóstico" 'has "Oficina dev-office: diagnóstico"'
out=$(cd "$PROJ" && OFFICE_CLAUDE_BIN="$WORK/no-existe" bash "$SCRIPT" install </dev/null 2>&1); code=$?
expect "sin Claude Code: dice cómo instalarlo y corta" '[ $code -eq 1 ] && has "Falta Claude Code" && has "claude.ai/install"'
run '' bogus
expect "opción desconocida: sale con 2" '[ $code -eq 2 ]'

# --- El lanzador de Windows --------------------------------------------------------------
PS1="$REPO/dev-office.ps1"
expect "ps1: usa el bash de Git for Windows y le pasa la carpeta del proyecto" 'grep -q "Git\\\\bin\\\\bash.exe" "$PS1" && grep -q -- "--project" "$PS1" && grep -q "dev-office.sh" "$PS1"'

[ "$FAILED" -eq 0 ] && echo "Todas las pruebas pasan." || { echo "Hay pruebas que fallan."; exit 1; }
