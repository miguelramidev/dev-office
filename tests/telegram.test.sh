#!/usr/bin/env bash
# Pruebas de la oficina remota por Telegram
# (plugins/office/skills/telegram/office-telegram.sh), con un curl falso: no se conecta a Telegram.
# Uso: bash tests/telegram.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/office/skills/telegram/office-telegram.sh"
CMD="$ROOT/plugins/office/skills/telegram/office-telegram.cmd"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
PROJ="$WORK/proj"
FAKE="$WORK/fake"
mkdir -p "$PROJ" "$FAKE/bin" "$FAKE/resp"
(cd "$PROJ" && git init -q -b dev)

# curl falso: anota "<método> <cuerpo>" en $FAKE/calls y responde lo que haya en
# $FAKE/resp/<método> (getUpdates responde una sola vez); si no hay nada, un ok genérico.
cat >"$FAKE/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""; for a in "$@"; do case "$a" in http*) url="$a" ;; esac; done
method="${url##*/}"
body=$(cat)
printf '%s %s\n' "$method" "$(printf '%s' "$body" | tr '\n' ' ')" >>"$FAKE/calls"
if [ -f "$FAKE/resp/$method" ]; then
  cat "$FAKE/resp/$method"
  [ "$method" = getUpdates ] && rm -f "$FAKE/resp/$method"
elif [ "$method" = getUpdates ]; then
  echo '{"ok":true,"result":[]}'
else
  echo '{"ok":true,"result":{"message_id":77}}'
fi
EOF
chmod +x "$FAKE/bin/curl"

export FAKE PATH="$FAKE/bin:$PATH"
export OFFICE_TELEGRAM_HOME="$WORK/home" OFFICE_TELEGRAM_NO_POLLER=1 CLAUDE_PROJECT_DIR="$PROJ"
STATE="$PROJ/.office/telegram"

run() { (cd "$PROJ" && bash "$SCRIPT" "$@"); }
hook() { local name="$1"; shift; printf '%s' "${1:-{\}}" | (cd "$PROJ" && bash "$SCRIPT" hook "$name"); }
calls() { cat "$FAKE/calls" 2>/dev/null; }
reset_calls() { rm -f "$FAKE/calls"; }

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
# expect <descripción> <condición de shell>
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$(calls)"; fi; }

# --- Sin configurar y con el modo remoto apagado, los hooks no hacen nada --------------
for h in context send permission; do
  out=$(hook "$h" '{"last_assistant_message":"hola","tool_name":"Bash","tool_input":{"command":"ls"}}' 2>&1); code=$?
  expect "hook $h apagado: sale con 0 sin salida ni llamadas" '[ $code -eq 0 ] && [ -z "$out" ] && [ -z "$(calls)" ]'
done
out=$(hook listen 2>&1); code=$?
expect "hook listen apagado: sale con 0 enseguida" '[ $code -eq 0 ] && [ -z "$out" ]'

# --- setup ---------------------------------------------------------------------------
echo '{"ok":false,"description":"Unauthorized"}' >"$FAKE/resp/getMe"
out=$(run setup 123:malo 2>&1); code=$?
expect "setup con un token inválido falla y no guarda nada" '[ $code -eq 1 ] && [ ! -f "$WORK/home/config.json" ]'

echo '{"ok":true,"result":{"username":"oficina_bot"}}' >"$FAKE/resp/getMe"
echo '{"ok":true,"result":[{"update_id":10,"message":{"chat":{"id":555,"type":"private"},"text":"hola"}}]}' >"$FAKE/resp/getUpdates"
reset_calls
out=$(run setup 123:bueno 2>&1); code=$?
expect "setup sin chat id lo toma del primer mensaje" '[ $code -eq 0 ] && [ "$(jq -r .chat "$WORK/home/config.json")" = 555 ]'
expect "setup guarda el nombre del bot" '[ "$(jq -r .bot "$WORK/home/config.json")" = oficina_bot ]'
expect "setup confirma en el chat" 'calls | grep -q "^sendMessage .*\"chat_id\":\"555\".*conectado"'
perms=$(ls -l "$WORK/home/config.json" | cut -c1-10)
expect "el archivo del bot es solo del usuario" '[ "$perms" = "-rw-------" ]'

out=$(run setup 123:bueno 999 2>&1); code=$?
expect "setup con chat id lo usa sin esperar mensajes" '[ $code -eq 0 ] && [ "$(jq -r .chat "$WORK/home/config.json")" = 999 ]'
out=$(run setup 123:bueno abc 2>&1); code=$?
expect "setup rechaza un chat id que no es número" '[ $code -eq 1 ]'

# Con el bot configurado pero el modo remoto apagado, los hooks siguen sin hacer nada.
reset_calls
out=$(hook send '{"last_assistant_message":"hola"}' 2>&1)
expect "con el modo remoto apagado no manda nada" '[ -z "$(calls)" ]'

