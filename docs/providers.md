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
   - corre el CLI en la carpeta del proyecto, con un tope de 9 minutos;
   - revisa lo que cambió y, en un developer, corre typecheck, lint y tests, con una vuelta de corrección como máximo; en un tester, confirma que el resultado que informa es el real;
   - le devuelve al PM el reporte con el mismo formato del rol, así que el ciclo de calidad (tester → QA → informe) no cambia.
4. **El informe** te dice qué proveedor hizo cada cosa y qué encontró el puente al verificar.

Cada encargo deja su prompt, el reporte del proveedor y el registro del CLI en `.office/runs/` (ignorada por git), por si querés ver qué pasó.

### QA con varios proveedores

Si configurás `set qa claude codex` (o los tres), el PM los coordina en tres pasos:

1. **Revisión independiente:** cada QA revisa sin ver lo de los otros.
2. **Validación cruzada:** una sola ronda. Cada QA recibe los hallazgos de los demás y marca cada uno como confirmado (lo reprodujo), refutado (con pruebas) o sin verificar.
3. **Consolidación:**
   - lo confirmado queda con su clasificación;
   - lo que encontró uno solo queda si tiene una reproducción concreta;
   - lo refutado con pruebas queda **en disputa**: nunca bloquea y te llega como importante, con los dos argumentos.

### Asesores del PM

Con `set pm codex` (o `gemini`, o los dos), antes de presentarte un plan que no es trivial o un diseño, el PM les pide una segunda opinión. Los asesores solo leen. Te muestra en qué coinciden, qué cambiarían y qué riesgos vieron, y qué tomó de cada uno.

## Si algo sale mal

| El PM te dice | Qué pasó | Qué hacer |
| --- | --- | --- |
| **PROVEEDOR NO DISPONIBLE** | El CLI no está instalado, no tiene sesión, se quedó sin cuota o tu cuenta no tiene el modelo. | Corré `bash .claude/office-agents.sh check` y seguí lo que indique. El PM te pregunta si reintentar, hacer ese encargo con Claude o pausar: nunca cambia de proveedor solo. |
| **REGLAS ROTAS** | Codex o Gemini tocó un archivo prohibido (secretos, claves, lockfiles), escribió fuera de su rol, commiteó o cambió de rama. | Revisá `git status` y `.office/runs/` y decidí vos qué deshacer. La oficina no deshace nada sola. |
| **TIEMPO AGOTADO** | El encargo tardó más de 9 minutos. | Pedile al PM que lo divida, o subí `OFFICE_EXTERNAL_TIMEOUT` en `.claude/settings.json` (en segundos, sin pasar de 590). |

La primera vez que el puente corre Codex o Gemini, Claude Code te pide permiso para el comando: aprobalo para esa sesión.

## Límites que conviene conocer

- **Codex y Gemini no pasan por los hooks de la oficina** (la protección de secretos y de ramas protegidas solo ve las herramientas de Claude). El puente no corre nada en una rama protegida y revisa todo después, pero **detecta, no impide**. Por eso el tester y QA no se saltean nunca.
- **Gemini no corre comandos de la terminal** en este modo: edita archivos y el puente corre las verificaciones. Como developer funciona bien; como tester o QA rinde menos, porque no puede ejecutar sus pruebas. Para esos roles conviene Claude o Codex.
- **Costo:** cada proveedor se paga con su cuenta, y el puente gasta un poco de Claude (Sonnet) por encargo para pasarlo y revisarlo.
- **Encargos grandes:** cada encargo se corta a los 9 minutos, porque Claude Code espera como máximo 10 por comando.
- **Si una versión nueva de un CLI cambia sus opciones,** se pueden agregar opciones extra con `OFFICE_CODEX_ARGS` y `OFFICE_GEMINI_ARGS` en `.claude/settings.json`, sin esperar una versión nueva de la oficina.

Para el detalle técnico (cómo se arma el prompt, qué controla el runner, los códigos de salida), ver [Arquitectura](architecture.md#proveedores-por-rol) y la skill `external-agents`.
