#!/usr/bin/env bash
# Funciones comunes de los hooks de dev-office. Se carga con "source" desde cada hook.
#
# Funciona en Linux, macOS (incluido el bash 3.2 que trae el sistema) y en Windows
# nativo con el bash de Git for Windows, que es el que usa Claude Code en Windows.

# Lee un campo del JSON que llega al hook (guardado en $INPUT) con un filtro de jq.
# Saca los "\r" del final: el jq de Windows escribe finales de línea CRLF y un
# "Bash\r" no se reconocería como "Bash".
# Uso: VALOR=$(json_get '.tool_input.command // empty')
json_get() {
  printf '%s' "$INPUT" | jq -r "$1" | tr -d '\r'
}

# Normaliza una ruta para poder compararla en cualquier sistema:
# - barras invertidas de Windows a "/" (C:\dev\app → C:/dev/app);
# - unidad de Windows al formato de Git Bash (C:/dev/app → /c/dev/app).
# Las rutas de Linux y macOS quedan igual.
norm_path() {
  local p="$1"
  p="${p//\\//}"
  case "$p" in
    [A-Za-z]:/* | [A-Za-z]:)
      local drive
      drive=$(printf '%s' "${p:0:1}" | tr '[:upper:]' '[:lower:]')
      p="/$drive${p:2}"
      ;;
  esac
  printf '%s' "$p"
}

# Indica si el sistema distingue mayúsculas en las rutas. En Windows no:
# "C:/Dev/App" y "c:/dev/app" son la misma carpeta.
paths_case_insensitive() {
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) return 0 ;;
  esac
  return 1
}

# Pasa una ruta normalizada a minúsculas si el sistema no distingue mayúsculas,
# para comparar rutas de la misma forma.
cmp_path() {
  if paths_case_insensitive; then
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
  else
    printf '%s' "$1"
  fi
}

# Instrucciones para instalar jq según el sistema.
jq_install_hint() {
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) echo "En Windows (PowerShell): winget install jqlang.jq, y después reiniciá Claude Code." ;;
    darwin*) echo "En macOS: brew install jq." ;;
    *) echo "En Linux: sudo apt install jq (o el gestor de paquetes de tu distribución)." ;;
  esac
}
