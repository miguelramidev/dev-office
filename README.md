# dev-office

Una oficina de desarrollo para [Claude Code](https://code.claude.com): vos sos el CEO, un **PM** conversa con vos y coordina, los **departamentos** hacen el trabajo y un **QA** intenta romper todo antes de que llegue a tu código.

> Estado: **v0.1 en construcción**. La API de los plugins puede cambiar entre versiones.

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
5. **Informe.** El PM te entrega un resumen por departamento: qué se hizo, qué archivos cambiaron, resultados de calidad y decisiones pendientes.

Vos solo hablás con el PM.

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
| `office`       | PM, QA, puente a Codex y Gemini, hooks de protección y registro de actividad, skills `office-setup`, `start-ticket`, `open-pr`, `review-fixes`, `handoff-ticket` y `office-agents` | PM y QA: Opus; puente: Sonnet |
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

## Qué va en el plugin y qué en tu proyecto

| En dev-office (genérico)       | En tu proyecto (propio)            |
| ------------------------------ | ---------------------------------- |
| Agentes: PM, QA, departamentos | `CLAUDE.md` y reglas del proyecto  |
| Hooks generales                | Permisos (`.claude/settings.json`) |
| Skills genéricas               | Skills propias del proyecto        |

Los agentes leen las reglas de cada proyecto, así que el mismo equipo se adapta a proyectos distintos. Los permisos van siempre en el proyecto porque Claude Code no permite que un plugin los defina.

## Documentación

- [Arquitectura: cómo trabaja la oficina](docs/architecture.md)
- [Instalar en un proyecto](docs/installation.md)
- [Claude, Codex o Gemini en cada rol](docs/providers.md)
- [Agregar un departamento](docs/add-department.md)
- [Skills de la comunidad](docs/community-skills.md)
- [Cambios por versión](CHANGELOG.md)

## Licencia

[MIT](LICENSE)
