#!/usr/bin/env bash
# Pruebas del script que actualiza la oficina en todos los proyectos
# (plugins/office/skills/update/update-office.sh).
# Usa un "claude" falso que anota cada llamada y devuelve una lista de plugins de prueba.
# Uso: bash tests/update-office.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/plugins/office/skills/update/update-office.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; FAILED=1; }

# --- Escenario: dos proyectos, una instalación de usuario y otro marketplace ----------
P1="$WORK/proyecto-uno"; P2="$WORK/proyecto-dos"; GONE="$WORK/borrado"
mkdir -p "$P1/.claude" "$P2/.claude"
OFFICE_NEW="$WORK/cache/office/0.14.0"
mkdir -p "$OFFICE_NEW/skills/office-agents" "$OFFICE_NEW/skills/update"
printf '#!/usr/bin/env bash\n# office-agents-version: 3\necho nuevo\n' >"$OFFICE_NEW/skills/office-agents/office-agents.sh"
printf '#!/usr/bin/env bash\n# update-office-version: 2\necho nuevo\n' >"$OFFICE_NEW/skills/update/update-office.sh"
printf '#!/usr/bin/env bash\n# office-agents-version: 2\necho viejo\n' >"$P1/.claude/office-agents.sh"
printf '#!/usr/bin/env bash\n# office-agents-version: 9\necho propio\n' >"$P2/.claude/office-agents.sh"

entry() { jq -cn --arg id "$1" --arg scope "$2" --arg v "$3" --arg p "${4:-}" --arg ip "${5:-$WORK/cache/x}" \
  '{id: $id, scope: $scope, version: $v, installPath: $ip} + (if $p == "" then {} else {projectPath: $p} end)'; }
{
  entry "office@dev-office" user 0.13.0 "" "$WORK/cache/office/0.13.0"
  entry "office@dev-office" project 0.13.0 "$P1" "$WORK/cache/office/0.13.0"
  entry "office@dev-office" project 0.13.0 "$P2" "$WORK/cache/office/0.13.0"
  entry "dept-backend@dev-office" project 0.2.2 "$P1"
  entry "dept-frontend@dev-office" local 0.3.1 "$GONE"
  entry "otro@otro-market" user 1.0.0
} | jq -s . >"$WORK/before.json"
jq --arg ip "$OFFICE_NEW" 'map(if .id == "office@dev-office" then .version = "0.14.0" | .installPath = $ip else . end)' "$WORK/before.json" >"$WORK/after.json"

# --- claude falso -----------------------------------------------------------------------
BIN="$WORK/bin"; mkdir -p "$BIN"
cat >"$BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "$PWD|$*" >>"$FAKE_CALLS"
case "$*" in
  "plugin list --json") if [ -f "$FAKE_UPDATED" ]; then cat "$FAKE_AFTER"; else cat "$FAKE_BEFORE"; fi ;;
  "plugin marketplace update dev-office") [ "${FAKE_MARKET_FAIL:-0}" = 1 ] && exit 1; echo "marketplace al día" ;;
  "plugin update "*) touch "$FAKE_UPDATED"; echo "actualizado" ;;
esac
exit 0
EOF
chmod +x "$BIN/claude"
export FAKE_CALLS="$WORK/calls.txt" FAKE_UPDATED="$WORK/updated" FAKE_BEFORE="$WORK/before.json" FAKE_AFTER="$WORK/after.json"

run() { : >"$FAKE_CALLS"; rm -f "$FAKE_UPDATED"; PATH="$BIN:$PATH" bash "$SCRIPT" --yes >"$WORK/out.txt" 2>&1; RC=$?; }
called() { grep -qF -- "$1" "$FAKE_CALLS"; }
count() { grep -cF -- "$1" "$FAKE_CALLS"; }

run
[ "$RC" -eq 0 ] && ok "termina bien" || { fail "termina bien (código $RC)"; cat "$WORK/out.txt"; }
called "|plugin marketplace update dev-office" && ok "actualiza el marketplace" || fail "actualiza el marketplace"
[ "$(count "plugin update office@dev-office --scope user")" -eq 1 ] && ok "el plugin de usuario se actualiza una vez" || fail "el plugin de usuario se actualiza una vez"
called "$P1|plugin update office@dev-office --scope project" && ok "office en el proyecto uno, desde su carpeta" || fail "office en el proyecto uno, desde su carpeta"
called "$P2|plugin update office@dev-office --scope project" && ok "office en el proyecto dos, desde su carpeta" || fail "office en el proyecto dos, desde su carpeta"
called "$P1|plugin update dept-backend@dev-office --scope project" && ok "departamento del proyecto uno" || fail "departamento del proyecto uno"
called "otro@otro-market" && fail "no toca plugins de otros marketplaces" || ok "no toca plugins de otros marketplaces"
called "dept-frontend" && fail "saltea un proyecto que ya no existe" || ok "saltea un proyecto que ya no existe"
grep -q "ya no existe" "$WORK/out.txt" && ok "avisa del proyecto que ya no existe" || fail "avisa del proyecto que ya no existe"
grep -q "echo nuevo" "$P1/.claude/office-agents.sh" && ok "refresca office-agents.sh si es más viejo" || fail "refresca office-agents.sh si es más viejo"
grep -q "echo propio" "$P2/.claude/office-agents.sh" && ok "no pisa un office-agents.sh más nuevo" || fail "no pisa un office-agents.sh más nuevo"
[ ! -f "$P1/.claude/update-office.sh" ] && ok "no crea scripts que el proyecto no tenía" || fail "no crea scripts que el proyecto no tenía"
grep -q "0.13.0 → 0.14.0" "$WORK/out.txt" && ok "muestra las versiones antes y después" || { fail "muestra las versiones antes y después"; cat "$WORK/out.txt"; }
grep -q "ya estaba al día" "$WORK/out.txt" && ok "marca lo que ya estaba al día" || fail "marca lo que ya estaba al día"

# Sin plugins de dev-office.
echo '[{"id":"otro@otro-market","scope":"user","version":"1.0.0"}]' >"$WORK/none.json"
FAKE_BEFORE="$WORK/none.json" run
[ "$RC" -eq 0 ] && grep -q "No hay plugins de dev-office" "$WORK/out.txt" && ! called "plugin update" && ok "sin la oficina instalada: avisa y no hace nada" || fail "sin la oficina instalada: avisa y no hace nada"

# Falla el marketplace.
FAKE_MARKET_FAIL=1 run
[ "$RC" -eq 1 ] && ! called "plugin update" && ok "si falla el marketplace, frena" || fail "si falla el marketplace, frena"

# Sin claude.
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
for t in bash jq grep sed tr cat head sort mkdir cp dirname; do ln -s "$(command -v $t)" "$EMPTY/$t"; done
PATH="$EMPTY" "$(command -v bash)" "$SCRIPT" --yes >"$WORK/out.txt" 2>&1
[ $? -eq 1 ] && grep -q "No encontré el comando claude" "$WORK/out.txt" && ok "sin Claude Code: avisa" || fail "sin Claude Code: avisa"

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
