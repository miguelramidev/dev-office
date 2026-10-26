#!/usr/bin/env bash
# office-agents-version: 1
# Configura qué proveedor (Claude, Codex o Gemini) hace cada rol de la oficina dev-office.
#
# Uso (desde la carpeta del proyecto):
#   bash .claude/office-agents.sh                  menú interactivo
#   bash .claude/office-agents.sh show             muestra la configuración de cada rol
#   bash .claude/office-agents.sh roles            lista los roles que se pueden configurar
#   bash .claude/office-agents.sh set <rol> <proveedor>[:<modelo>]... [--local]
#   bash .claude/office-agents.sh reset <rol>|--all [--local]
#   bash .claude/office-agents.sh get <rol>        el proveedor efectivo, uno por línea
#   bash .claude/office-agents.sh check            verifica que los CLIs estén instalados y con sesión
# En Windows también: .claude\office-agents.cmd <lo mismo>
#
# Ejemplos:
#   set backend.developer codex
#   set frontend.developer gemini:pro
#   set qa claude codex            (dos QA que se validan entre ellos)
#   set pm codex                   (el PM sigue en Claude y consulta a Codex como asesor)
#   set backend.architect claude:opus
#
# Archivos:
#   .claude/office-agents.json        la del equipo, va en git
#   .claude/office-agents.local.json  la tuya (--local), no va en git; manda rol por rol
#
# Reglas:
#   - Proveedores: claude, codex y gemini. Modelos de Claude: opus, sonnet o haiku.
#   - pm: el PM siempre es Claude; lo que se configura son sus asesores (codex o gemini).
#   - qa: uno o varios; con varios, revisan por separado y se validan entre ellos.
#   - El resto de los roles: un solo proveedor.
#   - Un rol sin configurar usa Claude con el modelo de siempre.
#
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows. Necesita jq.

KNOWN_ROLES="pm qa
backend.architect backend.developer backend.tester
frontend.architect frontend.designer frontend.developer frontend.tester
database.developer database.tester
scraper.developer scraper.tester
devops.architect devops.developer devops.tester"

die() {
  echo "office-agents: $1" >&2
  exit 1
}

jq_hint() {
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) echo "En Windows (PowerShell): winget install jqlang.jq, y después abrí otra terminal." ;;
    darwin*) echo "En macOS: brew install jq." ;;
    *) echo "En Linux: sudo apt install jq." ;;
  esac
}

command -v jq >/dev/null 2>&1 || die "falta jq. $(jq_hint)"

# jq sin los "\r" que agrega el jq de Windows.
jqc() { jq "$@" | tr -d '\r'; }

# --- Opciones generales -------------------------------------------------------

LOCAL=0
PROJECT=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --local) LOCAL=1 ;;
    --project) PROJECT="$2"; shift ;;
    -h | --help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
set -- ${ARGS[@]+"${ARGS[@]}"}

if [ -z "$PROJECT" ]; then
  PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r') || PROJECT=""
  [ -z "$PROJECT" ] && PROJECT=$(pwd)
fi
PROJECT="${PROJECT//\\//}"
SHARED="$PROJECT/.claude/office-agents.json"
LOCAL_FILE="$PROJECT/.claude/office-agents.local.json"
TARGET="$SHARED"
[ "$LOCAL" -eq 1 ] && TARGET="$LOCAL_FILE"

# --- Lectura ------------------------------------------------------------------

# Un archivo roto se avisa antes de cualquier cosa: si no, se leería como vacío.
for f in "$SHARED" "$LOCAL_FILE"; do
  if [ -f "$f" ] && ! jq empty "$f" >/dev/null 2>&1; then
    die "$f no es un JSON válido. Corregilo o borralo y volvé a configurar."
  fi
done

# Lista de proveedores de un rol en un archivo, uno por línea (vacío si no está).
read_role() {
  local file="$1" role="$2"
  [ -f "$file" ] || return 0
  jqc -r --arg r "$role" '.roles[$r] // empty | if type == "array" then .[] else . end' "$file"
}

# Proveedores efectivos de un rol: el archivo local manda sobre el del equipo.
# Sin configurar: "claude" (para pm, nada: no tiene asesores).
effective() {
  local role="$1" value
  value=$(read_role "$LOCAL_FILE" "$role")
  [ -z "$value" ] && value=$(read_role "$SHARED" "$role")
  if [ -z "$value" ] && [ "$role" != "pm" ]; then
    value="claude"
  fi
  [ -n "$value" ] && printf '%s\n' "$value"
}