# --- on ------------------------------------------------------------------------------
reset_calls
out=$(run on 2>&1); code=$?
expect "on enciende el modo remoto del proyecto" '[ $code -eq 0 ] && [ -f "$STATE/on" ]'
expect "on avisa en el chat con el proyecto y la rama" 'calls | grep -q "^sendMessage .*encendido: proj · dev"'

# --- hook context ----------------------------------------------------------------------
out=$(hook context)
expect "hook context le explica a Claude el puente" 'printf "%s" "$out" | jq -e ".hookSpecificOutput.additionalContext | contains(\"[Telegram · CEO]\")" >/dev/null'

# --- hook send -------------------------------------------------------------------------
reset_calls
hook send '{"last_assistant_message":"Terminé PROJ-123. Sugerencias: sumar tests."}' >/dev/null
expect "hook send manda el último mensaje del PM con encabezado" 'calls | grep -q "^sendMessage .*PM · proj · dev.*Terminé PROJ-123"'
reset_calls
long=$(awk 'BEGIN { for (i = 0; i < 300; i++) printf "linea %03d: el PM explica el proceso y sus sugerencias.\n", i }')
hook send "$(jq -cn --arg m "$long" '{last_assistant_message: $m}')" >/dev/null
n=$(calls | grep -c '^sendMessage')
maxlen=$(calls | sed 's/^sendMessage //' | jq -r '.text | length' | sort -n | tail -1)
expect "un mensaje largo se parte en varios de menos de 4096 caracteres ($n trozos)" '[ "$n" -ge 3 ] && [ "$maxlen" -le 4096 ]'
expect "los trozos se cortan entre líneas" '[ -z "$(calls | sed "s/^sendMessage //" | jq -r ".text" | grep -v "^linea [0-9][0-9][0-9]: el PM explica el proceso y sus sugerencias.$" | grep -v "^🧑" | grep -v "^$")" ]'
reset_calls
hook send '{"last_assistant_message":""}' >/dev/null
expect "hook send sin texto no manda nada" '[ -z "$(calls)" ]'

# --- hook listen -------------------------------------------------------------------------
jq -cn '{at: 1, text: "arrancá con PROJ-123"}' >>"$STATE/inbox.jsonl"
jq -cn '{at: 2, text: "y avisame al terminar"}' >>"$STATE/inbox.jsonl"
err=$(hook listen 2>&1 >/dev/null); code=$?
expect "hook listen despierta a la sesión (código 2) con los mensajes nuevos" '[ $code -eq 2 ] && printf "%s" "$err" | grep -q "^\[Telegram · CEO\] arrancá con PROJ-123"'
expect "hook listen junta los mensajes pendientes" 'printf "%s" "$err" | grep -q "y avisame al terminar"'
expect "hook listen anota lo que ya entregó" '[ "$(cat "$STATE/seen")" = 2 ]'
if command -v timeout >/dev/null 2>&1; then
  timeout 3 bash -c "printf '{}' | bash '$SCRIPT' hook listen" 2>/dev/null; code=$?
  expect "sin mensajes nuevos, hook listen se queda esperando" '[ $code -eq 124 ]'
fi

# --- hook permission ---------------------------------------------------------------------
PERM='{"tool_name":"Bash","agent_type":"backend.developer","tool_input":{"command":"npm run migrate"}}'
answer() { # answer <allow|deny>: responde el primer permiso pendiente, como el lector del bot
  local f i=0
  while [ $i -lt 50 ]; do
    f=$(ls "$STATE/perm" 2>/dev/null | grep -v '\.answer$' | head -1)
    [ -n "$f" ] && { printf '%s\n' "$1" >"$STATE/perm/$f.answer"; return; }
    sleep 0.1; i=$((i + 1))
  done
}
reset_calls
answer allow &
out=$(hook permission "$PERM"); wait
expect "permiso aprobado por Telegram: allow" '[ "$(printf "%s" "$out" | jq -r .hookSpecificOutput.decision.behavior)" = allow ]'
expect "el pedido muestra quién pide, la herramienta y el comando, con botones" 'calls | grep -q "^sendMessage .*backend.developer pide permiso · Bash.*npm run migrate.*inline_keyboard"'
expect "después de responder, el mensaje queda marcado como permitido" 'calls | grep -q "^editMessageText .*Permitido"'
expect "no quedan permisos pendientes" '[ -z "$(ls "$STATE/perm")" ]'
answer deny &
out=$(hook permission "$PERM"); wait
expect "permiso rechazado por Telegram: deny con explicación" '[ "$(printf "%s" "$out" | jq -r .hookSpecificOutput.decision.behavior)" = deny ] && printf "%s" "$out" | jq -e ".hookSpecificOutput.decision.message | contains(\"Telegram\")" >/dev/null'
reset_calls
out=$(OFFICE_TELEGRAM_PERM_WAIT=1 hook permission "$PERM"); code=$?
expect "sin respuesta a tiempo, el pedido pasa a la terminal (sin decisión)" '[ $code -eq 0 ] && [ -z "$out" ]'
expect "y el mensaje avisa que pasó a la terminal" 'calls | grep -q "^editMessageText .*pasó a la terminal"'

