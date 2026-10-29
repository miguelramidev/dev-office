#!/usr/bin/env bash
# Pruebas del script que corre encargos con Codex o Gemini (Antigravity CLI)
# (plugins/office/skills/external-agents/run-external.sh).
# Usa CLIs falsos de codex y agy que hacen lo que diga FAKE_MODE, en un proyecto de
# prueba, y compara el código de salida y el resumen. Uso: bash tests/run-external.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$REPO/plugins/office/skills/external-agents/run-external.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

# --- CLIs falsos --------------------------------------------------------------

FAKE_BIN="$WORK/bin"
# La configuración de Antigravity de estas pruebas (no la de quien las corre).
export OFFICE_GEMINI_CONFIG="$WORK/gemini/config.json"
mkdir -p "$FAKE_BIN"
export FAKE_ARGS="$WORK/fake-args.txt"
export FAKE_STDIN="$WORK/fake-stdin.txt"

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FAKE_ARGS"
OUT=""
while [ $# -gt 0 ]; do
  [ "$1" = "-o" ] && OUT="$2"
  shift
done
cat >"$FAKE_STDIN"
report() { [ -n "$OUT" ] && printf 'Hecho: listo.\n' >"$OUT"; }
case "${FAKE_MODE:-ok}" in
  ok) echo "// cambio" >>src/app.ts; report ;;
  env) echo "SECRET=1" >.env; report ;;
  lock) echo '{"lockfileVersion": 3}' >package-lock.json; report ;;
  commit) echo "// cambio" >>src/app.ts; git add -A; git commit -qm "x"; report ;;
  commit-env) echo "SECRET=1" >.env; git add -A; git commit -qm "x"; report ;;
  branch) git switch -qc otra; report ;;
  design) mkdir -p docs/design; echo "# Diseño" >docs/design/tema.md; report ;;
  qa-ok) mkdir -p .qa; echo "ataque" >.qa/ataque.test.ts; report ;;
  qa-bad) echo "// arreglo" >>src/app.ts; report ;;
  delete) rm src/util.ts; report ;;
  noop) report ;;
  noreport) ;;
  auth) echo "Error: Not logged in. Run 'codex login'." >&2; exit 1 ;;
  crash) echo "panic: algo se rompió" >&2; exit 2 ;;
  sleep) sleep 10; report ;;
  tokens) echo "// cambio" >>src/app.ts; echo "tokens used: 12,345" >&2; report ;;
esac
exit 0
EOF

# agy (Antigravity CLI): el encargo se lee del archivo que nombra el -p.
cat >"$FAKE_BIN/agy" <<'EOF'
#!/usr/bin/env bash
# La ayuda nombra --add-dir solo si FAKE_AGY_HELP lo trae (versiones nuevas de agy).
[ "$1" = "--help" ] && { printf '%s\n' "${FAKE_AGY_HELP:-}"; exit 0; }
printf '%s\n' "$*" >"$FAKE_ARGS"
PROMPT_FILE=$(printf '%s' "$2" | grep -oE '\.office/[^ ]+prompt\.md')
[ -n "$PROMPT_FILE" ] && cp "$PROMPT_FILE" "$FAKE_STDIN"
# Con --output-format stream-json, un evento JSON por línea (como Antigravity 1.3).
step() { local err=""; [ -n "${5:-}" ] && err=',"error":{"type":"TOOL_ERROR","message":"'"$5"'"}'; printf '{"event":"step_update","step_update":{"conversation_id":"c1","step_index":%s,"state":"%s","step_type":"tool","tool_name":"%s","tool_info":{"name":"%s","parameters":%s%s}}}\n' "$1" "$2" "$3" "$3" "$4" "$err"; }
result() { printf '{"event":"result","result":{"conversation_id":"c1","status":"SUCCESS","response":"%s","num_turns":1,"usage":{"input_tokens":6802,"output_tokens":115,"thinking_tokens":55,"total_tokens":%s}}}\n' "$1" "${2:-6917}"; }
case "${FAKE_MODE:-ok}" in
  ok)
    echo '{"event":"init","conversation_id":"c1","init":{"cwd":"x","tools":["view_file"]}}'
    step 2 DONE view_file '{"AbsolutePath":"src/app.ts"}'
    echo "// cambio" >>src/app.ts
    step 3 DONE replace_file_content '{"TargetFile":"src/app.ts"}'
    result "Hecho: listo." ;;
  noop) result "Hecho: nada que cambiar." ;;
  denied)
    step 2 ERROR run_command '{"CommandLine":"Remove-Item -Path \"src/old.ts\""}' 'permission check failed for unsandboxed \"Remove-Item\": user denied permission to run command:\nRemove-Item -Path src/old.ts'
    echo 'jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.' >&2
    result "" ;;
  gitrm)
    git rm -q src/util.ts
    step 2 DONE run_command '{"CommandLine":"git rm src/util.ts"}'
    result "Hecho: borré src/util.ts." ;;
  silent) ;;
  auth) echo "Error: authentication required. Run agy to sign in." >&2; exit 1 ;;
  badmodel) echo "ERROR: unknown model 'gemini-4-argon'" >&2; exit 1 ;;