# De dónde sale la configuración de un rol: local, equipo o por defecto.
source_of() {
  local role="$1"
  if [ -n "$(read_role "$LOCAL_FILE" "$role")" ]; then
    echo "local"
  elif [ -n "$(read_role "$SHARED" "$role")" ]; then
    echo "equipo"
  else
    echo "por defecto"
  fi
}

all_roles() {
  local extra=""
  for f in "$SHARED" "$LOCAL_FILE"; do
    [ -f "$f" ] && extra="$extra $(jqc -r '.roles // {} | keys[] | select(startswith("project."))' "$f")"
  done
  # shellcheck disable=SC2086
  printf '%s\n' $KNOWN_ROLES $extra | awk 'NF && !seen[$0]++'
}

# --- Validación ---------------------------------------------------------------

valid_role() {
  local role="$1" r
  case "$role" in
    project.[a-z0-9]*) return 0 ;;
  esac
  # shellcheck disable=SC2086
  for r in $KNOWN_ROLES; do
    [ "$r" = "$role" ] && return 0
  done
  return 1
}

validate_entry() {
  local role="$1" entry="$2" provider model
  provider="${entry%%:*}"
  model=""
  case "$entry" in *:*) model="${entry#*:}" ;; esac
  case "$provider" in
    claude)
      [ "$role" = "pm" ] && die "el PM ya es Claude: para pm configurá asesores (codex o gemini)."
      case "$model" in
        "" | opus | sonnet | haiku) ;;
        *) die "modelo de Claude inválido: '$model' (usá opus, sonnet o haiku)." ;;
      esac
      ;;
    codex | gemini)
      case "$model" in
        *[!A-Za-z0-9._-]*) die "modelo inválido: '$model' (solo letras, números, '.', '_' y '-')." ;;
      esac
      ;;
    *) die "proveedor desconocido: '$provider' (usá claude, codex o gemini)." ;;
  esac
}

# --- Escritura ----------------------------------------------------------------

write_role() {
  local role="$1"
  shift
  mkdir -p "$PROJECT/.claude"
  [ -f "$TARGET" ] || echo '{}' >"$TARGET"
  jq empty "$TARGET" >/dev/null 2>&1 || die "$TARGET no es un JSON válido."
  local value tmp
  value=$(printf '%s\n' "$@" | jq -R . | jq -s .)
  tmp="$TARGET.tmp"
  jqc -S --indent 2 --arg r "$role" --argjson v "$value" '.roles[$r] = $v' "$TARGET" >"$tmp" && mv "$tmp" "$TARGET"
}

remove_role() {
  local role="$1" tmp
  [ -f "$TARGET" ] || return 0
  tmp="$TARGET.tmp"
  if [ "$role" = "--all" ]; then
    jqc -S --indent 2 'del(.roles)' "$TARGET" >"$tmp" && mv "$tmp" "$TARGET"
  else
    jqc -S --indent 2 --arg r "$role" 'del(.roles[$r])' "$TARGET" >"$tmp" && mv "$tmp" "$TARGET"
  fi
}

# --- Comandos -----------------------------------------------------------------

cmd_set() {
  local role="$1"
  shift
  [ -z "$role" ] && die "falta el rol. Ejemplo: set backend.developer codex"
  valid_role "$role" || die "rol desconocido: '$role'. Mirá la lista con: roles"
  [ $# -eq 0 ] && die "falta el proveedor. Ejemplo: set $role codex"
  case "$role" in
    pm | qa) ;;
    *) [ $# -gt 1 ] && die "el rol $role lleva un solo proveedor (solo qa y pm aceptan varios)." ;;
  esac
  local e seen=" "
  for e in "$@"; do
    validate_entry "$role" "$e"
    case "$seen" in *" ${e%%:*} "*) die "'${e%%:*}' está repetido en $role." ;; esac
    seen="$seen${e%%:*} "
  done
  write_role "$role" "$@"
  echo "$role → $(printf '%s ' "$@")($( [ "$LOCAL" -eq 1 ] && echo local || echo equipo ))"
}

cmd_reset() {
  local role="$1"
  [ -z "$role" ] && die "falta el rol (o --all)."
  [ "$role" != "--all" ] && ! valid_role "$role" && die "rol desconocido: '$role'."
  remove_role "$role"
  echo "$role: vuelve a la configuración por defecto$( [ "$LOCAL" -eq 1 ] && echo ' (en tu archivo local)')."
}

