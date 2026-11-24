#!/usr/bin/env bash
# Pruebas del descubrimiento de la API interna de un sitio
# (plugins/dept-scraper/skills/discover-api/discover-api.mjs) y de las reglas de scraping.
# El modo HAR se prueba siempre; el modo navegador, solo si hay Playwright, contra una página
# local (sin internet).
# Uso: bash tests/discover-api.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/plugins/dept-scraper/skills/discover-api/discover-api.mjs"
SKILLS="$REPO/plugins/dept-scraper/skills"
WORK=$(mktemp -d)
SERVER_PID=""
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$WORK"' EXIT
FAILED=0

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | tail -n 30 | sed 's/^/      /'; FAILED=1; }
expect() { if eval "$2"; then ok "$1"; else fail "$1" "$out"; fi; }
has() { printf '%s' "$out" | grep -qF -- "$1"; }

command -v node >/dev/null 2>&1 || { echo "Falta node: no se pueden correr estas pruebas."; exit 1; }

# --- Modo HAR ---------------------------------------------------------------------------
HAR="$WORK/sitio.har"
node -e '
const body = JSON.stringify({ meta: { total: 3, csrfToken: "SECRETO-CSRF" }, data: { items: [
  { id: 1, name: "Leche", price: { amount: 1250, currency: "USD" } },
  { id: 2, name: "Pan", price: { amount: 900, currency: "USD" } },
  { id: 3, name: "Queso", price: { amount: 3000, currency: "USD" } } ] } });
const small = JSON.stringify({ id: 7, name: "Leche", sessionToken: "SECRETO-SESION" });
const h = (o) => Object.entries(o).map(([name, value]) => ({ name, value }));
const e = (method, url, headers, mime, text, extra = {}) => ({ request: { method, url, headers: h(headers), ...extra }, response: { status: 200, content: { mimeType: mime, text } }, _resourceType: "fetch" });
const log = { log: { entries: [
  e("GET", "https://tienda.example.com/categoria/lacteos", {}, "text/html", "<html></html>"),
  e("GET", "https://tienda.example.com/api/v2/products?page=1&apiKey=SECRETO-KEY", { Cookie: "sid=SECRETO-COOKIE", Authorization: "Bearer SECRETO-BEARER", "x-store-id": "12" }, "application/json; charset=utf-8", body),
  e("GET", "https://tienda.example.com/api/v2/products/101", {}, "application/json", small),
  e("GET", "https://tienda.example.com/api/v2/products/202", {}, "application/json", small),
  e("POST", "https://tienda.example.com/graphql", { "content-type": "application/json" }, "application/json", JSON.stringify({ data: { search: { results: [{ sku: "a" }, { sku: "b" }] } } }), { postData: { text: JSON.stringify({ operationName: "Search", variables: { q: "leche" }, query: "q" }) } }),
  e("GET", "https://www.google-analytics.com/g/collect?v=2", {}, "application/json", "{}"),
  { request: { method: "GET", url: "https://tienda.example.com/api/b64", headers: [] }, response: { status: 200, content: { mimeType: "application/json", encoding: "base64", text: Buffer.from(JSON.stringify({ ok: true })).toString("base64") } } },
] } };
require("fs").writeFileSync(process.argv[1], JSON.stringify(log));
' "$HAR"
OUT="$WORK/out"
out=$(cd "$WORK" && node "$SCRIPT" --har "$HAR" --out "$OUT" 2>&1); code=$?
expect "HAR: sale con 0 y escribe el resumen" '[ $code -eq 0 ] && [ -f "$OUT/summary.md" ]'
expect "HAR: la lista más larga va primero" '[ "$(grep -m1 "^## " "$OUT/summary.md")" = "## 01. GET tienda.example.com/api/v2/products" ]'
expect "HAR: encuentra la lista principal y sus campos" 'has "lista principal en \`\$.data.items\` (3 elementos): id: number, name: string, price: object"'
expect "HAR: agrupa /products/101 y /products/202 en /products/{id}" 'has "GET tienda.example.com/api/v2/products/{id}" && has "Visto 2 veces"'
expect "HAR: GraphQL con el nombre de la operación" 'has "(GraphQL: Search)"'
expect "HAR: dice qué autenticación manda, sin el valor" 'has "manda authorization: Bearer …, cookies"'
expect "HAR: encabezados propios" 'has "Encabezados propios: x-store-id"'
expect "HAR: descarta la analítica" 'has "1 de analítica o publicidad descartados" && ! has "google-analytics"'
expect "HAR: lee respuestas en base64" 'has "/api/b64"'
expect "HAR: no aparece el HTML" '! has "/categoria/lacteos"'
expect "HAR: ningún secreto en la salida ni en los archivos" '! has "SECRETO" && ! grep -rq "SECRETO" "$OUT"'
expect "HAR: oculta el parámetro apiKey y los campos sensibles de las respuestas" 'has "\`apiKey\`=<oculto>" && grep -q "\"csrfToken\": \"<oculto>\"" "$OUT"/01-*.json && grep -q "\"sessionToken\": \"<oculto>\"" "$OUT"/03-*.json'
expect "HAR: guarda una respuesta por endpoint" '[ "$(ls "$OUT"/*.json | wc -l | tr -d " ")" = "4" ]'
out=$(cd "$WORK" && node "$SCRIPT" --har "$HAR" 2>&1)
expect "HAR: por defecto guarda en .office/scraper/<sitio>/" '[ -f "$WORK/.office/scraper/tienda-example-com/summary.md" ]'

