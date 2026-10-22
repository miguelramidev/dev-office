#!/usr/bin/env bash
# Revisa la colección de Postman del proyecto y sus entornos.
#
# Uso: bash check-collection.sh [--fix] [carpeta]
#   carpeta  donde está la colección (por defecto, docs/api).
#   --fix    reescribe los archivos con el formato fijo (claves ordenadas, sangría
#            de 2 espacios, finales de línea LF). No corrige nada más.
#
# Revisa:
#   - que haya una sola colección (*.postman_collection.json) y al menos un entorno
#     (environments/*.postman_environment.json), y que sean JSON válidos;
#   - que la colección use el formato v2.1;
#   - que no haya dos carpetas o requests con el mismo nombre en el mismo nivel;
#   - que las URLs usen {{baseUrl}} y no una dirección escrita a mano;
#   - que no haya secretos: variables con nombre de secreto con valor, autorizaciones
#     o headers Authorization con un valor escrito, o tokens JWT pegados;
#   - que cada variable {{...}} que usa la colección esté declarada en cada entorno
#     (o en las variables de la colección);
#   - que el formato sea el fijo, para que los diffs sean chicos.
#
# Sale con 0 si está todo bien y con 1 si encontró problemas (los lista).
# Funciona en Linux, macOS (bash 3.2) y Windows con el bash de Git for Windows.

FIX=0
DIR=""
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    -h | --help)
      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) DIR="$arg" ;;
  esac
done
DIR="${DIR:-docs/api}"
DIR="${DIR//\\//}"
DIR="${DIR%/}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Falta jq. Windows: winget install jqlang.jq · macOS: brew install jq · Linux: sudo apt install jq" >&2
  exit 1
fi

PROBLEMS=0
problem() {
  echo "PROBLEMA $1"
  PROBLEMS=$((PROBLEMS + 1))
}

# jq sin los "\r" que agrega el jq de Windows.
jqc() { jq "$@" | tr -d '\r'; }

if [ ! -d "$DIR" ]; then
  echo "No existe la carpeta $DIR: el proyecto todavía no tiene colección." >&2
  exit 1
fi

