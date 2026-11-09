#!/usr/bin/env bash
# Pruebas del índice del proyecto (plugins/office/skills/project-map/project-index.sh).
# Uso: bash tests/project-map.test.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDX="$ROOT/plugins/office/skills/project-map/project-index.sh"
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
FAILED=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

ok() { echo "ok    $1"; }
fail() { echo "FALLA $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; FAILED=1; }
line() { grep -F "$1	" "$P/.office/index/files.tsv"; }
has_line() { if line "$2" | grep -qF -- "$3"; then ok "$1"; else fail "$1" "$(line "$2")"; fi; }
no_line() { if line "$2" >/dev/null; then fail "$1" "$(line "$2")"; else ok "$1"; fi; }
run() { out=$(cd "$P" && bash "$IDX" "$@" 2>&1); code=$?; }

grep -q '^# project-index-version: [0-9]' "$IDX" && ok "el script tiene versión" || fail "el script tiene versión"

# Fuera de un repositorio de git.
P="$WORK/sin-git"; mkdir -p "$P"
run --full
[ "$code" -ne 0 ] && echo "$out" | grep -q "repositorio de git" && ok "fuera de git: lo explica y falla" || fail "fuera de git: lo explica y falla" "$out"
run --hook
[ "$code" -eq 0 ] && [ -z "$out" ] && ok "fuera de git, el hook no dice nada ni falla" || fail "fuera de git, el hook no dice nada ni falla" "$out"

# Un proyecto con varios lenguajes.
P="$WORK/proyecto"; mkdir -p "$P" && cd "$P" && git init -q
mkdir -p "src/api" "src/ui" "app" "node_modules/lib" "dist" "db" "srv" "con espacio" "rs" "lib"
cat >src/api/orders.ts <<'EOF'
export async function createOrder() {}
export const ORDER_LIMIT = 10
export interface Order { id: string }
export type OrderId = string
export default class OrderService {}
export { helperA, helperB as renamed }
function internal() {}
EOF
printf 'module.exports = {}\nexports.legacy = 1\n' >src/api/legacy.js
printf 'export default function Cart() { return null }\n' >src/ui/Cart.tsx
printf 'def top():\n    pass\n\nclass Repo:\n    def method(self):\n        pass\n' >app/repo.py
printf 'package srv\n\nfunc Exported() {}\nfunc hidden() {}\ntype Server struct{}\nfunc (s *Server) Start() {}\n' >srv/server.go
printf 'pub fn run() {}\npub struct Config;\nfn private() {}\n' >rs/lib.rs
printf 'CREATE TABLE IF NOT EXISTS "orders" (id int);\ncreate index orders_idx on orders(id);\n' >db/001_init.sql
printf 'export const z = 1\n' >"con espacio/archivo con espacio.ts"
printf 'export const dep = 1\n' >node_modules/lib/index.js
printf 'export const built = 1\n' >dist/bundle.js
printf '%s\n' "$(head -c 3000 /dev/zero | tr '\0' 'x')" >lib/vendor.js
printf '{}\n' >package-lock.json
printf '# Proyecto\n' >README.md
printf 'node_modules/\ndist/\n' >.gitignore
git add -A && git commit -qm init
cd "$ROOT"

run --full
[ "$code" -eq 0 ] && echo "$out" | grep -q "Índice armado" && ok "--full arma el índice" || fail "--full arma el índice" "$out"
has_line "TypeScript: funciones, constantes, interfaces, tipos y la clase por defecto" "src/api/orders.ts" "createOrder, ORDER_LIMIT, Order, OrderId, OrderService"
has_line "TypeScript: export { a, b as c }" "src/api/orders.ts" "helperA, renamed"
if line "src/api/orders.ts" | grep -q "internal"; then fail "TypeScript: lo que no se exporta no aparece"; else ok "TypeScript: lo que no se exporta no aparece"; fi
has_line "CommonJS" "src/api/legacy.js" "module.exports, legacy"
has_line "export default function" "src/ui/Cart.tsx" "Cart"
has_line "Python: funciones y clases de primer nivel" "app/repo.py" "top, Repo"
if line "app/repo.py" | grep -q "method"; then fail "Python: los métodos no aparecen"; else ok "Python: los métodos no aparecen"; fi
has_line "Go: solo lo exportado" "srv/server.go" "Exported, Server, Start"
if line "srv/server.go" | grep -q "hidden"; then fail "Go: lo privado no aparece"; else ok "Go: lo privado no aparece"; fi
has_line "Rust: lo público" "rs/lib.rs" "run, Config"
has_line "SQL: tablas e índices" "db/001_init.sql" "orders, orders_idx"
has_line "rutas con espacios" "con espacio/archivo con espacio.ts" "z"
has_line "los archivos sin código también se listan" "README.md" ""
has_line "código minificado: se lista sin símbolos" "lib/vendor.js" "(generado o minificado)"
no_line "node_modules no se indexa" "node_modules/lib/index.js"
no_line "lo ignorado por git no se indexa" "dist/bundle.js"
no_line "los lockfiles no se indexan" "package-lock.json"
[ -s "$P/.office/index/state" ] && grep -q "^commit=$(cd "$P" && git rev-parse HEAD)" "$P/.office/index/state" && ok "guarda el commit del índice" || fail "guarda el commit del índice"

# Incremental: un archivo nuevo sin commitear, uno modificado, uno borrado y uno movido.
C0=$(cd "$P" && git rev-parse HEAD)
cd "$P"
printf 'export function nuevo() {}\n' >src/api/payments.ts
printf 'export async function createOrder() {}\nexport function cancelOrder() {}\n' >src/api/orders.ts
git rm -q src/api/legacy.js
git mv src/ui/Cart.tsx src/ui/ShoppingCart.tsx
cd "$ROOT"
run
[ "$code" -eq 0 ] && echo "$out" | grep -q "Índice al día" && ok "actualizar: termina bien" || fail "actualizar: termina bien" "$out"
has_line "actualizar: un archivo nuevo sin commitear aparece" "src/api/payments.ts" "nuevo"
has_line "actualizar: un archivo modificado tiene sus símbolos nuevos" "src/api/orders.ts" "createOrder, cancelOrder"
no_line "actualizar: un archivo borrado desaparece" "src/api/legacy.js"
no_line "actualizar: un archivo movido deja su ruta vieja" "src/ui/Cart.tsx"
has_line "actualizar: y aparece en la nueva" "src/ui/ShoppingCart.tsx" "Cart"
has_line "actualizar: lo que no cambió sigue igual" "srv/server.go" "Exported"

# --changes: lo agregado, borrado y movido desde un commit, por carpeta.
run --changes "$C0"
echo "$out" | grep -q '^src/api/  .*+ payments.ts' && echo "$out" | grep -q '^src/api/  .*- legacy.js' && ok "--changes: agregados y borrados, por carpeta" || fail "--changes: agregados y borrados, por carpeta" "$out"
echo "$out" | grep -q 'Cart.tsx → src/ui/ShoppingCart.tsx' && ok "--changes: movidos" || fail "--changes: movidos" "$out"
run --changes 0000000000000000000000000000000000000000
[ "$code" -ne 0 ] && echo "$out" | grep -q "No encuentro el commit" && ok "--changes con un commit que no existe: lo explica" || fail "--changes con un commit que no existe" "$out"

# Se deshacen los cambios sin commitear: el índice vuelve a como estaba.
cd "$P" && git reset -q --hard && rm -f src/api/payments.ts && cd "$ROOT"
run --hook
[ "$code" -eq 0 ] && [ -z "$out" ] && ok "hook: actualiza sin decir nada" || fail "hook: actualiza sin decir nada" "$out"
no_line "hook: un archivo nuevo que se borró desaparece" "src/api/payments.ts"
has_line "hook: un archivo que se restauró vuelve" "src/api/legacy.js" "legacy"
if line "src/api/orders.ts" | grep -q "cancelOrder"; then fail "hook: un archivo revertido vuelve a sus símbolos"; else ok "hook: un archivo revertido vuelve a sus símbolos"; fi

# Un commit nuevo también se toma.
cd "$P" && printf 'export const extra = 1\n' >src/api/extra.ts && git add -A && git commit -qm extra && cd "$ROOT"
run
has_line "actualizar: lo de un commit nuevo aparece" "src/api/extra.ts" "extra"

# --dirs y --stats.
run --dirs 1
echo "$out" | grep -q '^src/  ' && echo "$out" | grep -q '^(raíz)' && ok "--dirs: resumen de carpetas" || fail "--dirs: resumen de carpetas" "$out"
echo "$out" | grep -q '^src/api/' && fail "--dirs 1 no baja al segundo nivel" "$out" || ok "--dirs 1 no baja al segundo nivel"
run --dirs 2
echo "$out" | grep -q '^src/api/  [0-9]* archivos  \[ts×' && ok "--dirs 2: archivos y tipos por carpeta" || fail "--dirs 2: archivos y tipos por carpeta" "$out"
run --stats
echo "$out" | grep -q '^Archivos: [0-9]' && ok "--stats" || fail "--stats" "$out"

# Sin índice, el hook lo arma solo, y .office/ no aparece en git aunque el proyecto no lo ignore.
P="$WORK/sin-indice"; mkdir -p "$P" && (cd "$P" && git init -q && printf 'export const a = 1\n' >a.ts && git add -A && git commit -qm a)
run --hook
[ "$code" -eq 0 ] && [ -z "$out" ] && grep -q "^a.ts	a$" "$P/.office/index/files.tsv" && ok "hook sin índice: lo arma solo, sin decir nada" || fail "hook sin índice: lo arma solo" "$out"
[ -z "$(cd "$P" && git status --porcelain)" ] && ok "hook: .office/ queda fuera de git (exclude local)" || fail "hook: .office/ queda fuera de git" "$(cd "$P" && git status --porcelain)"
grep -q '^\.office/$' "$P/.git/info/exclude" && [ ! -e "$P/.gitignore" ] && ok "hook: usa el exclude local, no toca el .gitignore" || fail "hook: usa el exclude local"
run --hook
[ "$(grep -c '^\.office/$' "$P/.git/info/exclude")" -eq 1 ] && ok "hook: no repite la línea del exclude" || fail "hook: no repite la línea del exclude"
P="$WORK/apagado"; mkdir -p "$P" && (cd "$P" && git init -q && printf 'x\n' >a.txt && git add -A && git commit -qm a)
out=$(cd "$P" && OFFICE_INDEX=off bash "$IDX" --hook 2>&1); code=$?
[ "$code" -eq 0 ] && [ ! -e "$P/.office" ] && ok "OFFICE_INDEX=off apaga el índice automático" || fail "OFFICE_INDEX=off apaga el índice automático" "$out"

# Imports, grafo e impacto.
P="$WORK/grafo"; mkdir -p "$P" && cd "$P" && git init -q
mkdir -p src/api src/ui src/lib app/svc pkg/store web
printf 'export function fmt() {}\n' >src/lib/format.ts
printf "import { fmt } from '../lib/format'\nexport function createOrder() {}\n" >src/api/orders.ts
printf "import { createOrder } from './orders.js'\nexport const pay = 1\n" >src/api/payments.ts
printf "import { pay } from '@/api/payments'\nimport x from 'react'\nexport default function Cart() {}\n" >src/ui/Cart.tsx
printf "import Cart from './Cart'\ntest('x', () => {})\n" >src/ui/Cart.test.tsx
printf "export * from './api/orders'\n" >src/index.ts
printf "import {\n  fmt,\n} from \"../src/lib/format\"\nconst y = require('../src/index')\n" >web/multi.js
printf 'def helper():\n    pass\n' >app/svc/util.py
printf 'from .util import helper\nfrom app.svc import util\nimport os\n' >app/svc/main.py
printf 'module example.com/demo\n' >go.mod
printf 'package store\nfunc Save() {}\n' >pkg/store/store.go
printf 'package main\nimport (\n\t"fmt"\n\ts "example.com/demo/pkg/store"\n)\nfunc main() { s.Save() }\n' >main.go
git add -A && git commit -qm init
cd "$ROOT"
run --full
imp() { grep -qF "$1	$2" "$P/.office/index/imports.tsv"; }
imp src/api/orders.ts src/lib/format.ts && ok "imports: ruta relativa sin extensión" || fail "imports: ruta relativa sin extensión" "$(cat "$P/.office/index/imports.tsv")"
imp src/api/payments.ts src/api/orders.ts && ok "imports: './x.js' que en realidad es TypeScript" || fail "imports: './x.js' que es TypeScript"
imp src/ui/Cart.tsx src/api/payments.ts && ok "imports: alias @/ a src/" || fail "imports: alias @/"
grep -q "react" "$P/.office/index/imports.tsv" && fail "imports: los paquetes externos no entran" || ok "imports: los paquetes externos no entran"
imp src/index.ts src/api/orders.ts && ok "imports: export … from" || fail "imports: export … from"
imp web/multi.js src/lib/format.ts && imp web/multi.js src/index.ts && ok "imports: import de varias líneas y require" || fail "imports: varias líneas y require"
imp app/svc/main.py app/svc/util.py && ok "imports: Python relativo y absoluto" || fail "imports: Python" "$(grep app/ "$P/.office/index/imports.tsv")"
imp main.go pkg/store/ && ok "imports: Go, por carpeta del módulo" || fail "imports: Go" "$(grep go "$P/.office/index/imports.tsv")"
grep -q '^OFFICE_GRAPH({' "$P/.office/observer/graph.js" && ok "grafo: arma .office/observer/graph.js" || fail "grafo: arma graph.js"
if command -v node >/dev/null 2>&1; then
  out=$(node -e 'global.OFFICE_GRAPH = g => { const bad = g.edges.filter(([a, b]) => !(a in g.files) || !(b in g.files)); console.log(g.files.length + " " + g.edges.length + " " + bad.length); }; require(process.argv[1])' "$P/.office/observer/graph.js")
  [ "$(echo "$out" | cut -d' ' -f3)" = "0" ] && [ "$(echo "$out" | cut -d' ' -f2)" -ge 8 ] && ok "grafo: JSON válido y aristas a archivos que existen ($out)" || fail "grafo: JSON válido" "$out"
fi
run --impact src/lib/format.ts
echo "$out" | grep -q "Lo importan directo (2)" && echo "$out" | grep -q "src/api/orders.ts" && ok "--impact: lo que importa directo" || fail "--impact: directo" "$out"
echo "$out" | grep -A9 "indirectamente" | grep -q "src/ui/Cart.tsx" && ok "--impact: lo que depende indirectamente" || fail "--impact: indirecto" "$out"
echo "$out" | grep -A3 "Tests relacionados" | grep -q "src/ui/Cart.test.tsx" && ok "--impact: los tests que lo cubren" || fail "--impact: tests" "$out"
run --impact "$P/src/ui/Cart.tsx"
echo "$out" | grep -q "Impacto de: src/ui/Cart.tsx" && echo "$out" | grep -q "Cart.test.tsx" && ok "--impact: acepta rutas absolutas" || fail "--impact: rutas absolutas" "$out"
run --impact 'src\api\orders.ts'
echo "$out" | grep -q "Impacto de: src/api/orders.ts" && ok "--impact: acepta rutas con \\ (Windows)" || fail "--impact: rutas de Windows" "$out"
run --impact pkg/store/store.go
echo "$out" | grep -q "main.go" && ok "--impact: Go, quien importa el paquete" || fail "--impact: Go" "$out"
run --impact README-no-existe.md
echo "$out" | grep -q "No están en el índice" && ok "--impact: avisa si el archivo no está" || fail "--impact: archivo que no está" "$out"
run --impact
[ "$code" -ne 0 ] && ok "--impact sin archivos: falla con el uso" || fail "--impact sin archivos"
# Un archivo nuevo resuelve un import que antes no encontraba.
cd "$P" && printf "import { later } from './later'\n" >src/api/uses-later.ts && cd "$ROOT"; run
imp src/api/uses-later.ts src/api/later.ts && fail "imports: no inventa archivos que no existen" || ok "imports: no inventa archivos que no existen"
cd "$P" && printf 'export const later = 1\n' >src/api/later.ts && cd "$ROOT"; run
imp src/api/uses-later.ts src/api/later.ts && ok "imports: un archivo nuevo resuelve un import que antes no encontraba" || fail "imports: archivo nuevo resuelve import"
run --stats
echo "$out" | grep -q '^Imports dentro del proyecto: [1-9]' && ok "--stats cuenta los imports" || fail "--stats imports" "$out"

[ "$FAILED" -eq 0 ] && echo "Todo bien." || echo "Hubo fallas."
exit "$FAILED"
