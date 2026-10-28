#!/usr/bin/env bash
# Corre un encargo de la oficina dev-office con Codex o Gemini (con Antigravity CLI, agy) y
# revisa lo que hicieron.
# Lo usa el agente puente (office:external); no hace falta correrlo a mano.
#
# Uso:
#   bash run-external.sh --role <rol> --provider codex|gemini [--model <modelo>] --run-dir <carpeta>
#
#   --role      el rol de la oficina: backend.developer, qa, pm (asesor), project.<nombre>...
#   --model     opcional. Sin él, se usa el modelo del nivel del rol (el del modelo de Claude de
#               su agente: opus o sonnet) en ese proveedor, según office-agents.sh models.
#   --run-dir   carpeta del encargo dentro del proyecto (por ejemplo .office/runs/<id>), con
#               el encargo en task.md. Ahí quedan prompt.md, output.md, log.txt y summary.txt.
#
# Qué hace:
#   1. Verifica que el proveedor esté instalado y que la rama actual no esté protegida.
#   2. Arma el prompt: reglas para el proveedor, las instrucciones del rol y sus skills
#      (tomadas de los plugins de dev-office instalados) y el encargo.
#   3. Corre el CLI en la carpeta del proyecto, con el modelo y el razonamiento de la tabla
#      de office-agents.sh y con tope de tiempo
#      (OFFICE_EXTERNAL_TIMEOUT, en segundos; por defecto 540).
#   4. Revisa lo que cambió: archivos de secretos, claves o lockfiles, archivos fuera de lo
#      que el rol puede tocar, commits y cambios de rama. No deshace nada: lo informa.
#
# Códigos de salida:
#   0 terminó bien · 1 error de uso · 2 proveedor no disponible (no instalado, sin sesión,
#   sin cuota) · 3 el proveedor falló · 4 se rompió una regla (o la rama está protegida)
#   · 5 se agotó el tiempo.
#
# Variables opcionales: OFFICE_CODEX_ARGS y OFFICE_GEMINI_ARGS (opciones extra para codex y agy),
# OFFICE_PLUGINS_DIR (carpeta donde buscar los plugins de dev-office).
#
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]//\\//}")" && pwd)"
OFFICE_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

ROLE=""
PROVIDER=""
MODEL=""
RUN_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    -h | --help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "run-external: opción desconocida: $1" >&2; exit 1 ;;
  esac
done

usage_error() {
  echo "run-external: $1" >&2
  exit 1
}

[ -z "$ROLE" ] && usage_error "falta --role."
[ -z "$RUN_DIR" ] && usage_error "falta --run-dir."
case "$PROVIDER" in
  codex | gemini) ;;
  *) usage_error "--provider tiene que ser codex o gemini (Claude no pasa por acá)." ;;
esac
case "$MODEL" in
  *[!A-Za-z0-9._-]*) usage_error "modelo inválido: $MODEL" ;;
esac

# Binario de cada proveedor: Gemini se usa con Antigravity CLI.
case "$PROVIDER" in
  gemini) BIN="agy" ;;
  *) BIN="$PROVIDER" ;;
esac

PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && usage_error "hay que correrlo dentro del repositorio git del proyecto."
cd "$PROJECT" || exit 1

# En Windows (Git Bash), Codex y Antigravity son programas de Windows: no entienden las rutas
# de Git Bash (/c/dev/app), así que reciben las de Windows (C:/dev/app). OFFICE_OS permite
# probar el comportamiento de Windows desde otro sistema.
case "${OFFICE_OS:-${OSTYPE:-}}" in
  msys* | cygwin* | win32*) ON_WINDOWS=1 ;;
  *) ON_WINDOWS=0 ;;
