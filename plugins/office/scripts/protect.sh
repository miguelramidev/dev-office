#!/usr/bin/env bash
# Hook PreToolUse de dev-office: bloquea la edición de archivos sensibles.
# Recibe el JSON de la herramienta por stdin. Sale con 2 para bloquear (el mensaje
# de stderr le llega al agente) y con 0 para permitir.
#
# - Edit, Write y NotebookEdit: revisa la ruta del archivo.
# - Bash: revisa si el comando menciona archivos de secretos o claves privadas,
#   para que no se puedan leer ni modificar con cat, sed, echo, cp, etc.

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "dev-office: falta 'jq' y no se puede verificar qué archivo se toca. $(jq_install_hint)" >&2
  exit 2
fi

INPUT=$(cat)
TOOL=$(json_get '.tool_name // empty')

block() {
  echo "dev-office: no está permitido tocar $1 ($2). Si hace falta, pedile al CEO que lo haga a mano." >&2
  exit 2
}

# --- Bash ---------------------------------------------------------------------

if [ "$TOOL" = "Bash" ]; then
  COMMAND=$(json_get '.tool_input.command // empty')
  [ -z "$COMMAND" ] && exit 0

  # Se parte el comando en palabras y se mira el nombre de archivo de cada una
  # (lo que va después de la última "/", o de la última "\" en Windows). Así "process.env" no
  # cuenta, pero ".env", "apps/api/.env.local" o "apps\api\.env" sí. Las plantillas (.env.example, .env.sample,
  # .env.template) están permitidas.
  NAMES=$(printf '%s' "$COMMAND" | tr " \t\n\"'=<>();|&\`" '\n' | sed 's#.*[/\\]##')

  ENV_FILE=$(printf '%s\n' "$NAMES" \
    | grep -xE '\.env(\.[[:alnum:]_-]+)*' \
    | grep -vxE '\.env\.(example|sample|template)' \
    | head -n1 || true)
  [ -n "$ENV_FILE" ] && block "$ENV_FILE" "contiene secretos"

  KEY_FILE=$(printf '%s\n' "$NAMES" | grep -xE 'id_rsa|id_ed25519|.+\.pem' | head -n1 || true)
  [ -n "$KEY_FILE" ] && block "$KEY_FILE" "es una clave privada"

  exit 0
fi

# --- Edit, Write y NotebookEdit -----------------------------------------------

FILE_PATH=$(json_get '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Rutas de Windows (C:\proyecto\.env) a la forma con "/" para revisarlas igual.
FILE_PATH=$(norm_path "$FILE_PATH")
NAME="${FILE_PATH##*/}"

case "$NAME" in
  .env.example | .env.sample | .env.template) ;;
  .env | .env.*) block "$FILE_PATH" "contiene secretos" ;;
  *.pem | *.key | id_rsa | id_ed25519) block "$FILE_PATH" "es una clave privada" ;;
  pnpm-lock.yaml | package-lock.json | yarn.lock | bun.lockb | bun.lock) block "$FILE_PATH" "lo genera el gestor de paquetes" ;;
esac

case "$FILE_PATH" in
  */.git/* | .git/*) block "$FILE_PATH" "es interno de git" ;;
esac

exit 0