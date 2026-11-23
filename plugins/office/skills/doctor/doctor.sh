#!/usr/bin/env bash
# office-doctor-version: 1
# Diagnóstico de la oficina dev-office en un proyecto, al estilo de "flutter doctor": revisa
# las herramientas, los plugins, la configuración del proyecto, los proveedores (Codex y
# Gemini), Jira y lo opcional, y para cada cosa que falta dice cómo arreglarla.
#
# Uso (desde la carpeta del proyecto): bash doctor.sh [--project <carpeta>]
#
# Marcas: [✓] listo · [!] aviso (funciona, pero conviene arreglarlo) · [✗] falta (algo de la
# oficina no va a funcionar) · [-] opcional, sin configurar.
# Sale con 1 si hay algo que falta, con 0 si no. No cambia ningún archivo y no llama a ningún
# modelo: no gasta tokens. Para lo que hace gastar tokens, está /office:save-tokens.
#
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift ;;
    -h | --help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]//\\//}")" && pwd)
PLUGIN_ROOT=$(cd "$SELF_DIR/../.." && pwd)
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT" ] && PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && PROJECT=$(pwd)
PROJECT="${PROJECT//\\//}"
USER_DIR="${OFFICE_USER_CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_JSON="${OFFICE_CLAUDE_JSON:-${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"
CLAUDE_BIN="${OFFICE_CLAUDE_BIN:-claude}"
TELEGRAM_CFG="${OFFICE_TELEGRAM_HOME:-$HOME/.claude/office-telegram}/config.json"
MARKET="dev-office"

case "${OSTYPE:-}" in
  msys* | cygwin* | win32*) OS=windows ;;
  darwin*) OS=mac ;;
  *) OS=linux ;;
esac

# Cómo instalar una herramienta en este sistema.
install_hint() {
  case "$OS:$1" in
    windows:jq) echo "En PowerShell: winget install jqlang.jq, y después reiniciá Claude Code" ;;
    windows:gh) echo "En PowerShell: winget install GitHub.cli, y después gh auth login" ;;
    windows:git) echo "Instalá Git for Windows: winget install Git.Git" ;;
    mac:*) echo "brew install $1$([ "$1" = gh ] && echo ', y después gh auth login')" ;;
    linux:gh) echo "Seguí https://github.com/cli/cli#installation, y después gh auth login" ;;
    linux:*) echo "sudo apt install $1 (o el gestor de tu distribución)" ;;
  esac
}

# --- Salida ---------------------------------------------------------------------
# Cada sección junta sus líneas y se imprime con la marca de lo peor que encontró.

PROBLEMS=0
WARNINGS=0
SEC_NAME="" SEC_LINES="" SEC_LEVEL=0 SEC_OPTIONAL=0