esac
native_path() {
  if [ "$ON_WINDOWS" -eq 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1" | tr -d '\r'
  else
    printf '%s' "$1"
  fi
}

RUN_DIR="${RUN_DIR//\\//}"
case "$RUN_DIR" in
  /* | [A-Za-z]:/*) ;;
  *) RUN_DIR="$PROJECT/$RUN_DIR" ;;
esac
[ -f "$RUN_DIR/task.md" ] || usage_error "no existe $RUN_DIR/task.md con el encargo."

# Eventos para el observer (.office/observer/events.js). Nunca falla ni imprime.
obs_emit() {
  [ "${OFFICE_OBSERVER:-on}" = "off" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  mkdir -p "$PROJECT/.office/observer" 2>/dev/null || return 0
  local json
  json=$(jq -cn --argjson t "$(date +%s)" "$@" 2>/dev/null | tr -d '\r') || return 0
  [ -n "$json" ] && printf 'OFFICE_EVENT(%s);\n' "$json" >>"$PROJECT/.office/observer/events.js" 2>/dev/null
  return 0
}

PROMPT="$RUN_DIR/prompt.md"
OUTPUT="$RUN_DIR/output.md"
LOG="$RUN_DIR/log.txt"
SUMMARY="$RUN_DIR/summary.txt"
: >"$LOG"
rm -f "$OUTPUT"

# --- Qué puede tocar cada rol -------------------------------------------------

# write: todo el proyecto (salvo lo prohibido) · design: solo docs/design/ · qa: solo .qa/
# · none: nada (asesor del PM).
case "$ROLE" in
  pm) SCOPE="none" ;;
  qa) SCOPE="qa" ;;
  *.architect | *.designer) SCOPE="design" ;;
  *) SCOPE="write" ;;
esac

# --- Resumen ------------------------------------------------------------------

STATUS=""
STATUS_TEXT=""
DURATION=0
CHANGES=""
PROBLEMS=""

add_problem() { PROBLEMS=$(printf '%s\n- %s' "$PROBLEMS" "$1"); }

write_summary() {
  {
    echo "Proveedor: $PROVIDER${MODEL:+ · modelo: $MODEL}${EFFORT:+ · razonamiento: $EFFORT} · Rol: $ROLE${TIER:+ (nivel $TIER)}"
    echo "Resultado: $STATUS_TEXT"
    echo "Duración: ${DURATION}s"
    echo "Archivos cambiados:"
    if [ -n "$CHANGES" ]; then
      printf '%s\n' "$CHANGES" | sed 's/^/  /'
    else
      echo "  (ninguno)"
    fi
    if [ -n "$PROBLEMS" ]; then
      echo "Problemas:"
      printf '%s\n' "$PROBLEMS" | sed '/^$/d'
    fi
    [ -s "$OUTPUT" ] && echo "Reporte del proveedor: ${OUTPUT#"$PROJECT"/}"
    echo "Registro: ${LOG#"$PROJECT"/}"
  } >"$SUMMARY"
  cat "$SUMMARY"
}

finish() {
  STATUS="$1"
  STATUS_TEXT="$2"
  # Tokens: lo que informe el CLI en su salida, si lo informa (por ejemplo "tokens used: 12,345").
  local tok=""
  [ -f "$LOG" ] && tok=$(grep -oiE 'tokens used[^0-9]*[0-9][0-9,.]*' "$LOG" 2>/dev/null | tail -n1 | grep -oE '[0-9][0-9,.]*$' | tr -d ',.')
  obs_emit --arg role "$ROLE" --arg prov "$PROVIDER" --arg model "${MODEL:-}" --arg effort "${EFFORT:-}" \
    --argjson code "$STATUS" --arg text "$STATUS_TEXT" --argjson dur "${DURATION:-0}" --arg tok "$tok" \
    '{type: "external", t: $t, role: $role, provider: $prov, model: $model, effort: $effort, code: $code, result: $text, duration: $dur, tokens: (if $tok == "" then null else ($tok | tonumber) end)}'
  write_summary
  exit "$STATUS"
}

# --- Antes de correr ----------------------------------------------------------

if ! command -v "$BIN" >/dev/null 2>&1; then
  case "$PROVIDER" in
    codex) add_problem "codex no está instalado o no está en el PATH: npm install -g @openai/codex, y después codex login." ;;
    gemini) add_problem "Gemini se usa con Antigravity CLI (agy) y no está instalado o no está en el PATH. Mirá cómo instalarlo con: bash .claude/office-agents.sh check" ;;
  esac
  finish 2 "proveedor no disponible"
fi

BRANCH=$(git symbolic-ref --short -q HEAD 2>/dev/null | tr -d '\r')
PROTECTED="${OFFICE_PROTECTED_BRANCHES-main master}"
if [ -n "$BRANCH" ] && [ "$SCOPE" != "none" ]; then
  set -f
  for p in $PROTECTED; do
    # shellcheck disable=SC2254
    case "$BRANCH" in
      $p)
        set +f
        add_problem "la rama actual '$BRANCH' está protegida: no se corrió nada. Trabajá en una rama propia."
        finish 4 "rama protegida"
        ;;
    esac
  done
  set +f
fi

# Foto del estado del repositorio: una línea "ruta<TAB>hash" por archivo con cambios.
snapshot() {
  git status --porcelain -z -uall 2>/dev/null | while IFS= read -r -d '' entry; do
    local st="${entry:0:2}" path="${entry:3}" hash
    case "$st" in
      R* | C*) IFS= read -r -d '' _ ;;
    esac
    if [ -f "$path" ]; then
      hash=$(git hash-object -- "$path" 2>/dev/null | tr -d '\r')
    else
      hash="borrado"
    fi
    printf '%s\t%s\n' "$path" "$hash"
  done | sort
}

BEFORE="$RUN_DIR/.before"
AFTER="$RUN_DIR/.after"
snapshot >"$BEFORE"
HEAD_BEFORE=$(git rev-parse -q --verify HEAD 2>/dev/null | tr -d '\r')

# --- Prompt ---------------------------------------------------------------------

strip_frontmatter() {
  awk 'NR == 1 && /^---[[:space:]]*$/ { inside = 1; next }
       inside && /^---[[:space:]]*$/ { inside = 0; next }
       !inside' "$1"
}

# Skills que el rol nombra en sus instrucciones (por ejemplo `dept-backend:api-collection`).
mentioned_skills() {
  grep -oE '`(office|dept-[a-z]+):[a-z0-9-]+`' "$1" | tr -d '`\r'
}

frontmatter_skills() {
  awk 'NR == 1 && /^---/ { inside = 1; next }
       inside && /^---/ { exit }
       inside && /^skills:/ { list = 1; next }
       inside && list && /^[[:space:]]*-[[:space:]]*/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print; next }
       inside && list && /^[^[:space:]]/ { list = 0 }' "$1" | tr -d '\r'
}