esac
exit 0
EOF
# cygpath de Git Bash, para probar Windows: anota cada ruta que convierte y la devuelve igual
# (una ruta C:/... no existiría en este sistema).
export FAKE_CYGPATH="$WORK/cygpath.txt"
cat >"$FAKE_BIN/cygpath" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_CYGPATH"
printf '%s\n' "$2"
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/agy" "$FAKE_BIN/cygpath"

# PATH sin codex ni agy reales, para que las pruebas no dependan de lo instalado.
CLEAN_PATH=""
IFS=':' read -r -a PATH_DIRS <<<"$PATH"
for d in "${PATH_DIRS[@]}"; do
  [ -x "$d/codex" ] || [ -x "$d/agy" ] && continue
  CLEAN_PATH="${CLEAN_PATH:+$CLEAN_PATH:}$d"
done
export PATH="$FAKE_BIN:$CLEAN_PATH"

# --- Proyecto de prueba -------------------------------------------------------

# Arma un proyecto nuevo en la rama feature/PROJ-123 y deja la ruta en $PROJ.
N=0
new_project() {
  N=$((N + 1))
  PROJ="$WORK/proj$N"
  mkdir -p "$PROJ/src" "$PROJ/.claude/agents"
  (
    cd "$PROJ" || exit 1
    git init -q -b main
    git config user.email test@example.com
    git config user.name Test
    echo "export const a = 1;" >src/app.ts
    echo "export const b = 2;" >src/util.ts
    echo "{}" >package-lock.json
    printf -- '---\nname: seo\n---\n\nSos el especialista de SEO del proyecto.\n' >.claude/agents/seo.md
    git add -A
    git commit -qm init
    git switch -qc feature/PROJ-123-algo
    mkdir -p .office/runs/r1
    echo "Objetivo: agregar el endpoint de pedidos." >.office/runs/r1/task.md
  )
  rm -f "$FAKE_ARGS" "$FAKE_STDIN" "$FAKE_CYGPATH"
}

# check <código esperado> <descripción> <rol> <proveedor> [opciones extra del runner]
check() {
  local expected="$1" description="$2" role="$3" provider="$4"
  shift 4
  (cd "$PROJ" && bash "$RUNNER" --role "$role" --provider "$provider" --run-dir .office/runs/r1 "$@") >"$WORK/out.txt" 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "ok    $description"
  else
    echo "FALLA $description (esperado $expected, salió $actual)"
    sed 's/^/      /' "$WORK/out.txt"
    FAILED=1
  fi
}

