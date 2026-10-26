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
for tool in git jq awk sed tr cut sort mkdir mv cat dirname; do
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
