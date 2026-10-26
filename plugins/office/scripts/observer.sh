#!/usr/bin/env bash
# Hook del observer de dev-office: anota lo que pasa en la oficina para la página
# .office/observer/index.html (la oficina en pixel art).
#
# Escucha SessionStart, UserPromptSubmit, PreToolUse, SubagentStart, SubagentStop,
# Notification y Stop.
# Cada evento es una línea "OFFICE_EVENT({...});" en .office/observer/events.js, que la
# página lee sin servidor. Los tokens salen de las transcripciones que Claude Code ya
# guarda en el disco.
#
# Nunca bloquea, nunca imprime nada (en algunos eventos, lo que imprime un hook le llega
# al modelo) y no llama a ningún modelo: no gasta tokens.
# Para apagarlo: OFFICE_OBSERVER=off en el "env" de .claude/settings.json.

[ "${OFFICE_OBSERVER:-on}" = "off" ] && exit 0
exec >/dev/null 2>&1

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"
command -v jq || exit 0

INPUT=$(cat)
EVENT=$(json_get '.hook_event_name // empty')
[ -z "$EVENT" ] && exit 0

PROJECT=$(norm_path "${CLAUDE_PROJECT_DIR:-$PWD}")
DIR="$PROJECT/.office/observer"
EVENTS="$DIR/events.js"
mkdir -p "$DIR" || exit 0
NOW=$(date +%s)
AGENT_ID=$(json_get '.agent_id // empty')

emit() { [ -n "$1" ] && printf 'OFFICE_EVENT(%s);\n' "$1" >>"$EVENTS"; }

