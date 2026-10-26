#!/usr/bin/env bash
# Pruebas del script que corre encargos con Codex o Gemini
# (plugins/office/skills/external-agents/run-external.sh).
# Usa CLIs falsos de codex y gemini que hacen lo que diga FAKE_MODE, en un proyecto de
# prueba, y compara el código de salida y el resumen. Uso: bash tests/run-external.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$REPO/plugins/office/skills/external-agents/run-external.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

# --- CLIs falsos --------------------------------------------------------------

FAKE_BIN="$WORK/bin"
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
esac
exit 0
EOF

cat >"$FAKE_BIN/gemini" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FAKE_ARGS"
cat >"$FAKE_STDIN"
case "${FAKE_MODE:-ok}" in
  ok) echo "// cambio" >>src/app.ts; echo "Hecho: listo." ;;
  noop) echo "Hecho: nada que cambiar." ;;
  silent) ;;
  auth) echo "Please set an Auth method" >&2; exit 41 ;;
esac
exit 0
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/gemini"

# PATH sin codex ni gemini reales, para que las pruebas no dependan de lo instalado.
CLEAN_PATH=""
IFS=':' read -r -a PATH_DIRS <<<"$PATH"
for d in "${PATH_DIRS[@]}"; do
  [ -x "$d/codex" ] || [ -x "$d/gemini" ] && continue
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
  rm -f "$FAKE_ARGS" "$FAKE_STDIN"
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

new_project
FAKE_MODE=ok check 0 "codex: con modelo" backend.developer codex --model gpt-x
expect "$FAKE_ARGS" "-m gpt-x" "codex: pasa el modelo"

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

# --- Gemini ---------------------------------------------------------------------

new_project
FAKE_MODE=ok check 0 "gemini: developer" frontend.developer gemini --model pro
expect "$FAKE_ARGS" "--approval-mode auto_edit" "gemini: edita sin preguntar"
expect "$FAKE_ARGS" "-m pro" "gemini: pasa el modelo"
expect "$FAKE_STDIN" "no podés correr comandos" "gemini: el prompt le avisa que no corre comandos"
expect "$PROJ/.office/runs/r1/output.md" "Hecho: listo." "gemini: guarda la salida como reporte"

new_project
FAKE_MODE=noop check 0 "gemini: asesor del PM" pm gemini
expect "$FAKE_ARGS" "--approval-mode default" "gemini: asesor sin aprobar herramientas"

new_project
FAKE_MODE=auth check 2 "gemini sin credenciales (código 41)" frontend.developer gemini
new_project
FAKE_MODE=silent check 3 "gemini sin respuesta" frontend.developer gemini

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
