#!/usr/bin/env bash
# Pruebas del hook de protección (plugins/office/scripts/protect.sh).
# Cada caso manda el JSON de una herramienta y compara el código de salida:
# 2 = bloqueado, 0 = permitido. Uso: bash tests/protect.test.sh

HOOK="$(dirname "$0")/../plugins/office/scripts/protect.sh"
FAILED=0

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
file_tool() { jq -cn --arg t "$1" --arg p "$2" '{tool_name: $t, tool_input: {file_path: $p}}'; }

# Edit, Write y NotebookEdit
check 2 "Write sobre .env"                  "$(file_tool Write /p/.env)"
check 2 "Edit sobre .env.production"        "$(file_tool Edit /p/apps/api/.env.production)"
check 0 "Write sobre .env.example"          "$(file_tool Write /p/.env.example)"
check 2 "Edit sobre una clave .pem"         "$(file_tool Edit /p/certs/server.pem)"
check 2 "Edit sobre un lockfile"            "$(file_tool Edit /p/pnpm-lock.yaml)"
check 2 "Write dentro de .git"              "$(file_tool Write /p/.git/config)"
check 0 "Edit sobre código normal"          "$(file_tool Edit /p/src/app.ts)"
check 2 "NotebookEdit sobre .env" '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/p/.env"}}'

# Bash
check 2 "cat .env"                          "$(bash_cmd 'cat .env')"
check 2 "sed sobre .env de una subcarpeta"  "$(bash_cmd 'sed -i s/a/b/ apps/api/.env.production')"
check 2 "echo >> .env.local"                "$(bash_cmd 'echo X >> .env.local')"
check 2 "echo X>.env sin espacios"          "$(bash_cmd 'echo X>.env')"
check 2 "cp de la plantilla a .env"         "$(bash_cmd 'cp .env.example .env')"
check 2 "leer una clave privada"            "$(bash_cmd 'cat ~/.ssh/id_rsa')"
check 2 "usar un .pem"                      "$(bash_cmd 'openssl x509 -in cert.pem')"
check 0 "cat .env.example"                  "$(bash_cmd 'cat .env.example')"
check 0 "process.env en código"             "$(bash_cmd 'node -e "console.log(process.env.PORT)"')"
check 0 "buscar dotenv"                     "$(bash_cmd 'grep -r dotenv src')"
check 0 "correr tests"                      "$(bash_cmd 'pnpm test')"
check 0 "git status"                        "$(bash_cmd 'git status')"
check 0 "borrar .qa"                        "$(bash_cmd 'rm -r .qa')"

exit $FAILED