# expect <archivo> <texto> <descripción>: el archivo contiene el texto.
expect() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then
    echo "ok    $3"
  else
    echo "FALLA $3 (no aparece \"$2\" en ${1##*/})"
    FAILED=1
  fi
}

# expect_not <archivo> <texto> <descripción>
expect_not() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then
    echo "FALLA $3 (aparece \"$2\" en ${1##*/})"
    FAILED=1
  else
    echo "ok    $3"
  fi
}

# --- Codex ----------------------------------------------------------------------

new_project
FAKE_MODE=ok check 0 "codex: developer que cambia código" backend.developer codex
expect "$WORK/out.txt" "M src/app.ts" "codex: el resumen lista el archivo cambiado"
expect "$FAKE_ARGS" "exec -s workspace-write" "codex: corre con sandbox workspace-write"
expect "$FAKE_ARGS" "-a never" "codex: sin pedir aprobación"
expect "$FAKE_STDIN" "Sos el developer del departamento de backend" "prompt: incluye las instrucciones del rol"
expect "$FAKE_STDIN" "### Skill dept-backend:solid-backend" "prompt: incluye las skills del rol"
expect "$FAKE_STDIN" "Objetivo: agregar el endpoint de pedidos." "prompt: incluye el encargo"
expect "$FAKE_STDIN" "**Nunca** hagas commits" "prompt: incluye las reglas de la oficina"
expect_not "$FAKE_STDIN" "model: sonnet" "prompt: sin el frontmatter del agente"
expect "$FAKE_STDIN" "### Skill dept-backend:api-collection" "prompt: incluye las skills que el rol nombra"
expect_not "$FAKE_STDIN" "### Skill office:" "prompt: no copia las skills del PM"
expect "$PROJ/.office/runs/r1/output.md" "Hecho: listo." "codex: guarda el reporte"
expect "$PROJ/.office/observer/events.js" '"type":"external_start","t":' "observer: anota el inicio"
expect "$PROJ/.office/observer/events.js" '"role":"backend.developer","provider":"codex","model":"gpt-6.1-sol"' "observer: anota rol, proveedor y modelo"
expect "$PROJ/.office/observer/events.js" '"type":"external"' "observer: anota el final"

expect "$FAKE_ARGS" "-m gpt-6.1-sol" "codex: developer (nivel sonnet) usa gpt-6.1-sol"
expect "$FAKE_ARGS" 'model_reasoning_effort="medium"' "codex: razonamiento medio"
expect "$WORK/out.txt" "(nivel sonnet)" "el resumen dice el nivel"

new_project
FAKE_MODE=qa-ok check 0 "codex: QA (nivel opus)" qa codex
expect "$FAKE_ARGS" "-m gpt-6-astra" "codex: QA usa gpt-6-astra"

new_project
FAKE_MODE=design check 0 "codex: arquitecto (nivel opus)" backend.architect codex
expect "$FAKE_ARGS" "-m gpt-6-astra" "codex: arquitecto usa gpt-6-astra"

new_project
FAKE_MODE=ok check 0 "codex: con modelo" backend.developer codex --model gpt-x
expect "$FAKE_ARGS" "-m gpt-x" "codex: el modelo del rol manda sobre la tabla"

new_project
printf '{"models": {"codex": {"sonnet": "gpt-otro", "effort": "low"}}}' >"$PROJ/.claude/office-agents.json"
FAKE_MODE=ok check 0 "codex: tabla cambiada en el proyecto" backend.developer codex
expect "$FAKE_ARGS" "-m gpt-otro" "codex: usa el modelo de la tabla del proyecto"
expect "$FAKE_ARGS" 'model_reasoning_effort="low"' "codex: usa el razonamiento de la tabla del proyecto"

new_project
echo "// cambio del CEO" >>"$PROJ/src/util.ts"
FAKE_MODE=ok check 0 "un archivo que ya tenía cambios y no se tocó" backend.developer codex
expect_not "$WORK/out.txt" "src/util.ts" "no aparece en los cambios"