cmd_get() {
  local role="$1"
  [ -z "$role" ] && die "falta el rol."
  valid_role "$role" || die "rol desconocido: '$role'."
  effective "$role"
}

cmd_show() {
  printf '%-22s %-28s %s\n' "ROL" "PROVEEDOR" "ORIGEN"
  local role value
  while IFS= read -r role; do
    value=$(effective "$role" | tr '\n' ' ')
    if [ "$role" = "pm" ]; then
      value="claude${value:+ + asesores: $value}"
    fi
    printf '%-22s %-28s %s\n' "$role" "$value" "$(source_of "$role")"
  done <<EOF
$(all_roles)
EOF
}

cmd_roles() {
  all_roles
  echo "project.<nombre>   (un agente propio del proyecto, en .claude/agents/<nombre>.md)"
}

install_hint() {
  case "$1" in
    codex) echo "instalalo con: npm install -g @openai/codex (o en macOS: brew install --cask codex). Después: codex login" ;;
    gemini) echo "instalalo con: npm install -g @google/gemini-cli (o en macOS: brew install gemini-cli). Después configurá GEMINI_API_KEY (o Vertex AI / Code Assist)" ;;
  esac
}

cmd_check() {
  local used role entry problems=0
  used=$(all_roles | while IFS= read -r role; do effective "$role"; done | cut -d: -f1 | awk '!seen[$0]++')
  for provider in $used; do
    case "$provider" in
      claude) echo "ok    claude: es la sesión de Claude Code" ;;
      codex | gemini)
        if ! command -v "$provider" >/dev/null 2>&1; then
          echo "FALTA $provider: no está instalado o no está en el PATH; $(install_hint "$provider")"
          problems=$((problems + 1))
          continue
        fi
        if [ "$provider" = "codex" ]; then
          if codex login status >/dev/null 2>&1; then
            echo "ok    codex: instalado y con sesión"
          else
            echo "FALTA codex: instalado pero sin sesión; corré: codex login"
            problems=$((problems + 1))
          fi
        else
          if [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ] || [ -n "${GOOGLE_GENAI_USE_VERTEXAI:-}" ] || [ -f "$HOME/.gemini/.env" ]; then
            echo "ok    gemini: instalado y con credenciales"
          else
            echo "AVISO gemini: instalado, pero no encontré GEMINI_API_KEY ni ~/.gemini/.env. En modo no interactivo necesita una API key, Vertex AI o Code Assist."
            problems=$((problems + 1))
          fi
        fi
        ;;
    esac
  done
  [ "$problems" -eq 0 ] && echo "Todo listo." && return 0
  return 1
}

cmd_menu() {
  local roles role entries i choice
  echo "Proveedores de la oficina dev-office ($PROJECT)"
  while true; do
    echo
    cmd_show
    echo
    roles=$(all_roles)
    i=0
    while IFS= read -r role; do
      i=$((i + 1))
      printf '  %2d) %s\n' "$i" "$role"
    done <<EOF
$roles
EOF
    printf '\nNúmero o nombre del rol a cambiar (Enter para terminar): '
    read -r choice || break
    [ -z "$choice" ] && break
    case "$choice" in
      *[!0-9]*) role="$choice" ;;
      *) role=$(printf '%s\n' "$roles" | sed -n "${choice}p") ;;
    esac
    if [ -z "$role" ] || ! valid_role "$role"; then
      echo "No existe ese rol."
      continue
    fi
    case "$role" in
      pm) echo "El PM es siempre Claude. Elegí sus asesores: codex, gemini o los dos (vacío para ninguno)." ;;
      qa) echo "Uno o varios, separados por espacio (por ejemplo: claude codex)." ;;
      *) echo "Un proveedor: claude, codex o gemini, con modelo opcional (por ejemplo gemini:pro, claude:opus)." ;;
    esac
    printf '%s → ' "$role"
    read -r entries || break
    if [ -z "$entries" ]; then
      (cmd_reset "$role")
    else
      # shellcheck disable=SC2086
      (cmd_set "$role" $entries)
    fi
  done
  echo
  echo "Probá que los proveedores estén listos con: check"
}

case "${1:-}" in
  "") cmd_menu ;;
  show) cmd_show ;;
  roles) cmd_roles ;;
  set) shift; cmd_set "$@" ;;
  reset) shift; cmd_reset "${1:-}" ;;
  get) shift; cmd_get "${1:-}" ;;
  check) cmd_check ;;
  *) die "comando desconocido: '$1'. Usá: show, roles, set, reset, get o check (o --help)." ;;
esac
