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
expect '.prompt == "Objetivo: probar"' "encargo: guarda el texto completo"
LONG=$(printf 'x%.0s' $(seq 1 4100))
hook "$(jq -cn --arg p "Objetivo: algo largo $LONG" '{hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:{subagent_type:"dept-backend:developer", description:"[backend-developer] Largo", prompt:$p}}')"
expect '(.prompt | length) == 4004 and (.prompt | endswith("x\n[…]"))' "encargo: recorta en 4000 caracteres y lo marca"
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
verdict $'PASA\n\n## Resumen\n| a | b |'; expect '.text == "PASA\n\n## Resumen\n| a | b |"' "respuesta del agente: guarda el texto completo"
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
expect '.text == "listo"' "fin del turno: guarda la respuesta del PM al CEO"
{
  echo '{"type":"assistant","message":{"id":"p2","content":[{"type":"text","text":"Primera parte"}]}}'
  echo '{"type":"assistant","isSidechain":true,"message":{"id":"x2","content":[{"type":"text","text":"de un subagente"}]}}'
  echo '{"type":"assistant","message":{"id":"p3","content":[{"type":"text","text":"## Informe\nTodo listo"}]}}'
  echo '{"type":"assistant","message":{"id":"p4","content":[{"type":"tool_use","name":"Read"}]}}'
} >>"$M"
hook "$(jq -cn --arg t "$M" '{hook_event_name:"Stop", transcript_path:$t}')"
expect '.text == "## Informe\nTodo listo"' "fin del turno sin el texto en el evento: lo saca de la transcripción, sin subagentes"
hook '{"hook_event_name":"Stop"}'
expect '.type == "turn_end" and .text == ""' "fin del turno sin texto ni transcripción"
LINES=$(grep -c '^OFFICE_EVENT' "$EVENTS")
hook "$(jq -cn --arg t "$M" '{hook_event_name:"Stop", agent_id:"a1", transcript_path:$t}')"
[ "$(grep -c '^OFFICE_EVENT' "$EVENTS")" -eq "$LINES" ] && ok "Stop de un subagente: no lo anota como turno del PM" || fail "Stop de un subagente: no lo anota como turno del PM"

# --- Notification -------------------------------------------------------------------
hook '{"hook_event_name":"Notification","message":"Claude needs your permission to use Bash\nmore"}'
quiet "Notification"
expect '.type == "notify" and (.message | test("permission")) and (.message | test("\n") | not)' "aviso de Claude Code en una línea"

# --- Modo equipos ------------------------------------------------------------------
echo '{"teams": true, "roles": {"backend.developer": ["codex"], "qa": ["claude", "codex"]}}' >"$PROJ/.claude/office-agents.json"
hook '{"hook_event_name":"SessionStart","source":"resume"}'
expect '.type == "session" and .teams == true' "sesión: modo equipos activado"
echo '{"teams": false}' >"$PROJ/.claude/office-agents.local.json"
hook '{"hook_event_name":"SessionStart","source":"resume"}'
expect '.teams == false' "sesión: el archivo personal manda en el modo equipos"
echo '{"roles": {"backend.developer": ["claude"]}}' >"$PROJ/.claude/office-agents.local.json"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:{name:"backend-lead", subagent_type:"dept-backend:lead", description:"[backend-lead] Pedidos", prompt:"Objetivo: pedidos"}}')"
expect '.type == "delegate" and .name == "backend-lead" and .subagent_type == "dept-backend:lead" and .from == null' "el PM le encarga al líder"
hook "$(jq -cn '{hook_event_name:"PreToolUse", agent_id:"L1", agent_type:"backend-lead", tool_name:"Agent", tool_input:{subagent_type:"dept-backend:developer", description:"[backend-developer] Endpoints", prompt:"Objetivo: endpoints"}}')"
expect '.type == "delegate" and .from == "L1" and .from_type == "backend-lead" and .name == null and .subagent_type == "dept-backend:developer"' "el líder le encarga a su developer"
hook "$(jq -cn '{hook_event_name:"PreToolUse", agent_id:"L1", agent_type:"backend-lead", tool_name:"SendMessage", tool_input:{to:"team-lead", summary:"Reporte listo", message:"Reporte en .office/reports/x.md"}}')"
quiet "SendMessage"
expect '.type == "message" and .from == "L1" and .from_type == "backend-lead" and .to == "team-lead" and .text == "Reporte listo"' "mensaje del líder al PM, con su tipo de agente"
expect '.body == "Reporte en .office/reports/x.md"' "mensaje: guarda el texto completo"
hook "$(jq -cn '{hook_event_name:"PreToolUse", agent_id:"L1", agent_type:"backend-lead", tool_name:"Read", tool_input:{file_path:"/x/src/orders.ts"}}')"
expect '.type == "tool" and .agent_type == "backend-lead" and .target == "orders.ts"' "herramienta del líder, con su tipo de agente"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"SendMessage", tool_input:{to:"backend-lead", message:"Aprobado\nseguí con la migración y avisame cuando termines con todo lo que falta"}}')"
expect '.type == "message" and .from == null and .to == "backend-lead" and (.text | length) <= 60 and (.text | test("\n") | not)' "mensaje del PM al líder, en una línea"
expect '(.body | startswith("Aprobado\nseguí"))' "mensaje del PM al líder: el texto completo, con sus líneas"
hook "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"SendMessage", tool_input:{to:"backend-lead", message:{type:"shutdown_request"}}}')"
expect '.body == "{\"type\":\"shutdown_request\"}"' "mensaje con estructura: lo guarda como JSON"
hook '{"hook_event_name":"TeammateIdle","teammate_name":"backend-lead","team_name":"t"}'
quiet "TeammateIdle"
expect '.type == "teammate_idle" and .name == "backend-lead"' "el líder queda libre"
hook '{"hook_event_name":"TaskCreated","task_id":"7","task_subject":"Endpoints de pedidos","teammate_name":"backend-lead"}'
expect '.type == "task" and .state == "created" and .id == "7" and .name == "backend-lead"' "tarea creada"
hook '{"hook_event_name":"TaskCompleted","task_id":"7","task_subject":"Endpoints de pedidos"}'
quiet "TaskCompleted"
expect '.type == "task" and .state == "completed" and .name == null' "tarea terminada"
jq -e '.hooks | has("TeammateIdle") and has("TaskCreated") and has("TaskCompleted")' "$REPO/plugins/office/hooks/hooks.json" >/dev/null && ok "hooks.json escucha los eventos de equipo" || fail "hooks.json escucha los eventos de equipo"

