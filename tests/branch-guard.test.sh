#!/usr/bin/env bash
# Pruebas de la guardia de ramas (plugins/office/scripts/branch-guard.sh).
# Crea un repositorio temporal, se para en distintas ramas y compara el código de
# salida de cada caso: 2 = bloqueado, 0 = permitido. Uso: bash tests/branch-guard.test.sh

HOOK="$(cd "$(dirname "$0")/.." && pwd)/plugins/office/scripts/branch-guard.sh"
REPO=$(mktemp -d)
trap 'rm -rf "$REPO"' EXIT
FAILED=0

git -C "$REPO" init -q -b main
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$REPO" branch dev
export CLAUDE_PROJECT_DIR="$REPO"

check() {
  local expected="$1" description="$2" json="$3"
  printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "ok    $description"
  else
    echo "FALLA $description (esperado $expected, salió $actual)"
    FAILED=1
  fi
}

bash_cmd() { jq -cn --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
edit() { jq -cn --arg p "$1" '{tool_name: "Edit", tool_input: {file_path: $p}}'; }

# --- Ramas protegidas por defecto: main y master --------------------------------
unset OFFICE_PROTECTED_BRANCHES
git -C "$REPO" switch -q main
check 2 "por defecto: editar en main"                 "$(edit "$REPO/src/app.ts")"
git -C "$REPO" switch -q dev
check 0 "por defecto: editar en dev"                  "$(edit "$REPO/src/app.ts")"

# --- Proyecto que protege main y dev ----------------------------------------------
export OFFICE_PROTECTED_BRANCHES="main dev"

git -C "$REPO" switch -q dev
check 2 "editar en dev"                               "$(edit "$REPO/src/app.ts")"
check 2 "editar con ruta relativa en dev"             "$(edit "src/app.ts")"
check 0 "editar en .qa/ en dev"                       "$(edit "$REPO/.qa/attack.spec.ts")"
check 0 "editar fuera del proyecto en dev"            "$(edit "/home/otro/notas.md")"
check 2 "commit en dev"                               "$(bash_cmd 'git commit -m "x"')"
check 2 "commit con -C en dev"                        "$(bash_cmd "git -C $REPO commit -m x")"
check 2 "merge en dev"                                "$(bash_cmd 'git merge feature')"
check 2 "push sin argumentos desde dev"               "$(bash_cmd 'git push')"
check 2 "push origin desde dev"                       "$(bash_cmd 'git push origin')"
check 0 "pull en dev"                                 "$(bash_cmd 'git pull origin dev')"
check 0 "status en dev"                               "$(bash_cmd 'git status')"
check 0 "tests en dev"                                "$(bash_cmd 'pnpm test')"
check 0 "crear rama desde dev"                        "$(bash_cmd 'git switch -c PROJ-123-alertas origin/dev')"

git -C "$REPO" switch -q -c PROJ-123-alertas
check 0 "editar en rama de trabajo"                   "$(edit "$REPO/src/app.ts")"
check 0 "commit en rama de trabajo"                   "$(bash_cmd 'git add -A && git commit -m "feat: x"')"
check 0 "push de la rama de trabajo"                  "$(bash_cmd 'git push -u origin PROJ-123-alertas')"
check 0 "push sin argumentos de la rama de trabajo"   "$(bash_cmd 'git push')"
check 0 "rama con 'dev' en el nombre"                 "$(bash_cmd 'git push origin feature/dev-tools')"
check 2 "push hacia dev"                              "$(bash_cmd 'git push origin dev')"
check 2 "push HEAD:main"                              "$(bash_cmd 'git push origin HEAD:main')"
check 2 "push forzado a refs/heads/dev"               "$(bash_cmd 'git push origin +PROJ-123-alertas:refs/heads/dev')"
check 2 "push --all"                                  "$(bash_cmd 'git push --all origin')"
check 2 "push hacia main después de otro comando"     "$(bash_cmd 'pnpm test && git push origin main')"

# --- Patrones: ramas de épica ---------------------------------------------------------
export OFFICE_PROTECTED_BRANCHES="main dev epic/*"
mkdir -p "$REPO/epic"   # una carpeta con ese nombre no tiene que afectar al patrón
git -C "$REPO" switch -q -c epic/PROJ-100-carrito dev
check 2 "patrón: editar en una épica"                 "$(edit "$REPO/src/app.ts")"
check 2 "patrón: commit en una épica"                 "$(bash_cmd 'git commit -m x')"
check 2 "patrón: push desde una épica"                "$(bash_cmd 'git push -u origin epic/PROJ-100-carrito')"
check 0 "patrón: crear una feature desde la épica"    "$(bash_cmd 'git switch -c feature/PROJ-123-productos origin/epic/PROJ-100-carrito')"
git -C "$REPO" switch -q -c feature/PROJ-123-productos
check 0 "patrón: editar en una feature"               "$(edit "$REPO/src/app.ts")"
check 0 "patrón: push de la feature"                  "$(bash_cmd 'git push -u origin feature/PROJ-123-productos')"
check 2 "patrón: push hacia una épica"                "$(bash_cmd 'git push origin HEAD:epic/PROJ-100-carrito')"
check 0 "patrón: rama que solo contiene 'epic'"       "$(bash_cmd 'git push origin feature/epic-ideas')"
rmdir "$REPO/epic"

# --- Guardia desactivada -------------------------------------------------------------
export OFFICE_PROTECTED_BRANCHES=""
git -C "$REPO" switch -q main
check 0 "desactivada: editar en main"                 "$(edit "$REPO/src/app.ts")"

# --- Fuera de un repositorio git ------------------------------------------------------
export OFFICE_PROTECTED_BRANCHES="main dev"
CLAUDE_PROJECT_DIR=$(mktemp -d) check 0 "fuera de un repositorio" "$(edit "/tmp/x/app.ts")"

exit $FAILED
