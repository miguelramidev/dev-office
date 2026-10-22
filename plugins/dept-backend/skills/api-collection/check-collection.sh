#!/usr/bin/env bash
# Revisa las colecciones de Postman del proyecto y sus entornos.
#
# Uso: bash check-collection.sh [--fix] [carpeta]
#   carpeta  donde están las colecciones (por defecto, docs/api).
#   --fix    reescribe los archivos con el formato fijo (claves ordenadas, sangría
#            de 2 espacios, finales de línea LF). No corrige nada más.
#
# Estructura esperada:
#   <carpeta>/<proyecto>.postman_collection.json         la del proyecto, una sola
#   <carpeta>/epics/<EPICA>-<resumen>.postman_collection.json   una por épica (opcional)
#   <carpeta>/environments/<entorno>.postman_environment.json   al menos uno
#
# Revisa:
#   - que haya una sola colección del proyecto y al menos un entorno, y que todo
#     sea JSON válido;
#   - que cada colección use el formato v2.1 y tenga un info._postman_id distinto;
#   - que no haya dos carpetas o requests con el mismo nombre en el mismo nivel;
#   - que las URLs usen {{baseUrl}} y no una dirección escrita a mano;
#   - que no haya secretos: variables con nombre de secreto con valor, autorizaciones
#     o headers Authorization con un valor escrito, o tokens JWT pegados;
#   - que en las colecciones de épica cada request tenga un script de test;
#   - que cada variable {{...}} que usa alguna colección esté declarada en cada
#     entorno (o en las variables de esa colección);
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
      sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
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

# Reporta como problema cada línea no vacía que recibe por stdin.
problems_from() {
  local prefix="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] && problem "$prefix$line"
  done
}

# jq sin los "\r" que agrega el jq de Windows.
jqc() { jq "$@" | tr -d '\r'; }

if [ ! -d "$DIR" ]; then
  echo "No existe la carpeta $DIR: el proyecto todavía no tiene colección." >&2
  exit 1
fi

