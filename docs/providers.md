# Claude, Codex o Gemini en cada rol

La oficina puede repartir sus roles entre tres proveedores de IA: por ejemplo, Codex como developer de backend, Gemini como developer de front, dos QA que se validan entre ellos y Claude en todo lo demás. Esta guía explica cómo configurarlo, qué cambia y qué tenés que tener en cuenta.

## Por defecto: todo en Claude

**Si no configurás nada, la oficina funciona igual que siempre:** todos los roles son agentes de Claude, con sus modelos de siempre y razonamiento medio. La configuración de proveedores es opcional. Mientras no exista `.claude/office-agents.json`, el PM ni la mira, y el puente a Codex y Gemini no se usa.

Para volver a ese estado en cualquier momento: `bash .claude/office-agents.sh reset --all`, o borrar `.claude/office-agents.json`.

## Qué se puede configurar

| Rol | Nombre en la configuración | Qué se elige |
| --- | --- | --- |
| PM | `pm` | El PM es **siempre Claude**: es la sesión de Claude Code. Lo que se elige son sus **asesores** (Codex, Gemini o los dos), a los que les pide una segunda opinión antes de proponerte un plan o un diseño. |
| QA | `qa` | Uno o varios. Con varios, revisan por separado y después se validan entre ellos (ver "QA con varios proveedores"). |
| Departamentos | `backend.architect`, `backend.developer`, `backend.tester`, `frontend.architect`, `frontend.designer`, `frontend.developer`, `frontend.tester`, `database.developer`, `database.tester`, `scraper.developer`, `scraper.tester`, `devops.architect`, `devops.developer`, `devops.tester` | Un proveedor por rol. |
| Agentes propios del proyecto | `project.<nombre>` (el agente `.claude/agents/<nombre>.md`) | Un proveedor por rol. |

`bash .claude/office-agents.sh roles` muestra la lista.

## Modelos: a la par de Claude

No hace falta elegir el modelo. Cada rol tiene el nivel de su agente de Claude, y en Codex o Gemini usa el modelo equivalente, con razonamiento medio:

| Nivel | Roles | Claude | Codex | Gemini |
| --- | --- | --- | --- | --- |
| Opus | Asesores del PM, QA, arquitectos | Opus | `gpt-6-astra` | `gemini-4-argon` |
| Sonnet | Developers, testers, designer | Sonnet | `gpt-6.1-sol` | `gemini-3.8-flash` |

Es la tabla de dev-office (octubre de 2026). Los nombres de los modelos cambian seguido y no todas las cuentas tienen todos, así que el proyecto la puede cambiar (ver "Cambiar la tabla de modelos").

**Razonamiento:** todos los roles, de cualquier proveedor, van en **medio** (`effort: medium` en los agentes de Claude, `model_reasoning_effort="medium"` en Codex y `--effort medium` en Antigravity). Más razonamiento gasta más tokens y tarda más.

## Requisitos

| Proveedor | Instalar | Iniciar sesión |
| --- | --- | --- |
| Claude | Ya lo tenés: es Claude Code. | — |
| Codex | `npm install -g @openai/codex` (en macOS también `brew install --cask codex`). GPT-6 Astra necesita la versión 0.153.0 o más nueva. | `codex login`, con tu plan de ChatGPT o una API key. |
| Gemini | Se usa con **Antigravity CLI** (`agy`). macOS y Linux: `curl -fsSL https://antigravity.google/cli/install.sh \| bash`. Windows (PowerShell): `irm https://antigravity.google/cli/install.ps1 \| iex`. | Corré `agy` una vez e iniciá sesión con tu cuenta de Google. |

En Windows, después de instalar, cerrá y abrí la terminal y Claude Code para que los encuentre.

**Por qué Antigravity y no Gemini CLI:** desde el 18 de junio de 2026, Gemini CLI no atiende cuentas personales de Google (gratis, Google AI Pro ni Ultra), y Antigravity CLI es su reemplazo. Además, Gemini 4 Argon, el modelo de nivel Opus, está en Antigravity y no en Gemini CLI. Que tu cuenta lo tenga depende de tu plan de Google: lo ves con `agy models`.

## Configurar

### Desde Claude Code