new_project
FAKE_MODE=delete check 0 "borrar un archivo" backend.developer codex
expect "$WORK/out.txt" "D src/util.ts" "se marca como borrado"

# Reglas
new_project
FAKE_MODE=env check 4 "tocar .env" backend.developer codex
expect "$WORK/out.txt" "es un archivo de secretos" "dice por qué"

new_project
FAKE_MODE=lock check 4 "tocar un lockfile" backend.developer codex

new_project
FAKE_MODE=commit check 4 "hacer un commit" backend.developer codex
expect "$WORK/out.txt" "hizo un commit" "dice que commiteó"

new_project
FAKE_MODE=commit-env check 4 "commitear un .env" backend.developer codex
expect "$WORK/out.txt" "tocó .env" "revisa los archivos del commit"

new_project
FAKE_MODE=branch check 4 "cambiar de rama" backend.developer codex

new_project
FAKE_MODE=design check 0 "arquitecto que escribe en docs/design/" backend.architect codex
new_project
FAKE_MODE=ok check 4 "arquitecto que escribe código" backend.architect codex
new_project
FAKE_MODE=ok check 4 "designer que escribe código" frontend.designer codex

new_project
FAKE_MODE=qa-ok check 0 "QA que escribe en .qa/" qa codex
expect_not "$WORK/out.txt" ".qa/ataque" "lo de .qa/ no cuenta como cambio del QA"
expect "$FAKE_STDIN" "Sos el QA de la oficina" "prompt del QA"
new_project
FAKE_MODE=qa-bad check 4 "QA que corrige código" qa codex

new_project
FAKE_MODE=noop check 0 "asesor del PM" pm codex
expect "$FAKE_ARGS" "-s read-only" "asesor: codex en solo lectura"
expect "$FAKE_ARGS" "-m gpt-6-astra" "asesor: nivel opus"
expect "$FAKE_STDIN" "Sos asesor del PM" "asesor: su prompt"
new_project
FAKE_MODE=ok check 4 "asesor del PM que edita" pm codex

new_project
FAKE_MODE=ok check 0 "agente propio del proyecto" project.seo codex
expect "$FAKE_STDIN" "Sos el especialista de SEO" "prompt del agente del proyecto"

# Fallas del proveedor
new_project
FAKE_MODE=auth check 2 "codex sin sesión" backend.developer codex
new_project
FAKE_MODE=tokens check 0 "codex informa tokens" backend.developer codex
expect "$PROJ/.office/observer/events.js" '"tokens":12345' "observer: toma los tokens que informa el CLI"
new_project
FAKE_MODE=ok OFFICE_OBSERVER=off check 0 "observer desactivado" backend.developer codex
if [ -f "$PROJ/.office/observer/events.js" ]; then echo "FALLA observer desactivado: escribió eventos"; FAILED=1; else echo "ok    observer desactivado: no escribe eventos"; fi

new_project
FAKE_MODE=crash check 3 "codex falla" backend.developer codex
new_project
FAKE_MODE=noreport check 3 "codex sin reporte" backend.developer codex
new_project
FAKE_MODE=sleep OFFICE_EXTERNAL_TIMEOUT=2 check 5 "tiempo agotado" backend.developer codex

# Antes de correr
new_project
(cd "$PROJ" && git switch -q main)
FAKE_MODE=ok check 4 "rama protegida: no corre nada" backend.developer codex
if [ -f "$FAKE_ARGS" ]; then echo "FALLA rama protegida: el CLI se ejecutó"; FAILED=1; else echo "ok    rama protegida: el CLI no se ejecutó"; fi

new_project
(cd "$PROJ" && git switch -q main)
FAKE_MODE=ok OFFICE_PROTECTED_BRANCHES="dev" check 0 "main sin proteger si el proyecto no lo protege" backend.developer codex

