#!/usr/bin/env bash
# token-report-version: 1
# Resumen de tokens de la sesión de la oficina, para el informe del PM al CEO.
#
# Lee el registro del observer (.office/observer/events.js), que tiene los tokens exactos
# de cada agente (salen de las transcripciones de Claude Code) y los que informan Codex y
# Gemini. No llama a ningún modelo: no gasta tokens.
#
# Uso: bash token-report.sh [--prev]
#   --prev  la sesión anterior (events.prev.js), en vez de la actual.
#
# Imprime Markdown: una tabla por tarea, el total por agente y el total por proveedor.
# Los tokens son entrada + salida + caché escrita (sin lecturas de caché), igual que el
# observer. Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

FILE="events.js"
[ "${1:-}" = "--prev" ] && FILE="events.prev.js"

command -v jq >/dev/null 2>&1 || { echo "No se puede armar el resumen de tokens: falta jq."; exit 0; }
PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT="${PROJECT//\\//}"
EVENTS="$PROJECT/.office/observer/$FILE"

if [ ! -s "$EVENTS" ]; then
  echo "No hay datos de tokens: todavía no hubo actividad o el observer está apagado (OFFICE_OBSERVER=off)."
  exit 0
fi

sed -n 's/^OFFICE_EVENT(\(.*\));[[:space:]]*$/\1/p' "$EVENTS" | tr -d '\r' | jq -r -s '
  def tok(u): if u then ((u.i // 0) + (u.o // 0) + (u.cw // 0)) else 0 end;
  def num: if . >= 1000000 then ((. / 100000 | floor) / 10 | tostring) + "M"
           elif . >= 1000 then ((. / 100 | floor) / 10 | tostring) + "k"
           else tostring end;
  def role_of(t): if t == "office:qa" then "qa" elif t == "office:pm" then "pm"
                  else ((t // "") | capture("^dept-(?<d>[a-z]+):(?<r>[a-z-]+)$") | .d + "." + .r) // (t // "?") end;
  def rname(r):
    if r == "qa" then "QA" elif r == "pm" then "Asesor del PM"
    else (r | split(".")) as $p
      | if ($p | length) < 2 then r
        else ({"developer": "Developer", "tester": "Tester", "architect": "Arquitecto", "designer": "Designer", "lead": "Líder"}[$p[1]] // $p[1])
             + " de " + ({"backend": "backend", "frontend": "frontend", "database": "base de datos", "scraper": "scraping", "devops": "DevOps", "project": "proyecto"}[$p[0]] // $p[0]) end end;
  def prov(p): {"claude": "Claude", "codex": "Codex", "gemini": "Gemini"}[p] // p;
  def verdict(v): {"APROBACION": "pide aprobación", "VALIDACION": "VALIDÓ", "FALLO": "FALLÓ"}[v] // v;
  def amount: if . == null then "sin datos" else num end;
  def cell: tostring | gsub("\\|"; "/") | gsub("[\r\n]+"; " ");
  def strip: (. // "") | sub("^\\[[^\\]]*\\]\\s*"; "");

  # Encargos → inicio (por tipo de agente, en orden) → fin (por agent_id).
  (reduce .[] as $e ({pending: [], by: {}, tasks: [], ext: [], pm: 0, leads: false};
    if $e.type == "delegate" then
      .pending += [{type: $e.subagent_type, desc: ($e.description | strip),
                    role: ($e.role // role_of($e.subagent_type)),
                    provider: (($e.provider // "claude") | ascii_downcase), model: ($e.xmodel // $e.model)}]
      | if (($e.name // "") | test("-lead$")) or ((role_of($e.subagent_type) // "") | test("\\.lead$")) then .leads = true else . end
    elif $e.type == "start" then
      (.pending | map(.type) | index($e.agent_type)) as $i
      | if $i == null then .by[$e.agent] = {type: $e.agent_type, desc: "", role: role_of($e.agent_type), provider: "claude"}
        else .by[$e.agent] = .pending[$i] | .pending |= (.[:$i] + .[$i + 1:]) end
    elif $e.type == "stop" then
      .tasks += [(.by[$e.agent] // {type: $e.agent_type, desc: "", role: role_of($e.agent_type), provider: "claude"})
                 + {claude: tok($e.usage), known: ($e.usage != null), verdict: ($e.verdict // "LISTO")}]
    elif $e.type == "external" then .ext += [$e]
    elif $e.type == "turn_end" then .pm = (if tok($e.usage) > 0 then tok($e.usage) else .pm end)
    else . end)) as $s

  # Cada tarea del puente se queda con el primer resultado de Codex o Gemini de su rol.
  | (reduce $s.tasks[] as $t ({rows: [], ext: $s.ext};
      if $t.type == "office:external" then
        (.ext | map(.role) | index($t.role)) as $i
        | if $i == null then .rows += [$t + {ext: 0}]
          else .ext[$i] as $x | .rows += [$t + {ext: ($x.tokens // 0), provider: ($x.provider // $t.provider), model: ($x.model // $t.model)}]
               | .ext |= (.[:$i] + .[$i + 1:]) end
      else .rows += [$t + {ext: 0}] end)) as $m
  | $m.rows as $rows

  | ($rows | map(select(.provider != "claude") | .ext) | add // 0) as $extTotal
  | ($rows | map(.claude) | add // 0) as $agents

  | "## Consumo de tokens",
    "",
    (if ($rows | length) == 0 then "Ningún agente trabajó todavía en esta sesión." else
      "| Agente | Proveedor | Tarea | Resultado | Tokens |",
      "| --- | --- | --- | --- | --- |",
      ($rows[] |
        "| " + (rname(.role) | cell)
        + " | " + (prov(.provider) + (if .model and .provider != "claude" then " (" + .model + ")" else "" end) | cell)
        + " | " + ((if .desc == "" then "—" else .desc end) | .[0:70] | cell)
        + " | " + (verdict(.verdict) | cell)
        + " | " + (if .provider != "claude" then (prov(.provider) + " " + (.ext | num) + " + puente " + (if .known then .claude else null end | amount))
                   else (if .known then .claude else null end | amount) end)
        + " |"),
      "",
      "**Por agente**",
      "",
      "| Agente | Proveedor | Tareas | Claude | Codex o Gemini | Total | Promedio por tarea |",
      "| --- | --- | --- | --- | --- | --- | --- |",
      ($rows | group_by([.role, .provider]) | map({role: .[0].role, provider: .[0].provider, n: length,
          claude: (map(.claude) | add), ext: (map(.ext) | add), known: any(.[]; .known or .ext > 0)})
        | map(.total = .claude + .ext) | sort_by(-.total)[] |
        "| " + (rname(.role) | cell) + " | " + prov(.provider) + " | " + (.n | tostring)
        + " | " + (if .known then .claude else null end | amount) + " | " + (if .provider == "claude" then "—" else (.ext | num) end)
        + " | " + (if .known then .total else null end | amount) + " | " + (if .known then (.total / .n | floor) else null end | amount) + " |")
    end),
    "",
    "**Total de la sesión:** "
      + ([ "Claude " + (($s.pm + $agents) | num) + " (PM " + ($s.pm | num) + ", agentes y puente " + ($agents | num) + ")" ]
         + ($rows | map(select(.provider != "claude")) | group_by(.provider) | map(prov(.[0].provider) + " " + (map(.ext) | add | num)))
        | join(" · ")),
    "",
    "Tokens: entrada, salida y caché escrita, sin lecturas de caché. Los de Claude son exactos; los de Codex y Gemini, los que informa cada CLI.",
    (if $s.leads and ([$rows[] | select(.role | test("\\.lead$"))] | length) == 0
     then "Los líderes de departamento (modo equipos) no aparecen: Claude Code no informó sus tokens." else empty end)
'