# Carpeta de un plugin de dev-office. Busca, en orden: OFFICE_PLUGINS_DIR, al lado de
# office (el repositorio del marketplace) y en la caché de plugins de Claude Code
# (<marketplace>/<plugin>/<versión>/, la versión más reciente).
plugin_dir() {
  local name="$1" base found
  for base in "${OFFICE_PLUGINS_DIR:-}" "$OFFICE_ROOT/.."; do
    [ -n "$base" ] && [ -f "$base/$name/.claude-plugin/plugin.json" ] && { (cd "$base/$name" && pwd); return 0; }
  done
  found=$(ls -td "$OFFICE_ROOT/../../$name"/*/ 2>/dev/null | head -n1)
  [ -n "$found" ] && [ -f "$found/.claude-plugin/plugin.json" ] && { (cd "$found" && pwd); return 0; }
  return 1
}

ROLE_FILE=""
case "$ROLE" in
  pm) ROLE_FILE="$SKILL_DIR/roles/pm-advisor.md" ;;
  qa) ROLE_FILE="$OFFICE_ROOT/agents/qa.md" ;;
  project.*) ROLE_FILE="$PROJECT/.claude/agents/${ROLE#project.}.md" ;;
  *.*)
    DIR=$(plugin_dir "dept-${ROLE%%.*}") && ROLE_FILE="$DIR/agents/${ROLE#*.}.md"
    ;;
esac
[ -n "$ROLE_FILE" ] && [ -f "$ROLE_FILE" ] || usage_error "no encontré las instrucciones del rol '$ROLE' (¿está instalado su plugin?)."

# Nivel del rol: el modelo de Claude de su agente (los asesores del PM, como el PM: opus).
if [ "$ROLE" = "pm" ]; then
  TIER="opus"
else
  TIER=$(awk 'NR == 1 && /^---/ { inside = 1; next } inside && /^---/ { exit }
              inside && /^model:/ { sub(/^model:[[:space:]]*/, ""); print; exit }' "$ROLE_FILE" | tr -d '\r "')