# --- open-observer.sh en WSL ---------------------------------------------------------
OPEN="$REPO/plugins/office/skills/observer/open-observer.sh"
FAKE="$WORK/fakebin"; mkdir -p "$FAKE"
printf '#!/usr/bin/env bash\necho "\\\\\\\\wsl.localhost\\\\Ubuntu${2//\\//\\\\}"\n' >"$FAKE/wslpath"
printf '#!/usr/bin/env bash\necho "$1" >"%s/explorer.txt"\nexit 1\n' "$WORK" >"$FAKE/explorer.exe"
chmod +x "$FAKE/wslpath" "$FAKE/explorer.exe"
OUT=$(cd "$PROJ" && WSL_DISTRO_NAME=Ubuntu PATH="$FAKE:$PATH" bash "$OPEN" 2>&1)
RC=$?
echo "$OUT" | grep -q "En Windows: file://wsl.localhost/Ubuntu/.*/.office/observer/index.html" && ok "WSL: da el link para el navegador de Windows" || { fail "WSL: da el link para el navegador de Windows"; echo "$OUT"; }
[ "$RC" -eq 0 ] && grep -q '^\\\\wsl.localhost\\Ubuntu\\.*\\index.html$' "$WORK/explorer.txt" && ok "WSL: abre la página con la ruta de Windows" || fail "WSL: abre la página con la ruta de Windows"
printf '#!/usr/bin/env bash\necho "C:\\\\dev\\\\app\\\\.office\\\\observer\\\\index.html"\n' >"$FAKE/wslpath"
OUT=$(cd "$PROJ" && WSL_DISTRO_NAME=Ubuntu PATH="$FAKE:$PATH" bash "$OPEN" --no-open 2>&1)
echo "$OUT" | grep -q "En Windows: file:///C:/dev/app/.office/observer/index.html" && ok "WSL: proyecto en el disco de Windows" || { fail "WSL: proyecto en el disco de Windows"; echo "$OUT"; }

