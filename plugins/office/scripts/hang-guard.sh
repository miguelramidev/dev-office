#!/usr/bin/env bash
# Hook PreToolUse (Bash) de dev-office: frena los comandos que no terminan solos y dejarían al
# agente colgado esperando: servidores de desarrollo, modo watch, tail -f, un git commit que
# abre el editor, el reporte de Playwright que se queda sirviendo, o algo mandado a segundo
# plano con & sin redirigir su salida. Sale con 2 y le explica al agente cómo correrlo bien
# (el mensaje de stderr le llega); con 0 deja pasar.
#
# Lo que va con run_in_background: true pasa (salvo lo interactivo, que tampoco termina ahí),
# y lo que empieza con "timeout" también: ya tiene un tope.
# OFFICE_HANG_GUARD=off lo apaga.

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"

[ "${OFFICE_HANG_GUARD:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
[ "$(json_get '.tool_name // empty')" = "Bash" ] || exit 0
COMMAND=$(json_get '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
BACKGROUND=$(json_get '.tool_input.run_in_background // false')

# m <texto> <expresión regular>: sin procesos aparte (en Windows, cada grep tarda).
m() { [[ $1 =~ $2 ]]; }

stop() {
  printf 'dev-office: este comando no termina solo y te dejaría colgado: %s\n%s\n' "$1" "$2" >&2
  exit 2
}

BG_HINT="Si lo necesitás corriendo (por ejemplo, un servidor para probar contra él), lanzalo con run_in_background: true y cerralo cuando termines (con la herramienta para detener procesos en segundo plano). Si solo querías verificar algo, usá el comando que corre una vez y termina."

# Algo mandado a segundo plano con & dentro del comando: su salida sigue atada a la herramienta,
# que espera a que termine. Pasa si redirige la salida (> archivo 2>&1 &).
if printf '%s\n' "$COMMAND" | grep -qE '(^|[^&>|])&[[:space:]]*($|;|\))' && ! printf '%s' "$COMMAND" | grep -qE '>'; then
  stop "lo mandás a segundo plano con &, pero su salida sigue atada a la herramienta." \
    "Usá run_in_background: true en vez de &, o redirigí la salida: comando > .office/proceso.log 2>&1 &"
fi

# Cada parte del comando (separadas por &&, ||, ;, | o saltos de línea), sin las variables de
# entorno del principio ni los lanzadores (npx, pnpm exec...).
SEGMENTS=$(printf '%s\n' "$COMMAND" | sed -E 's/(&&|\|\||;|\|)/\n/g')
while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -z "$seg" ] && continue
  ENVS=""
  while m "$seg" '^[A-Za-z_][A-Za-z0-9_]*=[^ ]* '; do
    ENVS="$ENVS ${seg%% *}"
    seg="${seg#* }"
  done
  case "$seg" in timeout\ * | gtimeout\ *) continue ;; esac
  # Mandado a segundo plano con su salida redirigida (lo revisó el control de arriba): no espera.
  case "$seg" in *[!\&]\&) continue ;; esac
  seg=$(printf '%s' "$seg" | sed -E 's#^(npx( --yes| -y)?|pnpm (exec|dlx)|yarn (exec|dlx)|bunx|bun x|npm exec( --)?) +##; s#^(\./)?node_modules/\.bin/##')

  # --- Interactivos: tampoco terminan en segundo plano -----------------------------------
  if m "$seg" '^git( -C [^ ]+)? commit( |$)' \
    && ! m "$seg" '( -[A-Za-z]*[mFC]|--message|--file|--no-edit|--reuse-message|--fixup|--squash)' \
    && [ "${GIT_EDITOR:-}" != true ] && [ "${GIT_EDITOR:-}" != : ] && ! m "$ENVS" 'GIT_EDITOR=(true|:)'; then
    stop "git commit sin mensaje abre el editor y espera." "Pasá el mensaje: git commit -m \"...\" (o -F archivo)."
  fi
  if m "$seg" '^git( -C [^ ]+)? rebase( .*)? (-i|--interactive)( |$)'; then
    stop "git rebase -i abre el editor y espera." "Hacé el rebase sin -i, o pedíselo al CEO."
  fi
  if m "$seg" '^git( -C [^ ]+)? (add|checkout|reset|restore|stash)( .*)? (-p|--patch|-i|--interactive)( |$)'; then
    stop "el modo -p o -i de git pregunta parte por parte y espera." "Nombrá los archivos sin -p."
  fi
  if m "$seg" '^(npm|pnpm|yarn|bun) init( |$)' && ! m "$seg" ' (-y|--yes)( |$)'; then
    stop "npm init pregunta y espera respuestas." "Usá npm init -y."
  fi
  if m "$seg" '^(vi|vim|nvim|nano|emacs|less|more|top|htop|man)( |$)'; then
    stop "${seg%% *} es interactivo y espera." "Para leer o editar archivos usá Read y Edit; para buscar, Grep."
  fi

  [ "$BACKGROUND" = true ] && continue

  # --- Servidores y procesos que esperan para siempre ---------------------------------------
  if m "$seg" '^(npm|pnpm|yarn|bun)( +--?[A-Za-z-]+(=[^ ]+)?( +[^- ][^ ]*)?)*( +run)? +(dev|start|serve|preview|develop)( |$)' \
    || m "$seg" '^(npm|pnpm|yarn|bun)( +--?[A-Za-z-]+(=[^ ]+)?( +[^- ][^ ]*)?)*( +run)? +[A-Za-z0-9:_-]*watch[A-Za-z0-9:_-]*( |$)' \
    || m "$seg" '^turbo( +run)? +(dev|start|watch)( |$)' \
    || m "$seg" '^(next|nuxt|nuxi|astro|remix|gatsby|svelte-kit|wrangler) +(dev|start|preview|develop|serve)( |$)' \
    || m "$seg" '^vite( +(dev|serve|preview))?( +-[^ ]*( +[^- ][^ ]*)?)*$' \
    || m "$seg" '^(ng serve|expo start|react-native start|flutter run|webpack serve|webpack-dev-server|nodemon|ts-node-dev|tsx watch|php artisan serve|flask run|uvicorn|gunicorn|ngrok|http-server|live-server|serve)( |$)' \
    || m "$seg" '^((bin/)?rails (s|server)|(python3?|py) -m http\.server|(python3?|py) manage\.py runserver|dotnet watch|cargo watch|air)( |$)' \
    || { m "$seg" '^docker( |-)compose( .*)? up( |$)' && ! m "$seg" ' (-d|--detach)( |$)'; } \
    || m "$seg" '^(tail( .*)? -[A-Za-z]*[fF]|watch +[^-])'; then
    stop "levanta algo que se queda corriendo (\`$seg\`)." "$BG_HINT"
  fi

  # --- Tests y herramientas en modo watch ----------------------------------------------------
  if m "$seg" '( |^)--watch(All)?(=true)?( |$)' || m "$seg" '^(vitest +(watch|dev)|tsc( .*)? -w|gh run watch)( |$)'; then
    stop "corre en modo watch: espera cambios y no termina nunca (\`$seg\`)." \
      "Corré una vez y terminá: vitest run, jest --ci --watchAll=false, tsc --noEmit, gh run view (sin watch)."
  fi
  if m "$seg" '^ng test( |$)' && ! m "$seg" '--watch=false|--no-watch'; then
    stop "ng test queda en modo watch por defecto." "Corré: ng test --watch=false"
  fi
  if m "$seg" '^react-scripts test( |$)' && [ -z "${CI:-}" ] && ! m "$seg$ENVS" '--watchAll=false|CI=(true|1)'; then
    stop "react-scripts test queda en modo watch fuera de CI." "Corré: CI=true react-scripts test (o con --watchAll=false)"
  fi
  if m "$seg" '^playwright show-report( |$)'; then
    stop "playwright show-report deja un servidor sirviendo el reporte." "Leé el resultado en la salida de la prueba o en playwright-report/ con Read."
  fi
  if m "$seg" '^playwright test( |$)' && [ "${PLAYWRIGHT_HTML_OPEN:-}" != never ] && [ -z "${CI:-}" ] \
    && ! m "$seg$ENVS" '--reporter|PLAYWRIGHT_HTML_OPEN=never|CI=(true|1)'; then
    stop "playwright test, si algo falla, abre el reporte y se queda sirviéndolo." "Corré: PLAYWRIGHT_HTML_OPEN=never npx playwright test ... (o con --reporter=list)"
  fi
done <<EOF
$SEGMENTS
EOF
exit 0
