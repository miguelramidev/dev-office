#!/usr/bin/env bash
# Pruebas de la revisión de consumo (plugins/office/skills/save-tokens/token-check.sh).
# Uso: bash tests/save-tokens.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/plugins/office/skills/save-tokens/token-check.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
export HOME="$WORK/home"; mkdir -p "$HOME"

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
has() { if printf '%s' "$out" | grep -qF -- "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
hasnt() { if printf '%s' "$out" | grep -qF -- "$2"; then fail "$1" "$out"; else ok "$1"; fi; }
run() { out=$(cd "$1" && bash "$CHECK" 2>&1); code=$?; }

grep -q '^# token-check-version: [0-9]' "$CHECK" && ok "el script tiene versión" || fail "el script tiene versión"

# Proyecto sin CLAUDE.md ni configuración.
P1="$WORK/vacio"; mkdir -p "$P1"; (cd "$P1" && git init -q)
run "$P1"
[ "$code" -eq 0 ] && ok "sin nada: termina bien" || fail "sin nada: termina bien" "$out"
has "sin CLAUDE.md: lo avisa" "no hay"
has "QA por defecto: claude" "**QA:** claude."

# Proyecto con CLAUDE.md largo, sin tests relacionados, con tres QA, asesor, equipos y departamentos.
P2="$WORK/pesado"; mkdir -p "$P2/.claude" "$P2/docs" "$P2/.office/observer"; (cd "$P2" && git init -q)
head -c 40000 /dev/zero | tr '\0' 'a' >"$P2/docs/reglas.md"
printf 'Reglas del proyecto\n@docs/reglas.md\n- Tests: pnpm test\n' >"$P2/CLAUDE.md"
printf '{"roles":{"qa":["claude","codex","gemini"],"pm":["codex"]},"teams":true}' >"$P2/.claude/office-agents.local.json"
printf '{"enabledPlugins":{"office@dev-office":true,"dept-frontend@dev-office":true,"dept-scraper@dev-office":false}}' >"$P2/.claude/settings.local.json"
printf '{"enabledPlugins":{"dept-backend@dev-office":true}}' >"$HOME/.claude.settings.tmp"; mkdir -p "$HOME/.claude"; mv "$HOME/.claude.settings.tmp" "$HOME/.claude/settings.json"
echo 'OFFICE_EVENT({"type":"stop","t":1,"agent":"a","agent_type":"dept-frontend:developer","usage":{"i":0,"o":0,"cw":400000}});' >"$P2/.office/observer/events.js"
echo 'OFFICE_EVENT({"type":"stop","t":2,"agent":"a","agent_type":"dept-frontend:developer","usage":{"i":0,"o":0,"cw":100000},"resumed":true});' >>"$P2/.office/observer/events.js"
run "$P2"
has "suma lo que importa con @" "con lo que importa (docs/reglas.md)"
has "CLAUDE.md largo: lo avisa" "Es largo"
has "sin tests relacionados: lo avisa" "No tiene un comando para correr solo los tests relacionados"
has "tres QA: propone menos" "Con tres QA"
has "asesores: los nombra" "**Asesores del PM:** codex."
has "modo equipos: lo nombra" "**Modo equipos:** encendido"
has "departamentos de usuario y de proyecto" "dept-backend dept-frontend."
hasnt "un departamento desactivado no cuenta" "dept-scraper"
has "lo que más gastó, sumando las vueltas" "dept-frontend:developer 500k en 2 vueltas"

# Proyecto con CLAUDE.md corto y comandos acotados.
P3="$WORK/liviano"; mkdir -p "$P3"; (cd "$P3" && git init -q)
printf -- '- Tests de lo que cambiaste: pnpm vitest related <archivos> --run --reporter=dot\n' >"$P3/CLAUDE.md"
run "$P3"
has "CLAUDE.md corto: menos de 1k" "menos de 1k tokens"
hasnt "CLAUDE.md corto: no lo marca largo" "Es largo"
has "tests relacionados: lo reconoce" "Tiene un comando para correr solo los tests relacionados"
has "salida corta: la reconoce" "Indica una salida corta"
has "sin mapa: lo avisa" "**Mapa del proyecto:** no hay"
has "sin índice: lo avisa" "**Índice de archivos:** no hay. Se arma solo"

# Con mapa enlazado e índice.
mkdir -p "$P3/docs" "$P3/.office/index"
printf '# Mapa\n' >"$P3/docs/project-map.md"
printf '\n## Dónde está cada cosa\n- Mapa: `docs/project-map.md`\n' >>"$P3/CLAUDE.md"
printf 'a.ts\tx\nb.ts\ty\n' >"$P3/.office/index/files.tsv"
run "$P3"
has "con mapa: lo reconoce" "**Mapa del proyecto:** docs/project-map.md"
has "con índice: cuenta los archivos" "**Índice de archivos:** 2 archivos"

[ "$FAILED" -eq 0 ] && echo "Todo bien." || echo "Hubo fallas."
exit "$FAILED"