# Tokens de una transcripción: entrada, salida, escritura y lectura de caché.
# Cada mensaje puede aparecer en varias líneas con el mismo id: se cuenta una vez.
# $2 = 1 deja afuera las líneas de subagentes (en la transcripción principal).
usage_of() {
  local f
  f=$(norm_path "$1")
  [ -n "$1" ] && [ -f "$f" ] || { echo 'null'; return; }
  jq -c -R -s --argjson main "${2:-0}" '
    split("\n") | map(fromjson? // empty)
    | map(select(.type == "assistant" and .message.usage != null and ($main == 0 or .isSidechain != true)))
    | map({ id: (.message.id // .uuid), u: .message.usage })
    | group_by(.id) | map(max_by(.u.output_tokens // 0).u)
    | { i: (map(.input_tokens // 0) | add // 0), o: (map(.output_tokens // 0) | add // 0),
        cw: (map(.cache_creation_input_tokens // 0) | add // 0), cr: (map(.cache_read_input_tokens // 0) | add // 0) }
  ' "$f" | tr -d '\r'
}

case "$EVENT" in
  SessionStart)
    SOURCE=$(json_get '.source // "startup"')
    # Sesión nueva: el registro anterior queda como events.prev.js.
    if [ "$SOURCE" = "startup" ] || [ "$SOURCE" = "clear" ]; then
      [ -f "$EVENTS" ] && mv -f "$EVENTS" "$DIR/events.prev.js"
    fi
    # La página se copia (o se actualiza) desde el plugin.
    PAGE_SRC="$(dirname "${BASH_SOURCE[0]//\\//}")/../observer/index.html"
    if [ -f "$PAGE_SRC" ] && ! cmp -s "$PAGE_SRC" "$DIR/index.html"; then
      cp "$PAGE_SRC" "$DIR/index.html"
    fi
    BRANCH=$(git -C "$PROJECT" symbolic-ref --short -q HEAD | tr -d '\r')
    TICKET=$(printf '%s' "$BRANCH" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -n1)
    # Proveedores por rol: el archivo personal manda sobre el del equipo.
    CONFIG=$(for f in "$PROJECT/.claude/office-agents.json" "$PROJECT/.claude/office-agents.local.json"; do
      [ -f "$f" ] && jq -c '.roles // {}' "$f" | tr -d '\r'
    done | jq -c -s 'add // {}')
    # Departamentos instalados, según los plugins habilitados.
    DEPTS=$(for f in "$HOME/.claude/settings.json" "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
      [ -f "$f" ] && jq -c '.enabledPlugins // {}' "$f" | tr -d '\r'
    done | jq -c -s 'add // {} | to_entries | map(select(.value == true) | .key | split("@")[0] | select(startswith("dept-")) | ltrimstr("dept-")) | unique | if length == 0 then null else . end')
    [ -z "$CONFIG" ] && CONFIG='{}'
    [ -z "$DEPTS" ] && DEPTS='null'
    emit "$(jq -c -n --argjson t "$NOW" --arg source "$SOURCE" --arg branch "$BRANCH" --arg ticket "$TICKET" \
      --arg project "${PROJECT##*/}" --argjson config "$CONFIG" --argjson depts "$DEPTS" \
      '{type: "session", t: $t, source: $source, branch: $branch, ticket: $ticket, project: $project, config: $config, departments: $depts}')"
    ;;

  UserPromptSubmit)
    [ -z "$AGENT_ID" ] && emit "{\"type\":\"prompt\",\"t\":$NOW}"
    ;;

  PreToolUse)
    TOOL=$(json_get '.tool_name // empty')
    if [ -z "$AGENT_ID" ] && { [ "$TOOL" = "Agent" ] || [ "$TOOL" = "Task" ]; }; then
      # El PM encarga trabajo. Con el puente, el encargo empieza con Rol, Proveedor y Modelo.
      emit "$(printf '%s' "$INPUT" | jq -c --argjson t "$NOW" '
        def field($k): ([(.tool_input.prompt // "") | capture("(^|\\n)" + $k + ":[ \\t]*(?<v>[^\\n\\r]+)")] | first | .v // null);
        { type: "delegate", t: $t,
          subagent_type: (.tool_input.subagent_type // "general-purpose"),
          description: ((.tool_input.description // "")[0:140]),
          model: (.tool_input.model // null),
          role: field("Rol"), provider: field("Proveedor"), xmodel: field("Modelo"), mode: field("Modo") }' | tr -d '\r')"
    else
      emit "$(printf '%s' "$INPUT" | jq -c --argjson t "$NOW" '
        .tool_input as $in
        | { type: "tool", t: $t, agent: (.agent_id // null), tool: .tool_name,
            target: ((if $in.file_path then ($in.file_path | split("/") | last | split("\\") | last)
                      elif $in.notebook_path then ($in.notebook_path | split("/") | last)
                      elif $in.command then $in.command
                      elif $in.skill then $in.skill
                      elif $in.pattern then $in.pattern
                      elif $in.url then $in.url
                      elif $in.description then $in.description
                      else "" end) | tostring | gsub("[\\r\\n]+"; " ") | .[0:80]) }' | tr -d '\r')"
    fi
    ;;

  SubagentStart)
    emit "$(printf '%s' "$INPUT" | jq -c --argjson t "$NOW" '{type: "start", t: $t, agent: .agent_id, agent_type: (.agent_type // "")}' | tr -d '\r')"
    ;;

  SubagentStop)
    USAGE=$(usage_of "$(json_get '.agent_transcript_path // empty')" 0)
    emit "$(printf '%s' "$INPUT" | jq -c --argjson t "$NOW" --argjson usage "${USAGE:-null}" '
      (.last_assistant_message // "") as $m
      | ($m | split("\n") | map(select(test("\\S"))) | first // "" | ascii_upcase) as $f
      | { type: "stop", t: $t, agent: .agent_id, agent_type: (.agent_type // ""), usage: $usage,
          verdict: (if ($f | test("PROVEEDOR NO DISPONIBLE")) then "PROVEEDOR NO DISPONIBLE"
                    elif ($f | test("REGLAS ROTAS")) then "REGLAS ROTAS"
                    elif ($f | test("TIEMPO AGOTADO")) then "TIEMPO AGOTADO"
                    elif ($f | test("EL PROVEEDOR FALL")) then "FALLO"
                    elif ($f | test("^\\W*RECHAZADO")) then "RECHAZADO"
                    elif ($f | test("^\\W*APROBADO")) then "APROBADO"
                    elif ($f | test("^\\W*FALLA")) then "FALLA"
                    elif ($f | test("^\\W*PASA")) then "PASA"
                    elif ($f | test("^\\W*VALIDACI")) then "VALIDACION"
                    elif ($m | test("necesito aprobaci"; "i")) then "APROBACION"
                    else "LISTO" end) }' | tr -d '\r')"
    ;;

  Notification)
    [ -z "$AGENT_ID" ] && emit "$(printf '%s' "$INPUT" | jq -c --argjson t "$NOW" '{type: "notify", t: $t, message: ((.message // "") | gsub("[\\r\\n]+"; " ") | .[0:100])}' | tr -d '\r')"
    ;;

  Stop)
    if [ -z "$AGENT_ID" ]; then
      USAGE=$(usage_of "$(json_get '.transcript_path // empty')" 1)
      emit "{\"type\":\"turn_end\",\"t\":$NOW,\"usage\":${USAGE:-null}}"
    fi
    ;;
esac

exit 0
