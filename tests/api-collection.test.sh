#!/usr/bin/env bash
# Pruebas del script que revisa la colección de Postman
# (plugins/dept-backend/skills/api-collection/check-collection.sh).
# Cada caso arma una carpeta de colección en un directorio temporal y compara el
# código de salida: 0 = en orden, 1 = con problemas. Uso: bash tests/api-collection.test.sh

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/plugins/dept-backend/skills/api-collection/check-collection.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
CASE=0

# Arma una carpeta con la colección y el entorno local dados (JSON en una línea),
# los pasa al formato fijo y deja la ruta en $DIR.
make_dir() {
  CASE=$((CASE + 1))
  DIR="$WORK/case$CASE/docs/api"
  mkdir -p "$DIR/environments"
  printf '%s' "$1" | jq -S --indent 2 . >"$DIR/app.postman_collection.json"
  printf '%s' "$2" | jq -S --indent 2 . >"$DIR/environments/local.postman_environment.json"
}

check() {
  local expected="$1" description="$2"
  shift 2
  bash "$SCRIPT" "$@" >"$WORK/out.txt" 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "ok    $description"
  else
    echo "FALLA $description (esperado $expected, salió $actual)"
    sed 's/^/      /' "$WORK/out.txt"
    FAILED=1
  fi
}

SCHEMA='https://schema.getpostman.com/json/collection/v2.1.0/collection.json'

# Colección correcta: auth de colección con variable, login que guarda el token,
# un endpoint REST con variable de ruta y una operación GraphQL.
GOOD=$(jq -cn --arg s "$SCHEMA" '{
  info: {name: "App", schema: $s},
  auth: {type: "bearer", bearer: [{key: "token", value: "{{accessToken}}", type: "string"}]},
  item: [
    {name: "Auth", item: [
      {name: "Login", request: {method: "POST", auth: {type: "noauth"},
        url: {raw: "{{baseUrl}}/auth/login", host: ["{{baseUrl}}"], path: ["auth", "login"]},
        body: {mode: "raw", raw: "{\"email\": \"{{userEmail}}\", \"password\": \"{{userPassword}}\"}"}},
       event: [{listen: "test", script: {type: "text/javascript",
        exec: ["pm.environment.set(\"accessToken\", pm.response.json().accessToken);"]}}]}
    ]},
    {name: "Products", item: [
      {name: "Get product", request: {method: "GET",
        url: {raw: "{{baseUrl}}/products/:id", host: ["{{baseUrl}}"], path: ["products", ":id"],
              variable: [{key: "id", value: "{{productId}}"}]},
        header: [{key: "X-Request-Id", value: "{{$guid}}"}]}}
    ]},
    {name: "GraphQL", item: [
      {name: "Query products", request: {method: "POST",
        url: {raw: "{{baseUrl}}/graphql", host: ["{{baseUrl}}"], path: ["graphql"]},
        body: {mode: "graphql", graphql: {query: "query { products { id } }", variables: "{}"}}}}
    ]}
  ]}')
GOOD_ENV='{"name":"local","values":[
  {"key":"baseUrl","value":"http://localhost:3000","enabled":true},
  {"key":"accessToken","value":"","type":"secret","enabled":true},
  {"key":"userEmail","value":"","enabled":true},
  {"key":"userPassword","value":"","type":"secret","enabled":true},
  {"key":"productId","value":"1","enabled":true}]}'

make_dir "$GOOD" "$GOOD_ENV"
check 0 "colección correcta" "$DIR"

make_dir "$GOOD" "$GOOD_ENV"
check 0 "ruta de Windows con barras invertidas" "$(printf '%s' "$DIR" | tr '/' '\\')"

# Formato
make_dir "$GOOD" "$GOOD_ENV"
jq -c . "$DIR/app.postman_collection.json" >"$DIR/tmp.json" && mv "$DIR/tmp.json" "$DIR/app.postman_collection.json"
check 1 "formato distinto del fijo" "$DIR"
check 0 "--fix corrige el formato" --fix "$DIR"
check 0 "después de --fix queda en orden" "$DIR"

make_dir "$GOOD" "$GOOD_ENV"
sed 's/$/\r/' "$DIR/app.postman_collection.json" >"$DIR/tmp.json" && mv "$DIR/tmp.json" "$DIR/app.postman_collection.json"
check 0 "finales de línea CRLF (git en Windows) no cuentan como formato" "$DIR"

# Estructura
make_dir "$GOOD" "$GOOD_ENV"
cp "$DIR/app.postman_collection.json" "$DIR/other.postman_collection.json"
check 1 "dos colecciones en la misma carpeta" "$DIR"

make_dir "$GOOD" "$GOOD_ENV"
rm "$DIR/environments/local.postman_environment.json"
check 1 "sin entornos" "$DIR"

make_dir "$GOOD" "$GOOD_ENV"
printf '{ roto' >"$DIR/app.postman_collection.json"
check 1 "JSON inválido" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.info.schema = "https://schema.getpostman.com/json/collection/v2.0.0/collection.json"')" "$GOOD_ENV"
check 1 "formato v2.0" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.item[1].item += [.item[1].item[0]]')" "$GOOD_ENV"
check 1 "request repetido en la misma carpeta" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.item[1].item[0].request.url.raw = "http://localhost:3000/products/:id"')" "$GOOD_ENV"
check 1 "URL escrita a mano" "$DIR"

check 1 "carpeta que no existe" "$WORK/no-existe"

# Secretos
make_dir "$GOOD" "$(printf '%s' "$GOOD_ENV" | jq -c '.values[1].value = "abc123"')"
check 1 "token con valor en el entorno" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.auth.bearer[0].value = "abc123"')" "$GOOD_ENV"
check 1 "autorización bearer con valor escrito" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.auth = {type: "apikey", apikey: [{key: "key", value: "X-Api-Key"}, {key: "value", value: "sk_live_123"}]}')" "$GOOD_ENV"
check 1 "autorización apikey con valor escrito" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.item[1].item[0].request.header += [{key: "Authorization", value: "Bearer abc123"}]')" "$GOOD_ENV"
check 1 "header Authorization con valor escrito" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.item[1].item[0].request.header += [{key: "Authorization", value: "Bearer {{accessToken}}"}]')" "$GOOD_ENV"
check 0 "header Authorization con variable" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.item[1].item[0].response = [{name: "OK", body: "{\"token\": \"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc\"}"}]')" "$GOOD_ENV"
check 1 "JWT pegado en un ejemplo de respuesta" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.variable = [{key: "clientSecret", value: "shh"}]')" "$GOOD_ENV"
check 1 "variable de colección secreta con valor" "$DIR"

# Variables
make_dir "$GOOD" "$(printf '%s' "$GOOD_ENV" | jq -c 'del(.values[4])')"
check 1 "variable usada sin declarar en el entorno" "$DIR"

make_dir "$(printf '%s' "$GOOD" | jq -c '.variable = [{key: "productId", value: "1"}]')" "$(printf '%s' "$GOOD_ENV" | jq -c 'del(.values[4])')"
check 0 "variable declarada en la colección" "$DIR"

make_dir "$GOOD" "$GOOD_ENV"
printf '%s' "$GOOD_ENV" | jq -S --indent 2 'del(.values[0])' >"$DIR/environments/staging.postman_environment.json"
check 1 "a un segundo entorno le falta una variable" "$DIR"

if [ "$FAILED" -ne 0 ]; then
  echo "Hay pruebas que fallan."
  exit 1
fi
echo "Todas las pruebas pasan."