MAIN=$(find "$DIR" -maxdepth 1 -type f -name '*.postman_collection.json' | sort)
COUNT=$(printf '%s' "$MAIN" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then
  echo "No hay colección del proyecto (*.postman_collection.json) en $DIR." >&2
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  problem "hay $COUNT colecciones en $DIR y la del proyecto tiene que ser una sola (las de épica van en $DIR/epics/):"
  printf '%s\n' "$MAIN" | sed 's/^/         /'
fi

EPICS=$(find "$DIR/epics" -maxdepth 1 -type f -name '*.postman_collection.json' 2>/dev/null | sort)
ENVS=$(find "$DIR/environments" -maxdepth 1 -type f -name '*.postman_environment.json' 2>/dev/null | sort)
[ -z "$ENVS" ] && problem "no hay entornos en $DIR/environments/ (por ejemplo local.postman_environment.json)"

# Archivos con JSON inválido: no se pueden revisar más.
VALID_FILES=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if jq empty "$f" >/dev/null 2>&1; then
    VALID_FILES=$(printf '%s\n%s' "$VALID_FILES" "$f")
  else
    problem "$f no es un JSON válido"
  fi
done <<EOF
$MAIN
$EPICS
$ENVS
EOF

is_valid() { printf '%s\n' "$VALID_FILES" | grep -qxF "$1"; }

# Nombres que indican un secreto. Se usa en las variables y en las autorizaciones.
SECRET_DEF='def secretkey: (. // "") | tostring | test("token|secret|password|passwd|apikey|api_key|api-key|private_key|privatekey|credential"; "i");
def isvar: (. // "") | tostring | (. == "" or test("^\\{\\{[^{}]+\\}\\}$"));'

# --- Colecciones --------------------------------------------------------------

# Variables usadas por cada colección, como líneas "archivo<TAB>variable" que no
# están declaradas en las variables de esa misma colección.
USED=""
IDS=""

check_collection() {
  local file="$1" kind="$2" schema id

  schema=$(jqc -r '.info.schema // ""' "$file")
  case "$schema" in
    *collection/v2.1*) ;;
    *) problem "$file no está en formato v2.1 (info.schema = \"$schema\")" ;;
  esac

  id=$(jqc -r '.info._postman_id // ""' "$file")
  if [ -n "$id" ]; then
    if printf '%s\n' "$IDS" | cut -f1 | grep -qxF "$id"; then
      problem "$file tiene el mismo info._postman_id que $(printf '%s\n' "$IDS" | grep -F "$id" | head -n1 | cut -f2): Postman reemplazaría una con la otra al importarlas"
    fi
    IDS=$(printf '%s\n%s\t%s' "$IDS" "$id" "$file")
  fi

  # Nombres repetidos en el mismo nivel.
  problems_from "$file: " < <(jqc -r '
    def walk_items($path):
      (.item // []) as $items
      | ($items | map(.name // "") | group_by(.) | map(select(length > 1) | .[0])[]
         | "nombre repetido en \($path): \"\(.)\"" ),
        ($items[] | select(.item) | walk_items($path + "/" + (.name // "?")));
    walk_items("")' "$file")

  # Requests sin nombre o con URL escrita a mano.
  problems_from "$file: " < <(jqc -r '
    .. | objects | select(has("request"))
    | (.name // "") as $n
    | (if $n == "" then "hay un request sin nombre" else empty end),
      ((.request.url | if type == "object" then (.raw // "") else (. // "") end) as $u
       | if ($u | test("^\\s*https?://"; "i")) then "\"\($n)\" usa una URL escrita a mano (\($u)): usá {{baseUrl}}" else empty end)
  ' "$file")

  # Secretos.
  problems_from "$file: " < <(jqc -r "$SECRET_DEF"'
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
      | if . > 0 then "hay \(.) token(s) JWT pegados: reemplazalos por <token> o una variable" else empty end )
  ' "$file")

  # En una colección de épica, cada paso del flujo verifica su respuesta.
  if [ "$kind" = "epic" ]; then
    problems_from "$file: " < <(jqc -r '
      .. | objects | select(has("request"))
      | select([(.event // [])[] | select(.listen == "test")
                | .script.exec // [] | if type == "array" then join("") else tostring end
                | select(test("\\S"))] | length == 0)
      | "\"\(.name // "?")\" no tiene un script de test: cada paso de un flujo verifica su respuesta"
    ' "$file")
  fi

  # Variables usadas que la colección no declara.
  local used
  used=$(jqc -r '
    ((.variable // []) | map(.key)) as $own
    | [.. | strings | scan("\\{\\{([^{}]+)\\}\\}") | .[0] | gsub("^\\s+|\\s+$"; "")
       | select(startswith("$") | not)] | unique
    | map(select(. as $v | $own | index($v) | not)) | .[]' "$file")
  if [ -n "$used" ]; then
    USED=$(printf '%s\n%s' "$USED" "$(printf '%s\n' "$used" | sed "s|^|$file	|")")
  fi
}

while IFS= read -r f; do
  [ -n "$f" ] && is_valid "$f" && check_collection "$f" main
done <<EOF
$MAIN
EOF

while IFS= read -r f; do
  [ -n "$f" ] && is_valid "$f" && check_collection "$f" epic
done <<EOF
$EPICS
EOF

# --- Entornos -----------------------------------------------------------------

while IFS= read -r env; do
  [ -z "$env" ] && continue
  is_valid "$env" || continue

  problems_from "$env: " < <(jqc -r "$SECRET_DEF"'
    (.values // [])[] | select(.key | secretkey) | select(.value | isvar | not)
    | "la variable \"\(.key)\" tiene un valor: los secretos van vacíos y cada uno los carga en su Postman"
  ' "$env")

  DEFINED=$(jqc -r '(.values // [])[].key' "$env")
  while IFS='	' read -r file v; do
    [ -z "$v" ] && continue
    printf '%s\n' "$DEFINED" | grep -qxF "$v" \
      || problem "$env: falta declarar la variable \"$v\" que usa $file (puede ir vacía)"
  done <<EOF
$USED
EOF
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
  echo "Colecciones con $PROBLEMS problema(s)."
  exit 1
fi
EPIC_COUNT=$(printf '%s' "$EPICS" | grep -c . || true)
echo "Colecciones en orden: la del proyecto y $EPIC_COUNT de épica."
exit 0