begin() { SEC_NAME="$1"; SEC_LINES=""; SEC_LEVEL=0; SEC_OPTIONAL=0; }
add() { SEC_LINES="$SEC_LINES$1
"; }
good() { add "    ✓ $1"; }
info() { add "    • $1"; }
# warn/bad <qué pasa> [cómo arreglarlo]
warn() { add "    ! $1"; [ -n "${2:-}" ] && add "      → $2"; [ "$SEC_LEVEL" -lt 1 ] && SEC_LEVEL=1; WARNINGS=$((WARNINGS + 1)); }
bad() { add "    ✗ $1"; [ -n "${2:-}" ] && add "      → $2"; SEC_LEVEL=2; PROBLEMS=$((PROBLEMS + 1)); }
optional() { add "    - $1"; [ -n "${2:-}" ] && add "      → $2"; SEC_OPTIONAL=1; }
end() {
  local mark="✓"
  [ "$SEC_LEVEL" -eq 0 ] && [ "$SEC_OPTIONAL" -eq 1 ] && mark="-"
  [ "$SEC_LEVEL" -eq 1 ] && mark="!"
  [ "$SEC_LEVEL" -eq 2 ] && mark="✗"
  printf '[%s] %s\n%s\n' "$mark" "$SEC_NAME" "$SEC_LINES"
}

echo "Oficina dev-office: diagnóstico de $PROJECT"
echo

# --- 1. Herramientas --------------------------------------------------------------

begin "Herramientas"
HAVE_CLAUDE=0
if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  HAVE_CLAUDE=1
  good "Claude Code $("$CLAUDE_BIN" --version 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
else
  warn "No encontré el comando claude en esta terminal: no puedo revisar los plugins instalados." "Corré el diagnóstico desde Claude Code (/office:doctor) o desde una terminal donde funcione claude --version"
fi
if command -v git >/dev/null 2>&1; then
  good "git $(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
else
  bad "Falta git: la oficina trabaja con ramas, commits y PRs." "$(install_hint git)"
fi
HAVE_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
  good "jq $(jq --version 2>/dev/null | tr -d '\r' | sed 's/^jq-//')"
else
  bad "Falta jq: sin él, los hooks de la oficina no funcionan (ramas protegidas, permisos, observer, Telegram)." "$(install_hint jq)"
fi
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    good "gh con sesión"
  else
    warn "gh está instalado, pero sin sesión: /office:open-pr y /office:review-fixes no van a poder abrir PRs ni leer revisiones." "gh auth login"
  fi
else
  warn "Falta gh (GitHub CLI): /office:open-pr y /office:review-fixes lo necesitan." "$(install_hint gh)"
fi
end

if [ "$HAVE_JQ" -eq 0 ]; then
  echo "Sin jq no puedo revisar el resto. Instalalo y volvé a correr el diagnóstico."
  exit 1
fi

jqc() { jq "$@" 2>/dev/null | tr -d '\r'; }
# Rutas comparables en cualquier sistema (C:\dev\App, /c/dev/App y C:/dev/App son la misma).
NP='def np: gsub("\\\\"; "/") | if test("^/[A-Za-z]/") then .[1:2] + ":" + .[2:] else . end
  | if test("^[A-Za-z]:") then ascii_downcase else . end | sub("/+$"; "");'
PROJECT_KEY=$(jq -rn --arg p "$PROJECT" "$NP"' $p | np' | tr -d '\r')

# Versión x.y.z como número comparable.
vnum() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk -F. '{ print $1 * 1000000 + $2 * 1000 + $3 }'; }

