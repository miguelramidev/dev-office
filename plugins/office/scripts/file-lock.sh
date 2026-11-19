#!/usr/bin/env bash
# Hook de dev-office: dos agentes no editan el mismo archivo a la vez.
#
# Cuando la oficina trabaja en paralelo (dos tickets a la vez, o partes de un ticket), cada
# agente edita su propia lista de archivos. Este hook lo hace cumplir:
#   - PreToolUse (Edit, Write, NotebookEdit, MultiEdit) de un subagente: el primer agente que
#     edita un archivo lo reserva. Si otro agente que sigue trabajando ya lo tiene, bloquea
#     (código 2) y le dice quién lo tiene, para que siga con sus archivos y lo diga en su reporte.
#   - SubagentStop: libera los archivos del agente que terminó.
#   - SessionStart: empieza sin reservas.
# Una reserva vence si su agente no edita nada en OFFICE_LOCK_TTL segundos (30 minutos por
# defecto), por si un agente se cortó sin avisar. El PM (la sesión principal) no reserva:
# no edita código. No cuida .qa/ ni .office/, ni los archivos de fuera del proyecto.
# Los cambios con comandos (sed, git mv) y los de Codex o Gemini no pasan por acá: esos los
# cuida el plan del PM (cada encargo con su lista de archivos) y el puente, que avisa al
# terminar si tocaron algo de otro. Se apaga con OFFICE_FILE_LOCKS=off.
# Las reservas están en .office/locks.tsv: <ruta> <agente> <tipo de agente> <última edición>.

[ "${OFFICE_FILE_LOCKS:-}" = "off" ] && exit 0

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]//\\//}")/lib.sh"
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
EVENT=$(json_get '.hook_event_name // empty')
AGENT=$(json_get '.agent_id // empty')
PROJECT=$(norm_path "${CLAUDE_PROJECT_DIR:-$PWD}")
PROJECT="${PROJECT%/}"
DIR="$PROJECT/.office"
LOCKS="$DIR/locks.tsv"
TTL="${OFFICE_LOCK_TTL:-1800}"
NOW=$(date +%s)

# Sección crítica: dos hooks pueden correr a la vez. mkdir es atómico en todos los sistemas.
MUTEX="$DIR/locks.mutex"
acquire() {
  local i=0
  mkdir -p "$DIR" 2>/dev/null || return 1
  until mkdir "$MUTEX" 2>/dev/null; do
    i=$((i + 1))
    # Un mutex de más de 10 segundos quedó de un hook que se cortó.
    if [ "$i" -ge 50 ]; then rm -rf "$MUTEX"; mkdir "$MUTEX" 2>/dev/null && return 0; return 1; fi
    sleep 0.2
  done
}
release() { rm -rf "$MUTEX"; }

case "$EVENT" in
  SessionStart)
    rm -f "$LOCKS"; rm -rf "$MUTEX"
    exit 0
    ;;
  SubagentStop)
    [ -n "$AGENT" ] && [ -f "$LOCKS" ] || exit 0
    acquire || exit 0
    awk -F '\t' -v a="$AGENT" '$2 != a' "$LOCKS" > "$LOCKS.tmp" && mv "$LOCKS.tmp" "$LOCKS"
    release
    exit 0
    ;;
  PreToolUse) ;;
  *) exit 0 ;;
esac

# Solo los subagentes reservan.
[ -n "$AGENT" ] || exit 0
FILE_PATH=$(json_get '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$FILE_PATH" ] || exit 0
FILE_PATH=$(norm_path "$FILE_PATH")
case "$FILE_PATH" in /*) ;; *) FILE_PATH="$PROJECT/$FILE_PATH" ;; esac
FILE_CMP=$(cmp_path "$FILE_PATH")
ROOT_CMP=$(cmp_path "$PROJECT")
case "$FILE_CMP" in
  "$ROOT_CMP"/.qa/* | "$ROOT_CMP"/.office/*) exit 0 ;;
  "$ROOT_CMP"/*) REL="${FILE_CMP#"$ROOT_CMP"/}" ;;
  *) exit 0 ;;
esac
TYPE=$(json_get '.agent_type // empty')
TYPE="${TYPE:-agente}"

acquire || exit 0
touch "$LOCKS"
# Saca las reservas vencidas y busca la de este archivo.
awk -F '\t' -v now="$NOW" -v ttl="$TTL" 'now - $4 <= ttl' "$LOCKS" > "$LOCKS.tmp" && mv "$LOCKS.tmp" "$LOCKS"
HOLDER=$(awk -F '\t' -v r="$REL" '$1 == r { print $2 "\t" $3 "\t" $4; exit }' "$LOCKS")
if [ -n "$HOLDER" ]; then
  H_AGENT=$(printf '%s' "$HOLDER" | cut -f1)
  H_TYPE=$(printf '%s' "$HOLDER" | cut -f2)
  H_AT=$(printf '%s' "$HOLDER" | cut -f3)
  if [ "$H_AGENT" != "$AGENT" ]; then
    release
    MIN=$(( (NOW - H_AT) / 60 ))
    {
      echo "dev-office: $REL lo está editando otro agente que sigue trabajando ($H_TYPE, última edición hace $MIN min)."
      echo "No lo edites: seguí con los archivos de tu encargo. Si lo necesitás para terminar, decilo en tu reporte (qué cambio y por qué) y el PM lo coordina cuando el otro termine."
    } >&2
    exit 2
  fi
fi
# Reserva nueva o renovada: este agente lo está editando ahora.
awk -F '\t' -v r="$REL" '$1 != r' "$LOCKS" > "$LOCKS.tmp" && mv "$LOCKS.tmp" "$LOCKS"
printf '%s\t%s\t%s\t%s\n' "$REL" "$AGENT" "$TYPE" "$NOW" >> "$LOCKS"
release
exit 0
