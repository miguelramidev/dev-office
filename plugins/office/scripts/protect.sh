#!/usr/bin/env bash
# Hook PreToolUse de dev-office: bloquea la edición de archivos sensibles.
# Recibe el JSON de la herramienta por stdin. Sale con 2 para bloquear (el mensaje
# de stderr le llega al agente) y con 0 para permitir.

if ! command -v jq >/dev/null 2>&1; then
  echo "dev-office: falta 'jq' y no se puede verificar qué archivo se edita. Instalalo (sudo apt install jq / brew install jq)." >&2
  exit 2
fi

FILE_PATH=$(jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

NAME=$(basename "$FILE_PATH")

block() {
  echo "dev-office: no está permitido editar $FILE_PATH ($1). Si hace falta, pedile al CEO que lo haga a mano." >&2
  exit 2
}

case "$NAME" in
  .env.example | .env.sample | .env.template) ;;
  .env | .env.*) block "contiene secretos" ;;
  *.pem | *.key | id_rsa | id_ed25519) block "es una clave privada" ;;
  pnpm-lock.yaml | package-lock.json | yarn.lock | bun.lockb | bun.lock) block "lo genera el gestor de paquetes" ;;
esac

case "$FILE_PATH" in
  */.git/* | .git/*) block "es interno de git" ;;
esac

exit 0