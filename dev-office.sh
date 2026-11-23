#!/usr/bin/env bash
# dev-office-script-version: 1
# Instala, desinstala o reinstala desde 0 la oficina dev-office en un proyecto, preguntando
# paso a paso. Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.
#
# Desde internet, en la carpeta del proyecto:
#   macOS, Linux o Git Bash:  bash <(curl -fsSL https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.sh)
#   Windows (PowerShell):     irm https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.ps1 | iex
#
# Uso: bash dev-office.sh [install|uninstall|reinstall|doctor] [opciones]
#   Sin comando, muestra un menú.
#
# Opciones, para no contestar alguna pregunta (con --yes, todo lo demás va con lo de por defecto):
#   --project <carpeta>        el proyecto (por defecto, la carpeta actual)
#   --yes                      acepta lo de por defecto en cada pregunta
#   --scope local|project      local: solo vos (por defecto); project: todo el equipo, en git
#   --departments "a b"        backend, frontend, database, scraper, devops, docs, research; all o none
#   --docs git|local           dónde van los documentos de la oficina (modo local)
#   --protected "main dev"     ramas protegidas (por defecto, main y master)
#   --jira <etiqueta>|no       conectar Jira con la cuenta de esa etiqueta (trabajo, personal...)
#   --jira-site <sitio>        el sitio de Jira, por ejemplo miempresa.atlassian.net
#   --delete-docs              al desinstalar, borrar también los documentos de la oficina
#   --remove-marketplace       al desinstalar, sacar el marketplace si ya no queda la oficina en ningún proyecto

set -u

REPO_SLUG="${OFFICE_MARKETPLACE_SOURCE:-miguelramidev/dev-office}"
MARKET="dev-office"
CLAUDE_BIN="${OFFICE_CLAUDE_BIN:-claude}"
CLAUDE_JSON="${OFFICE_CLAUDE_JSON:-${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"

CMD=""
PROJECT=""
YES=0
OPT_SCOPE=""
OPT_DEPTS=""
OPT_DOCS=""
OPT_PROTECTED=""
OPT_JIRA=""
OPT_SITE=""
DELETE_DOCS=0
REMOVE_MKT=0
while [ $# -gt 0 ]; do
  case "$1" in
    install | uninstall | reinstall | doctor) CMD="$1" ;;
    --project) PROJECT="$2"; shift ;;
    --yes | -y) YES=1 ;;
    --scope) OPT_SCOPE="$2"; shift ;;
    --departments) OPT_DEPTS="$2"; shift ;;
    --docs) OPT_DOCS="$2"; shift ;;
    --protected) OPT_PROTECTED="$2"; shift ;;
    --jira) OPT_JIRA="$2"; shift ;;
    --jira-site) OPT_SITE="$2"; shift ;;
    --delete-docs) DELETE_DOCS=1 ;;
    --remove-marketplace) REMOVE_MKT=1 ;;
    -h | --help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0" 2>/dev/null || echo "Uso: bash dev-office.sh [install|uninstall|reinstall|doctor]"; exit 0 ;;
    *) echo "Opción desconocida: $1 (bash dev-office.sh --help)" >&2; exit 2 ;;
  esac
  shift
done
case "$OPT_SCOPE" in "" | local | project) ;; *) echo "--scope: local o project." >&2; exit 2 ;; esac
case "$OPT_DOCS" in "" | git | local) ;; *) echo "--docs: git o local." >&2; exit 2 ;; esac

case "${OSTYPE:-}" in
  msys* | cygwin* | win32*) OS=windows ;;
  darwin*) OS=mac ;;
  *) OS=linux ;;
esac

# --- Preguntas ------------------------------------------------------------------------
# Con "bash <(curl ...)" o "curl ... | bash", las respuestas se leen de la terminal.

IN=0
if [ -z "${OFFICE_INSTALL_STDIN:-}" ] && [ ! -t 0 ] && (exec 3</dev/tty) 2>/dev/null; then
  exec 3</dev/tty
  IN=3
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m' G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' D=$'\033[2m' N=$'\033[0m'
else
  B="" G="" Y="" R="" D="" N=""
