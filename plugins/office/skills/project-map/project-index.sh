#!/usr/bin/env bash
# project-index-version: 3
# Índice de archivos y símbolos del proyecto, para que los agentes encuentren dónde está cada
# cosa sin recorrer carpetas. No llama a ningún modelo: no gasta tokens.
#
# Guarda en .office/index/ (fuera de git):
#   files.tsv  una línea por archivo: <ruta>\t<lo que exporta o declara: funciones, clases, tipos...>
#   imports.tsv  quién importa a quién: <archivo>\t<archivo o carpeta/ que importa>, solo dentro del
#              proyecto (JavaScript y TypeScript, Python, Go y Dart).
#   state      el commit del último índice y los archivos que tenían cambios sin commitear.
# Y en .office/observer/graph.js, el grafo para la vista "Proyecto" del observer.
#
# Uso: bash project-index.sh [opción]
#   (sin opción)        actualiza el índice: solo lo que cambió desde la última vez, o todo si no hay.
#   --full              lo arma de cero.
#   --hook              para el hook de inicio de sesión: lo arma si no existe o lo actualiza, sin
#                       imprimir nada y sin fallar nunca. Se apaga con OFFICE_INDEX=off.
#   --dirs [N]          resumen de carpetas hasta N niveles (2 por defecto): cuántos archivos, de
#                       qué tipo y cuáles parecen de entrada. Sirve para escribir el mapa.
#   --changes <commit>  archivos agregados, borrados o movidos desde ese commit (más lo que no está
#                       commiteado), por carpeta. Sirve para actualizar el mapa.
#   --impact <archivo>… qué archivos dependen de esos (directo e indirecto) y qué tests los cubren.
#                       Sirve para saber qué probar y qué atacar sin explorar el código.
#   --stats             cuántos archivos, símbolos e imports tiene el índice y de qué commit es.
#
# Para buscar: Grep del nombre en .office/index/files.tsv (por ejemplo "createOrder" o "orders/").
# Funciona en Linux, macOS (bash 3.2 y el awk del sistema) y Windows con el bash de Git for Windows.

MODE="update"
ARG=""
case "${1:-}" in
  "") ;;
  --full) MODE="full" ;;
  --hook) MODE="hook" ;;
  --dirs) MODE="dirs"; ARG="${2:-2}" ;;
  --changes) MODE="changes"; ARG="${2:-}" ;;
  --stats) MODE="stats" ;;
  --impact) MODE="impact"; shift; IMPACT_ARGS=("$@") ;;
  -h | --help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Opción desconocida: $1 (mirá --help)." >&2; exit 1 ;;
esac

quiet() { [ "$MODE" = "hook" ]; }
say() { quiet || echo "$@"; }
fail() { quiet && exit 0; echo "$@" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "No se puede armar el índice: falta git."
ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -z "$ROOT" ] && fail "No se puede armar el índice: esta carpeta no es un repositorio de git."
cd "$ROOT" || fail "No se puede entrar a $ROOT."

DIR=".office/index"
FILES="$DIR/files.tsv"
STATE="$DIR/state"
RAW="$DIR/imports.raw.tsv"
IMPORTS="$DIR/imports.tsv"
GRAPH=".office/observer/graph.js"
MAX_SYMS=30          # símbolos por archivo; el resto se resume en "…+N"
MAX_LINES=4000       # líneas que se leen de cada archivo (lo de más abajo casi nunca declara nada nuevo)
INCREMENTAL_LIMIT=3000

export LC_ALL=C

# Archivos que no vale la pena indexar: dependencias, generados, binarios y lockfiles.
skip_path() {
  grep -v -E '(^|/)(node_modules|vendor|dist|build|out|target|coverage|\.next|\.nuxt|\.turbo|\.cache|\.git|\.office|\.qa|__pycache__|\.venv|venv|Pods|DerivedData|\.gradle|\.dart_tool|generated|__generated__)/' |
    grep -v -E '\.(min\.js|min\.css|map|lock|lockb|png|jpe?g|gif|webp|avif|ico|svg|bmp|tiff?|pdf|zip|gz|tgz|bz2|xz|7z|rar|jar|war|class|o|a|so|dylib|dll|exe|bin|woff2?|ttf|otf|eot|mp3|mp4|mov|avi|webm|wav|ogg|psd|sketch|fig|db|sqlite3?|snap)$' |
    grep -v -E '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb|composer\.lock|Gemfile\.lock|Cargo\.lock|poetry\.lock|go\.sum|Podfile\.lock)$'
}

