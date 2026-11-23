#!/usr/bin/env bash
# token-check-version: 6
# Revisa la configuración del proyecto y de la oficina en busca de lo que más tokens hace
# gastar a cada agente. No llama a ningún modelo: no gasta tokens.
#
# Uso: bash token-check.sh
#
# Imprime Markdown con cada punto: qué encontró y, si conviene, qué cambiar.
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT="${PROJECT//\\//}"
HAS_JQ=0; command -v jq >/dev/null 2>&1 && HAS_JQ=1

chars() { [ -f "$1" ] && wc -c <"$1" | tr -d ' \r' || echo 0; }
lines() { [ -f "$1" ] && wc -l <"$1" | tr -d ' \r' || echo 0; }
# Tokens aproximados de un archivo, como texto corto: "36k" o "800".
tokens() { local t=$(( $(chars "$1") / 4 )); if [ "$t" -ge 1000 ]; then echo "$((t / 1000))k"; else echo "$t"; fi; }

echo "## Revisión de consumo"
echo

# 1. CLAUDE.md: se carga en cada agente, en cada arranque. Se suman los archivos que importa con @.
MD="$PROJECT/CLAUDE.md"
if [ -f "$MD" ]; then
  total=$(chars "$MD")
  imported=""
  for ref in $(grep -oE '(^|[[:space:]])@[A-Za-z0-9_./-]+' "$MD" | tr -d ' \t' | sed 's/^@//' | tr -d '\r'); do
    f="$PROJECT/$ref"
    [ -f "$f" ] || continue
    total=$((total + $(chars "$f")))
    imported="$imported $ref"
  done
  tok=$((total / 4))
  if [ "$tok" -lt 1000 ]; then size="menos de 1k"; else size="unos $((tok / 1000))k"; fi
  echo "- **CLAUDE.md:** $(lines "$MD") líneas, $size tokens${imported:+ con lo que importa (${imported# })}. Se carga en cada agente, cada vez que arranca."
  if [ "$tok" -gt 6000 ]; then
    echo "  - ⚠️ Es largo. Dejá en el CLAUDE.md las reglas y los comandos, y mové lo que es explicación o historia a \`docs/\`, donde los agentes lo leen solo si lo necesitan."
  fi
  # Las reglas del proyecto también valen: en el modo local de la oficina, los comandos
  # rápidos están en .claude/rules/.
  RULES_TXT=$(cat "$MD" "$PROJECT"/.claude/rules/*.md 2>/dev/null)
  # Cuenta como "tests relacionados" un comando con modo related, una regla de "solo lo que
  # tocaste", o dónde está el test de cada archivo (lo que se usa en Flutter, Go o Python).
  if printf '%s' "$RULES_TXT" | grep -qiE 'related|findRelatedTests|--changed|relacionad|(pruebas|tests?) de lo que (tocaste|cambiaste)|solo (las pruebas|los tests)|_test\.(dart|go|py)|test_[a-z_<>]+\.py|\.(test|spec)\.[jt]sx?.{0,40}(junto|al lado|mismo)'; then
    echo "  - ✅ Tiene un comando para correr solo los tests relacionados."
  else
    echo "  - ⚠️ No tiene un comando para correr solo los tests relacionados con un cambio. Sin eso, el developer y el tester pueden terminar corriendo la suite completa, y la tarea tarda más. Ejemplo: \`Tests de lo que cambiaste: pnpm vitest related <archivos> --run --reporter=dot\`."
  fi
  if printf '%s' "$RULES_TXT" | grep -qiE 'CI.{0,60}(suite|tests)|(suite|tests).{0,60}\bCI\b'; then
    echo "  - ✅ Dice si la suite completa la corre CI."
  elif [ -d "$PROJECT/.github/workflows" ] || [ -f "$PROJECT/.gitlab-ci.yml" ]; then
    echo "  - 💡 El proyecto tiene CI. Si corre la suite completa en los PR que abre la oficina (los de cada ticket, no solo los que van a la rama base o a producción), decilo en las reglas (\`La suite completa la corre CI en los PR de ticket\`): así \`open-pr\` no la vuelve a correr en local. Si no corre en esos PR, no cambies nada: en local, la suite completa se corre en el PR de la épica (o en el del ticket, si no tiene épica)."
  fi
  if [ -f "$PROJECT/package.json" ] && [ "$HAS_JQ" -eq 1 ] && jq -r '.scripts.test // ""' "$PROJECT/package.json" 2>/dev/null | tr -d '\r' | grep -qE '(^|[ &;])vitest( |$)|--watch' \
     && ! printf '%s' "$RULES_TXT" | grep -qiE 'vitest run|--run|watchAll=false|--ci'; then
    echo "  - ⚠️ El script \`test\` de \`package.json\` arranca en modo watch: un agente que lo corre se queda esperando hasta que lo corta el tiempo límite. Poné en las reglas cómo correrlo una vez (\`pnpm vitest run\` o \`jest --ci --watchAll=false\`)."
  fi
  if printf '%s' "$RULES_TXT" | grep -qiE 'reporter|--silent|[[:space:]]-q([[:space:]]|$)|--quiet'; then
    echo "  - ✅ Indica una salida corta para algún comando."
  else
    echo "  - 💡 Si el runner de tests tiene una salida corta (\`--reporter=dot\`, \`--silent\`, \`-q\`), ponela en el comando: cada línea de salida queda en el contexto del agente."
  fi
else
  echo "- **CLAUDE.md:** no hay. Los agentes van a explorar el proyecto para entender cómo se trabaja: un CLAUDE.md corto con los comandos y las reglas les ahorra esa búsqueda."
fi

# 2. Mapa e índice: sin ellos, cada agente busca dónde está cada cosa.
MAP="$PROJECT/docs/project-map.md"
if [ -f "$MD" ] && grep -qE 'project-map[^ ]*\.md' "$MD"; then
  ref=$(grep -oE '[A-Za-z0-9_./-]*project-map[A-Za-z0-9_./-]*\.md' "$MD" | head -1)
  [ -n "$ref" ] && MAP="$PROJECT/$ref"
fi
if [ -f "$MAP" ]; then
  ML=$(lines "$MAP")
  if [ "$ML" -gt 150 ]; then
    # Un mapa largo casi siempre es un historial: un párrafo por ticket con sus archivos.
    TICKETS=$(grep -cE '(^|[^A-Za-z])[A-Z][A-Z0-9]+-[0-9]+' "$MAP" 2>/dev/null || echo 0)
    echo "- ⚠️ **Mapa del proyecto:** ${MAP#$PROJECT/} tiene $ML líneas (unos $(tokens "$MAP") tokens) y debería tener hasta 150: lo lee el PM al planear y cada agente que lo abre.$( [ "${TICKETS:-0}" -gt 5 ] && printf ' Nombra tickets en %s líneas: se volvió un historial de lo que hizo cada tarea, y eso ya está en git.' "$TICKETS") Conviene rehacerlo con la skill \`/office:project-map\` (qué hay en cada carpeta y dónde vive cada cosa, sin entradas por ticket) y pasar las áreas grandes a \`docs/project-map/<área>.md\`."
  else
    echo "- ✅ **Mapa del proyecto:** ${MAP#$PROJECT/}, $ML líneas."
  fi
else
  echo "- ⚠️ **Mapa del proyecto:** no hay. Cada agente busca dónde está cada cosa, y eso crece con el proyecto. El PM lo crea solo en la próxima tarea, o ya mismo con \`/office:project-map\`: sirve igual para un proyecto empezado y de cualquier tamaño."
fi
if [ -s "$PROJECT/.office/index/files.tsv" ]; then
  echo "- ✅ **Índice de archivos:** $(grep -c . "$PROJECT/.office/index/files.tsv") archivos; se actualiza solo al empezar cada sesión."
else
  echo "- ⚠️ **Índice de archivos:** no hay. Se arma solo al empezar la próxima sesión (si no, revisá que no esté apagado con \`OFFICE_INDEX=off\`), o ya mismo con \`project-index.sh --full\`, en segundos y sin tokens."
fi

# 3. Departamentos instalados: las skills de cada uno se suman al contexto de todos los agentes.
if [ "$HAS_JQ" -eq 1 ]; then
  depts=""
  for s in "$HOME/.claude/settings.json" "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
    [ -f "$s" ] || continue
    d=$(tr -d '\r' <"$s" | jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value == true) | .key | select(test("^dept-")) | sub("@.*$"; "")' 2>/dev/null)
    depts="$depts $d"
  done
  depts=$(printf '%s\n' $depts | sort -u | tr '\n' ' ' | sed 's/ *$//')
  if [ -n "$depts" ]; then
    echo "- **Departamentos instalados:** $depts. Cada uno suma sus skills al contexto de todos los agentes: desinstalá los que este proyecto no usa (\`claude plugin uninstall <nombre>@dev-office --scope <el mismo con que lo instalaste>\`)."
  fi
fi

# 4. Configuración de la oficina: QA, asesores, modo equipos y proveedores.
if [ "$HAS_JQ" -eq 1 ]; then
  cfg='{}'
  for f in "$PROJECT/.claude/office-agents.json" "$PROJECT/.claude/office-agents.local.json"; do
    [ -f "$f" ] && cfg=$(printf '%s' "$cfg" | jq -c --slurpfile o "$f" '. * ($o[0] // {})' 2>/dev/null || echo "$cfg")
  done
  qa=$(printf '%s' "$cfg" | jq -r '(.roles.qa // .qa // "claude") | if type == "array" then join(" ") else tostring end' 2>/dev/null)
  nqa=$(printf '%s\n' $qa | grep -c .)
  pmadv=$(printf '%s' "$cfg" | jq -r '(.roles.pm // .pm // empty) | if type == "array" then join(" ") else tostring end' 2>/dev/null)
  teams=$(printf '%s' "$cfg" | jq -r '.teams // false' 2>/dev/null)
  echo "- **QA:** ${qa:-claude}."
  [ "${nqa:-1}" -ge 3 ] && echo "  - 💡 Con tres QA, cada tarea normal paga tres revisiones (y una vuelta de validación cruzada si hay bloqueantes). Para la mayoría alcanza con uno o dos: \`office-agents.sh set qa claude codex --local\`."
  if [ -n "$pmadv" ]; then
    echo "- **Asesores del PM:** $pmadv. Cada uno suma una consulta antes de cada plan; si no te aportan, \`office-agents.sh reset pm --local\`."
  fi
  [ "$teams" = "true" ] && echo "- **Modo equipos:** encendido. El líder de cada departamento es un agente más por tarea; apagalo si no lo necesitás: \`office-agents.sh teams off --local\`."
fi

# 5. Lo que gastó la última sesión, si hay registro.
EV="$PROJECT/.office/observer/events.js"
if [ "$HAS_JQ" -eq 1 ] && [ -s "$EV" ]; then
  sed -n 's/^OFFICE_EVENT(\(.*\));[[:space:]]*$/\1/p' "$EV" | tr -d '\r' | jq -r -s '
    def tok(u): if u then ((u.i // 0) + (u.o // 0) + (u.cw // 0)) else 0 end;
    def num: if . >= 1000000 then ((. / 100000 | floor) / 10 | tostring) + "M"
             elif . >= 1000 then ((. / 100 | floor) / 10 | tostring) + "k" else tostring end;
    [ .[] | select(.type == "stop" and .usage != null) | {t: (.agent_type // "?"), n: tok(.usage)} ]
    | group_by(.t) | map({t: .[0].t, n: (map(.n) | add), k: length}) | sort_by(-.n) | .[0:3]
    | if length == 0 then empty else
        "- **Lo que más gastó en esta sesión:** " + (map(.t + " " + (.n | num) + " en " + (.k | tostring) + (if .k == 1 then " vuelta" else " vueltas" end)) | join(" · ")) + ". El detalle, con `/office:usage`."
      end' 2>/dev/null
fi

echo
echo "Tokens aproximados: caracteres / 4. No llama a ningún modelo."