fi
title() { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }
good() { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
note() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
fail() { printf '  %s✗%s %s\n' "$R" "$N" "$1"; }
line() { printf '  %s\n' "$1"; }

# ask <pregunta> <por defecto>: escribe la respuesta (o lo de por defecto) en ANSWER.
ask() {
  local q="$1" def="${2:-}"
  if [ "$YES" -eq 1 ]; then ANSWER="$def"; printf '%s%s%s %s\n' "$B" "$q" "$N" "${def:-(nada)}"; return; fi
  printf '%s%s%s%s ' "$B" "$q" "$N" "${def:+ [$def]}"
  ANSWER=""
  IFS= read -r ANSWER <&"$IN" || true
  ANSWER=$(printf '%s' "$ANSWER" | tr -d '\r' | sed 's/^ *//; s/ *$//')
  [ -z "$ANSWER" ] && ANSWER="$def"
}
# yes_no <pregunta> s|n: 0 si la respuesta es sí.
yes_no() {
  local def="$2" hint="[s/N]"
  [ "$def" = s ] && hint="[S/n]"
  if [ "$YES" -eq 1 ]; then printf '%s%s%s %s\n' "$B" "$1" "$N" "$([ "$def" = s ] && echo sí || echo no)"; [ "$def" = s ]; return; fi
  while :; do
    printf '%s%s%s %s ' "$B" "$1" "$N" "$hint"
    local a=""
    IFS= read -r a <&"$IN" || a=""
    a=$(printf '%s' "$a" | tr -d '\r' | tr 'A-Z' 'a-z')
    [ -z "$a" ] && a="$def"
    case "$a" in s | si | sí | y | yes) return 0 ;; n | no) return 1 ;; esac
    line "Contestá s o n."
  done
}
# run <comando...>: lo muestra y lo corre. Si falla, pregunta si seguir.
run() {
  printf '  %s$ %s%s\n' "$D" "$*" "$N"
  if "$@"; then return 0; fi
  fail "Falló: $*"
  yes_no "  ¿Seguimos igual?" n || exit 1
  return 1
}
claude() { command "$CLAUDE_BIN" "$@"; }

# --- Requisitos -----------------------------------------------------------------------

install_hint() {
  case "$OS:$1" in
    windows:claude) echo "En PowerShell: irm https://claude.ai/install.ps1 | iex" ;;
    *:claude) echo "curl -fsSL https://claude.ai/install.sh | bash" ;;
    windows:jq) echo "winget install jqlang.jq" ;;
    windows:gh) echo "winget install GitHub.cli" ;;
    windows:git) echo "winget install Git.Git" ;;
    mac:*) echo "brew install $1" ;;
    linux:gh) echo "https://github.com/cli/cli#installation" ;;
    linux:*) echo "sudo apt install $1" ;;
  esac
}
# Ofrece instalar una herramienta con el gestor del sistema. 0 si quedó instalada.
offer_install() {
  local tool="$1" cmd
  cmd=$(install_hint "$tool")
  case "$cmd" in winget* | brew* | sudo*) ;; *) line "Instalalo así: $cmd"; return 1 ;; esac
  case "$cmd" in winget*) command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1 || { line "Instalalo así: $cmd"; return 1; } ;; esac
  case "$cmd" in brew*) command -v brew >/dev/null 2>&1 || { line "Instalá Homebrew (https://brew.sh) y después: $cmd"; return 1; } ;; esac
  yes_no "  ¿Lo instalo ahora? ($cmd)" s || return 1
  # shellcheck disable=SC2086
  run $cmd || return 1
  if [ "$OS" = windows ]; then
    note "Cerrá esta terminal, abrí una nueva y volvé a correr este script: Windows toma lo instalado en una terminal nueva."
    exit 0
  fi
  command -v "$tool" >/dev/null 2>&1
}

CHECKED=0
check_tools() {
  [ "$CHECKED" -eq 1 ] && return 0
  title "Herramientas"
  if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
    good "Claude Code $(claude --version 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  else
    fail "Falta Claude Code."
    line "Instalalo así: $(install_hint claude)"
    line "Después abrí una terminal nueva, corré claude una vez para iniciar sesión y volvé a correr este script."
    exit 1
  fi
  if command -v git >/dev/null 2>&1; then good "git"; else fail "Falta git."; offer_install git || exit 1; fi
  if command -v jq >/dev/null 2>&1; then good "jq"; else
    fail "Falta jq: lo usan este script y los hooks de la oficina."
    offer_install jq || exit 1
    good "jq"
  fi
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then good "gh con sesión"; else
      note "gh está instalado, pero sin sesión: la oficina lo usa para abrir PRs."
      if yes_no "  ¿Iniciás sesión ahora? (gh auth login)" n; then gh auth login <&"$IN" || note "No se pudo; después corré gh auth login."; fi
    fi
  else
    note "Falta gh (GitHub CLI): la oficina lo usa para abrir PRs y leer revisiones. Es opcional para instalar."
    if offer_install gh; then gh auth login <&"$IN" || note "Después corré gh auth login."; fi
  fi
}

# --- El proyecto y lo que hay instalado -----------------------------------------------

[ -z "$PROJECT" ] && PROJECT=$(pwd)
PROJECT="${PROJECT//\\//}"
cd "$PROJECT" 2>/dev/null || { echo "No existe la carpeta $PROJECT." >&2; exit 1; }
PROJECT=$(pwd -P)

# Rutas comparables en cualquier sistema (C:\dev\App, /c/dev/App y C:/dev/App son la misma).
NP='def np: gsub("\\\\"; "/") | if test("^/[A-Za-z]/") then .[1:2] + ":" + .[2:] else . end
  | if test("^[A-Za-z]:") then ascii_downcase else . end | sub("/+$"; "");'