new_project
SAVED_PATH="$PATH"
export PATH="$CLEAN_PATH"
check 2 "codex no instalado" backend.developer codex
export PATH="$SAVED_PATH"

new_project
check 1 "rol desconocido" ventas.developer codex
new_project
check 1 "proveedor inválido" backend.developer claude
new_project
rm "$PROJ/.office/runs/r1/task.md"
check 1 "sin task.md" backend.developer codex

# --- Gemini (Antigravity CLI) -------------------------------------------------

new_project
FAKE_MODE=ok check 0 "gemini: developer" frontend.developer gemini
expect "$FAKE_ARGS" "--mode accept-edits" "gemini: edita sin preguntar"
expect "$FAKE_ARGS" "--model gemini-3.8-flash" "gemini: developer (nivel sonnet) usa gemini-3.8-flash"
expect "$FAKE_ARGS" "--effort medium" "gemini: razonamiento medio"
expect "$FAKE_ARGS" "--print-timeout 10m" "gemini: el tope de agy queda por encima del de la oficina"
expect "$FAKE_ARGS" ".office/runs/r1/prompt.md" "gemini: se le pide leer el encargo del archivo"
expect "$FAKE_STDIN" "Sos el developer del departamento de frontend" "gemini: el archivo tiene las instrucciones del rol"
expect "$FAKE_STDIN" "no correr comandos" "gemini: el prompt le avisa que no corre comandos"
expect "$PROJ/.office/runs/r1/output.md" "Hecho: listo." "gemini: guarda la salida como reporte"

new_project
FAKE_MODE=ok check 0 "gemini: con modelo" frontend.developer gemini --model gemini-3.1-pro-preview
expect "$FAKE_ARGS" "--model gemini-3.1-pro-preview" "gemini: el modelo del rol manda"

new_project
FAKE_MODE=noop check 0 "gemini: asesor del PM" pm gemini
expect_not "$FAKE_ARGS" "--mode accept-edits" "gemini: asesor en el modo normal (sin aprobar ediciones)"
expect "$FAKE_ARGS" "--model gemini-4-argon" "gemini: asesor (nivel opus) usa gemini-4-argon"

new_project
FAKE_MODE=auth check 2 "gemini sin sesión" frontend.developer gemini
new_project
FAKE_MODE=badmodel check 2 "gemini sin el modelo en la cuenta" qa gemini
expect "$WORK/out.txt" "tier gemini opus" "dice cómo elegir otro modelo"
new_project
FAKE_MODE=silent check 3 "gemini sin respuesta" frontend.developer gemini
new_project
SAVED_PATH="$PATH"
export PATH="$CLEAN_PATH"
check 2 "agy no instalado" frontend.developer gemini
expect "$WORK/out.txt" "Antigravity" "dice que Gemini se usa con Antigravity"
export PATH="$SAVED_PATH"

# --- Windows: sandbox de Codex, rutas y carpeta de Antigravity ----------------------

new_project
FAKE_MODE=ok check 0 "codex en Linux o macOS" backend.developer codex
expect_not "$FAKE_ARGS" "windows.sandbox" "codex: fuera de Windows no toca el sandbox de Windows"
[ ! -s "$FAKE_CYGPATH" ] && echo "ok    fuera de Windows no convierte rutas" || { echo "FALLA fuera de Windows no convierte rutas"; FAILED=1; }
new_project
OFFICE_OS=msys FAKE_MODE=ok check 0 "codex en Windows" backend.developer codex
expect "$FAKE_ARGS" 'windows.sandbox="unelevated"' "codex: en Windows prende su sandbox sin permisos de administrador"
expect "$FAKE_CYGPATH" "-m $PROJ" "codex: en Windows la carpeta del proyecto pasa a formato de Windows"
expect "$FAKE_CYGPATH" "-m $PROJ/.office/runs/r1/output.md" "codex: en Windows la ruta del reporte pasa a formato de Windows"
expect "$FAKE_STDIN" "están en \`.office/runs/r1/skills/dept-backend/solid-backend/\`, dentro del proyecto" "prompt: las skills apuntan a su copia dentro del proyecto"
[ -f "$PROJ/.office/runs/r1/skills/dept-backend/solid-backend/SKILL.md" ] && echo "ok    las skills del rol se copian dentro de la corrida" || { echo "FALLA las skills del rol se copian dentro de la corrida"; FAILED=1; }
new_project
OFFICE_OS=msys OFFICE_CODEX_ARGS='-c windows.sandbox="elevated"' FAKE_MODE=ok check 0 "codex en Windows con opciones propias" backend.developer codex
expect "$FAKE_ARGS" 'windows.sandbox="unelevated" -c windows.sandbox="elevated"' "codex: las opciones propias van después y mandan"