echo '{"log":{"entries":[{"request":{"method":"GET","url":"https://x.example.com/"},"response":{"status":200,"content":{"mimeType":"text/html","text":"<p>"}}}]}}' >"$WORK/vacio.har"
out=$(cd "$WORK" && node "$SCRIPT" --har "$WORK/vacio.har" --out "$WORK/o2" 2>&1)
expect "HAR sin JSON: lo dice y sugiere el JSON embebido" 'has "No encontré pedidos JSON" && has "__NEXT_DATA__"'
out=$(cd "$WORK" && node "$SCRIPT" --har "$WORK/no-existe.har" 2>&1); code=$?
expect "HAR que no existe: error" '[ $code -eq 1 ] && has "No pude leer el HAR"'
out=$(node "$SCRIPT" 2>&1); code=$?
expect "sin argumentos: uso y código 2" '[ $code -eq 2 ] && has "Uso:"'
out=$(node "$SCRIPT" ftp://x 2>&1); code=$?
expect "dirección que no es http: código 2" '[ $code -eq 2 ]'

# --- Modo navegador (si hay Playwright) ---------------------------------------------------
if node -e 'require("playwright")' >/dev/null 2>&1; then
  PORT=$((20000 + RANDOM % 20000))
  cat >"$WORK/server.cjs" <<'EOF'
const http = require("http");
const page = `<!doctype html><title>Tienda</title><body><script>
fetch('/api/items?page=1&token=SECRETO-T', { headers: { 'x-client': 'web', Authorization: 'Bearer SECRETO-B' } });
</script>`;
http.createServer((req, res) => {
  if (req.url.startsWith("/api/")) { res.setHeader("content-type", "application/json"); return res.end(JSON.stringify({ items: [{ id: 1, n: "a" }, { id: 2, n: "b" }], auth: { accessToken: "SECRETO-A" } })); }
  if (req.url === "/bloqueado") { res.statusCode = 403; res.setHeader("content-type", "text/html"); return res.end("<title>Just a moment...</title>"); }
  res.setHeader("content-type", "text/html"); res.end(page);
}).listen(Number(process.argv[2]), "127.0.0.1");
EOF
  node "$WORK/server.cjs" "$PORT" & SERVER_PID=$!
  sleep 1
  out=$(cd "$WORK" && node "$SCRIPT" "http://127.0.0.1:$PORT/" --wait 1 --scroll 1 --out "$WORK/live" 2>&1); code=$?
  expect "navegador: graba el pedido JSON de la página" '[ $code -eq 0 ] && has "GET 127.0.0.1:$PORT/api/items" && has "(2 elementos)"'
  expect "navegador: ningún secreto" '! has "SECRETO" && ! grep -rq "SECRETO" "$WORK/live"'
  out=$(cd "$WORK" && node "$SCRIPT" "http://127.0.0.1:$PORT/bloqueado" --wait 0 --scroll 0 --out "$WORK/live2" 2>&1)
  expect "navegador: avisa cuando la página está bloqueada" 'has "La página parece bloqueada" && has "--har"'
else
  echo "salto el modo navegador: no hay Playwright"
fi

# --- Reglas de scraping ----------------------------------------------------------------------
R="$SKILLS/responsible-scraping/SKILL.md"; A="$SKILLS/anti-blocking/SKILL.md"
expect "reglas: la API interna está en el orden de fuentes, antes del HTML" 'grep -q "la API interna del sitio.*discover-api.*HTML estático" "$R"'
expect "reglas: por defecto, un bloqueo se avisa; el anti-bloqueo es por proyecto" 'grep -q "^- \*\*Por defecto:\*\*.*se registra y se avisa" "$R" && grep -q "Si las reglas del proyecto activan el anti-bloqueo" "$R"'
expect "anti-bloqueo: solo datos públicos, sin captchas ni cuentas, ritmo por sitio" 'grep -q "Solo datos públicos" "$A" && grep -q "No se resuelven captchas" "$A" && grep -q "se mantiene \*\*por sitio\*\*" "$A"'
expect "anti-bloqueo: credenciales de proxies fuera del código y de los logs" 'grep -q "Credenciales fuera del código" "$A"'
expect "developer y tester usan las skills nuevas" 'grep -q "dept-scraper:discover-api" "$REPO/plugins/dept-scraper/agents/developer.md" && grep -q "dept-scraper:anti-blocking" "$REPO/plugins/dept-scraper/agents/tester.md"'

[ "$FAILED" -eq 0 ] && echo "Todas las pruebas pasan." || { echo "Hay pruebas que fallan."; exit 1; }
