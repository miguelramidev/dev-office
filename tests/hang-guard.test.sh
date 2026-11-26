#!/usr/bin/env bash
# Pruebas del hook que frena los comandos que no terminan solos
# (plugins/office/scripts/hang-guard.sh).
# Uso: bash tests/hang-guard.test.sh

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO/plugins/office/scripts/hang-guard.sh"
FAILED=0
unset CI PLAYWRIGHT_HTML_OPEN GIT_EDITOR OFFICE_HANG_GUARD

# run <comando> [en segundo plano: true|false]: deja el código en CODE y el mensaje en MSG.
run() {
  MSG=$(jq -cn --arg c "$1" --argjson bg "${2:-false}" '{tool_name: "Bash", tool_input: {command: $c, run_in_background: $bg}}' | bash "$HOOK" 2>&1)
  CODE=$?
}
stops() { run "$1" "${2:-false}"; if [ "$CODE" -eq 2 ]; then echo "ok    frena: $1${2:+ (bg=$2)}"; else echo "FALLA no frenó: $1"; FAILED=1; fi; }
passes() { run "$1" "${2:-false}"; if [ "$CODE" -eq 0 ]; then echo "ok    deja pasar: $1${2:+ (bg=$2)}"; else echo "FALLA frenó: $1"; printf '%s\n' "$MSG" | sed 's/^/      /'; FAILED=1; fi; }

# Servidores
stops "npm run dev"
stops "pnpm dev"
stops "pnpm --filter web dev"
stops "yarn start"
stops "cd apps/web && npm run dev"
stops "npx next dev -p 3001"
stops "vite"
stops "npx vite --port 5173"
stops "flutter run -d chrome"
stops "docker compose up"
stops "tail -f logs/app.log"
stops "PORT=4000 npm run start"
stops "python -m http.server 8000"
stops "npm run dev &"
passes "npm run dev" true
passes "npm run dev > .office/dev.log 2>&1 &"
passes "docker compose up -d"
passes "vite build"
passes "npm run build"
passes "npm run dev:db-migrate"
passes "timeout 60 npm run dev"
passes "tail -n 50 logs/app.log"

# Watch
stops "npx vitest watch"
stops "npx jest --watch"
stops "jest --watchAll"
stops "npx tsc -w"
stops "npm run test:watch"
stops "ng test"
stops "npx react-scripts test"
stops "gh run watch 123"
passes "npx vitest run src/a.test.ts"
passes "npx vitest related src/a.ts --run"
passes "npx jest --ci --watchAll=false"
passes "ng test --watch=false"
passes "CI=true npx react-scripts test"
passes "npx tsc --noEmit"
passes "flutter test test/a_test.dart"

# Playwright
stops "npx playwright test"
stops "npx playwright show-report"
passes "PLAYWRIGHT_HTML_OPEN=never npx playwright test"
passes "npx playwright test --reporter=list"
MSG=$(jq -cn '{tool_name: "Bash", tool_input: {command: "npx playwright test"}}' | PLAYWRIGHT_HTML_OPEN=never bash "$HOOK" 2>&1); [ $? -eq 0 ] && echo "ok    deja pasar playwright con PLAYWRIGHT_HTML_OPEN=never en el entorno" || { echo "FALLA playwright con la variable en el entorno"; FAILED=1; }

# Interactivos (también en segundo plano)
stops "git commit"
stops "git add -A && git commit" true
stops "git rebase -i HEAD~3"
stops "git add -p"
stops "npm init"
stops "vim src/a.ts"
passes 'git commit -m "fix: x"'
passes 'git commit -am "fix: x"'
passes "git commit -F .office/msg.txt"
passes "git commit --amend --no-edit"
passes "git rebase origin/main"
passes "GIT_EDITOR=true git commit"
passes "npm init -y"
passes "git -C apps/web commit -m x"

# Mensaje y apagado
run "npm run dev"
printf '%s' "$MSG" | grep -q "run_in_background: true" && echo "ok    el mensaje dice cómo correrlo" || { echo "FALLA el mensaje no dice cómo correrlo"; FAILED=1; }
MSG=$(jq -cn '{tool_name: "Bash", tool_input: {command: "npm run dev"}}' | OFFICE_HANG_GUARD=off bash "$HOOK" 2>&1); [ $? -eq 0 ] && echo "ok    OFFICE_HANG_GUARD=off lo apaga" || { echo "FALLA no se apaga"; FAILED=1; }
MSG=$(jq -cn '{tool_name: "Edit", tool_input: {file_path: "a"}}' | bash "$HOOK" 2>&1); [ $? -eq 0 ] && echo "ok    ignora lo que no es Bash" || { echo "FALLA frenó algo que no es Bash"; FAILED=1; }
jq -e '.hooks.PreToolUse | any(.matcher == "Bash" and (.hooks | any(.command | test("hang-guard.sh"))))' "$REPO/plugins/office/hooks/hooks.json" >/dev/null && echo "ok    hooks.json lo registra para Bash" || { echo "FALLA hooks.json no lo registra"; FAILED=1; }

[ "$FAILED" -eq 0 ] && echo "Todas las pruebas pasan." || { echo "Hay pruebas que fallan."; exit 1; }