SHARED_SETTINGS="$PROJECT/.claude/settings.json"
LOCAL_SETTINGS="$PROJECT/.claude/settings.local.json"
USER_SETTINGS="$USER_DIR/settings.json"
read_json() { [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1 && cat "$1" || echo '{}'; }
# Ruta de un JSON válido, o de uno vacío: ~/.claude.json puede ser grande para pasarlo como
# argumento, así que jq lo lee del archivo (--slurpfile).
EMPTY_JSON=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/office-doctor-$$.json")
echo '{}' >"$EMPTY_JSON"
trap 'rm -f "$EMPTY_JSON"' EXIT
json_file() { if [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1; then printf '%s' "$1"; else printf '%s' "$EMPTY_JSON"; fi; }
SHARED_JSON=$(read_json "$SHARED_SETTINGS")
LOCAL_JSON=$(read_json "$LOCAL_SETTINGS")
USER_JSON=$(read_json "$USER_SETTINGS")
# Lo que vale en el proyecto: el local manda sobre el compartido, y este sobre el de usuario.
MERGED=$(printf '%s\n%s\n%s\n' "$USER_JSON" "$SHARED_JSON" "$LOCAL_JSON" | jqc -s '.[0] * .[1] * .[2]')
# Las reglas del proyecto, donde los agentes las leen.
RULES_TXT=$(cat "$PROJECT/CLAUDE.md" "$PROJECT"/.claude/rules/*.md 2>/dev/null)
# La regla de permisos que office-setup siempre agrega: marca dónde se aplicó.
has_office_rules() { printf '%s' "$1" | jq -e '(.permissions.allow // []) | index("Bash(gh pr checks)") != null' >/dev/null 2>&1; }

# --- 2. Plugins ---------------------------------------------------------------------

begin "Plugins de la oficina"
INSTALLED=""
if [ "$HAVE_CLAUDE" -eq 1 ]; then
  INSTALLED=$("$CLAUDE_BIN" plugin list --json 2>/dev/null | tr -d '\r' | jqc -c --arg m "@$MARKET" --arg p "$PROJECT_KEY" "$NP"'
    .[] | select(.id | endswith($m))
    | select(.scope == "user" or .scope == "managed" or ((.projectPath // "") | np) == $p)')
  MKT_DIR=$("$CLAUDE_BIN" plugin marketplace list --json 2>/dev/null | tr -d '\r' | jqc -r --arg m "$MARKET" '.[] | select(.name == $m) | .installLocation // .path // empty' | head -n1)
  MKT_DIR="${MKT_DIR//\\//}"
  OFFICE_ROWS=$(printf '%s\n' "$INSTALLED" | jqc -c 'select(.id | startswith("office@"))')
  if [ -z "$OFFICE_ROWS" ]; then
    bad "La oficina (office) no está instalada en este proyecto." "claude plugin install office@$MARKET --scope local"
  else
    if printf '%s\n' "$OFFICE_ROWS" | jq -e 'select(.enabled == false)' >/dev/null 2>&1 && ! printf '%s\n' "$OFFICE_ROWS" | jq -e 'select(.enabled != false)' >/dev/null 2>&1; then
      SC=$(printf '%s\n' "$OFFICE_ROWS" | jqc -r '.scope' | head -n1)
      bad "La oficina está instalada, pero desactivada." "claude plugin enable office@$MARKET --scope $SC"
    fi
  fi
  SCOPES_BY_ID=$(printf '%s\n' "$INSTALLED" | jqc -s -r 'group_by(.id)[] | "\(.[0].id)|\(map(.scope) | unique | join(" "))|\(map(.version) | max)"')
  DEPTS=""
  OLD=""
  while IFS='|' read -r id scopes ver; do
    [ -z "$id" ] && continue
    name="${id%@*}"
    case "$scopes" in
      *" "*) warn "$name está instalado en más de un alcance ($scopes): se carga dos veces." "Dejá uno solo; por ejemplo: claude plugin uninstall $id --scope ${scopes%% *}" ;;
    esac
    case "$name" in dept-*) DEPTS="$DEPTS ${name#dept-}" ;; esac
    [ "$name" = office ] && good "office $ver (alcance: $scopes)"
    if [ -n "$MKT_DIR" ] && [ -f "$MKT_DIR/plugins/$name/.claude-plugin/plugin.json" ]; then
      latest=$(jqc -r '.version // empty' "$MKT_DIR/plugins/$name/.claude-plugin/plugin.json")
      if [ -n "$latest" ] && [ -n "$ver" ] && [ "$(vnum "$ver")" -lt "$(vnum "$latest")" ]; then OLD="$OLD $name $ver → $latest,"; fi
    fi
    case "$scopes" in
      project) has_office_rules "$LOCAL_JSON" && ! has_office_rules "$SHARED_JSON" \
        && warn "$name está instalado para el equipo (--scope project), pero tu oficina es local." "claude plugin uninstall $id --scope project && claude plugin install $id --scope local (ver docs/migration.md)" ;;
    esac
  done <<EOF
$SCOPES_BY_ID
EOF
  if [ -n "$DEPTS" ]; then
    good "Departamentos:$DEPTS"
  elif [ -n "$OFFICE_ROWS" ]; then
    warn "No hay ningún departamento instalado: el PM no tiene a quién encargarle el trabajo." "Instalá los que uses, por ejemplo: claude plugin install dept-frontend@$MARKET --scope local"
  fi
  if [ -n "$OLD" ]; then
    warn "Hay versiones nuevas:${OLD%,}." "/office:update (o el doble click en update-office) y reiniciá Claude Code"
  elif [ -n "$INSTALLED" ] && [ -n "$MKT_DIR" ]; then
    good "Al día con el marketplace (según su última actualización)"
  fi
else
  info "Sin el comando claude, no puedo ver qué plugins hay instalados."
fi
end

# --- 3. Proyecto --------------------------------------------------------------------

begin "Configuración del proyecto"
IS_GIT=0
if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  IS_GIT=1
else
  warn "La carpeta no es un repositorio de git: la oficina no puede crear ramas, ignorar sus archivos ni abrir PRs." "git init, o abrí Claude Code en la carpeta del repositorio"
fi
if [ -f "$PROJECT/CLAUDE.md" ]; then
  good "CLAUDE.md"
elif ls "$PROJECT"/.claude/rules/*.md >/dev/null 2>&1; then
  good "Reglas del proyecto en .claude/rules/"
else
  warn "No hay CLAUDE.md ni reglas en .claude/rules/: los agentes no conocen las reglas del proyecto (comandos, ramas, convenciones)." "Creá un CLAUDE.md (/init) o, si el proyecto no puede tenerlo, .claude/rules/office-project.md"
fi

MODE=""
has_office_rules "$LOCAL_JSON" && MODE="local"
has_office_rules "$SHARED_JSON" && MODE="${MODE:+$MODE y }compartido"
case "$MODE" in
  "") bad "La oficina no está configurada en este proyecto (faltan los permisos base, las ramas protegidas y los archivos ignorados)." "/office:office-setup" ;;
  local) good "Modo local: la configuración está solo en tu computadora (.claude/settings.local.json)" ;;
  compartido) good "Modo compartido: la configuración va en git (.claude/settings.json)" ;;
  *) warn "La oficina está configurada en los dos modos, local y compartido." "Si es solo tuya: /office:office-setup con --move-to-local. Si es del equipo, borrá las reglas de la oficina de .claude/settings.local.json" ;;
esac

AGENT=$(printf '%s' "$MERGED" | jqc -r '.agent // empty')
case "$AGENT" in
  office:pm) good "El PM arranca solo al abrir claude" ;;
  "") warn "claude arranca sin el PM: hay que elegirlo con /agents cada vez." "/office:office-setup (o agregá \"agent\": \"office:pm\" a .claude/settings.local.json)" ;;
  *) info "El agente por defecto es $AGENT, no el PM: para trabajar con la oficina, elegí office:pm con /agents." ;;
esac
PMODE=$(printf '%s' "$MERGED" | jqc -r '.permissions.defaultMode // empty')
[ -n "$PMODE" ] && info "Modo de permisos: $PMODE"
PROT=$(printf '%s' "$MERGED" | jqc -r '.env.OFFICE_PROTECTED_BRANCHES // empty')
if [ -n "$PROT" ]; then info "Ramas protegidas: $PROT"; else info "Ramas protegidas: main y master (las de por defecto)"; fi

# Los comandos de tests, lint y typecheck permitidos: sin ellos, los testers piden permiso
# para cada uno.
if printf '%s' "$MERGED" | jq -e '(.permissions.allow // []) | any(test("^Bash\\(.*(test|lint|tsc|typecheck|type-check|analyze|vitest|jest|pytest|ruff|eslint|cargo|go vet)"; "i"))' >/dev/null 2>&1; then
  good "Comandos de verificación (tests, lint o typecheck) permitidos"
elif [ -n "$MODE" ]; then
  warn "No hay comandos de tests, lint ni typecheck permitidos: el developer y el tester te van a pedir permiso para cada uno." "/office:office-setup (paso de comandos de verificación), o sumá reglas como \"Bash(pnpm test *)\" a los permisos"
fi
if printf '%s' "$RULES_TXT" | grep -qiE 'related|findRelatedTests|--changed|relacionad|(pruebas|tests?) de lo que (tocaste|cambiaste)|solo (las pruebas|los tests)|_test\.(dart|go|py)|test_[a-z_<>]+\.py|\.(test|spec)\.[jt]sx?.{0,40}(junto|al lado|mismo)'; then
  good "Las reglas dicen cómo correr solo los tests relacionados"
else
  warn "Las reglas no dicen cómo correr solo los tests relacionados con un cambio: las tareas tardan más." "/office:office-setup (sección \"Comandos rápidos\"); por ejemplo: Tests de lo que cambiaste: pnpm vitest related <archivos> --run"
fi

if [ "$IS_GIT" -eq 1 ] && [ -n "$MODE" ]; then
  if git -C "$PROJECT" check-ignore -q .office/x 2>/dev/null && git -C "$PROJECT" check-ignore -q .qa/x 2>/dev/null; then
    good "git ignora los archivos de trabajo de la oficina (.office/, .qa/)"
  else
    bad "git no ignora .office/ o .qa/: los archivos de trabajo de la oficina pueden terminar en un commit." "/office:office-setup"
  fi
  if [ "$MODE" = local ]; then
    TRACKED=$(git -C "$PROJECT" ls-files -- .claude/office-agents.sh .claude/office-agents.cmd .claude/office-agents.json .claude/office-telegram.sh .claude/office-telegram.cmd .claude/update-office.sh .claude/update-office.cmd .claude/update-office.command 2>/dev/null | tr -d '\r' | tr '\n' ' ')
    [ -n "$TRACKED" ] && warn "Tu oficina es local, pero git sigue los archivos de la oficina: ${TRACKED% }." "git rm --cached ${TRACKED% } y commiteá ese cambio (ver docs/migration.md)"
  fi
fi

# Los scripts que la oficina copió en .claude/: si son más viejos que los del plugin.
script_version() { grep -m1 -oE -- '-version: [0-9]+' "$1" 2>/dev/null | grep -oE '[0-9]+'; }
STALE=""
for pair in office-agents/office-agents.sh telegram/office-telegram.sh update/update-office.sh; do
  dst="$PROJECT/.claude/${pair##*/}"; src="$PLUGIN_ROOT/skills/$pair"
  [ -f "$dst" ] && [ -f "$src" ] || continue
  new=$(script_version "$src"); old=$(script_version "$dst")
  [ -n "$new" ] && [ "${old:-0}" -lt "$new" ] && STALE="$STALE ${pair##*/},"
done
[ -n "$STALE" ] && warn "Hay copias viejas de los scripts de la oficina en .claude/:${STALE%,}." "/office:update"
BAKS=$(cd "$PROJECT" 2>/dev/null && ls .claude/*.bak 2>/dev/null | tr '\n' ' ')
[ -n "$BAKS" ] && info "Copias de seguridad de office-setup: ${BAKS% }. Borralas cuando estés conforme."
end

# --- 4. Proveedores -----------------------------------------------------------------

begin "Proveedores (Claude, Codex y Gemini)"
OA="$PLUGIN_ROOT/skills/office-agents/office-agents.sh"
if [ -f "$OA" ]; then
  # La tabla de roles de "show" (hasta la primera línea en blanco): qué proveedores se usan.
  USED=$(bash "$OA" --project "$PROJECT" show 2>/dev/null | tr -d '\r' | awk 'NR > 1 && NF == 0 { exit } NR > 1' | grep -oE 'codex|gemini' | sort -u | tr '\n' ' ')
  if [ -z "$USED" ]; then
    good "Todos los roles en Claude"
  else
    CHECK=$(bash "$OA" --project "$PROJECT" check 2>&1 | tr -d '\r')
    while IFS= read -r line; do
      case "$line" in
        "ok    claude"*) ;;
        "ok    "*) good "${line#ok    }" ;;
        "FALTA "*) bad "${line#FALTA }" ;;
        "AVISO "*) warn "${line#AVISO }" ;;
      esac
    done <<EOF
$CHECK
EOF
    case " $USED " in
      *" gemini "*)
        ST=$(bash "$OA" --project "$PROJECT" gemini-permissions status 2>&1 | tr -d '\r')
        if printf '%s' "$ST" | grep -q 'activados ('; then
          good "Gemini puede correr los comandos seguros (tests, lint, git de lectura)"
        else
          if [ -f "$PROJECT/.claude/office-agents.sh" ]; then
            FIX="bash .claude/office-agents.sh gemini-permissions on (en Windows: .claude\\office-agents.cmd gemini-permissions on)"
          else
            FIX="/office:office-agents y pedí activar los permisos de Gemini (gemini-permissions on)"
          fi
          warn "${ST% Corré: gemini-permissions on}" "$FIX"
        fi
        ;;
    esac
    info "Roles en Codex o Gemini: /office:office-agents"
  fi
else
  info "No encontré office-agents.sh en el plugin."
fi
end

# --- 5. Jira ------------------------------------------------------------------------

begin "Jira (Atlassian)"
CJ=$(json_file "$CLAUDE_JSON")
MCPJ=$(json_file "$PROJECT/.mcp.json")
SERVERS=$(jqc -cn --slurpfile cjs "$CJ" --slurpfile mjs "$MCPJ" --arg p "$PROJECT_KEY" "$NP"'
  $cjs[0] as $cj | $mjs[0] as $mj
  | [ ( $cj.projects // {} | to_entries[] | select((.key | np) == $p) | .value.mcpServers // {} | to_entries[] | {scope: "local", name: .key, s: .value} ),
    ( $mj.mcpServers // {} | to_entries[] | {scope: "project", name: .key, s: .value} ),
    ( $cj.mcpServers // {} | to_entries[] | {scope: "user", name: .key, s: .value} ) ]
  | map(select((.s.url // "") | test("atlassian\\.(com|net)")) )')
COUNT=$(printf '%s' "$SERVERS" | jqc 'map(select(.name == "atlassian")) | length')
OTHER=$(printf '%s' "$SERVERS" | jqc -r 'map(select(.name != "atlassian") | .name) | unique | join(", ")')
[ -n "$OTHER" ] && warn "Hay un servidor de Atlassian con otro nombre ($OTHER): el PM solo usa el que se llama atlassian." "claude mcp remove $OTHER y volvé a agregarlo con el nombre atlassian (/office:office-setup, paso de Jira)"
if [ "${COUNT:-0}" -eq 0 ]; then
  [ -z "$OTHER" ] && optional "No conectado (opcional)." "/office:office-setup (paso de Jira)"
else
  EFF=$(printf '%s' "$SERVERS" | jqc -c 'map(select(.name == "atlassian")) | first')
  SCOPE=$(printf '%s' "$EFF" | jqc -r '.scope')
  URL=$(printf '%s' "$EFF" | jqc -r '.s.url // ""')
  LABEL=$(printf '%s' "$URL" | sed -n 's/.*[?&]cuenta=\([^&]*\).*/\1/p')
  case "$SCOPE" in local) WHERE="solo en este proyecto" ;; project) WHERE="en .mcp.json" ;; *) WHERE="para todos tus proyectos" ;; esac
  if printf '%s' "$EFF" | jq -e '.s.headers.Authorization // .s.headers.authorization' >/dev/null 2>&1; then
    good "Conectado $WHERE, con un token de API"
  elif [ -n "$LABEL" ]; then
    good "Conectado $WHERE, con la cuenta \"$LABEL\""
  else
    good "Conectado $WHERE"
    [ "$SCOPE" = local ] && info "Si usás más de una cuenta de Atlassian, cada una con su etiqueta: ?cuenta=<etiqueta> (docs/migration.md)."
  fi
  [ "$SCOPE" = user ] && warn "Está con alcance user: aparece en todos tus proyectos, y todos usan la misma cuenta." "claude mcp remove atlassian -s user, y en cada proyecto: claude mcp add --transport http --scope local atlassian \"https://mcp.atlassian.com/v2/mcp?cuenta=<etiqueta>\""
  [ "${COUNT:-0}" -gt 1 ] && warn "atlassian está en más de un alcance ($(printf '%s' "$SERVERS" | jqc -r 'map(select(.name == "atlassian") | .scope) | join(", ")')); manda el $SCOPE." "Dejá uno solo: claude mcp remove atlassian -s <alcance que sobra>"
  if printf '%s' "$RULES_TXT" | grep -qi 'sitio de jira'; then
    good "Las reglas dicen el sitio de Jira"
  else
    warn "Las reglas no dicen el sitio de Jira: si tu cuenta ve varios, el PM puede usar otro." "Agregá a las reglas del proyecto: Sitio de Jira: miempresa.atlassian.net"
  fi
  info "La sesión la ves en Claude Code con /mcp."
