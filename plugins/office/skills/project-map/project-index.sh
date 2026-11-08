#!/usr/bin/env bash
# project-index-version: 2
# Índice de archivos y símbolos del proyecto, para que los agentes encuentren dónde está cada
# cosa sin recorrer carpetas. No llama a ningún modelo: no gasta tokens.
#
# Guarda en .office/index/ (fuera de git):
#   files.tsv  una línea por archivo: <ruta>\t<lo que exporta o declara: funciones, clases, tipos...>
#   state      el commit del último índice y los archivos que tenían cambios sin commitear.
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
#   --stats             cuántos archivos y símbolos tiene el índice y de qué commit es.
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
  -h | --help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
extract() {
  local list
  list=$(mktemp "${TMPDIR:-/tmp}/office-index.XXXXXX") || return 1
  # Solo los que existen y son archivos comunes.
  while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done >"$list"
  if [ -s "$list" ]; then
    # Rutas con espacios: xargs con una ruta por línea.
    tr '\n' '\0' <"$list" | xargs -0 awk -v maxs="$MAX_SYMS" -v maxl="$MAX_LINES" '
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
      FNR == 1 { flush(); cur = FILENAME; sub(/^\.\//, "", cur); L = lang(FILENAME); syms = ""; n = 0; skip = 0; split("", seen) }
      FNR > maxl || L == "" || skip { next }
      {
        line = $0; sub(/\r$/, "", line)
        # Una línea larguísima al principio: código minificado o generado. Se lista sin símbolos.
        if (FNR <= 5 && length(line) > 1500) { skip = 1; syms = "(generado o minificado)"; n = 0; next }
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
  list_files | extract | sort -t "$(printf '\t')" -k1,1 >"$FILES.tmp" && mv -f "$FILES.tmp" "$FILES"
  write_state
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
  if [ "$n" -eq 0 ]; then rm -f "$changed"; write_state; return; fi
  if [ "$n" -gt "$INCREMENTAL_LIMIT" ]; then rm -f "$changed"; build_full; return; fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/office-index.XXXXXX")
  # Se sacan las líneas de los archivos que cambiaron y se vuelven a extraer los que siguen existiendo
  # (y no son ignorados ni de los que no se indexan).
  awk -F '\t' 'NR == FNR { ch[$0] = 1; next } !($1 in ch)' "$changed" "$FILES" >"$tmp"
  list_files | awk 'NR == FNR { ch[$0] = 1; next } ($0 in ch)' "$changed" - | extract >>"$tmp"
  sort -t "$(printf '\t')" -k1,1 -u "$tmp" >"$FILES.tmp" && mv -f "$FILES.tmp" "$FILES"
  rm -f "$tmp" "$changed"
  write_state
}

case "$MODE" in
  full)
    start=$(date +%s)
    build_full
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
    if [ -s "$FILES" ] && [ -s "$STATE" ]; then build_incremental; else build_full; fi
    say "Índice al día: $(grep -c . "$FILES") archivos ($FILES)."
    ;;
  stats)
    [ -s "$FILES" ] || { echo "Este proyecto todavía no tiene índice. Armalo con: bash $0 --full"; exit 0; }
    echo "Archivos: $(grep -c . "$FILES")"
    echo "Con símbolos: $(awk -F '\t' '$2 != "" && $2 !~ /^\(/' "$FILES" | grep -c .)"
    echo "Commit: $(sed -n 's/^commit=//p' "$STATE" | cut -c1-12)"
    echo "Actualizado: $(sed -n 's/^updated=//p' "$STATE")"
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