# Lista de archivos del proyecto: los de git más los nuevos que no están ignorados.
list_files() {
  { git ls-files 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | tr -d '\r' | skip_path | sort -u
}

# Extrae los símbolos de los archivos que recibe por stdin (uno por línea) y escribe <ruta>\t<símbolos>.
# Los imports, sin resolver (<ruta>\t<lo que importa>), van al archivo que recibe como argumento.
extract() {
  local list rawout="$1"
  : >>"$rawout"
  list=$(mktemp "${TMPDIR:-/tmp}/office-index.XXXXXX") || return 1
  # Solo los que existen y son archivos comunes.
  while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done >"$list"
  if [ -s "$list" ]; then
    # Rutas con espacios: xargs con una ruta por línea.
    tr '\n' '\0' <"$list" | xargs -0 awk -v maxs="$MAX_SYMS" -v maxl="$MAX_LINES" -v rawout="$rawout" -v q="'" '
      function lang(f,  e) {
        e = tolower(f); sub(/.*\./, "", e)
        if (e ~ /^(js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte|astro)$/) return "js"
        if (e == "py") return "py"
        if (e == "go") return "go"
        if (e == "rs") return "rs"
        if (e ~ /^(java|kt|kts|cs|scala|swift|groovy)$/) return "jvm"
        if (e == "php") return "php"
        if (e == "rb") return "rb"
        if (e == "dart") return "dart"
        if (e ~ /^(ex|exs)$/) return "ex"
        if (e == "sql") return "sql"
        if (e ~ /^(c|h|cpp|hpp|cc|hh)$/) return "c"
        return ""
      }
      function add(s) {
        if (s == "" || (s in seen)) return
        seen[s] = 1; n++
        if (n <= maxs) syms = syms (syms == "" ? "" : ", ") s
      }
      function flush() {
        if (cur == "") return
        out = syms
        if (n > maxs) out = out ", …+" (n - maxs)
        printf "%s\t%s\n", cur, out
      }
      function name_after(line, re,  r) {
        if (!match(line, re)) return ""
        r = substr(line, RSTART, RLENGTH)
        sub(re "", "", r)
        return r
      }
      # Primer identificador después de la palabra clave.
      function ident(s) {
        if (match(s, /^[A-Za-z_$][A-Za-z0-9_$]*/)) return substr(s, RSTART, RLENGTH)
        return ""
      }
      BEGIN {
        QS = "[\"" q "]"; NQ = "[^\"" q "]+"
        RE_FROM = "(from|import)[ \t]*[(]?[ \t]*" QS NQ QS
        RE_REQ = "require[ \t]*[(][ \t]*" QS NQ QS
        RE_QUOTED = QS NQ QS
      }
      function unq(t) { sub("^[^\"" q "]*" QS, "", t); sub(QS "$", "", t); return t }
      function imp(t) { if (t != "") print cur "\t" t >> rawout }
      FNR == 1 { flush(); cur = FILENAME; sub(/^\.\//, "", cur); L = lang(FILENAME); syms = ""; n = 0; skip = 0; ingo = 0; split("", seen) }
      FNR > maxl || L == "" || skip { next }
      {
        line = $0; sub(/\r$/, "", line)
        # Una línea larguísima al principio: código minificado o generado. Se lista sin símbolos.
        if (FNR <= 5 && length(line) > 1500) { skip = 1; syms = "(generado o minificado)"; n = 0; next }
        # Imports dentro del proyecto (los paquetes externos no importan para el grafo).
        if (L == "js") {
          s = line
          while (match(s, RE_FROM)) { t = unq(substr(s, RSTART, RLENGTH)); s = substr(s, RSTART + RLENGTH); if (t ~ /^(\.|\/|@\/|~\/)/) imp(t) }
          s = line
          while (match(s, RE_REQ)) { t = unq(substr(s, RSTART, RLENGTH)); s = substr(s, RSTART + RLENGTH); if (t ~ /^(\.|\/|@\/|~\/)/) imp(t) }
        } else if (L == "py") {
          if (match(line, /^[ \t]*from[ \t]+[.A-Za-z0-9_]+[ \t]+import/)) { t = substr(line, RSTART, RLENGTH); sub(/^[ \t]*from[ \t]+/, "", t); sub(/[ \t]+import$/, "", t); imp(t) }
          else if (match(line, /^import[ \t]+/)) { t = substr(line, RSTART + RLENGTH); k = split(t, parts, ","); for (i = 1; i <= k; i++) { p = parts[i]; sub(/^[ \t]+/, "", p); sub(/[ \t].*/, "", p); imp(p) } }
        } else if (L == "go") {
          if (ingo) { if (line ~ /^[ \t]*\)/) ingo = 0; else if (match(line, RE_QUOTED)) imp(unq(substr(line, RSTART, RLENGTH))) }
          else if (line ~ /^import[ \t]*\(/) ingo = 1
          else if (line ~ /^import[ \t]/ && match(line, RE_QUOTED)) imp(unq(substr(line, RSTART, RLENGTH)))
        } else if (L == "dart") {
          if (line ~ /^(import|export|part)[ \t]/ && match(line, RE_QUOTED)) imp(unq(substr(line, RSTART, RLENGTH)))
        }
        if (L == "js") {
          if (match(line, /^[ \t]*export[ \t]+(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?(async[ \t]+)?(function\*?|class|const|let|var|interface|type|enum|namespace)[ \t]+/)) {
            add(ident(substr(line, RSTART + RLENGTH)))
          } else if (match(line, /^[ \t]*export[ \t]+default[ \t]+/)) {
            add("default")
          } else if (match(line, /^[ \t]*export[ \t]*\{/)) {
            rest = substr(line, RSTART + RLENGTH); sub(/\}.*/, "", rest)
            k = split(rest, parts, ",")
            for (i = 1; i <= k; i++) { p = parts[i]; sub(/^[ \t]*(type[ \t]+)?/, "", p); if (match(p, /[ \t]as[ \t]+/)) p = substr(p, RSTART + RLENGTH); add(ident(p)) }
          } else if (match(line, /^[ \t]*(module\.)?exports\.[A-Za-z_$][A-Za-z0-9_$]*/)) {
            p = substr(line, RSTART, RLENGTH); sub(/.*exports\./, "", p); add(p)
          } else if (line ~ /^[ \t]*module\.exports[ \t]*=/) {
            add("module.exports")
          }
        } else if (L == "py") {
          if (match(line, /^(async[ \t]+)?def[ \t]+/) || match(line, /^class[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "go") {
          if (match(line, /^func[ \t]+(\([^)]*\)[ \t]*)?/)) { s = ident(substr(line, RSTART + RLENGTH)); if (s ~ /^[A-Z]/) add(s) }
          else if (match(line, /^type[ \t]+/)) { s = ident(substr(line, RSTART + RLENGTH)); if (s ~ /^[A-Z]/) add(s) }
        } else if (L == "rs") {
          if (match(line, /^[ \t]*pub(\([a-z]+\))?[ \t]+(async[ \t]+)?(unsafe[ \t]+)?(fn|struct|enum|trait|type|mod|const|static)[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "jvm") {
          if (match(line, /^[ \t]*((public|private|protected|internal|open|abstract|final|static|sealed|data|partial|export|inline|value|enum)[ \t]+)*(class|interface|enum|record|object|struct|protocol|trait|extension)[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
          else if (match(line, /^((public|internal|private)[ \t]+)?(suspend[ \t]+)?fun[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "php") {
          if (match(line, /^[ \t]*((abstract|final|readonly)[ \t]+)*(class|interface|trait|enum)[ \t]+/) || match(line, /^function[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "rb") {
          if (match(line, /^[ \t]*(class|module)[ \t]+/)) { s = substr(line, RSTART + RLENGTH); if (match(s, /^[A-Za-z_:][A-Za-z0-9_:]*/)) add(substr(s, RSTART, RLENGTH)) }
          else if (match(line, /^([ \t][ \t]?)?def[ \t]+(self\.)?/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "dart") {
          if (match(line, /^((abstract|sealed|base|final|interface|mixin)[ \t]+)*(class|mixin|enum|extension|typedef)[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "ex") {
          if (match(line, /^[ \t]*defmodule[ \t]+/)) { s = substr(line, RSTART + RLENGTH); if (match(s, /^[A-Za-z_.]+/)) add(substr(s, RSTART, RLENGTH)) }
          else if (match(line, /^[ \t]*def[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        } else if (L == "sql") {
          low = tolower(line)
          if (match(low, /create[ \t]+(or[ \t]+replace[ \t]+)?(table|view|materialized[ \t]+view|function|procedure|type|index|unique[ \t]+index)[ \t]+(if[ \t]+not[ \t]+exists[ \t]+)?/)) {
            s = substr(low, RSTART + RLENGTH); gsub(/["`\[]/, "", s); if (match(s, /^[a-z_][a-z0-9_.]*/)) add(substr(s, RSTART, RLENGTH))
          }
        } else if (L == "c") {
          if (match(line, /^(typedef[ \t]+)?(struct|class|enum|union)[ \t]+/)) add(ident(substr(line, RSTART + RLENGTH)))
        }
      }
      END { flush() }
    ' 2>/dev/null
  fi
  rm -f "$list"
}

head_commit() { git rev-parse HEAD 2>/dev/null | tr -d '\r'; }
# Rutas con cambios sin commitear (modificadas, nuevas o borradas; en un renombre, las dos).
dirty_paths() {
  git status --porcelain -uall 2>/dev/null | tr -d '\r' | cut -c4- | awk '{ n = split($0, p, / -> /); for (i = 1; i <= n; i++) { s = p[i]; gsub(/^"|"$/, "", s); print s } }' | sort -u
}

write_state() {
  {
    echo "commit=$(head_commit)"
    echo "updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$STATE"
  dirty_paths >"$DIR/dirty"
}

build_full() {
  mkdir -p "$DIR"
  : >"$RAW.tmp"
  list_files | extract "$RAW.tmp" | sort -t "$(printf '\t')" -k1,1 >"$FILES.tmp" && mv -f "$FILES.tmp" "$FILES"
  sort -u "$RAW.tmp" >"$RAW" && rm -f "$RAW.tmp"
  resolve_imports
  write_state
}

# Resuelve cada import a un archivo (o carpeta, en Go) del proyecto. Lo que no se encuentra
# (paquetes externos, alias desconocidos) se descarta. Se rehace entero porque un archivo nuevo
# puede resolver imports viejos, y es rápido.
resolve_imports() {
  local gomod dartpkg
  gomod=$(sed -n 's/^module[[:space:]]*//p' go.mod 2>/dev/null | head -n1 | tr -d '\r ')
  dartpkg=$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml 2>/dev/null | head -n1 | tr -d '\r "' | tr -d "'")
  [ -f "$RAW" ] || : >"$RAW"
  awk -F '\t' -v gomod="$gomod" -v dartpkg="$dartpkg" '
    BEGIN { nj = split(".ts .tsx .js .jsx .mjs .cjs .mts .cts .vue .svelte .astro .d.ts", JX, " ") }
    function norm(p,  n, parts, out, i, m, r) {
      n = split(p, parts, "/"); m = 0
      for (i = 1; i <= n; i++) { if (parts[i] == "" || parts[i] == ".") continue; if (parts[i] == "..") { if (m > 0) m--; continue } out[++m] = parts[i] }
      r = ""; for (i = 1; i <= m; i++) r = r (i > 1 ? "/" : "") out[i]; return r
    }
    function dirof(p) { if (p ~ /\//) { sub(/\/[^\/]*$/, "", p); return p } return "" }
    function join(d, x) { return d == "" ? x : d "/" x }
    function try_js(b,  i, c) {
      if (b in F) return b
      for (i = 1; i <= nj; i++) if ((b JX[i]) in F) return b JX[i]
      for (i = 1; i <= nj; i++) if ((b "/index" JX[i]) in F) return b "/index" JX[i]
      if (b ~ /\.[mc]?[jt]sx?$/) { c = b; sub(/\.[mc]?[jt]sx?$/, "", c); return try_js(c) }
      return ""
    }
    function py(p) {
      if ((p ".py") in F) return p ".py"
      if ((p "/__init__.py") in F) return p "/__init__.py"
      if (("src/" p ".py") in F) return "src/" p ".py"
      if (("src/" p "/__init__.py") in F) return "src/" p "/__init__.py"
      return ""
    }
    NR == FNR { F[$1] = 1; D[dirof($1)] = 1; next }
    {
      src = $1; spec = $2; sub(/\?.*$/, "", spec); e = tolower(src); sub(/.*\./, "", e); to = ""
      if (e ~ /^(js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte|astro)$/) {
        if (spec ~ /^\./) to = try_js(norm(join(dirof(src), spec)))
        else if (spec ~ /^[@~]\//) { x = substr(spec, 3); to = try_js(norm("src/" x)); if (to == "") to = try_js(norm(x)) }
        else if (spec ~ /^\//) to = try_js(norm(spec))
      } else if (e == "py") {
        if (spec ~ /^\./) {
          match(spec, /^\.+/); dots = RLENGTH; rest = substr(spec, dots + 1); gsub(/\./, "/", rest)
          base = dirof(src); for (i = 1; i < dots; i++) base = dirof(base)
          to = py(norm(join(base, rest)))
        } else { x = spec; gsub(/\./, "/", x); to = py(x) }
      } else if (e == "go") {
        if (gomod != "" && spec == gomod) { if ("" in D) to = "/" }
        else if (gomod != "" && index(spec, gomod "/") == 1) { d = substr(spec, length(gomod) + 2); if (d in D) to = d "/" }
      } else if (e == "dart") {
        if (dartpkg != "" && index(spec, "package:" dartpkg "/") == 1) { x = "lib/" substr(spec, length("package:" dartpkg "/") + 1); if (x in F) to = x }
        else if (spec !~ /^[a-z]+:/) { x = norm(join(dirof(src), spec)); if (x in F) to = x }
      }
      if (to != "" && to != src && to != dirof(src) "/") print src "\t" to
    }' "$FILES" "$RAW" | sort -u >"$IMPORTS.tmp" && mv -f "$IMPORTS.tmp" "$IMPORTS"
}

# El grafo para la vista "Proyecto" del observer: los archivos y quién importa a quién, como índices.
write_graph() {
  mkdir -p "$(dirname "$GRAPH")"
  awk -F '\t' -v now="$(date +%s)" '
    BEGIN { n = 0; ne = 0 }
    function esc(x) { gsub(/\\/, "\\\\", x); gsub(/"/, "\\\"", x); return x }
    function dirof(p) { if (p ~ /\//) { sub(/\/[^\/]*$/, "", p); return p } return "" }
    NR == FNR { idx[$1] = n; name[n] = $1; d = dirof($1); if (!(d in firstOf)) firstOf[d] = n; n++; next }
    {
      a = $1; b = $2
      if (!(a in idx)) next
      if (b ~ /\/$/) { b = substr(b, 1, length(b) - 1); if (!(b in firstOf)) next; j = firstOf[b] } else { if (!(b in idx)) next; j = idx[b] }
      e = e (ne++ ? "," : "") "[" idx[a] "," j "]"
    }
    END {
      printf "OFFICE_GRAPH({\"v\":1,\"t\":%s,\"files\":[", now
      for (i = 0; i < n; i++) printf "%s\"%s\"", (i ? "," : ""), esc(name[i])
      printf "],\"edges\":[%s]});\n", e
    }' "$FILES" "$IMPORTS" >"$GRAPH.tmp" 2>/dev/null && mv -f "$GRAPH.tmp" "$GRAPH"
}

build_incremental() {
  local prev changed tmp n
  prev=$(sed -n 's/^commit=//p' "$STATE" 2>/dev/null | tr -d '\r')
  # Sin commit anterior conocido (otro clon, historia reescrita): de cero.
  if [ -z "$prev" ] || ! git cat-file -e "$prev^{commit}" 2>/dev/null; then build_full; return; fi
  changed=$(mktemp "${TMPDIR:-/tmp}/office-index.XXXXXX")
  {
    [ "$prev" != "$(head_commit)" ] && git diff --name-only "$prev" HEAD 2>/dev/null
    dirty_paths
    cat "$DIR/dirty" 2>/dev/null
  } | tr -d '\r' | sort -u >"$changed"
  n=$(grep -c . "$changed")
  if [ "$n" -eq 0 ]; then rm -f "$changed"; [ -f "$IMPORTS" ] || resolve_imports; write_state; return; fi
  if [ "$n" -gt "$INCREMENTAL_LIMIT" ]; then rm -f "$changed"; build_full; return; fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/office-index.XXXXXX")
  # Se sacan las líneas de los archivos que cambiaron y se vuelven a extraer los que siguen existiendo
  # (y no son ignorados ni de los que no se indexan).
  awk -F '\t' 'NR == FNR { ch[$0] = 1; next } !($1 in ch)' "$changed" "$FILES" >"$tmp"
  awk -F '\t' 'NR == FNR { ch[$0] = 1; next } !($1 in ch)' "$changed" "$RAW" >"$RAW.tmp"
  list_files | awk 'NR == FNR { ch[$0] = 1; next } ($0 in ch)' "$changed" - | extract "$RAW.tmp" >>"$tmp"
  sort -t "$(printf '\t')" -k1,1 -u "$tmp" >"$FILES.tmp" && mv -f "$FILES.tmp" "$FILES"
  sort -u "$RAW.tmp" >"$RAW" && rm -f "$RAW.tmp"
  rm -f "$tmp" "$changed"
  resolve_imports
  write_state
}

case "$MODE" in
  full)
    start=$(date +%s)
    build_full
    write_graph
    say "Índice armado: $(grep -c . "$FILES") archivos en $(($(date +%s) - start)) s ($FILES)."
    ;;
  update | hook)
    if [ "$MODE" = "hook" ] && [ "${OFFICE_INDEX:-on}" = "off" ]; then exit 0; fi
    # Que .office/ no aparezca como archivo nuevo en git, aunque el proyecto no lo ignore:
    # se agrega al exclude local del repositorio (no se commitea).
    if ! git check-ignore -q "$DIR/files.tsv" 2>/dev/null; then
      ex=$(git rev-parse --git-path info/exclude 2>/dev/null | tr -d '\r')
      [ -n "$ex" ] && { mkdir -p "$(dirname "$ex")"; printf '%s\n' ".office/" >>"$ex"; }
    fi
    # Un índice de una versión anterior (sin imports) se arma de cero una vez.
    if [ -s "$FILES" ] && [ -s "$STATE" ] && [ -f "$RAW" ]; then build_incremental; else build_full; fi
    write_graph
    say "Índice al día: $(grep -c . "$FILES") archivos ($FILES)."
    ;;
  stats)
    [ -s "$FILES" ] || { echo "Este proyecto todavía no tiene índice. Armalo con: bash $0 --full"; exit 0; }
    echo "Archivos: $(grep -c . "$FILES")"
    echo "Con símbolos: $(awk -F '\t' '$2 != "" && $2 !~ /^\(/' "$FILES" | grep -c .)"
    echo "Imports dentro del proyecto: $(grep -c . "$IMPORTS" 2>/dev/null || echo 0)"
    echo "Commit: $(sed -n 's/^commit=//p' "$STATE" | cut -c1-12)"
    echo "Actualizado: $(sed -n 's/^updated=//p' "$STATE")"
    ;;
  impact)
    [ "${#IMPACT_ARGS[@]}" -gt 0 ] || fail "Faltan los archivos: --impact <archivo> [<archivo>…] (rutas del proyecto)."
    if [ ! -s "$FILES" ] || [ ! -f "$RAW" ]; then build_full; write_graph; fi
    # Rutas relativas al proyecto, con / y sin ./ adelante, aunque vengan absolutas o con \.
    targets=""
    for a in "${IMPACT_ARGS[@]}"; do
      a="${a//\\//}"; a="${a#"$ROOT"/}"; a="${a#./}"
      targets="$targets$a"$'\n'
    done
    printf '%s' "$targets" | awk -F '\t' -v maxn=30 '
      function dirof(p) { if (p ~ /\//) { sub(/\/[^\/]*$/, "", p); return p } return "" }
      function istest(p) { return p ~ /(^|\/)(__tests__|tests?|spec|e2e)\// || p ~ /[._-](test|spec|e2e)\.[A-Za-z]+$/ || p ~ /(^|\/)test_[^\/]*\.py$/ || p ~ /_test\.go$/ }
      function base(p) { sub(/.*\//, "", p); sub(/\.[^.]*$/, "", p); sub(/[._-](test|spec|e2e)$/, "", p); sub(/^test_/, "", p); sub(/_test$/, "", p); return p }
      function show(title, list, cnt,  i, out) {
        if (cnt == 0) return
        printf "%s (%d):\n", title, cnt
        for (i = 1; i <= cnt && i <= maxn; i++) printf "  %s\n", list[i]
        if (cnt > maxn) printf "  …y %d más\n", cnt - maxn
      }
      FILENAME == "-" { if ($0 != "") { T[$0] = 1; nt++; tl = tl (tl == "" ? "" : ", ") $0 } next }
      FILENAME ~ /files\.tsv$/ { all[++na] = $1; known[$1] = 1; next }
      {
        # Aristas al revés: de lo importado a quien lo importa. En Go, el import es la carpeta.
        to = $2; from = $1
        if (to ~ /\/$/) { dk = substr(to, 1, length(to) - 1); rdir[dk] = rdir[dk] "\n" from } else rev[to] = rev[to] "\n" from
      }
      END {
        for (t in T) { lvl[t] = 0; q[++qn] = t; if (!(t in known)) unknown = unknown (unknown == "" ? "" : ", ") t }
        # Hasta 5 niveles: los archivos se muestran hasta el 3 (directo y dos de indirecto), y
        # los tests hasta el 5, porque suelen estar al final de la cadena.
        for (h = 1; h <= qn; h++) {
          cur = q[h]; if (lvl[cur] >= 5) continue
          s = rev[cur] (dirof(cur) in rdir ? rdir[dirof(cur)] : "")
          k = split(s, fr, "\n")
          for (i = 1; i <= k; i++) { f = fr[i]; if (f == "" || (f in lvl)) continue; lvl[f] = lvl[cur] + 1; q[++qn] = f }
        }
        # Tests: los que dependen del cambio y los que se llaman como lo cambiado.
        for (t in T) tb[base(t)] = 1
        for (i = 1; i <= na; i++) { f = all[i]; if (istest(f) && !(f in T) && (base(f) in tb)) { if (!(f in lvl)) lvl[f] = 9 } }
        for (h = 1; h <= qn; h++) { f = q[h]; if (f in T) continue; if (istest(f)) { tests[++ntst] = f; continue } if (lvl[f] == 1) direct[++nd] = f; else if (lvl[f] <= 3) indirect[++ni] = f }
        for (f in lvl) if (lvl[f] == 9) tests[++ntst] = f
        printf "Impacto de: %s\n", tl
        if (unknown != "") printf "No están en el índice (¿archivos nuevos sin guardar o fuera del proyecto?): %s\n", unknown
        if (nd + ni + ntst == 0) { print "Nadie en el proyecto importa estos archivos (o el lenguaje no está en el grafo: JavaScript, TypeScript, Python, Go y Dart)."; exit }
        show("Lo importan directo", direct, nd)
        show("Dependen indirectamente (hasta 3 niveles)", indirect, ni)
        show("Tests relacionados", tests, ntst)
      }' - "$FILES" "$IMPORTS"
    ;;
  dirs)
    [ -s "$FILES" ] || build_full
    case "$ARG" in '' | *[!0-9]*) ARG=2 ;; esac
    awk -F '\t' -v depth="$ARG" '
      {
        path = $1; k = split(path, seg, "/")
        e = tolower(seg[k]); if (e ~ /\./) { sub(/.*\./, "", e) } else e = "(sin ext.)"
        base = tolower(seg[k])
        entry = (base ~ /^(index|main|app|server|mod|lib|__init__|program|startup|routes?|router|schema|models?)\.[a-z]+$/ || base ~ /^(readme(\.md)?|package\.json|pyproject\.toml|go\.mod|cargo\.toml|pubspec\.yaml|composer\.json|gemfile|build\.gradle(\.kts)?|pom\.xml|dockerfile|makefile)$/)
        d = ""
        for (i = 1; i < k && i <= depth; i++) {
          d = d (d == "" ? "" : "/") seg[i]
          cnt[d]++; ext[d, e]++; if (!((d, e) in seenx)) { seenx[d, e] = 1; exts[d] = exts[d] " " e }
          if (entry && i == k - 1 && nent[d] < 3) { nent[d]++; ents[d] = ents[d] (ents[d] == "" ? "" : ", ") seg[k] }
        }
        if (k == 1) { root++; if (entry && nroot < 6) { nroot++; rents = rents (rents == "" ? "" : ", ") seg[k] } }
      }
      END {
        printf "(raíz)  %d archivos%s\n", root, (rents != "" ? "  · " rents : "")
        for (d in cnt) {
          m = split(exts[d], es, " "); top = ""
          for (r = 1; r <= 3; r++) { best = ""; bv = 0; for (j = 1; j <= m; j++) if (!(es[j] in used) && ext[d, es[j]] > bv) { bv = ext[d, es[j]]; best = es[j] } if (best == "") break; used[best] = 1; top = top (top == "" ? "" : " ") best "×" bv }
          for (j = 1; j <= m; j++) delete used[es[j]]
          printf "%s/  %d archivos  [%s]%s\n", d, cnt[d], top, (ents[d] != "" ? "  · " ents[d] : "")
        }
      }' "$FILES" | sort
    ;;
  changes)
    [ -z "$ARG" ] && fail "Falta el commit: --changes <commit> (el del comentario map-commit del mapa)."
    git cat-file -e "$ARG^{commit}" 2>/dev/null || fail "No encuentro el commit $ARG en este repositorio: si el mapa es de otra historia, revisalo entero."
    TAB=$(printf '\t')
    {
      { git diff --name-only --diff-filter=A "$ARG" 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | tr -d '\r' | skip_path | sed "s/^/+$TAB/"
      git diff --name-only --diff-filter=D "$ARG" 2>/dev/null | tr -d '\r' | skip_path | sed "s/^/-$TAB/"
      git diff --name-status -M --diff-filter=R "$ARG" 2>/dev/null | tr -d '\r' | awk -F '\t' '{ print "~\t" $2 "\t" $3 }'
    } | sort -u | awk -F '\t' '
      function dir(p) { if (p ~ /\//) { sub(/\/[^\/]*$/, "", p); return p "/" } return "(raíz)" }
      function base(p) { sub(/.*\//, "", p); return p }
      {
        if ($1 == "~") { d = dir($2); item = "↦ " base($2) " → " $3 }
        else { d = dir($2); item = ($1 == "+" ? "+ " : "- ") base($2) }
        if (!(d in out)) order[++n] = d
        out[d] = out[d] (out[d] == "" ? "" : ", ") item; total++
      }
      END {
        if (total == 0) { print "Sin archivos agregados, borrados ni movidos desde ese commit: el mapa sigue valiendo."; exit }
        for (i = 1; i <= n; i++) print order[i] "  " out[order[i]]
      }'
    ;;
esac
exit 0