fi
case "$TIER" in opus | sonnet | haiku) ;; *) TIER="sonnet" ;; esac

# Modelo y razonamiento: los de la tabla de office-agents.sh (la del proyecto, si la cambió),
# salvo que el rol traiga un modelo propio.
AGENTS_SCRIPT="$OFFICE_ROOT/skills/office-agents/office-agents.sh"
EFFORT=""
if [ -f "$AGENTS_SCRIPT" ]; then
  [ -z "$MODEL" ] && MODEL=$(bash "$AGENTS_SCRIPT" --project "$PROJECT" model "$PROVIDER" "$TIER" 2>>"$LOG" | tr -d '\r')
  EFFORT=$(bash "$AGENTS_SCRIPT" --project "$PROJECT" effort "$PROVIDER" 2>>"$LOG" | tr -d '\r')
fi
case "$MODEL" in *[!A-Za-z0-9._-]*) usage_error "modelo inválido en la tabla: $MODEL" ;; esac
case "$EFFORT" in *[!a-z]*) EFFORT="" ;; esac

provider_rules() {
  cat <<'EOF'
## Reglas de la oficina para este encargo

Trabajás para la oficina de desarrollo dev-office, en lugar de un agente de Claude Code. Estas reglas mandan sobre todo lo demás:

- **Nunca** hagas commits, push, merge, rebase, stash ni cambies de rama. No toques la carpeta `.git`.
- **Nunca** leas ni modifiques archivos de secretos (`.env` y sus variantes; las plantillas `.env.example` sí), claves privadas (`*.pem`, `*.key`, `id_rsa`, `id_ed25519`) ni lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, `bun.lockb`).
- No instales dependencias ni hagas pedidos de red.
- No escribas en la carpeta `.office/`: es de la oficina.
- Las instrucciones de tu rol nombran herramientas de Claude Code (Read, Grep, Glob, Edit, Write, Bash, Skill, Agent): usá las tuyas equivalentes. Las skills que esas instrucciones nombran están copiadas más abajo, con la carpeta de sus archivos.
- Si algo del encargo necesita una de las acciones prohibidas, no la hagas: explicalo al final de tu reporte con "Necesito aprobación".
- Tu **último mensaje** es tu reporte al PM, en el idioma del proyecto y con el formato que piden las instrucciones de tu rol. No escribas nada después del reporte.
EOF
  case "$SCOPE" in
    none) echo "- **Solo leés.** No crees, edites ni borres archivos, y no corras comandos que cambien algo." ;;
    qa) echo "- Solo podés escribir dentro de \`.qa/\`." ;;
    design) echo "- Solo podés escribir dentro de \`docs/design/\`." ;;
  esac
  case "$PROVIDER" in
    gemini)
      echo "- No corras comandos de la terminal, ni siquiera para listar o buscar archivos: acá se rechazan solos. Para leer, listar y buscar en el proyecto usá tus herramientas de archivos."
      [ "$SCOPE" != "none" ] && echo "- En este modo podés editar archivos, pero no correr comandos de la terminal. No corras tests, typecheck ni lint: el agente de la oficina los corre después de vos. En tu reporte, en la parte de verificación, poné \"La corre la oficina\"."
      ;;
    codex)
      echo "- Trabajás en un sandbox sin red. Si un comando falla por falta de red, no insistas: decilo en el reporte."
      ;;
  esac
}