new_project
FAKE_MODE=ok check 0 "gemini: agy sin --add-dir" frontend.developer gemini
expect_not "$FAKE_ARGS" "--add-dir" "gemini: si agy no lo tiene, no le pasa --add-dir"
expect "$FAKE_STDIN" "ni siquiera para listar o buscar archivos" "gemini: el prompt le pide usar sus herramientas de archivos"
expect "$FAKE_STDIN" "No le pases trabajo a subagentes" "gemini: el prompt le pide no delegar en subagentes"
expect "$FAKE_STDIN" "No recorras \`node_modules\`" "gemini: el prompt le pide no recorrer node_modules"
new_project
FAKE_AGY_HELP="  --add-dir <dir>  Add a directory to the workspace" FAKE_MODE=ok check 0 "gemini: agy con --add-dir" frontend.developer gemini
expect "$FAKE_ARGS" "--add-dir $PROJ" "gemini: le pasa la carpeta del proyecto actual"
new_project
OFFICE_OS=msys FAKE_AGY_HELP="--add-dir" FAKE_MODE=ok check 0 "gemini en Windows" frontend.developer gemini
expect "$FAKE_CYGPATH" "-m $PROJ" "gemini: en Windows la carpeta pasa a formato de Windows"
new_project
FAKE_MODE=noop check 0 "gemini: asesor sin comandos" pm gemini
expect "$FAKE_STDIN" "ni siquiera para listar o buscar archivos" "gemini: el asesor también usa sus herramientas de archivos"

# --- Caché de plugins con varias versiones -----------------------------------------
# Como en ~/.claude/plugins/cache/<marketplace>/<plugin>/<versión>/: se usa la versión más
# nueva por número, aunque una vieja se haya modificado después.
CACHE="$WORK/cache/dev-office"
mkdir -p "$CACHE/office" "$CACHE/dept-backend"
cp -R "$REPO/plugins/office" "$CACHE/office/9.0.0"
cp -R "$REPO/plugins/dept-backend" "$CACHE/dept-backend/0.10.0"
cp -R "$REPO/plugins/dept-backend" "$CACHE/dept-backend/0.9.0"
printf '\nMARCA-VERSION-NUEVA\n' >>"$CACHE/dept-backend/0.10.0/agents/developer.md"
printf '\nMARCA-VERSION-VIEJA\n' >>"$CACHE/dept-backend/0.9.0/agents/developer.md"
touch "$CACHE/dept-backend/0.9.0"
new_project
(cd "$PROJ" && FAKE_MODE=ok bash "$CACHE/office/9.0.0/skills/external-agents/run-external.sh" --role backend.developer --provider codex --run-dir .office/runs/r1) >"$WORK/out.txt" 2>&1
expect "$FAKE_STDIN" "MARCA-VERSION-NUEVA" "caché: usa la versión más nueva del plugin (0.10.0 > 0.9.0)"
expect_not "$FAKE_STDIN" "MARCA-VERSION-VIEJA" "caché: no usa la carpeta vieja aunque se haya modificado después"

# --- Permisos de comandos de Gemini ---------------------------------------------------

