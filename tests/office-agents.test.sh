#!/usr/bin/env bash
# Pruebas del script que configura los proveedores por rol
# (plugins/office/skills/office-agents/office-agents.sh).
# Uso: bash tests/office-agents.test.sh

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/plugins/office/skills/office-agents/office-agents.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
mkdir -p "$PROJ"
(cd "$PROJ" && git init -q)

run() { (cd "$PROJ" && bash "$SCRIPT" "$@") 2>&1; }

# check <código esperado> <descripción> <argumentos...>
check() {
  local expected="$1" description="$2"
  shift 2
  run "$@" >"$WORK/out.txt"
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "ok    $description"
  else
    echo "FALLA $description (esperado $expected, salió $actual)"
    sed 's/^/      /' "$WORK/out.txt"
    FAILED=1
  fi
}

# same <esperado> <descripción> <argumentos...>: la salida es exactamente lo esperado.
same() {
  local expected="$1" description="$2" actual
  shift 2
  actual=$(run "$@" | tr '\n' ' ' | sed 's/ $//')
  if [ "$actual" = "$expected" ]; then
    echo "ok    $description"
  else
    echo "FALLA $description (esperado \"$expected\", salió \"$actual\")"
    FAILED=1
  fi
}

# Por defecto
same "claude" "sin configurar, un rol es claude" get backend.developer
same "" "sin configurar, el PM no tiene asesores" get pm

# set y get
check 0 "set de un developer" set backend.developer codex
same "codex" "get devuelve lo configurado" get backend.developer
check 0 "set con modelo" set frontend.developer gemini:pro
same "gemini:pro" "get con modelo" get frontend.developer
check 0 "varios QA" set qa claude codex
same "claude codex" "get de varios QA" get qa
check 0 "asesores del PM" set pm codex gemini
same "codex gemini" "get de los asesores" get pm
check 0 "claude con modelo" set backend.architect claude:opus
check 0 "agente del proyecto" set project.seo gemini
same "gemini" "get del agente del proyecto" get project.seo

if jq -e '.roles["backend.developer"] == ["codex"]' "$PROJ/.claude/office-agents.json" >/dev/null; then
  echo "ok    guarda en .claude/office-agents.json"
else
  echo "FALLA guarda en .claude/office-agents.json"
  FAILED=1
fi

# Archivo local
check 0 "set local" set backend.developer claude --local
same "claude" "el local manda" get backend.developer
run show >"$WORK/show.txt"
if grep -E '^backend\.developer +claude +local' "$WORK/show.txt" >/dev/null; then
  echo "ok    show marca el origen local"
else
  echo "FALLA show marca el origen local"
  FAILED=1
fi
check 0 "reset local" reset backend.developer --local
same "codex" "sin el local vuelve el del equipo" get backend.developer

# Reset
check 0 "reset de un rol" reset frontend.developer
same "claude" "después del reset vuelve a claude" get frontend.developer
check 0 "reset de todo" reset --all
same "claude" "después de reset --all, qa vuelve a claude" get qa

# Errores
check 1 "rol desconocido" set ventas.developer codex
check 1 "proveedor desconocido" set backend.developer openai
check 1 "dos proveedores en un developer" set backend.developer codex gemini
check 1 "claude como asesor del PM" set pm claude
check 1 "modelo de Claude inválido" set backend.tester claude:gpt
check 1 "modelo con caracteres raros" set backend.tester 'codex:a;rm'
check 1 "proveedor repetido en qa" set qa codex codex
check 1 "set sin proveedor" set backend.developer
check 1 "comando desconocido" otro

echo '{ roto' >"$PROJ/.claude/office-agents.json"
check 1 "JSON roto" get backend.developer
rm "$PROJ/.claude/office-agents.json"

# check: sin los CLIs instalados
run set backend.developer codex >/dev/null
EMPTY_PATH="$WORK/emptybin"
mkdir -p "$EMPTY_PATH"
for tool in git jq awk sed tr cut sort mkdir mv cat dirname grep head bash env; do
  p=$(command -v "$tool") && ln -s "$p" "$EMPTY_PATH/$tool"
done
BASH_BIN=$(command -v bash)
(cd "$PROJ" && PATH="$EMPTY_PATH" "$BASH_BIN" "$SCRIPT" check) >"$WORK/out.txt" 2>&1
if [ $? -ne 0 ] && grep -q "FALTA codex" "$WORK/out.txt"; then
  echo "ok    check avisa que falta codex"