# --- Resumen de tokens (skill usage) ---------------------------------------------------
REPORT="$REPO/plugins/office/skills/usage/token-report.sh"
TP="$WORK/tokproj"; mkdir -p "$TP/.office/observer"; (cd "$TP" && git init -q)
cat >"$TP/.office/observer/events.js" <<'EVS'
OFFICE_EVENT({"type":"session","t":1,"source":"startup"});
OFFICE_EVENT({"type":"delegate","t":2,"subagent_type":"office:external","description":"[backend-developer · codex] Endpoints | pedidos","role":"backend.developer","provider":"codex","xmodel":"gpt-x"});
OFFICE_EVENT({"type":"start","t":3,"agent":"a1","agent_type":"office:external"});
OFFICE_EVENT({"type":"external","t":4,"role":"backend.developer","provider":"codex","model":"gpt-x","tokens":120500,"code":0});
OFFICE_EVENT({"type":"stop","t":5,"agent":"a1","agent_type":"office:external","usage":{"i":500,"o":3000,"cw":15000},"verdict":"LISTO"});
OFFICE_EVENT({"type":"delegate","t":6,"subagent_type":"dept-backend:tester","description":"[backend-tester] Tests"});
OFFICE_EVENT({"type":"start","t":7,"agent":"a2","agent_type":"dept-backend:tester"});
OFFICE_EVENT({"type":"stop","t":8,"agent":"a2","agent_type":"dept-backend:tester","usage":{"i":300,"o":4000,"cw":22000,"cr":99999},"verdict":"FALLA"});
OFFICE_EVENT({"type":"stop","t":9,"agent":"a3","agent_type":"office:qa","usage":null,"verdict":"APROBADO"});
OFFICE_EVENT({"type":"turn_end","t":10,"usage":{"i":5000,"o":12000,"cw":180000}});
EVS
OUT=$(cd "$TP" && bash "$REPORT")
RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q '^## Consumo de tokens' && ok "resumen: sección de consumo" || { fail "resumen: sección de consumo"; echo "$OUT"; }
echo "$OUT" | grep -q '| Developer de backend | Codex (gpt-x) | Endpoints / pedidos | LISTO | Codex 120.5k + puente 18.5k |' && ok "resumen: tarea por el puente, con el proveedor y el puente separados" || { fail "resumen: tarea por el puente"; echo "$OUT"; }
echo "$OUT" | grep -q '| Tester de backend | Claude | Tests | FALLA | 26.3k |' && ok "resumen: tarea de Claude, sin lecturas de caché" || fail "resumen: tarea de Claude, sin lecturas de caché"
echo "$OUT" | grep -q '| QA | Claude | — | APROBADO | sin datos |' && ok "resumen: sin transcripción dice sin datos" || fail "resumen: sin transcripción dice sin datos"
echo "$OUT" | grep -q 'Claude 241.8k (PM 197k, agentes y puente 44.8k) · Codex 120.5k' && ok "resumen: total por proveedor con el PM aparte" || { fail "resumen: total por proveedor"; echo "$OUT" | tail -4; }
# Modo equipos: Claude Code identifica al líder como "<área>-lead", no como "dept-<área>:lead".
cat >"$TP/.office/observer/events.js" <<'EVS'
OFFICE_EVENT({"type":"delegate","t":1,"name":"backend-lead","subagent_type":"dept-backend:lead","description":"[backend-lead] Pedidos"});
OFFICE_EVENT({"type":"delegate","t":2,"name":"frontend-lead","subagent_type":"dept-frontend:lead","description":"[frontend-lead] Pantalla"});
OFFICE_EVENT({"type":"start","t":3,"agent":"L2","agent_type":"frontend-lead"});
OFFICE_EVENT({"type":"start","t":4,"agent":"L1","agent_type":"backend-lead"});
OFFICE_EVENT({"type":"stop","t":5,"agent":"L1","agent_type":"backend-lead","usage":{"i":100,"o":900,"cw":9000},"verdict":"LISTO"});
OFFICE_EVENT({"type":"stop","t":6,"agent":"L2","agent_type":"frontend-lead","usage":{"i":100,"o":400,"cw":4500},"verdict":"LISTO"});
EVS
OUT=$(cd "$TP" && bash "$REPORT")
echo "$OUT" | grep -q '| Líder de backend | Claude | Pedidos | LISTO | 10k |' && ok "resumen: reconoce al líder como <área>-lead" || { fail "resumen: reconoce al líder como <área>-lead"; echo "$OUT"; }
echo "$OUT" | grep -q '| Líder de frontend | Claude | Pantalla | LISTO | 5k |' && ok "resumen: con varios líderes, cada tarea es de su líder" || { fail "resumen: con varios líderes"; echo "$OUT"; }
OUT=$(mkdir -p "$WORK/sinnada" && cd "$WORK/sinnada" && CLAUDE_PROJECT_DIR="$WORK/sinnada" bash "$REPORT")
echo "$OUT" | grep -q "No hay datos de tokens" && ok "resumen: sin registro avisa" || fail "resumen: sin registro avisa"

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