Corré `/office:office-agents`. La skill copia el script de configuración al proyecto (`.claude/office-agents.sh` y `.claude/office-agents.cmd`), te muestra cómo está y te ayuda a elegir. También la ofrece `/office:office-setup`.

### Desde la terminal del proyecto

macOS, Linux o Git Bash:

```bash
bash .claude/office-agents.sh                        # menú interactivo
bash .claude/office-agents.sh set backend.developer codex
bash .claude/office-agents.sh set frontend.developer gemini
bash .claude/office-agents.sh set qa claude codex    # dos QA que se validan entre ellos
bash .claude/office-agents.sh set pm codex           # Codex como asesor del PM
bash .claude/office-agents.sh show                   # cómo quedó cada rol
bash .claude/office-agents.sh check                  # ¿están instalados, con sesión y con los modelos?
```

Windows, desde CMD o PowerShell: `.claude\office-agents.cmd` con los mismos comandos.

Otros comandos:

| Comando | Qué hace |
| --- | --- |
| `reset <rol>` | Vuelve ese rol a Claude. |
| `reset --all` | Vuelve todo a Claude. |
| `set <rol> codex:<modelo>` | El rol usa ese modelo en lugar del de la tabla. Para Claude: `claude:opus`, `claude:sonnet` o `claude:haiku`. |
| `get <rol>` | El proveedor efectivo del rol. |
| `models` | La tabla de modelos por nivel y de dónde sale cada valor. |
| `tier ...` | Cambia la tabla de modelos (ver abajo). |

El PM lee la configuración cada vez que encarga algo: no hace falta reiniciar.

### Para el equipo o solo para vos

- `.claude/office-agents.json` es la configuración **del equipo**: hacé commit de ese archivo y de `.claude/office-agents.sh` y `.claude/office-agents.cmd` para que todos usen la misma.
- Con `--local`, el cambio va a `.claude/office-agents.local.json`, que es **tuya** y no va en git. Manda rol por rol sobre la del equipo. Sirve, por ejemplo, si el equipo usa Codex de developer y vos no tenés cuenta: `bash .claude/office-agents.sh set backend.developer claude --local`.

### Cambiar la tabla de modelos

```bash
bash .claude/office-agents.sh models                              # ver la tabla
bash .claude/office-agents.sh tier gemini opus gemini-3.1-pro-preview
bash .claude/office-agents.sh tier codex effort high              # más razonamiento
bash .claude/office-agents.sh tier codex opus default             # volver al de dev-office
```

Los niveles son `opus`, `sonnet` y `haiku`, y `effort` es el razonamiento. Con `--local`, el cambio es solo para vos.

## Cómo trabaja

1. **El PM lee la configuración** antes de encargar trabajo y te dice en el plan qué proveedor hace cada rol.
2. **Los roles en Claude** son los agentes de siempre.
3. **Los roles en Codex o Gemini** los hace el **puente** (`office:external`, un agente de Claude en Sonnet):
   - le pasa al proveedor las instrucciones del rol, sus skills y el encargo completo;
   - corre el CLI en la carpeta del proyecto, en segundo plano y con un tope de 30 minutos;
   - controla que no haya roto las reglas de la oficina (secretos, lockfiles, alcance del rol, commits y rama). Es un control del script, que no gasta tokens;
   - **no corre tests, lint ni typecheck:** es liviano a propósito, para que el trabajo pesado no gaste Claude. La verificación la hacen el developer (si puede), el tester y QA;
   - le devuelve al PM el reporte con el mismo formato del rol, así que el ciclo de calidad (tester → QA → informe) no cambia.
4. **El informe** te dice qué proveedor hizo cada cosa. Como el puente no repite la verificación, con un rol en Codex o Gemini el tester y QA no se saltean nunca.

Cada encargo deja su prompt, el reporte del proveedor y el registro del CLI en `.office/runs/` (ignorada por git), por si querés ver qué pasó.

### QA con varios proveedores

Si configurás `set qa claude codex` (o los tres), el PM los coordina en tres pasos:

1. **Revisión independiente:** cada QA revisa sin ver lo de los otros.
2. **Validación cruzada:** una sola ronda. Cada QA recibe los hallazgos de los demás y marca cada uno como confirmado (lo reprodujo), refutado (con pruebas) o sin verificar.
3. **Consolidación:**
   - lo confirmado queda con su clasificación;
   - lo que encontró uno solo queda si tiene una reproducción concreta;
   - lo refutado con pruebas queda **en disputa**: nunca bloquea y te llega como importante, con los dos argumentos.