{
  echo "# Encargo de la oficina dev-office"
  echo
  echo "Rol: \`$ROLE\` · Proyecto: la carpeta actual · Rama: \`${BRANCH:-sin rama}\`"
  echo
  provider_rules
  echo
  echo "## Instrucciones de tu rol"
  echo
  strip_frontmatter "$ROLE_FILE"
  # Las que precarga y las que nombra, sin repetir. Las de office (start-ticket, open-pr...)
  # son del PM y no se copian.
  SKILLS=$({ frontmatter_skills "$ROLE_FILE"; mentioned_skills "$ROLE_FILE"; } | grep -v '^office:' | awk 'NF && !seen[$0]++')
  if [ -n "$SKILLS" ]; then
    echo
    echo "## Skills de tu rol"
    while IFS= read -r skill; do
      [ -z "$skill" ] && continue
      plugin="${skill%%:*}"
      name="${skill#*:}"
      PDIR=$(plugin_dir "$plugin") || PDIR=""
      SKILL_FILE="$PDIR/skills/$name/SKILL.md"
      echo
      if [ -n "$PDIR" ] && [ -f "$SKILL_FILE" ]; then
        echo "### Skill $skill"
        echo
        echo "(Los archivos de esta skill están en \`$(native_path "$PDIR/skills/$name")/\`.)"
        echo
        strip_frontmatter "$SKILL_FILE"
      else
        echo "### Skill $skill: no se encontró; seguí las instrucciones del rol."
      fi
    done <<EOF
$SKILLS
EOF
  fi
  echo
  echo "## El encargo del PM"
  echo
  cat "$RUN_DIR/task.md"
} | tr -d '\r' >"$PROMPT"

# --- Correr el proveedor -----------------------------------------------------------

TIMEOUT="${OFFICE_EXTERNAL_TIMEOUT:-540}"
case "$TIMEOUT" in '' | *[!0-9]*) TIMEOUT=540 ;; esac

STDOUT_FILE="$RUN_DIR/.stdout"
STDIN_FILE="$PROMPT"
case "$PROVIDER" in
  codex)
    SANDBOX="workspace-write"
    [ "$SCOPE" = "none" ] && SANDBOX="read-only"
    # En Windows, el sandbox propio de Codex viene apagado y entonces rechaza hasta los comandos
    # de lectura ("blocked by policy"). El modo unelevated lo prende sin pedir permisos de
    # administrador. OFFICE_CODEX_ARGS va después, así que lo puede cambiar.
    WIN_ARGS=()
    [ "$ON_WINDOWS" -eq 1 ] && WIN_ARGS=(-c 'windows.sandbox="unelevated"')
    # shellcheck disable=SC2206 # las opciones extra se separan por espacios a propósito
    CMD=(codex -a never exec -s "$SANDBOX" --skip-git-repo-check -C "$(native_path "$PROJECT")" -o "$(native_path "$OUTPUT")"
      ${MODEL:+-m "$MODEL"} ${EFFORT:+-c "model_reasoning_effort=\"$EFFORT\""} ${WIN_ARGS[@]+"${WIN_ARGS[@]}"} ${OFFICE_CODEX_ARGS:-} -)
    ;;
  gemini)
    # Antigravity CLI: el encargo es largo, así que se le pide que lo lea del archivo.
    # accept-edits edita sin preguntar; los comandos de la terminal quedan sin aprobar.
    # El asesor del PM corre en el modo normal: lo que necesita aprobación se niega solo.
    MODE_ARGS=(--mode accept-edits)
    [ "$SCOPE" = "none" ] && MODE_ARGS=()
    STDIN_FILE=/dev/null
    # La carpeta del proyecto como espacio de trabajo, si esta versión de agy lo permite.
    DIR_ARGS=()
    "$BIN" --help 2>&1 | grep -q -- '--add-dir' && DIR_ARGS=(--add-dir "$(native_path "$PROJECT")")
    # shellcheck disable=SC2206
    CMD=(agy -p "Tu encargo completo está en el archivo ${PROMPT#"$PROJECT"/}. Leelo entero antes de empezar y seguilo al pie de la letra."
      ${MODE_ARGS[@]+"${MODE_ARGS[@]}"} ${DIR_ARGS[@]+"${DIR_ARGS[@]}"} ${MODEL:+--model "$MODEL"} ${EFFORT:+--effort "$EFFORT"}
      --output-format text --print-timeout "$(( TIMEOUT / 60 + 1 ))m" ${OFFICE_GEMINI_ARGS:-})
    ;;
