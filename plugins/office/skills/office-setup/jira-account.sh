#!/usr/bin/env bash
# Conecta Jira a ESTE proyecto con una cuenta de Atlassian puntual, usando un token de API.
#
# Con el inicio de sesión normal (OAuth), Claude Code guarda una sola sesión de Atlassian para
# toda la computadora: si en un proyecto usás la cuenta del trabajo y en otro la personal, la
# última que conectaste pisa a la otra. Con un token de API, cada proyecto guarda la suya.
#
# Lo corre el CEO en su terminal, en la carpeta del proyecto (el token nunca pasa por el chat):
#   bash jira-account.sh
# Pide el email de la cuenta, el token de API (no se muestra al escribirlo) y, opcional, el
# sitio (miempresa.atlassian.net) para comprobar que el token funciona. Después registra el
# servidor "atlassian" solo para este proyecto (claude mcp add --scope local), con el token en
# la cabecera. Queda en ~/.claude.json de tu usuario, no en el repositorio.
# El token se crea en https://id.atlassian.com/manage-profile/security/api-tokens (con
# alcances), y la organización tiene que tener habilitada la autenticación con token para el
# servidor MCP de Atlassian.
# Sin preguntar (para scripts): OFFICE_JIRA_EMAIL, OFFICE_JIRA_TOKEN y OFFICE_JIRA_SITE.

set -u
URL="https://mcp.atlassian.com/v2/mcp"

die() { echo "Error: $*" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || die "no encuentro el comando claude. Corré esto en una terminal donde funcione claude."
command -v base64 >/dev/null 2>&1 || die "no encuentro el comando base64."

ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r') || ROOT=""
[ -n "$ROOT" ] && cd "$ROOT"

EMAIL="${OFFICE_JIRA_EMAIL:-}"
TOKEN="${OFFICE_JIRA_TOKEN:-}"
SITE="${OFFICE_JIRA_SITE-__ask__}"
if [ -z "$EMAIL" ]; then printf 'Email de la cuenta de Atlassian para este proyecto: '; read -r EMAIL; fi
if [ -z "$TOKEN" ]; then printf 'Token de API (no se muestra): '; read -rs TOKEN; echo; fi
if [ "$SITE" = "__ask__" ]; then printf 'Sitio de Jira, para comprobar el token (ej: miempresa.atlassian.net; Enter para saltar): '; read -r SITE; fi
EMAIL=$(printf '%s' "$EMAIL" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
TOKEN=$(printf '%s' "$TOKEN" | tr -d '\r\n ')
SITE=$(printf '%s' "$SITE" | tr -d '\r ' | sed 's#^https\{0,1\}://##; s#/.*$##')
case "$EMAIL" in *@*) ;; *) die "el email no parece válido." ;; esac
[ -n "$TOKEN" ] || die "falta el token."

# Comprobar el token contra Jira, si hay sitio y curl.
if [ -n "$SITE" ] && command -v curl >/dev/null 2>&1; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -u "$EMAIL:$TOKEN" "https://$SITE/rest/api/3/myself" 2>/dev/null)
  case "$CODE" in
    200) echo "El token funciona en $SITE." ;;
    401 | 403) die "Jira rechazó el email o el token en $SITE (código $CODE). Revisá los dos y volvé a correrlo." ;;
    *) echo "AVISO: no pude comprobar el token en $SITE (código ${CODE:-sin respuesta}). Sigo igual." ;;
  esac
fi

AUTH=$(printf '%s' "$EMAIL:$TOKEN" | base64 | tr -d '\r\n')
claude mcp remove atlassian -s local >/dev/null 2>&1 || true
if ! claude mcp add --transport http --scope local --header "Authorization: Basic $AUTH" atlassian "$URL" >/dev/null 2>&1; then
  die "claude mcp add falló. Probá a mano: claude mcp add --transport http --scope local --header \"Authorization: Basic <email:token en base64>\" atlassian $URL"
fi
echo "Listo: en este proyecto ($(pwd)), Jira usa la cuenta $EMAIL."
echo "Reiniciá Claude Code para que tome la conexión."
if [ -n "$SITE" ]; then
  echo "Anotá el sitio en las reglas del proyecto, así el PM usa ese y no otro: Sitio de Jira: $SITE"
fi