### Modo equipos

Con `bash .claude/office-agents.sh teams on`, cada departamento tiene un líder que encarga el trabajo a su developer y a su tester. El líder respeta esta configuración: si el developer de backend va en Codex, se lo encarga por el puente. Los líderes son siempre Claude (Sonnet), como el PM. Detalle en [Arquitectura: modo equipos](architecture.md#modo-equipos-un-líder-por-departamento).

### Asesores del PM

Con `set pm codex` (o `gemini`, o los dos), antes de presentarte un plan que no es trivial o un diseño, el PM les pide una segunda opinión. Los asesores solo leen. Te muestra en qué coinciden, qué cambiarían y qué riesgos vieron, y qué tomó de cada uno.

## Si algo sale mal

| El PM te dice | Qué pasó | Qué hacer |
| --- | --- | --- |
| **PROVEEDOR NO DISPONIBLE** | El CLI no está instalado, no tiene sesión, se quedó sin cuota o tu cuenta no tiene el modelo. | Corré `bash .claude/office-agents.sh check` y seguí lo que indique. El PM te pregunta si reintentar, hacer ese encargo con Claude o pausar: nunca cambia de proveedor solo. |
| **REGLAS ROTAS** | Codex o Gemini tocó un archivo prohibido (secretos, claves, lockfiles), escribió fuera de su rol, commiteó o cambió de rama. | Revisá `git status` y `.office/runs/` y decidí vos qué deshacer. La oficina no deshace nada sola. |
| **TIEMPO AGOTADO** | El encargo tardó más de 30 minutos. | Pedile al PM que lo divida, o subí `OFFICE_EXTERNAL_TIMEOUT` en el `env` de `.claude/settings.local.json` (en segundos). |

La primera vez que el puente corre Codex o Gemini, Claude Code te pide permiso para el comando: aprobalo para esa sesión.

## Límites que conviene conocer

- **Codex y Gemini no pasan por los hooks de la oficina** (la protección de secretos y de ramas protegidas solo ve las herramientas de Claude). El puente no corre nada en una rama protegida y revisa todo después, pero **detecta, no impide**. Por eso el tester y QA no se saltean nunca.
- **Gemini no corre comandos de la terminal** en este modo: edita archivos y las verificaciones las corren el tester y QA después. Como developer funciona bien; como tester o QA rinde menos, porque no puede ejecutar sus pruebas. Para esos roles conviene Claude o Codex. El puente le pide que lea y busque en el proyecto con sus herramientas de archivos, porque en este modo cualquier comando se rechaza solo. También le pide que haga todo él, sin pasarle trabajo a subagentes: en este modo, el resultado de un subagente no le llega y el encargo se corta por tiempo. Usá Antigravity CLI 1.3.6 o más nuevo; `office-agents.sh check` avisa si tenés uno más viejo.

### Permisos de comandos para Gemini (opcional)

Por defecto, Gemini solo lee y edita archivos, y el lint, el typecheck y los tests los corren el tester y QA después. Un tester en Gemini sin permisos no puede correr tests: en ese caso el PM le pasa el trabajo del tester a Claude o a Codex y te avisa. Si querés que Gemini también corra comandos (para que rinda como tester, o para que verifique su propio trabajo), activá los permisos:

```bash
bash .claude/office-agents.sh gemini-permissions on    # activar
bash .claude/office-agents.sh gemini-permissions off   # desactivar
bash .claude/office-agents.sh gemini-permissions       # ver el estado
```

- **Qué deja correr**, de a uno y sin encadenar (sin `;`, `&&`, `|`, `` ` ``, `$`, `<` ni `>`):
  - git de lectura: `git status`, `git diff`, `git log`, `git show`, `git ls-files`, `git grep` y `git blame`;
  - borrar y mover archivos del repo: `git rm` y `git mv`. Antigravity no tiene herramienta para borrar, así que es la única forma. Git solo actúa sobre archivos que sigue dentro del repo (no sobre `.env` ni nada fuera del proyecto), deja el cambio preparado sin hacer commit y se deshace con `git restore`;
  - listar carpetas: `ls`, `dir` o `Get-ChildItem`;
  - lint, typecheck, tests y chequeo de formato del proyecto: con `pnpm`, `npm`, `yarn` o `bun` (`pnpm test`, `npm run lint`, `pnpm test:unit`, `pnpm format:check`...) y con `npx tsc`, `eslint`, `jest`, `vitest` o `prettier --check`. `pnpm format` a secas no, porque suele formatear el repo entero;
  - formatear archivos puntuales: `npx prettier --write` seguido de cada archivo, con su ruta relativa (`npx prettier --write src/app.ts src/util.ts`). Nada de `.`, carpetas, comodines, rutas absolutas o que empiecen con `..`, ni opciones extra: así no reformatea archivos que no tienen que ver con la tarea. Las reglas no pueden bloquear un `..` en el medio de una ruta (`src/../../otro.ts`), pero prettier solo cambia el formato.
- **Lo demás se sigue rechazando solo:** commits, push, cambios de rama, instalar paquetes, `rm`, `del` o `Remove-Item`, red y cualquier comando encadenado.
- **Dónde quedan:** en `~/.gemini/config/config.json` (en Windows, `C:\Users\<usuario>\.gemini\config\config.json`), en `userSettings.globalPermissionGrants.allow`. Es el único lugar del que Antigravity, sin pantalla, lee permisos de comandos; los de `settings.json` los ignora. La primera vez se guarda una copia del archivo (`config.json.bak-dev-office`). `off` saca solo las reglas de la oficina y deja las tuyas.
- **Valen para toda tu computadora,** no solo para un proyecto: Antigravity no permite guardar permisos dentro del repo. También aplican cuando usás `agy` por tu cuenta.
- **Correr tests ejecuta código del proyecto,** igual que con Claude o Codex. No uses `--dangerously-skip-permissions`: aprueba cualquier comando.
- **Antigravity no tiene herramienta para borrar archivos:** puede ver, crear, editar y buscar, pero para borrar necesita un comando. Con los permisos activados usa `git rm` y `git mv`; sin ellos, el PM le pasa los encargos de borrar o mover archivos a Claude (o a Codex) y te avisa.
- **Si ya los habías activado antes de esta versión,** corré `gemini-permissions on` otra vez para sumar `git rm` y `git mv` (el estado dice "incompletos" hasta entonces).
- **Un comando rechazado corta toda la corrida:** sin pantalla, cuando Antigravity rechaza un comando, Gemini termina ahí, sin reporte. Por eso el encargo le pide buscar con su herramienta `grep_search` y no con `git grep`, y correr solo los comandos de la lista, tal cual. Si igual pasa, el puente le da **un segundo intento** con el aviso de qué se rechazó (gasta tokens de Gemini, no de Claude; `OFFICE_GEMINI_RETRY=0` lo apaga).
- **Qué le rechazaron:** el puente corre a Gemini con `--output-format stream-json` y anota cada paso en el registro de la corrida (`.office/runs/<corrida>/log.txt`). Si Antigravity le rechaza un comando, el resumen dice cuál fue, exacto. El flujo completo queda en `stream.jsonl`.
- **En Windows**, el puente prende el sandbox de Codex en modo `unelevated`; sin eso, Codex no puede ni leer el proyecto ("blocked by policy"). Si usás Codex por tu cuenta en Windows y te pasa lo mismo, agregá a `%USERPROFILE%\.codex\config.toml` la sección `[windows]` con `sandbox = "unelevated"`.
- **Costo:** cada proveedor se paga con su cuenta, y el puente gasta un poco de Claude (Sonnet) por encargo para pasarlo y revisarlo.
- **Encargos grandes:** el puente corre al proveedor en segundo plano y lo espera hasta 30 minutos (`OFFICE_EXTERNAL_TIMEOUT`). Si se pasa, conviene dividir el encargo.
- **Si una versión nueva de un CLI cambia sus opciones,** se pueden agregar opciones extra con `OFFICE_CODEX_ARGS` y `OFFICE_GEMINI_ARGS` en `.claude/settings.json`, sin esperar una versión nueva de la oficina.

Para el detalle técnico (cómo se arma el prompt, qué controla el runner, los códigos de salida), ver [Arquitectura](architecture.md#proveedores-por-rol) y la skill `external-agents`.