project_key() { jq -rn --arg p "$PROJECT" "$NP"' $p | np' | tr -d '\r'; }

# Los plugins de la oficina de este proyecto (y los de alcance user), uno por línea.
installed() {
  claude plugin list --json 2>/dev/null | tr -d '\r' | jq -c --arg m "@$MARKET" --arg p "$(project_key)" "$NP"'
    .[]? | select(.id | endswith($m))
    | select(.scope == "user" or .scope == "managed" or ((.projectPath // "") | np) == $p)' 2>/dev/null
}
# Todos los de la oficina, en cualquier proyecto.
installed_anywhere() {
  claude plugin list --json 2>/dev/null | tr -d '\r' | jq -c --arg m "@$MARKET" '.[]? | select(.id | endswith($m))' 2>/dev/null
}
market_dir() {
  local d
  d=$(claude plugin marketplace list --json 2>/dev/null | tr -d '\r' | jq -r --arg m "$MARKET" '.[]? | select(.name == $m) | .installLocation // .path // empty' 2>/dev/null | head -n1)
  printf '%s' "${d//\\//}"
}
# Un archivo del plugin office: de la copia del marketplace o de la instalada.
office_file() {
  local rel="$1" d
  d=$(market_dir)
  [ -n "$d" ] && [ -f "$d/plugins/office/$rel" ] && { printf '%s' "$d/plugins/office/$rel"; return; }
  d=$(installed | jq -r 'select(.id | startswith("office@")) | .installPath // empty' | head -n1 | tr -d '\r')
  d="${d//\\//}"
  [ -n "$d" ] && [ -f "$d/$rel" ] && { printf '%s' "$d/$rel"; return; }
  return 1
}
exclude_file() { local e; e=$(git rev-parse --git-path info/exclude 2>/dev/null | tr -d '\r') && printf '%s' "$e"; }
docs_local_now() { local e; e=$(exclude_file) && grep -qxF '# >>> dev-office: documentos locales' "$e" 2>/dev/null; }
# Lo que había antes de reinstalar, para proponerlo de nuevo.
PREV_SCOPE="" PREV_DEPTS="" PREV_DOCS="" PREV_PROT=""
# Las ramas protegidas que ya tiene el proyecto (los settings locales mandan).
current_protected() {
  local f out=""
  for f in .claude/settings.json .claude/settings.local.json; do
    [ -f "$f" ] && out=$(jq -r --arg o "$out" '.env.OFFICE_PROTECTED_BRANCHES // $o' "$f" 2>/dev/null | tr -d '\r')
  done
  printf '%s' "$out"
}
has_office_rules() { [ -f "$1" ] && jq -e '(.permissions.allow // []) | index("Bash(gh pr checks)") != null' "$1" >/dev/null 2>&1; }
local_mcp() { # local_mcp <nombre>: 0 si el servidor está con alcance local en este proyecto.
  [ -f "$CLAUDE_JSON" ] || return 1
  jq -e --arg p "$(project_key)" --arg n "$1" "$NP"'
    .projects // {} | to_entries | any((.key | np) == $p and ((.value.mcpServers // {}) | has($n)))' "$CLAUDE_JSON" >/dev/null 2>&1
}

check_project() {
  [ "$CHECKED" -eq 1 ] && return 0
  CHECKED=1
  title "Proyecto"
  line "Carpeta: $PROJECT"
  if [ "$PROJECT" = "$(cd "$HOME" && pwd -P)" ]; then
    note "Es tu carpeta de usuario, no la de un proyecto. Entrá a la carpeta del proyecto (cd) y volvé a correr el script."
    yes_no "  ¿Seguimos igual?" n || exit 1
  fi
  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    good "Repositorio de git"
  else
    note "No es un repositorio de git: la oficina trabaja con ramas, commits y PRs."
    yes_no "  ¿Seguimos igual?" n || exit 1
  fi
}

# Departamentos que conviene instalar según lo que tiene el proyecto.
suggest_departments() {
  local s="" deps=""
  [ -f package.json ] && deps=$(jq -r '[(.dependencies // {}), (.devDependencies // {})] | add | keys[]?' package.json 2>/dev/null | tr -d '\r' | tr '\n' ' ')
  deps=" $deps "
  if [ -f pubspec.yaml ] || printf '%s' "$deps" | grep -qE ' (react|next|vue|nuxt|svelte|@sveltejs/kit|@angular/core|vite|react-native|expo|astro|solid-js) '; then s="$s frontend"; fi
  if [ -f go.mod ] || [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f composer.json ] || [ -f Gemfile ] || [ -f pom.xml ] || [ -f build.gradle ] || [ -f Cargo.toml ] \
    || printf '%s' "$deps" | grep -qE ' (express|fastify|@nestjs/core|hono|koa|@hapi/hapi|@trpc/server|@apollo/server) '; then s="$s backend"; fi
  if [ -d prisma ] || [ -d migrations ] || [ -d supabase ] || printf '%s' "$deps" | grep -qE ' (prisma|@prisma/client|drizzle-orm|typeorm|sequelize|mongoose|knex|kysely|pg|mysql2|mongodb) '; then s="$s database"; fi
  if printf '%s' "$deps" | grep -qE ' (puppeteer|cheerio|crawlee|got-scraping|jsdom) '; then s="$s scraper"; fi
  if [ -f Dockerfile ] || [ -d .github/workflows ] || ls ./*.tf >/dev/null 2>&1 || [ -d terraform ] || [ -d infra ]; then s="$s devops"; fi
  printf '%s' "${s# }"
}

# --- Instalar ---------------------------------------------------------------------------

ensure_marketplace() {
  title "Marketplace"
  if [ -n "$(market_dir)" ]; then
    run claude plugin marketplace update "$MARKET" && good "Marketplace $MARKET actualizado"
  else
    run claude plugin marketplace add "$REPO_SLUG" && good "Marketplace $MARKET agregado"
  fi
  [ -n "$(market_dir)" ] || { fail "No encuentro el marketplace $MARKET después de agregarlo."; exit 1; }
}

do_install() {
  local current scope depts available labels d mdir def=""
  check_tools
  check_project
  current=$(installed)
  if [ -n "$current" ] && [ "${REINSTALLING:-0}" -eq 0 ]; then
    title "Ya está instalada"
    printf '%s\n' "$current" | jq -r '"  \(.id) \(.version) (\(.scope))"'
    line "1) Actualizar, sumar departamentos y revisar la configuración"
    line "2) Reinstalar desde 0 (desinstala y vuelve a instalar; los documentos quedan)"
    line "3) Salir"
    ask "¿Qué hacemos?" 1
    case "$ANSWER" in
      2) do_reinstall; return ;;
      3) exit 0 ;;
    esac
  fi

  ensure_marketplace
  mdir=$(market_dir)

  # Alcance
  scope="$OPT_SCOPE"
  if [ -z "$scope" ]; then
    scope=$(printf '%s\n' "$current" | jq -r 'select(.id | startswith("office@")) | .scope' 2>/dev/null | grep -E '^(local|project)$' | head -n1)
    [ -z "$scope" ] && scope="$PREV_SCOPE"
    if [ -z "$scope" ]; then
      title "¿Para quién?"
      line "1) Solo para vos (local): nada de la oficina se sube al repositorio. Recomendado."
      line "2) Para todo el equipo (project): la configuración va en git."
      ask "Elegí" 1
      [ "$ANSWER" = 2 ] && scope=project || scope=local
    fi
  fi
  good "Alcance: $scope"

  # Departamentos
  title "Departamentos"
  available=$(jq -r '.plugins[] | select(.name | startswith("dept-")) | .name | sub("^dept-"; "")' "$mdir/.claude-plugin/marketplace.json" 2>/dev/null | tr -d '\r')
  [ -z "$available" ] && available="backend frontend database scraper devops docs research"
  depts="$OPT_DEPTS"
  if [ -z "$depts" ]; then
    local have sug i=1 n
    have=$(printf '%s\n' "$current" | jq -r '.id | select(startswith("dept-")) | sub("^dept-"; "") | sub("@.*"; "")' 2>/dev/null | tr -d '\r' | tr '\n' ' ')
    [ -z "${have// /}" ] && have="$PREV_DEPTS"
    sug=$(suggest_departments)
    for n in $available; do
      labels=$(jq -r --arg n "dept-$n" '.plugins[] | select(.name == $n) | .description | split(":")[0]' "$mdir/.claude-plugin/marketplace.json" 2>/dev/null | tr -d '\r')
      line "$i) $n${labels:+ — $labels}$(case " $have " in *" $n "*) echo " (instalado)" ;; esac)"
      i=$((i + 1))
    done
    def="${have% }"
    [ -z "$def" ] && def="$sug"
    [ -n "$sug" ] && [ -z "$have" ] && line "Según lo que tiene el proyecto, te sugiero: $sug"
    line "Escribí los números o los nombres separados por espacios, \"all\" para todos o \"none\" para ninguno."
  fi
  # Pregunta hasta que todo lo que se escribió sea un departamento (con --departments o --yes,
  # lo que no existe se saltea).
  local chosen="" tok k bad
  while :; do
    if [ -z "$OPT_DEPTS" ]; then ask "Departamentos:" "${def:-none}"; depts="$ANSWER"; fi
    case "$depts" in
      all | todos) depts="$available" ;;
      none | ninguno) depts="" ;;
    esac
    chosen="" bad=""
    for tok in $depts; do
      case "$tok" in
        *[!0-9]*) case " $(printf '%s' "$available" | tr '\n' ' ') " in *" ${tok#dept-} "*) chosen="$chosen ${tok#dept-}" ;; *) bad="$bad $tok" ;; esac ;;
        *) k=$(printf '%s\n' "$available" | sed -n "${tok}p"); [ -n "$k" ] && chosen="$chosen $k" || bad="$bad $tok" ;;
      esac
    done
    [ -z "$bad" ] && break
    if [ -n "$OPT_DEPTS" ] || [ "$YES" -eq 1 ]; then
      for tok in $bad; do note "No existe el departamento $tok: lo salteo."; done
      break
    fi
    line "No existe:$bad. Elegí de la lista (números o nombres), all o none."
  done
  chosen=$(printf '%s\n' $chosen | awk '!seen[$0]++' | tr '\n' ' ')
  chosen="${chosen% }"

  # Instalar o actualizar
  title "Plugins"
  for d in office $chosen; do
    local id="$d@$MARKET"
    [ "$d" != office ] && id="dept-$d@$MARKET"
    local row
    row=$(printf '%s\n' "$current" | jq -c --arg id "$id" --arg s "$scope" 'select(.id == $id and .scope == $s)' 2>/dev/null | head -n1)
    if [ -n "$row" ]; then
      run claude plugin update "$id" --scope "$scope" && good "${id%@*} actualizado"
    else
      run claude plugin install "$id" --scope "$scope" && good "${id%@*} instalado"
    fi
  done
  [ -z "$chosen" ] && note "Sin departamentos, el PM no tiene a quién encargarle el trabajo. Los sumás cuando quieras volviendo a correr este script."

  # Configuración del proyecto
  title "Configuración del proyecto"
  local setup args=() prot docs
  setup=$(office_file skills/office-setup/setup.sh) || { fail "No encuentro el setup de la oficina."; exit 1; }
  [ "$scope" = project ] && args+=(--shared)
  prot="$OPT_PROTECTED"
  if [ -z "$prot" ]; then
    local cur_prot
    cur_prot=$(current_protected)
    line "Las ramas protegidas son las que la oficina no toca directo (trabaja en otra rama y abre un PR)."
    while :; do
      ask "Ramas protegidas, separadas por espacios:" "${cur_prot:-${PREV_PROT:-main master}}"
      prot="$ANSWER"
      case "$(printf '%s' "$prot" | tr 'A-Z' 'a-z')" in
        s | n | si | sí | no | y | yes) line "Escribí los nombres de las ramas (por ejemplo: main dev), o Enter para dejar las de siempre." ;;
        *) break ;;
      esac
    done
  fi
  [ -n "$prot" ] && [ "$prot" != "main master" ] && args+=(--protected "$prot")
  if [ "$scope" = local ]; then
    docs="$OPT_DOCS"
    if [ -z "$docs" ]; then
      line "Los documentos de la oficina son el mapa del proyecto, las decisiones, los diseños, las colecciones de API y las investigaciones."
      local ddef=n
      { docs_local_now || [ "$PREV_DOCS" = local ]; } && ddef=s
      if yes_no "¿Los dejás solo en tu computadora, sin subirlos a git? (por ejemplo, en el repositorio de tu trabajo)" "$ddef"; then docs=local; else docs=git; fi
    fi
    args+=(--docs "$docs")
  fi
  if CLAUDE_PROJECT_DIR="$PROJECT" bash "$setup" ${args[@]+"${args[@]}"} | sed 's/^/  /'; then :; else fail "El setup falló."; exit 1; fi

  # Jira
  title "Jira (opcional)"
  local label="$OPT_JIRA" site="$OPT_SITE"
  if [ -z "$label" ]; then
    if yes_no "¿Conectás Jira en este proyecto?" n; then
      line "Cada cuenta de Atlassian lleva su etiqueta: los proyectos con la misma etiqueta comparten el login."
      ask "Etiqueta de la cuenta (por ejemplo trabajo o personal):" personal
      label="$ANSWER"
    else
      label=no
    fi
  fi
  if [ "$label" != no ]; then
    label=$(printf '%s' "$label" | tr -cd 'A-Za-z0-9_-')
    local_mcp atlassian && run claude mcp remove atlassian -s local
    run claude mcp add --transport http --scope local atlassian "https://mcp.atlassian.com/v2/mcp?cuenta=$label" && good "Jira conectado con la cuenta \"$label\""
    if [ -z "$site" ] && [ "$YES" -eq 0 ]; then ask "Sitio de Jira (por ejemplo miempresa.atlassian.net), o Enter para saltear:" ""; site="$ANSWER"; fi
    if [ -n "$site" ]; then
      local rules=".claude/rules/office-project.md"
      mkdir -p .claude/rules
      if grep -qi '^Sitio de Jira:' "$rules" 2>/dev/null; then
        sed -i.tmp "s|^Sitio de Jira:.*|Sitio de Jira: $site|" "$rules" && rm -f "$rules.tmp"
      else
        printf 'Sitio de Jira: %s\n' "$site" >>"$rules"
      fi
      good "Sitio de Jira anotado en $rules"
    fi
    line "Falta iniciar sesión: abrí claude, corré /mcp, elegí atlassian → autenticar y entrá con esa cuenta."
  else
    line "Lo conectás después con /office:office-setup."
  fi

  # Diagnóstico
  title "Diagnóstico"
  local doc
  if doc=$(office_file skills/doctor/doctor.sh); then
    CLAUDE_PROJECT_DIR="$PROJECT" OFFICE_CLAUDE_BIN="$CLAUDE_BIN" bash "$doc" --project "$PROJECT" | sed 's/^/  /'
  fi

  title "Listo"
  line "1. Abrí Claude Code en esta carpeta: claude (arranca con el PM)."
  line "2. Corré /office:office-setup para lo propio del proyecto: los comandos de tests, lint y typecheck, y las reglas."
  line "3. Si algo no anda, /office:doctor te dice qué falta."
  [ ! -f CLAUDE.md ] && line "4. El proyecto no tiene CLAUDE.md: créalo con /init (o, si no puede tenerlo, usá .claude/rules/office-project.md)."
  return 0
}

# --- Desinstalar ------------------------------------------------------------------------

# Los archivos que la oficina deja en el proyecto (sin los documentos).
OFFICE_FILES=(".office" ".qa" ".claude/office-activity.log" ".claude/office-agents.sh" ".claude/office-agents.cmd"
  ".claude/office-agents.json" ".claude/office-agents.local.json" ".claude/office-telegram.sh" ".claude/office-telegram.cmd"
  ".claude/update-office.sh" ".claude/update-office.cmd" ".claude/update-office.command"
  ".claude/settings.json.bak" ".claude/settings.local.json.bak")
# Las reglas del proyecto que escribió office-setup (por ejemplo, el sitio de Jira).
RULES_FILE=".claude/rules/office-project.md"
DOC_FILES=("docs/project-map.md" "docs/project-map" "docs/decisions" "docs/design" "docs/api" "docs/research")

existing() { local f out=""; for f in "$@"; do [ -e "$f" ] && out="$out $f"; done; printf '%s' "${out# }"; }

do_uninstall() {
  local reinstall="${1:-0}" current proj_rows user_rows setup files docs tracked
  check_tools
  check_project
  current=$(installed)
  proj_rows=$(printf '%s\n' "$current" | jq -c 'select(.scope == "local" or .scope == "project")' 2>/dev/null)
  user_rows=$(printf '%s\n' "$current" | jq -c 'select(.scope == "user")' 2>/dev/null)

  title "Qué hay de la oficina en este proyecto"
  if [ -n "$current" ]; then printf '%s\n' "$current" | jq -r '"  \(.id) \(.version) (\(.scope))"'; else line "Ningún plugin de la oficina instalado."; fi
  has_office_rules .claude/settings.local.json && line "Configuración local (.claude/settings.local.json)"
  has_office_rules .claude/settings.json && line "Configuración del equipo (.claude/settings.json)"
  files=$(existing "${OFFICE_FILES[@]}")
  [ -n "$files" ] && line "Archivos: $files"
  docs=$(existing "${DOC_FILES[@]}")
  [ -n "$docs" ] && line "Documentos: $docs"
  local_mcp atlassian && line "Jira: atlassian, solo en este proyecto"
  if [ -z "$current" ] && [ -z "$files" ] && ! has_office_rules .claude/settings.local.json && ! has_office_rules .claude/settings.json; then
    good "No queda nada de la oficina en este proyecto."
    [ "$reinstall" -eq 1 ] && return 0
  fi
  if [ "$reinstall" -eq 0 ]; then
    yes_no "¿Desinstalo la oficina de este proyecto?" s || exit 0
  fi

  # Los documentos: se decide antes de sacar la configuración, porque si eran locales y quedan,
  # siguen fuera de git.
  local keep_docs=1 had_docs_local=0
  docs_local_now && had_docs_local=1
  docs=$(existing "${DOC_FILES[@]}")
  if [ -n "$docs" ] && [ "$reinstall" -eq 0 ]; then
    title "Documentos"
    line "$docs: son documentación del proyecto (el mapa, las decisiones...)."
    if [ "$DELETE_DOCS" -eq 1 ] || { [ "$YES" -eq 0 ] && yes_no "¿Los borro también?" n; }; then keep_docs=0; fi
  fi

  # 1. La configuración, antes de sacar los plugins: el setup está en el plugin.
  title "Configuración"
  if has_office_rules .claude/settings.local.json || has_office_rules .claude/settings.json || grep -q '^# >>> dev-office: ' "$(git rev-parse --git-path info/exclude 2>/dev/null || echo /dev/null)" 2>/dev/null; then
    if setup=$(office_file skills/office-setup/setup.sh); then
      CLAUDE_PROJECT_DIR="$PROJECT" bash "$setup" --remove | sed 's/^/  /'
    else
      note "No encuentro el setup de la oficina para sacar su configuración. Sacala a mano de .claude/settings.local.json y .claude/settings.json (las reglas \"Bash(gh pr checks)\" y compañía, \"agent\": \"office:pm\" y las variables OFFICE_)."
    fi
  else
    good "Sin configuración de la oficina"
  fi
  # Si los documentos eran locales y quedan, siguen fuera de git.
  if [ "$had_docs_local" -eq 1 ] && [ "$keep_docs" -eq 1 ] && [ "$reinstall" -eq 0 ]; then
    { echo "# >>> dev-office: documentos locales"; printf '%s/\n' "${DOC_FILES[@]}" | sed 's|\.md/$|.md|'; echo "# <<< dev-office: documentos locales"; } >>"$(exclude_file)"
    good "Los documentos siguen fuera de git (.git/info/exclude)"
  fi

  # 2. Los archivos de trabajo, los scripts copiados y tu configuración de proveedores.
  title "Archivos"
  files=$(existing "${OFFICE_FILES[@]}")
  if [ -n "$files" ]; then
    line "$files"
    if [ "$reinstall" -eq 1 ] || yes_no "¿Los borro?" s; then
      # shellcheck disable=SC2086
      tracked=$(git ls-files -- $files 2>/dev/null | tr -d '\r' | tr '\n' ' ')
      # shellcheck disable=SC2086
      rm -rf $files && good "Borrados"
      [ -n "$tracked" ] && note "Estaban en git: ${tracked% }. Revisá el cambio y commitealo."
    fi
  else
    good "No hay archivos de la oficina"
  fi
  # Los settings que quedaron vacíos, sin la oficina.
  local f
  for f in .claude/settings.local.json .claude/settings.json; do
    [ -f "$f" ] && jq -e '. == {}' "$f" >/dev/null 2>&1 && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1 && rm -f "$f" && good "$f quedó vacío: lo borré"
  done
  if [ -f "$RULES_FILE" ] && [ "$reinstall" -eq 0 ]; then
    line "$RULES_FILE tiene las reglas del proyecto que anotó la oficina (por ejemplo, el sitio de Jira)."
    yes_no "¿Lo borro?" n && rm -f "$RULES_FILE" && good "Borrado"
  fi
  if [ -n "$docs" ] && [ "$reinstall" -eq 0 ]; then
    if [ "$keep_docs" -eq 0 ]; then
      # shellcheck disable=SC2086
      rm -rf $docs && good "Documentos borrados"
    else
      good "Los documentos quedan"
    fi
  fi
  rmdir .claude/rules .claude 2>/dev/null

  # 3. Jira de este proyecto.
  if local_mcp atlassian && [ "$reinstall" -eq 0 ]; then
    title "Jira"
    if yes_no "¿Saco Jira (atlassian) de este proyecto? Tu login en otros proyectos no cambia." s; then
      run claude mcp remove atlassian -s local && good "Jira sacado"
    fi
  fi
  [ -f .mcp.json ] && jq -e '.mcpServers.atlassian' .mcp.json >/dev/null 2>&1 && note ".mcp.json (del equipo) tiene atlassian: no lo toco."

  # 4. Los plugins: primero los departamentos, después office (dependen de él).
  title "Plugins"
  local row id sc
  for row in $(printf '%s\n' "$proj_rows" | jq -r 'select(.id | startswith("office@") | not) | "\(.id)|\(.scope)"'; printf '%s\n' "$proj_rows" | jq -r 'select(.id | startswith("office@")) | "\(.id)|\(.scope)"'); do
    id="${row%|*}"; sc="${row#*|}"
    run claude plugin uninstall "$id" --scope "$sc" && good "${id%@*} desinstalado ($sc)"
  done
  [ -z "$proj_rows" ] && good "No hay plugins de la oficina instalados en este proyecto"
  if [ -n "$user_rows" ]; then
    note "Hay plugins de la oficina con alcance user (para todos tus proyectos): $(printf '%s\n' "$user_rows" | jq -r '.id' | tr '\n' ' ')"
    if [ "$reinstall" -eq 1 ] || yes_no "¿Los desinstalo también? Dejan de estar en todos tus proyectos." n; then
      for row in $(printf '%s\n' "$user_rows" | jq -r 'select(.id | startswith("office@") | not) | .id'; printf '%s\n' "$user_rows" | jq -r 'select(.id | startswith("office@")) | .id'); do
        run claude plugin uninstall "$row" --scope user && good "${row%@*} desinstalado (user)"
      done
    fi
  fi
  [ "$reinstall" -eq 1 ] && return 0

  # 5. Si ya no queda la oficina en ningún proyecto: lo de tu usuario.
  if [ -z "$(installed_anywhere)" ]; then
    title "Tu computadora"
    line "Ya no queda la oficina en ningún proyecto."
    local desk f
    for desk in "$HOME/Desktop" "$HOME/Escritorio" "$HOME/OneDrive/Desktop" "$HOME/OneDrive/Escritorio"; do
      f=$(cd "$desk" 2>/dev/null && existing update-office.sh update-office.cmd update-office.command)
      [ -z "$f" ] && continue
      if yes_no "¿Borro el actualizador del Escritorio ($desk: $f)?" s; then
        # shellcheck disable=SC2086
        (cd "$desk" && rm -f $f) && good "Actualizador borrado"
      fi
    done
    if [ -d "$HOME/.claude/office-telegram" ] && yes_no "¿Borro la configuración de Telegram de la oficina (el bot y tu chat)?" n; then
      rm -rf "$HOME/.claude/office-telegram" && good "Telegram borrado"
    fi
    if [ -n "$(market_dir)" ] && { [ "$REMOVE_MKT" -eq 1 ] || { [ "$YES" -eq 0 ] && yes_no "¿Saco también el marketplace dev-office?" n; }; }; then
      run claude plugin marketplace remove "$MARKET" && good "Marketplace sacado"
    fi
  fi

  # Lo que git ve ahora y antes ignoraba la oficina (por ejemplo, tus settings locales).
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local seen
    seen=$(git status --porcelain --untracked-files=normal -- .claude .mcp.json "${DOC_FILES[@]}" 2>/dev/null | tr -d '\r' | sed -n 's/^?? //p' | tr '\n' ' ')
    if [ -n "$seen" ]; then
      title "Git"
      note "Sin la oficina, git ve archivos que antes ignoraba: ${seen% }"
      if yes_no "¿Los agrego a .git/info/exclude para que no se suban?" s; then
        printf '%s\n' $seen >>"$(exclude_file)" && good "Agregados a .git/info/exclude"
      fi
    fi
  fi

  title "Listo"
  line "La oficina quedó desinstalada de este proyecto. Si tenías Claude Code abierto acá, reinicialo."
  [ -f .claude/settings.json ] && git ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1 && line "Revisá git status: si la oficina estaba en git, commiteá el cambio."
  return 0
}

do_reinstall() {
  REINSTALLING=1
  title "Reinstalar desde 0"
  line "Desinstalo la oficina de este proyecto (sus plugins, su configuración y sus archivos de trabajo) y la vuelvo a instalar."
  line "Quedan los documentos (mapa, decisiones, diseños) y la conexión con Jira."
  yes_no "¿Seguimos?" s || exit 0
  check_tools
  check_project
  PREV_SCOPE=$(installed | jq -r 'select(.id | startswith("office@")) | .scope' 2>/dev/null | grep -E '^(local|project)$' | head -n1)
  PREV_DEPTS=$(installed | jq -r '.id | select(startswith("dept-")) | sub("^dept-"; "") | sub("@.*"; "")' 2>/dev/null | tr -d '\r' | tr '\n' ' ')
  docs_local_now && PREV_DOCS=local
  PREV_PROT=$(current_protected)
  do_uninstall 1
  do_install
}

do_doctor() {
  local doc
  doc=$(office_file skills/doctor/doctor.sh) || { echo "La oficina no está instalada en este proyecto: no encuentro el diagnóstico."; exit 1; }
  CLAUDE_PROJECT_DIR="$PROJECT" OFFICE_CLAUDE_BIN="$CLAUDE_BIN" bash "$doc" --project "$PROJECT"
}

# --- Menú -------------------------------------------------------------------------------

command -v jq >/dev/null 2>&1 || {
  echo "Falta jq: este script y los hooks de la oficina lo necesitan."
  echo "Instalalo así: $(install_hint jq). Después abrí una terminal nueva y volvé a correr el script."
  exit 1
}

printf '%sOficina dev-office%s\n' "$B" "$N"
if [ -z "$CMD" ]; then
  if command -v "$CLAUDE_BIN" >/dev/null 2>&1 && [ -n "$(installed)" ]; then
    line "Proyecto: $PROJECT (la oficina está instalada)"
  else
    line "Proyecto: $PROJECT"
  fi
  line "1) Instalar (o actualizar y sumar departamentos)"
  line "2) Desinstalar"
  line "3) Reinstalar desde 0"
  line "4) Diagnóstico"
  line "5) Salir"
  ask "¿Qué hacemos?" 1
  case "$ANSWER" in
    1) CMD=install ;; 2) CMD=uninstall ;; 3) CMD=reinstall ;; 4) CMD=doctor ;; *) exit 0 ;;
  esac
fi

case "$CMD" in
  install) do_install ;;
  uninstall) do_uninstall 0 ;;
  reinstall) do_reinstall ;;
  doctor) do_doctor ;;
esac