esac

echo "\$ ${CMD[*]} < ${STDIN_FILE#"$PROJECT"/}" >>"$LOG"
obs_emit --arg role "$ROLE" --arg prov "$PROVIDER" --arg model "${MODEL:-}" --arg effort "${EFFORT:-}" \
  '{type: "external_start", t: $t, role: $role, provider: $prov, model: $model, effort: $effort}'
START=$(date +%s)
"${CMD[@]}" <"$STDIN_FILE" >"$STDOUT_FILE" 2>>"$LOG" &
PID=$!
TIMED_OUT=0
while kill -0 "$PID" 2>/dev/null; do
  if [ $(( $(date +%s) - START )) -ge "$TIMEOUT" ]; then
    TIMED_OUT=1
    kill "$PID" 2>/dev/null
    sleep 2
    kill -9 "$PID" 2>/dev/null
    break
  fi
  sleep 1
done
wait "$PID" 2>/dev/null
RC=$?
DURATION=$(( $(date +%s) - START ))
echo "(código de salida: $RC)" >>"$LOG"

# Antigravity escribe el reporte en la salida estándar; Codex, en el archivo de -o.
if [ ! -s "$OUTPUT" ] && [ -s "$STDOUT_FILE" ]; then
  tr -d '\r' <"$STDOUT_FILE" >"$OUTPUT"
elif [ -s "$STDOUT_FILE" ]; then
  { echo "--- salida estándar ---"; cat "$STDOUT_FILE"; } >>"$LOG"
fi
rm -f "$STDOUT_FILE"

# --- Revisar lo que cambió ----------------------------------------------------

snapshot >"$AFTER"
HEAD_AFTER=$(git rev-parse -q --verify HEAD 2>/dev/null | tr -d '\r')
BRANCH_AFTER=$(git symbolic-ref --short -q HEAD 2>/dev/null | tr -d '\r')

