#!/usr/bin/env bash
# Pruebas del hook del observer (plugins/office/scripts/observer.sh).
# Le pasa el JSON de cada evento de Claude Code y revisa las líneas que escribe en
# .office/observer/events.js. Uso: bash tests/observer.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO/plugins/office/scripts/observer.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

PROJ="$WORK/proj"
mkdir -p "$PROJ/.claude"
(cd "$PROJ" && git init -q -b main && git config user.email t@example.com && git config user.name T && git commit -q --allow-empty -m init && git switch -qc feature/PROJ-123-pedidos)
EVENTS="$PROJ/.office/observer/events.js"
export CLAUDE_PROJECT_DIR="$PROJ"
export HOME="$WORK/home"
mkdir -p "$HOME/.claude"

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; FAILED=1; }

# hook <json>: corre el hook y guarda lo que imprimió y su código de salida.
hook() {
  printf '%s' "$1" | bash "$HOOK" >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
  RC=$?
}

# last_event: la última línea de events.js como JSON.
last_event() { tail -n1 "$EVENTS" | sed -e 's/^OFFICE_EVENT(//' -e 's/);$//'; }

# expect <filtro jq que da true> <descripción>
expect() {
  if last_event | jq -e "$1" >/dev/null 2>&1; then ok "$2"; else fail "$2"; echo "      $(last_event)"; fi
}

quiet() {
  if [ "$RC" -eq 0 ] && [ ! -s "$WORK/stdout.txt" ]; then ok "$1: sale con 0 y no imprime nada"; else fail "$1: sale con 0 y no imprime nada (código $RC)"; cat "$WORK/stdout.txt"; fi
}

# --- Configuración del proyecto ------------------------------------------------
echo '{"roles": {"backend.developer": ["codex"], "qa": ["claude", "codex"]}}' >"$PROJ/.claude/office-agents.json"
echo '{"roles": {"backend.developer": ["claude"]}}' >"$PROJ/.claude/office-agents.local.json"
echo '{"enabledPlugins": {"office@dev-office": true, "dept-backend@dev-office": true, "dept-frontend@dev-office": true, "dept-scraper@dev-office": false}}' >"$PROJ/.claude/settings.json"

# --- SessionStart ---------------------------------------------------------------
hook '{"hook_event_name":"SessionStart","source":"startup","session_id":"s1","cwd":"x","transcript_path":"x"}'
quiet "SessionStart"
expect '.type == "session" and .branch == "feature/PROJ-123-pedidos" and .ticket == "PROJ-123"' "sesión: rama y ticket"
expect '.config["backend.developer"] == ["claude"] and .config.qa == ["claude","codex"]' "sesión: proveedores, con el archivo personal mandando"
expect '.departments == ["backend","frontend"]' "sesión: departamentos instalados (solo los habilitados)"
[ -f "$PROJ/.office/observer/index.html" ] && cmp -s "$PROJ/.office/observer/index.html" "$REPO/plugins/office/observer/index.html" && ok "sesión: copia la página" || fail "sesión: copia la página"

hook '{"hook_event_name":"SessionStart","source":"resume"}'
[ "$(grep -c '^OFFICE_EVENT' "$EVENTS")" -eq 2 ] && ok "resume: sigue el mismo registro" || fail "resume: sigue el mismo registro"
hook '{"hook_event_name":"SessionStart","source":"startup"}'
[ "$(grep -c '^OFFICE_EVENT' "$EVENTS")" -eq 1 ] && [ -f "$PROJ/.office/observer/events.prev.js" ] && ok "sesión nueva: guarda el registro anterior y empieza otro" || fail "sesión nueva: guarda el registro anterior y empieza otro"

# --- UserPromptSubmit -------------------------------------------------------------
hook '{"hook_event_name":"UserPromptSubmit","prompt":"una clave secreta","session_id":"s1"}'
quiet "UserPromptSubmit"
expect '.type == "prompt"' "el CEO escribe"
grep -q "clave secreta" "$EVENTS" && fail "no guarda el texto del CEO" || ok "no guarda el texto del CEO"

# --- PreToolUse -------------------------------------------------------------------
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:{subagent_type:"office:external", description:"[backend-developer · codex] Endpoints de pedidos", prompt:"Rol: backend.developer\nProveedor: codex\nModelo: gpt-x\nModo: normal\n\nObjetivo: ..."}}')"
quiet "PreToolUse del PM"
expect '.type == "delegate" and .subagent_type == "office:external" and .role == "backend.developer" and .provider == "codex" and .xmodel == "gpt-x" and .mode == "normal"' "encargo al puente: rol, proveedor, modelo y modo"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:{subagent_type:"dept-backend:tester", description:"[backend-tester] Tests", prompt:"Objetivo: probar"}}')"
expect '.type == "delegate" and .subagent_type == "dept-backend:tester" and .role == null and .provider == null' "encargo a un agente de Claude"
hook "$(jq -cn '{hook_event_name:"PreToolUse", agent_id:"a1", tool_name:"Edit", tool_input:{file_path:"/p/src/orders/routes.ts"}}')"
expect '.type == "tool" and .agent == "a1" and .tool == "Edit" and .target == "routes.ts"' "herramienta de un subagente: solo el nombre del archivo"
hook "$(jq -cn '{hook_event_name:"PreToolUse", agent_id:"a1", tool_name:"Edit", tool_input:{file_path:"C:\\p\\src\\app.ts"}}')"
expect '.target == "app.ts"' "ruta de Windows"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"pnpm test\n--watch=false and a very long command that keeps going and going and going on"}}')"
expect '.agent == null and .tool == "Bash" and (.target | length) <= 80 and (.target | test("\n") | not)' "herramienta del PM: comando recortado y en una línea"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Skill", tool_input:{skill:"office:start-ticket"}}')"
expect '.tool == "Skill" and .target == "office:start-ticket"' "skill del PM"