# --- Lector del bot ------------------------------------------------------------------------
: >"$STATE/perm/abcd1234"
cat >"$FAKE/resp/getUpdates" <<'EOF'
{"ok":true,"result":[
 {"update_id":20,"message":{"chat":{"id":999,"type":"private"},"text":"corré los tests"}},
 {"update_id":21,"message":{"chat":{"id":4242,"type":"private"},"text":"soy un extraño"}},
 {"update_id":22,"message":{"chat":{"id":999,"type":"private"},"text":"/estado"}},
 {"update_id":23,"callback_query":{"id":"q1","data":"p:abcd1234:allow","message":{"message_id":5,"chat":{"id":999}}}},
 {"update_id":24,"callback_query":{"id":"q2","data":"p:ffff0000:allow","message":{"message_id":6,"chat":{"id":999}}}},
 {"update_id":25,"callback_query":{"id":"q3","data":"p:abcd1234:allow","message":{"message_id":5,"chat":{"id":4242}}}}
]}
EOF
reset_calls
before=$(wc -l <"$STATE/inbox.jsonl")
now_ts=$(date +%s); echo "$now_ts" >"$STATE/alive"
OFFICE_TELEGRAM_POLL_ONCE=1 run _poll
after=$(wc -l <"$STATE/inbox.jsonl")
expect "el lector pasa a la oficina los textos de tu chat" '[ $((after - before)) -eq 1 ] && tail -1 "$STATE/inbox.jsonl" | grep -q "corré los tests"'
expect "el lector ignora otros chats" '! grep -q "extraño" "$STATE/inbox.jsonl"'
expect "/estado se responde sin despertar a la oficina" 'calls | grep -q "^sendMessage .*proj · dev.*La oficina está"'
expect "un botón responde el permiso pendiente" '[ "$(cat "$STATE/perm/abcd1234.answer")" = allow ]'
expect "un botón de un pedido que ya no está pendiente no aprueba nada" '[ ! -f "$STATE/perm/ffff0000.answer" ] && calls | grep -q "^answerCallbackQuery .*ya no está pendiente"'
expect "el lector guarda por dónde va" '[ "$(cat "$WORK/home/offset")" = 26 ]'
expect "el lector se suelta al terminar" '[ ! -f "$WORK/home/poll.json" ]'

# --- status, test y off ----------------------------------------------------------------------
out=$(run status 2>&1)
expect "status muestra el bot, el chat y el modo remoto" 'printf "%s" "$out" | grep -q "@oficina_bot · chat 999" && printf "%s" "$out" | grep -q "encendido"'
reset_calls
out=$(run test 2>&1); code=$?
expect "test manda un mensaje de prueba" '[ $code -eq 0 ] && calls | grep -q "^sendMessage .*Prueba de dev-office"'
reset_calls
out=$(run off 2>&1); code=$?
expect "off apaga el modo remoto y avisa" '[ $code -eq 0 ] && [ ! -f "$STATE/on" ] && calls | grep -q "^sendMessage .*apagado"'
reset_calls
out=$(hook send '{"last_assistant_message":"hola"}'; hook context)
expect "apagado, los hooks vuelven a no hacer nada" '[ -z "$out" ] && [ -z "$(calls)" ]'
out=$(run forget 2>&1)
expect "forget borra el bot guardado" '[ ! -f "$WORK/home/config.json" ]'

# --- Archivos --------------------------------------------------------------------------------
v_sh=$(grep -m1 '^# office-telegram-version:' "$SCRIPT" | awk '{print $3}')
v_cmd=$(grep -m1 'office-telegram-version:' "$CMD" | tr -d '\r' | awk '{print $3}')
expect "el .sh y el .cmd tienen la misma versión ($v_sh)" '[ -n "$v_sh" ] && [ "$v_sh" = "$v_cmd" ]'
expect "el .cmd tiene finales de línea CRLF" '[ "$(grep -c $'"'"'\r$'"'"' "$CMD")" -eq "$(wc -l <"$CMD" | tr -d " ")" ]'
expect "los hooks del plugin usan el script de la skill" 'grep -q "skills/telegram/office-telegram.sh\\\\\" hook permission" "$ROOT/plugins/office/hooks/hooks.json"'

if [ "$FAILED" -eq 0 ]; then
  echo "Todas las pruebas pasan."
else
  echo "Hay pruebas que fallan."
  exit 1
fi
