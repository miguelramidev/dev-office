#!/usr/bin/env bash
# update-office-version: 1
# Actualiza la oficina dev-office en todos tus proyectos de una vez.
#
#   1. Actualiza el marketplace dev-office.
#   2. Actualiza cada plugin de dev-office instalado, en su scope: los de usuario una vez,
#      y los de proyecto (o locales) en la carpeta de cada proyecto donde estén instalados.
#   3. Refresca en cada proyecto los scripts que la oficina copió en .claude/
#      (office-agents, office-telegram y estos lanzadores), si hay una versión más nueva.
#   4. Muestra las versiones antes y después.
#
# Uso: bash update-office.sh [--yes]
#   Con doble click: update-office.cmd (Windows) o update-office.command (macOS).
#   --yes  no espera una tecla al terminar (para correrlo desde otra herramienta).
#
# Necesita: Claude Code (el comando claude) y jq.
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

MARKET="dev-office"
WAIT=1
[ "${1:-}" = "--yes" ] && WAIT=0

finish() {
  echo
  [ "$WAIT" -eq 1 ] && [ -t 0 ] && { printf 'Tocá Enter para cerrar...'; read -r _; }
  exit "$1"
}

say() { printf '%s\n' "$*"; }

command -v claude >/dev/null 2>&1 || { say "No encontré el comando claude. Instalá Claude Code o abrí una terminal donde funcione 'claude --version'."; finish 1; }
command -v jq >/dev/null 2>&1 || {
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) say "Falta jq. En PowerShell: winget install jqlang.jq, y después volvé a abrir este script." ;;
    darwin*) say "Falta jq. Instalalo con: brew install jq" ;;
    *) say "Falta jq. Instalalo con: sudo apt install jq" ;;
  esac
  finish 1
}

# Rutas de Windows (C:\dev\app) a la forma de Git Bash para poder entrar a la carpeta.
to_bash_path() {
  local p="${1//\\//}"
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$p" 2>/dev/null && return; fi
  printf '%s' "$p"
}

# Versión de los scripts copiados: la línea "<nombre>-version: N".
script_version() { grep -m1 -oE -- '-version: [0-9]+' "$1" 2>/dev/null | grep -oE '[0-9]+'; }

installs() {
  claude plugin list --json 2>/dev/null | tr -d '\r' | jq -c --arg m "@$MARKET" '.[] | select(.id | endswith($m))' 2>/dev/null
}

say "Oficina dev-office: actualización"
say "================================="
BEFORE=$(installs)
if [ -z "$BEFORE" ]; then
  say "No hay plugins de dev-office instalados en esta computadora."
  say "Instalá la oficina en un proyecto con: claude plugin install office@$MARKET --scope project"
  finish 0
fi

say
say "1. Marketplace"
if ! claude plugin marketplace update "$MARKET"; then
  say "No pude actualizar el marketplace $MARKET. Revisá tu conexión y volvé a intentar."
  finish 1
fi

say
say "2. Plugins"
PROBLEMS=0
DONE_USER=""
while IFS= read -r row; do
  [ -z "$row" ] && continue
  id=$(printf '%s' "$row" | jq -r '.id')
  scope=$(printf '%s' "$row" | jq -r '.scope')
  project=$(printf '%s' "$row" | jq -r '.projectPath // empty')
  case "$scope" in
    user | managed)
      case " $DONE_USER " in *" $id "*) continue ;; esac
      DONE_USER="$DONE_USER $id"
      say "- $id (usuario)"
      claude plugin update "$id" --scope "$scope" || PROBLEMS=$((PROBLEMS + 1))
      ;;
    project | local)
      dir=$(to_bash_path "$project")
      if [ -z "$project" ] || [ ! -d "$dir" ]; then
        say "- $id en $project: la carpeta ya no existe, lo salteo."
        continue
      fi
      say "- $id en ${project}"
      (cd "$dir" && claude plugin update "$id" --scope "$scope") || PROBLEMS=$((PROBLEMS + 1))
      ;;
  esac
done <<EOF
$BEFORE
EOF

say
say "3. Scripts de la oficina en cada proyecto"
AFTER=$(installs)
OFFICE_DIR=$(printf '%s\n' "$AFTER" | jq -r 'select(.id | startswith("office@")) | .installPath' | head -n1)
OFFICE_DIR=$(to_bash_path "$OFFICE_DIR")
PROJECTS=$(printf '%s\n' "$AFTER" | jq -r '.projectPath // empty' | sort -u)
if [ -z "$OFFICE_DIR" ] || [ ! -d "$OFFICE_DIR" ]; then
  say "No encontré la carpeta del plugin office: los scripts quedan como estaban."
else
  refreshed=0
  while IFS= read -r project; do
    [ -z "$project" ] && continue
    dir=$(to_bash_path "$project")
    [ -d "$dir/.claude" ] || continue
    for pair in "office-agents/office-agents.sh" "office-agents/office-agents.cmd" "telegram/office-telegram.sh" "telegram/office-telegram.cmd" "update/update-office.sh" "update/update-office.cmd" "update/update-office.command"; do
      name="${pair##*/}"
      src="$OFFICE_DIR/skills/$pair"
      dst="$dir/.claude/$name"
      [ -f "$dst" ] && [ -f "$src" ] || continue
      new=$(script_version "$src"); old=$(script_version "$dst")
      if [ -n "$new" ] && [ "${old:-0}" -lt "$new" ]; then
        cp "$src" "$dst" && say "- $project: .claude/$name actualizado" && refreshed=$((refreshed + 1))
      fi
    done
  done <<EOF
$PROJECTS
EOF
  [ "$refreshed" -eq 0 ] && say "- Ya estaban al día."
fi

say
say "4. Versiones"
printf '%s\n' "$AFTER" | jq -r --argjson before "$(printf '%s\n' "$BEFORE" | jq -s 'map({key: (.id + "|" + .scope + "|" + (.projectPath // "")), value: .version}) | from_entries')" '
  (.id + "|" + .scope + "|" + (.projectPath // "")) as $k
  | "- \(.id | split("@")[0]) (\(if .projectPath then .projectPath else .scope end)): \($before[$k] // "?") → \(.version)\(if ($before[$k] // "") == .version then " (ya estaba al día)" else "" end)"'

say
if [ "$PROBLEMS" -gt 0 ]; then
  say "Hubo $PROBLEMS plugin(s) que no se pudieron actualizar: mirá los mensajes de arriba."
  finish 1
fi
say "Listo. Reiniciá Claude Code en los proyectos que tengas abiertos (o usá /reload-plugins) para que tomen la versión nueva."
finish 0