fi
end

# --- 6. Opcional --------------------------------------------------------------------

begin "Opcional"
if [ -f "$TELEGRAM_CFG" ]; then
  good "Telegram: bot configurado"
else
  optional "Telegram: sin configurar (para seguir y aprobar desde el celular)." "/office:telegram"
fi
case " ${DEPTS:-} " in
  *" frontend "*)
    if jqc -n --slurpfile cjs "$CJ" --slurpfile mjs "$MCPJ" --arg p "$PROJECT_KEY" "$NP"'
        $cjs[0] as $cj | $mjs[0] as $mj
        | [($cj.projects // {} | to_entries[] | select((.key | np) == $p) | .value.mcpServers // {}), ($mj.mcpServers // {}), ($cj.mcpServers // {})]
        | any(has("figma"))' | grep -q true; then
      good "Figma conectado"
    else
      optional "Figma: sin conectar (si los diseños están en Figma)." "/office:office-setup (paso de diseños)"
    fi
    ;;
esac
if [ "$(printf '%s' "$MERGED" | jqc -r '.env.OFFICE_OBSERVER // "on"')" = off ]; then
  optional "Observer apagado (OFFICE_OBSERVER=off): /office:usage no tiene datos de tokens ni de tiempo."
else
  good "Observer encendido: /office:observer para verlo y /office:usage para el consumo"
fi
if [ -f "$PROJECT/docs/project-map.md" ] || printf '%s' "$RULES_TXT" | grep -qi 'project-map'; then
  good "Mapa del proyecto"
else
  optional "Sin mapa del proyecto todavía: el PM lo arma en la primera tarea." "/office:project-map, si lo querés ya"
fi
end

# --- Resumen ------------------------------------------------------------------------

if [ "$PROBLEMS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "Todo listo."
else
  P="$PROBLEMS problema$([ "$PROBLEMS" -ne 1 ] && echo s)"
  W="$WARNINGS aviso$([ "$WARNINGS" -ne 1 ] && echo s)"
  echo "Encontré $P y $W. Para el consumo de tokens, /office:save-tokens."
fi
[ "$PROBLEMS" -eq 0 ]