else
  echo "FALLA check avisa que falta codex"
  sed 's/^/      /' "$WORK/out.txt"
  FAILED=1
fi

# check con CLIs falsos: codex viejo y agy con una cuenta sin Gemini 4 Argon.
FAKE_BIN="$WORK/fakebin"
mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\ncase "$1" in\n  --version) echo "codex-cli 0.150.2" ;;\n  login) exit 0 ;;\nesac\n' >"$FAKE_BIN/codex"
printf '#!/usr/bin/env bash\n[ "$1" = models ] && printf "gemini-3.8-flash\\ngemini-3.5-flash-lite\\n"\n' >"$FAKE_BIN/agy"
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/agy"
run set frontend.developer gemini >/dev/null
(cd "$PROJ" && PATH="$FAKE_BIN:$EMPTY_PATH" "$BASH_BIN" "$SCRIPT" check) >"$WORK/out.txt" 2>&1
CHECK_RC=$?
for want in "ok    codex: instalado y con sesión" "necesita Codex CLI 0.153.0" "ok    gemini: Antigravity CLI instalado" "no tiene el modelo 'gemini-4-argon'"; do
  if grep -qF "$want" "$WORK/out.txt"; then
    echo "ok    check: $want"
  else
    echo "FALLA check: falta \"$want\""
    sed 's/^/      /' "$WORK/out.txt"
    FAILED=1
  fi
done
[ "$CHECK_RC" -ne 0 ] && echo "ok    check: con avisos sale con error" || { echo "FALLA check: con avisos tendría que salir con error"; FAILED=1; }
if grep -qF "gemini-3.8-flash'" "$WORK/out.txt"; then
  echo "FALLA check: avisa por un modelo que la cuenta sí tiene"
  FAILED=1
else
  echo "ok    check: no avisa por los modelos que la cuenta tiene"
fi
run reset --all >/dev/null

# Tabla de modelos por nivel
same "gpt-6-astra" "nivel opus de codex" model codex opus
same "gpt-6.1-sol" "nivel sonnet de codex" model codex sonnet
same "gemini-4-argon" "nivel opus de gemini" model gemini opus
same "gemini-3.8-flash" "nivel sonnet de gemini" model gemini sonnet
same "medium" "razonamiento medio por defecto (codex)" effort codex
same "medium" "razonamiento medio por defecto (gemini)" effort gemini
check 0 "cambiar un modelo del equipo" tier codex opus gpt-7-algo
same "gpt-7-algo" "el modelo cambiado" model codex opus
check 0 "cambiar el razonamiento" tier gemini effort high
same "high" "el razonamiento cambiado" effort gemini
check 0 "cambiar un modelo solo para mí" tier codex opus gpt-mio --local
same "gpt-mio" "el local manda en la tabla" model codex opus
run models >"$WORK/models.txt"
if grep -E '^codex +opus +gpt-mio +local' "$WORK/models.txt" >/dev/null && grep -E '^codex +sonnet +gpt-6\.1-sol +dev-office' "$WORK/models.txt" >/dev/null; then
  echo "ok    models muestra el modelo y su origen"
else
  echo "FALLA models muestra el modelo y su origen"
  sed 's/^/      /' "$WORK/models.txt"
  FAILED=1
fi
check 0 "volver al de dev-office (local)" tier codex opus default --local
same "gpt-7-algo" "sin el local vuelve el del equipo" model codex opus
check 0 "volver al de dev-office (equipo)" tier codex opus default
same "gpt-6-astra" "vuelve el de dev-office" model codex opus
check 1 "tier con proveedor inválido" tier claude opus x
check 1 "tier con nivel inválido" tier codex mega x
check 1 "tier con valor raro" tier codex opus 'a b'
check 1 "model con nivel inválido" model codex effort
run tier gemini effort default >/dev/null

# Menú interactivo: elegir el rol por número y después volverlo al valor por defecto.
printf '2\ncodex gemini\n\n' | run >/dev/null
same "codex gemini" "menú: configura un rol por número" get qa
printf 'qa\n\n\n' | run >/dev/null
same "claude" "menú: vacío vuelve al valor por defecto" get qa

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