new_project
FAKE_MODE=ok check 0 "gemini sin permisos de comandos" frontend.developer gemini
expect "$FAKE_STDIN" "La corre la oficina" "gemini sin permisos: la verificación la corre la oficina"
expect_not "$FAKE_STDIN" "Solo podés correr estos comandos" "gemini sin permisos: no le ofrece comandos"
bash "$REPO/plugins/office/skills/office-agents/office-agents.sh" gemini-permissions on >/dev/null
new_project
FAKE_MODE=ok check 0 "gemini con permisos de comandos" frontend.developer gemini
expect "$FAKE_STDIN" "Solo podés correr estos comandos, de a uno y sin encadenarlos" "gemini con permisos: sabe qué comandos puede correr"
expect "$FAKE_STDIN" "poné el resultado real en tu reporte" "gemini con permisos: corre sus verificaciones"
expect_not "$FAKE_STDIN" "La corre la oficina" "gemini con permisos: ya no dice que la corre la oficina"
new_project
FAKE_MODE=ok check 0 "codex con los permisos de Gemini activados" backend.developer codex
expect_not "$FAKE_STDIN" "Solo podés correr estos comandos" "codex: los permisos de Gemini no le cambian nada"
rm -rf "$WORK/gemini"

# --- Gemini con stream-json: pasos, tokens y comandos rechazados ------------------------

new_project
FAKE_MODE=ok check 0 "gemini: stream-json" frontend.developer gemini
expect "$FAKE_ARGS" "--output-format stream-json" "gemini: pide la salida por pasos"
expect "$PROJ/.office/runs/r1/output.md" "Hecho: listo." "gemini: el reporte sale del resultado final"
expect_not "$PROJ/.office/runs/r1/output.md" '"event"' "gemini: el reporte no trae los eventos JSON"
expect "$PROJ/.office/runs/r1/log.txt" "paso 3 · replace_file_content · src/app.ts → ok" "gemini: el registro cuenta cada paso"
expect "$PROJ/.office/runs/r1/stream.jsonl" '"event":"result"' "gemini: guarda el flujo completo"
expect "$PROJ/.office/observer/events.js" '"tokens":6917' "gemini: el observer recibe sus tokens"
new_project
FAKE_MODE=denied check 3 "gemini: comando rechazado" frontend.developer gemini
expect "$WORK/out.txt" "Comandos que Antigravity le rechazó a Gemini" "gemini: el resumen dice que le rechazaron un comando"
expect "$WORK/out.txt" 'Remove-Item -Path "src/old.ts"' "gemini: muestra el comando exacto"
expect "$WORK/out.txt" "gemini-permissions on" "gemini sin permisos: dice cómo activarlos"
expect "$WORK/out.txt" "se frenó porque Antigravity le rechazó un comando" "gemini: explica por qué no hay reporte"
expect "$PROJ/.office/runs/r1/log.txt" "paso 2 · run_command · Remove-Item" "gemini: el rechazo queda en el registro"
mkdir -p "$WORK/gemini"
bash "$REPO/plugins/office/skills/office-agents/office-agents.sh" gemini-permissions on >/dev/null
new_project
FAKE_MODE=denied check 3 "gemini con permisos: comando fuera de la lista" frontend.developer gemini
expect "$WORK/out.txt" "No están entre los permitidos de gemini-permissions" "gemini con permisos: dice que el comando no está en la lista"
expect "$WORK/out.txt" "tiene que usar git rm o git mv" "gemini con permisos: dice cómo borrar"
new_project
FAKE_MODE=gitrm check 0 "gemini: borra con git rm" frontend.developer gemini
expect "$WORK/out.txt" "src/util.ts" "gemini: el borrado aparece en los archivos cambiados"
expect "$FAKE_STDIN" "borrar y mover archivos del repo con \`git rm\` y \`git mv\`" "gemini con permisos: sabe que borra con git rm"
rm -rf "$WORK/gemini"

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
