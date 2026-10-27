# dev-office

Una oficina de desarrollo para [Claude Code](https://code.claude.com): vos sos el CEO, un **PM** conversa con vos y coordina, los **departamentos** hacen el trabajo y un **QA** intenta romper todo antes de que llegue a tu código.

> Estado: **en desarrollo activo (versiones 0.x)**. La API de los plugins puede cambiar entre versiones; qué cambió en cada una está en el [registro de cambios](CHANGELOG.md).

## Empezá acá

Si es la primera vez que usás la oficina, seguí estos pasos en orden:

1. **Instalala en tu proyecto:** requisitos, plugins y `office-setup`. → [Instalar en un proyecto](docs/installation.md)
2. **Trabajá con el PM:** `claude --agent office:pm` y contale qué querés hacer. → [Empezar a trabajar](docs/installation.md#4-empezar-a-trabajar)
3. **Mirá la oficina en vivo:** `/office:observer`. → [Ver qué hace el equipo](docs/installation.md#5-ver-qué-hace-el-equipo)
4. **Opcional, Codex o Gemini en algunos roles:** `/office:office-agents`. → [Claude, Codex o Gemini en cada rol](docs/providers.md)
5. **Opcional, un líder por departamento:** `bash .claude/office-agents.sh teams on`. → [Modo equipos](docs/architecture.md#modo-equipos-un-líder-por-departamento)
6. **Mantenela al día:** `/office:update` o la lista de comandos. → [Actualizar](docs/installation.md#6-actualizar)

Si algo no anda: [Problemas comunes](docs/installation.md#8-problemas-comunes). Para entender cómo trabaja todo por dentro: [Arquitectura](docs/architecture.md).

### Comandos de la oficina

| Comando | Para qué |
| --- | --- |
| `claude --agent office:pm` | Abrir la oficina: hablás con el PM. |
| `/office:office-setup` | Preparar un proyecto la primera vez (permisos, `.gitignore`, ramas, Jira). |
| `/office:start-ticket PROJ-123` | Empezar un ticket de Jira: crea la rama correcta y lo pasa a "en curso". |
| `/office:open-pr` | Abrir el PR del trabajo terminado. |
| `/office:review-fixes` | Resolver los comentarios del PR y revisar lo que corregiste a mano. |
| `/office:handoff-ticket` | Avisarle a otro equipo, en su ticket de Jira, de un cambio que lo afecta. |
| `/office:office-agents` | Elegir Claude, Codex o Gemini para cada rol, y el modo equipos. |
| `/office:observer` | Abrir la oficina en pixel art en el navegador. |
| `/office:usage` | Ver cuántos tokens gastó cada agente en cada tarea, por agente y por proveedor. El PM lo agrega al final de su informe. |
| `/office:update` | Dejar el botón para actualizar la oficina en todos tus proyectos. |

## Cómo funciona

```
                         CEO (vos)
                             │
                        PM (Opus)
       ┌─────────────┬───────┴───────┬──────────────┐
    Backend       Frontend        Base de datos   Scraping   ...
  architect      designer        developer       developer
  developer      developer       tester          tester
  tester         tester
       └─────────────┴───────┬───────┴──────────────┘
                             │
                        QA (Opus)
                   el enemigo de la app
```

1. **Reunión.** Hablás con el PM sobre qué cambiar, mejorar o priorizar. Opina, te contradice si hace falta y te propone opciones. No activa a nadie hasta que decidas.
2. **Diseño.** Para funciones nuevas o cambios grandes, los roles de diseño (el arquitecto de backend y el designer de frontend) escriben una propuesta en `docs/design/` y vos la aprobás antes de que se programe. Los bugs y ajustes chicos se saltean este paso.
3. **Ejecución.** Con tu decisión, el PM arma un plan, lo aprobás y activa solo a los departamentos que hacen falta. El resto no trabaja ni gasta tokens.
4. **Calidad.** Todo el código pasa por el tester del departamento y después por QA. Si algo falla, vuelve al departamento, con un máximo de 3 vueltas.
5. **Informe.** El PM te entrega un resumen por departamento: qué se hizo, qué archivos cambiaron, resultados de calidad y decisiones pendientes. Al final, el consumo de tokens de cada agente por tarea y el total por agente y por proveedor, para que veas qué conviene mover a Codex o Gemini, o desactivar.

Vos solo hablás con el PM.

**Modo equipos (opcional).** Cada departamento puede tener un líder: el PM le pasa el encargo, el líder lo reparte entre su developer y su tester, coordina las vueltas entre ellos dentro del departamento y le entrega al PM un reporte con las acciones requeridas. Se activa con `bash .claude/office-agents.sh teams on` y usa los agent teams de Claude Code, que son experimentales y gastan más tokens. Sin activarlo, todo sigue como siempre: el PM coordina a cada developer y tester.

**La oficina en pixel art.** Con `/office:observer` se abre en el navegador una página local donde ves la oficina trabajar en vivo: el PM camina de oficina en oficina y va a buscar el reporte de cada departamento que termina, la gente se levanta a hablar con su líder, el tester le lleva la falla al developer, los QA debaten sus hallazgos y en los ratos libres alguien va por un café o a charlar con otro departamento, y el PM espera en la puerta de Reuniones hasta que lo llamás; cada empleado muestra qué está haciendo, con qué proveedor y cuántos tokens lleva, y abajo tenés los tokens por proveedor, los resultados de tester y QA y la actividad de la sesión. Cuando el PM te entrega un informe, al que más trabajó le llega una pizza de compensación. Cada sesión empieza con una oficina básica que se amuebla con los tokens que gasta el equipo: en la tienda comprás escritorios, plantas, cuadros, muebles y ropa, el nivel sube con los tokens y el catálogo cambia en cada sesión. Se arma con los hooks de la oficina, sin servidor y sin gastar tokens.

**Claude, Codex o Gemini en cada rol.** Cada rol de la oficina lo puede hacer el proveedor que elijas: por ejemplo, Codex como developer de backend, Gemini como developer de front y Claude en el resto. Lo configurás con `/office:office-agents` o con el script que queda en el proyecto (`bash .claude/office-agents.sh`, o `.claude\office-agents.cmd` en Windows). Cada rol usa el modelo del mismo nivel que tiene en Claude: los roles de Opus (PM, QA, arquitectos) van con GPT-6 Astra o Gemini 4 Argon, y los de Sonnet con GPT-6.1 Sol o Gemini 3.8 Flash, todos con razonamiento medio. Gemini se usa con Antigravity CLI y tu cuenta de Google. El PM es siempre Claude, pero puede consultar a Codex o Gemini como asesores antes de proponerte un plan. Si configurás más de un QA, cada uno revisa por separado y después validan lo que encontraron los otros: lo confirmado queda y lo que está en disputa te llega con los dos argumentos. Si no configurás nada, todo sigue en Claude como siempre. Guía completa: [docs/providers.md](docs/providers.md).

**Ramas y tickets.** Nunca se trabaja sobre las ramas protegidas del proyecto (por ejemplo `main`, `dev` y las `epic/*`): un hook bloquea las ediciones, los commits y los pushes ahí. Si usás Jira, decile al PM "trabajemos en PROJ-123" (o usá `/office:start-ticket PROJ-123`). Según el tipo del ticket, su épica y sus etiquetas, crea la rama correcta (por ejemplo `feature/PROJ-123-<resumen>` desde la rama de su épica), pasa el ticket a "en curso" en Jira y te dice a qué rama va el PR.

**Colecciones de la API.** Si instalás `dept-backend`, el proyecto tiene en `docs/api/` colecciones de Postman con entornos compartidos, autorización y un login que guarda el token solo:

- **La del proyecto:** toda la API (REST y GraphQL), ordenada por recurso, para pasársela al frontend. Si el proyecto ya tiene endpoints, pedile al PM "generá la colección de la API" y la arma completa desde el código.
- **Una por épica** (`docs/api/epics/`): los flujos de la épica en orden, con tests en cada paso, para correrlos de punta a punta con el Collection Runner de Postman. Cuando la épica se integra, queda como prueba de regresión.

Se actualizan cada vez que cambia un endpoint, así siempre tenés la API de tu rama.

**Pull requests y revisiones.** Con el trabajo terminado, pedile al PM "abrí el PR" (o usá `/office:open-pr`): corre las verificaciones, elige el destino según el ticket y te muestra el PR antes de abrirlo. Si después dejás comentarios en el PR o corregís algo a mano, decile "revisá mis correcciones del PR" (o `/office:review-fixes`): lee los comentarios sin resolver, los checks y tus commits, y los corrige el departamento que corresponde. Nada se sube ni se publica sin tu confirmación, y los PRs los mergeás vos.

**Avisos a otros equipos.** Si un cambio obliga a otro equipo a adaptarse (por ejemplo, el backend cambió la API y el front no se tocó), al abrir el PR la oficina busca en Jira el ticket de ese equipo relacionado con el cambio. Le agrega a la descripción qué cambió y qué tiene que hacer, y deja un comentario para que se entere quien lo sigue. Si no hay ticket, propone crearlo en la misma épica. Antes de escribir te muestra el texto, y si el ticket no tiene responsable te pregunta a quién se asigna. También lo podés pedir con `/office:handoff-ticket`. Necesita [`gh`](https://cli.github.com/) con sesión iniciada.

## Plugins

| Plugin         | Contiene                                                                  | Modelos       |
| -------------- | ------------------------------------------------------------------------- | ------------- |
| `office`       | PM, QA, puente a Codex y Gemini, hooks de protección y registro de actividad, observer en pixel art, skills `office-setup`, `start-ticket`, `open-pr`, `review-fixes`, `handoff-ticket`, `office-agents`, `observer`, `usage` y `update` | PM y QA: Opus; puente: Sonnet |
| `dept-backend` | Arquitecto, developer y tester de backend, skills de backend sólido y de colección de Postman | Arquitecto: Opus; developer y tester: Sonnet |
| `dept-frontend` | Arquitecto, designer de UI/UX, developer y tester de web (Next.js, React) y móvil (React Native), skills de frontend sólido y de lectura de diseños entregados (imágenes o Figma) | Arquitecto: Opus; el resto: Sonnet |
| `dept-database` | Developer (DB manager) y tester de Postgres y MongoDB, skill de base de datos sólida | Sonnet |
| `dept-scraper` | Developer y tester de scraping, skill de scraping responsable             | Sonnet        |
| `dept-devops` | Arquitecto, developer y tester de CI/CD, despliegues, infraestructura como código, contenedores y servidores, skill de DevOps sólido | Arquitecto: Opus; developer y tester: Sonnet |

Cada departamento es un plugin aparte: instalás solo los que tu proyecto necesita. Todos dependen de `office`.

Para el detalle técnico de cada tecnología, los agentes también usan las skills oficiales de Supabase (Postgres), MongoDB, Vercel (React, Next.js y React Native) y Expo, si las instalás en el proyecto. Ver [skills de la comunidad](docs/community-skills.md).

## Requisitos

- Claude Code actualizado.
- `git` y `jq` (los usan los hooks).
- `gh` con sesión iniciada, para abrir PRs y aplicar correcciones de revisión (opcional).
- Codex CLI o Antigravity CLI (para Gemini) con sesión iniciada, si querés que hagan algún rol (opcional).
- Linux, macOS o Windows. En Windows funciona de forma nativa (con Git for Windows) o dentro de WSL2. Ver [instalación](docs/installation.md).

## Instalación

Dentro de Claude Code, en la carpeta de tu proyecto:

```text
/plugin marketplace add miguelramidev/dev-office
/plugin install office@dev-office
/plugin install dept-backend@dev-office
/plugin install dept-frontend@dev-office
/plugin install dept-database@dev-office
/plugin install dept-scraper@dev-office
/plugin install dept-devops@dev-office
```

Después preparás el proyecto con la skill `office-setup`, que crea la configuración de permisos y lo necesario en `.gitignore`. Para empezar a trabajar:

```bash
claude --agent office:pm
```

Guía completa: [docs/installation.md](docs/installation.md).

**Para actualizar**, `/office:update` te deja un script que con un doble click (`update-office.cmd` en Windows, `update-office.command` en macOS) actualiza la oficina en todos tus proyectos.

## Qué va en el plugin y qué en tu proyecto

| En dev-office (genérico)       | En tu proyecto (propio)            |
| ------------------------------ | ---------------------------------- |
| Agentes: PM, QA, departamentos | `CLAUDE.md` y reglas del proyecto  |
| Hooks generales                | Permisos (`.claude/settings.json`) |
| Skills genéricas               | Skills propias del proyecto        |

Los agentes leen las reglas de cada proyecto, así que el mismo equipo se adapta a proyectos distintos. Los permisos van siempre en el proyecto porque Claude Code no permite que un plugin los defina.

## Documentación

- [Arquitectura: cómo trabaja la oficina](docs/architecture.md)
  - [Modo equipos: un líder por departamento](docs/architecture.md#modo-equipos-un-líder-por-departamento)
  - [Observer: la oficina en pixel art](docs/architecture.md#observer)
- [Instalar en un proyecto](docs/installation.md)
  - [Actualizar](docs/installation.md#6-actualizar)
  - [Problemas comunes](docs/installation.md#8-problemas-comunes)
- [Claude, Codex o Gemini en cada rol](docs/providers.md)
- [Agregar un departamento](docs/add-department.md)
- [Skills de la comunidad](docs/community-skills.md)
- [Cambios por versión](CHANGELOG.md)

## Licencia

[MIT](LICENSE)
