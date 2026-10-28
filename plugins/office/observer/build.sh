#!/usr/bin/env bash
# Arma la página del observer (index.html) a partir de src/:
#   src/page.html  la página, con <!-- @style --> y <!-- @script --> donde va el resto;
#   src/style.css  los estilos;
#   src/js/*.js    el script, en partes que se juntan en orden dentro de una sola función;
#   src/vendor/    three.js y los muebles KayKit de la vista 3D (<!-- @vendor -->), que arma
#                  tools/vendor.mjs (ver tools/package.json).
# La página se abre desde el disco, sin servidor, y con file:// el navegador no deja cargar
# módulos de otros archivos: por eso se entrega todo junto en un solo index.html.
#
# Uso: bash plugins/office/observer/build.sh          arma index.html
#      bash plugins/office/observer/build.sh --check  falla si index.html no está al día
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build() {
  local line f
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "<!-- @style -->") cat "$DIR/src/style.css" ;;
      "<!-- @vendor -->")
        for f in three-office kaykit; do printf '<script id="%s">\n' "$f"; cat "$DIR/src/vendor/$f.js"; printf '</script>\n'; done
        ;;
      "<!-- @script -->")
        printf '%s\n' '<script>' '(() => {' '  "use strict";' ''
        for f in "$DIR"/src/js/*.js; do cat "$f"; done
        printf '%s\n' '})();' '</script>'
        ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$DIR/src/page.html"
}

if [ "${1:-}" = "--check" ]; then
  if build | cmp -s - "$DIR/index.html"; then exit 0; fi
  echo "index.html no está al día con src/: corré bash plugins/office/observer/build.sh" >&2
  exit 1
fi
build >"$DIR/index.html.tmp" && mv "$DIR/index.html.tmp" "$DIR/index.html"
echo "Listo: $DIR/index.html"