COLLECTIONS=$(find "$DIR" -maxdepth 1 -type f -name '*.postman_collection.json' | sort)
COUNT=$(printf '%s' "$COLLECTIONS" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then
  echo "No hay ninguna colección (*.postman_collection.json) en $DIR." >&2
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  problem "hay $COUNT colecciones en $DIR y tiene que haber una sola por proyecto:"
  printf '%s\n' "$COLLECTIONS" | sed 's/^/         /'
fi
COLLECTION=$(printf '%s\n' "$COLLECTIONS" | head -n1)

ENVS=$(find "$DIR/environments" -maxdepth 1 -type f -name '*.postman_environment.json' 2>/dev/null | sort)
[ -z "$ENVS" ] && problem "no hay entornos en $DIR/environments/ (por ejemplo local.postman_environment.json)"

# Archivos con JSON inválido: no se pueden revisar más.
ALL_FILES=$(printf '%s\n%s\n' "$COLLECTION" "$ENVS" | grep .)
VALID_FILES=""
while IFS= read -r f; do
  if jq empty "$f" >/dev/null 2>&1; then
    VALID_FILES=$(printf '%s\n%s' "$VALID_FILES" "$f")
  else
    problem "$f no es un JSON válido"
  fi
done <<EOF
$ALL_FILES
EOF

is_valid() { printf '%s\n' "$VALID_FILES" | grep -qxF "$1"; }

# Nombres que indican un secreto. Se usa en las variables y en las autorizaciones.
SECRET_DEF='def secretkey: (. // "") | tostring | test("token|secret|password|passwd|apikey|api_key|api-key|private_key|privatekey|credential"; "i");
def isvar: (. // "") | tostring | (. == "" or test("^\\{\\{[^{}]+\\}\\}$"));'

# --- Colección ----------------------------------------------------------------

if is_valid "$COLLECTION"; then
  SCHEMA=$(jqc -r '.info.schema // ""' "$COLLECTION")
  case "$SCHEMA" in
    *collection/v2.1*) ;;
    *) problem "$COLLECTION no está en formato v2.1 (info.schema = \"$SCHEMA\")" ;;
  esac

  # Nombres repetidos en el mismo nivel.
  jqc -r '
    def walk_items($path):
      (.item // []) as $items
      | ($items | map(.name // "") | group_by(.) | map(select(length > 1) | .[0])[]
         | "nombre repetido en \($path): \"\(.)\"" ),
        ($items[] | select(.item) | walk_items($path + "/" + (.name // "?")));
    walk_items("")' "$COLLECTION" | while IFS= read -r line; do echo "PROBLEMA $line"; done
  DUP=$(jqc -r '
    def walk_items:
      (.item // []) as $items
      | ($items | map(.name // "") | group_by(.) | map(select(length > 1)) | length),
        ($items[] | select(.item) | walk_items);
    [walk_items] | add // 0' "$COLLECTION")
  PROBLEMS=$((PROBLEMS + DUP))

  # Requests sin nombre o con URL escrita a mano.
  while IFS= read -r line; do
    [ -n "$line" ] && problem "$line"
  done <<EOF
$(jqc -r '
  .. | objects | select(has("request"))
  | (.name // "") as $n
  | (if $n == "" then "hay un request sin nombre" else empty end),
    ((.request.url | if type == "object" then (.raw // "") else (. // "") end) as $u
     | if ($u | test("^\\s*https?://"; "i")) then "\"\($n)\" usa una URL escrita a mano (\($u)): usá {{baseUrl}}" else empty end)
' "$COLLECTION")
EOF

  # Secretos en la colección.
  while IFS= read -r line; do
    [ -n "$line" ] && problem "$line"
  done <<EOF
$(jqc -r "$SECRET_DEF"'
  ( (.variable // [])[] | select(.key | secretkey) | select(.value | isvar | not)
    | "la variable de colección \"\(.key)\" tiene un valor: los secretos van vacíos o como {{variable}}" ),
  ( .. | objects | select((.type? | type) == "string" and ((.[.type]? // null) | type) == "array")
    | .type as $t | .[$t][]
    | select((.key | secretkey) or ($t == "apikey" and .key == "value"))
    | select(.value | isvar | not)
    | "una autorización \($t) tiene escrito el valor de \"\(.key)\": usá una variable, por ejemplo {{accessToken}}" ),
  ( .. | objects | select((.key? | type) == "string" and (.key | ascii_downcase) == "authorization")
    | select((.value // "") | tostring | test("\\{\\{") or . == "" | not)
    | "un header Authorization tiene un valor escrito: usá una variable, por ejemplo Bearer {{accessToken}}" ),
  ( [.. | strings | select(test("eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\."))] | length
    | if . > 0 then "hay \(.) token(s) JWT pegados en la colección: reemplazalos por <token> o una variable" else empty end )
' "$COLLECTION")
EOF

  # Variables usadas por la colección.
  USED=$(jqc -r '
    [.. | strings | scan("\\{\\{([^{}]+)\\}\\}") | .[0] | gsub("^\\s+|\\s+$"; "")
     | select(startswith("$") | not)] | unique | .[]' "$COLLECTION")
  COLLECTION_VARS=$(jqc -r '(.variable // [])[].key' "$COLLECTION")
fi

# --- Entornos -----------------------------------------------------------------

while IFS= read -r env; do
  [ -z "$env" ] && continue
  is_valid "$env" || continue

  while IFS= read -r line; do
    [ -n "$line" ] && problem "$env: $line"
  done <<EOF
$(jqc -r "$SECRET_DEF"'
  (.values // [])[] | select(.key | secretkey) | select(.value | isvar | not)
  | "la variable \"\(.key)\" tiene un valor: los secretos van vacíos y cada uno los carga en su Postman"' "$env")
EOF

  if [ -n "${USED:-}" ]; then
    DEFINED=$(printf '%s\n%s\n' "$(jqc -r '(.values // [])[].key' "$env")" "$COLLECTION_VARS")
    while IFS= read -r v; do
      [ -z "$v" ] && continue
      printf '%s\n' "$DEFINED" | grep -qxF "$v" \
        || problem "$env: falta declarar la variable \"$v\" que usa la colección (puede ir vacía)"
    done <<EOF
$USED
EOF
  fi
done <<EOF
$ENVS
EOF

# --- Formato fijo -------------------------------------------------------------

while IFS= read -r f; do
  [ -z "$f" ] && continue
  FORMATTED=$(jqc -S --indent 2 . "$f")
  CURRENT=$(tr -d '\r' <"$f")
  if [ "$FORMATTED" != "$CURRENT" ]; then
    if [ "$FIX" -eq 1 ]; then
      printf '%s\n' "$FORMATTED" >"$f"
      echo "formato corregido: $f"
    else
      problem "$f no tiene el formato fijo: corré este script con --fix"
    fi
  fi
done <<EOF
$VALID_FILES
EOF

if [ "$PROBLEMS" -gt 0 ]; then
  echo "Colección con $PROBLEMS problema(s)."
  exit 1
fi
echo "Colección en orden: $COLLECTION"
exit 0