CHANGED=$(awk -F'\t' 'NR == FNR { before[$1] = $2; next }
  { seen[$1] = 1; if (!($1 in before) || before[$1] != $2) print $1 }
  END { for (p in before) if (!(p in seen)) print p }' "$BEFORE" "$AFTER")
# Si commiteó, los archivos del commit quedaron limpios: se suman para revisarlos igual.
if [ -n "$HEAD_AFTER" ] && [ "$HEAD_AFTER" != "$HEAD_BEFORE" ]; then
  if [ -n "$HEAD_BEFORE" ]; then
    COMMITTED=$(git diff --name-only "$HEAD_BEFORE" "$HEAD_AFTER" 2>/dev/null | tr -d '\r')
  else
    COMMITTED=$(git show --pretty=format: --name-only "$HEAD_AFTER" 2>/dev/null | tr -d '\r')
  fi
  CHANGED=$(printf '%s\n%s\n' "$CHANGED" "$COMMITTED")
fi
CHANGED=$(printf '%s\n' "$CHANGED" | sed '/^$/d' | sort -u)
rm -f "$BEFORE" "$AFTER"

forbidden_reason() {
  local name="${1##*/}"
  case "$name" in
    .env.example | .env.sample | .env.template) ;;
    .env | .env.*) echo "es un archivo de secretos"; return ;;
    *.pem | *.key | id_rsa | id_ed25519) echo "es una clave privada"; return ;;
    package-lock.json | pnpm-lock.yaml | yarn.lock | bun.lockb | bun.lock) echo "es un lockfile"; return ;;
  esac
  case "$1" in
    .git/*) echo "es interno de git" ;;
  esac
}

if [ -n "$CHANGED" ]; then
  while IFS= read -r path; do
    case "$path" in
      .office/*) continue ;;
      .qa/*) [ "$SCOPE" = "qa" ] && continue ;;
    esac
    if [ ! -e "$path" ]; then
      mark="D"
    elif [ -n "$HEAD_BEFORE" ] && git cat-file -e "$HEAD_BEFORE:$path" 2>/dev/null; then
      mark="M"
    else
      mark="A"
    fi
    CHANGES=$(printf '%s\n%s %s' "$CHANGES" "$mark" "$path")

    reason=$(forbidden_reason "$path")
    [ -n "$reason" ] && add_problem "tocó $path, que $reason."
    case "$SCOPE" in
      none) add_problem "tocó $path y el rol solo puede leer." ;;
      qa) add_problem "tocó $path y el QA solo puede escribir en .qa/." ;;
      design)
        case "$path" in
          docs/design/*) ;;
          *) add_problem "tocó $path y el rol solo puede escribir en docs/design/." ;;
        esac
        ;;
    esac
  done <<EOF
$CHANGED
EOF
  CHANGES=$(printf '%s\n' "$CHANGES" | sed '/^$/d')
fi

[ "$HEAD_AFTER" != "$HEAD_BEFORE" ] && add_problem "hizo un commit o movió HEAD (antes ${HEAD_BEFORE:-ninguno}, ahora ${HEAD_AFTER:-ninguno})."
[ "$BRANCH_AFTER" != "$BRANCH" ] && add_problem "cambió de rama: de '${BRANCH:-ninguna}' a '${BRANCH_AFTER:-ninguna}'."

# --- Resultado ----------------------------------------------------------------

[ -n "$PROBLEMS" ] && finish 4 "se rompieron reglas de la oficina"

if [ "$TIMED_OUT" -eq 1 ]; then
  add_problem "se cortó a los ${TIMEOUT}s (OFFICE_EXTERNAL_TIMEOUT). Conviene dividir el encargo."
  finish 5 "tiempo agotado"
fi

# Mensajes típicos de sesión, credenciales o cuota (sin \b, que el grep de macOS no siempre entiende).
UNAVAILABLE_PATTERN='not logged in|please log ?in|codex login|authentication required|sign in|unauthori[sz]ed|(^|[^0-9])401([^0-9]|$)|invalid api key|api key not|missing api key|quota|rate.?limit|(^|[^0-9])429([^0-9]|$)|usage limit|resource.?exhausted|insufficient.?(credit|quota|balance)|billing'
MODEL_PATTERN='unknown model|invalid model|model not found|model .*not (available|supported|found)|does not have access to (the )?model'
if [ "$RC" -ne 0 ]; then
  if [ -n "$MODEL" ] && grep -qiE "$MODEL_PATTERN" "$LOG"; then
    add_problem "$PROVIDER no tiene el modelo '$MODEL' para esta cuenta. Elegí otro con: bash .claude/office-agents.sh tier $PROVIDER $TIER <modelo> (o en el rol: $PROVIDER:<modelo>)."
    finish 2 "proveedor no disponible"
  fi
  if grep -qiE "$UNAVAILABLE_PATTERN" "$LOG"; then
    add_problem "$PROVIDER no está disponible (sesión, credenciales o cuota). Mirá el registro: ${LOG#"$PROJECT"/}"
    finish 2 "proveedor no disponible"
  fi
  add_problem "$PROVIDER terminó con código $RC. Mirá el registro: ${LOG#"$PROJECT"/}"
  finish 3 "el proveedor falló"
fi

if [ ! -s "$OUTPUT" ]; then
  add_problem "$PROVIDER terminó sin devolver un reporte."
  finish 3 "el proveedor falló"
fi

finish 0 "terminó bien"