# --- SubagentStart y SubagentStop -----------------------------------------------------
hook '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"office:external"}'
quiet "SubagentStart"
expect '.type == "start" and .agent == "a1" and .agent_type == "office:external"' "empieza un agente"

# Transcripción con un mensaje repetido (mismo id): se cuenta una vez.
T="$WORK/agent.jsonl"
{
  echo '{"type":"user","message":{"role":"user","content":"hola"}}'
  echo '{"type":"assistant","isSidechain":true,"message":{"id":"m1","usage":{"input_tokens":100,"output_tokens":5,"cache_creation_input_tokens":1000,"cache_read_input_tokens":0}}}'
  echo '{"type":"assistant","isSidechain":true,"message":{"id":"m1","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":1000,"cache_read_input_tokens":0}}}'
  echo '{"type":"assistant","isSidechain":true,"message":{"id":"m2","usage":{"input_tokens":20,"output_tokens":30,"cache_creation_input_tokens":0,"cache_read_input_tokens":4000}}}'
  echo 'línea rota {'
} >"$T"
verdict() {
  hook "$(jq -cn --arg m "$1" --arg t "$T" '{hook_event_name:"SubagentStop", agent_id:"a1", agent_type:"dept-backend:tester", agent_transcript_path:$t, last_assistant_message:$m}')"
}
verdict $'**PASA**\n\nTests: 12'
quiet "SubagentStop"
expect '.type == "stop" and .verdict == "PASA"' "veredicto PASA (con negrita)"
expect '.usage == {"i":120,"o":80,"cw":1000,"cr":4000}' "tokens del agente: un mensaje repetido cuenta una vez y la línea rota se saltea"
verdict $'FALLA\n- test x'; expect '.verdict == "FALLA"' "veredicto FALLA"
verdict 'APROBADO'; expect '.verdict == "APROBADO"' "veredicto APROBADO"
verdict '**RECHAZADO**: 1 bloqueante'; expect '.verdict == "RECHAZADO"' "veredicto RECHAZADO"
verdict $'**PROVEEDOR NO DISPONIBLE**\ncodex sin sesión'; expect '.verdict == "PROVEEDOR NO DISPONIBLE"' "veredicto del puente: proveedor no disponible"
verdict 'REGLAS ROTAS'; expect '.verdict == "REGLAS ROTAS"' "veredicto del puente: reglas rotas"
verdict $'Diseño listo.\n\nNecesito aprobación: el diseño completo.'; expect '.verdict == "APROBACION"' "pide aprobación"
verdict 'Hecho: endpoints listos.'; expect '.verdict == "LISTO"' "sin veredicto: listo"
hook '{"hook_event_name":"SubagentStop","agent_id":"a2","agent_type":"x","agent_transcript_path":"/no/existe"}'
expect '.usage == null and .verdict == "LISTO"' "transcripción que no existe: sin tokens"

# --- Stop -------------------------------------------------------------------------
M="$WORK/main.jsonl"
{
  echo '{"type":"assistant","message":{"id":"p1","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":300,"cache_read_input_tokens":0}}}'
  echo '{"type":"assistant","isSidechain":true,"message":{"id":"x1","usage":{"input_tokens":999,"output_tokens":999,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
} >"$M"
hook "$(jq -cn --arg t "$M" '{hook_event_name:"Stop", transcript_path:$t, last_assistant_message:"listo"}')"
quiet "Stop"
expect '.type == "turn_end" and .usage == {"i":10,"o":20,"cw":300,"cr":0}' "fin del turno: tokens del PM sin los de subagentes"
LINES=$(grep -c '^OFFICE_EVENT' "$EVENTS")
hook "$(jq -cn --arg t "$M" '{hook_event_name:"Stop", agent_id:"a1", transcript_path:$t}')"
[ "$(grep -c '^OFFICE_EVENT' "$EVENTS")" -eq "$LINES" ] && ok "Stop de un subagente: no lo anota como turno del PM" || fail "Stop de un subagente: no lo anota como turno del PM"

# --- Notification -------------------------------------------------------------------
hook '{"hook_event_name":"Notification","message":"Claude needs your permission to use Bash\nmore"}'
quiet "Notification"
expect '.type == "notify" and (.message | test("permission")) and (.message | test("\n") | not)' "aviso de Claude Code en una línea"

# --- Todo el archivo es JavaScript válido para la página -------------------------------
if command -v node >/dev/null 2>&1; then
  if node -e "const fs=require('fs');let n=0;global.OFFICE_EVENT=()=>n++;eval(fs.readFileSync(process.argv[1],'utf8'));if(!n)process.exit(1)" "$EVENTS"; then ok "events.js se puede cargar desde la página"; else fail "events.js se puede cargar desde la página"; fi
fi

# --- Casos raros ---------------------------------------------------------------------
LINES=$(grep -c '^OFFICE_EVENT' "$EVENTS")
OFFICE_OBSERVER=off bash "$HOOK" <<<'{"hook_event_name":"UserPromptSubmit"}' >/dev/null 2>&1
[ "$(grep -c '^OFFICE_EVENT' "$EVENTS")" -eq "$LINES" ] && ok "OFFICE_OBSERVER=off: no anota nada" || fail "OFFICE_OBSERVER=off: no anota nada"
hook 'esto no es json'
quiet "entrada inválida"
hook '{"hook_event_name":"Notification"}'
quiet "evento que no escucha"

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
