# Agregar un departamento

Receta para "contratar" un departamento nuevo. Los ejemplos de referencia son `plugins/dept-backend` (con rol de diseño) y `plugins/dept-scraper` (sin rol de diseño).

## 1. Nombre

- Plugin: `dept-<área>` en inglés y en minúsculas (`dept-backend`, `dept-frontend`, `dept-database`).
- Agentes:
  - `developer`: siempre.
  - `tester`: si el área produce código testeable.
  - Un rol de diseño, si el área toma decisiones que conviene aprobar antes de programar: `architect` (estructura y contratos) o `designer` (pantallas y experiencia).
- Dentro de Claude Code se llaman `dept-<área>:<agente>`, por ejemplo `dept-backend:architect`.

## 2. Estructura

```
plugins/dept-<área>/
├── .claude-plugin/plugin.json
├── agents/
│   ├── architect.md     ← opcional: rol de diseño
│   ├── developer.md
│   └── tester.md        ← opcional
└── skills/              ← opcional: conocimiento genérico del área
```

`plugin.json`:

```json
{
  "name": "dept-<área>",
  "version": "0.1.0",
  "description": "Departamento de <área>: ...",
  "dependencies": ["office"]
}
```

## 3. Agentes

Copiá los agentes de `dept-backend` (o de `dept-scraper` si el área no tiene rol de diseño) y adaptá lo específico del área. Reglas obligatorias:

- **`description` empieza con "Departamento de <área> - <rol>."** y dice con claridad qué hace y cuándo lo activa el PM. El PM elige a quién activar leyendo esa descripción.
- **Modelo:** `sonnet` para developer y tester. Los roles de diseño que definen estructura (como `architect`) van en `opus`, porque sus errores se multiplican en todo lo que se construye encima.
- **Roles de diseño:** solo escriben en `docs/design/`, siguen la plantilla de `dept-backend/agents/architect.md` y terminan siempre pidiendo aprobación del diseño.
- **Sin `permissionMode`, `hooks` ni `mcpServers`:** en plugins Claude Code los ignora.
- **`Skill` en `tools`:** sin esa herramienta el agente no puede usar las skills del proyecto ni las de la comunidad.
- **Skills de la comunidad:** si hay skills oficiales para la tecnología del área, agregá la sección "Skills de la comunidad" en la skill del departamento (ver `dept-database/skills/solid-database/SKILL.md`) y sumalas a [docs/community-skills.md](community-skills.md) y a la tabla de `office-setup`.
- **Mantener las secciones comunes:** leer el `CLAUDE.md` del proyecto antes de trabajar, límites (no tocar lo del otro rol, no trabajar fuera del proyecto, leer con Read y no con `cat`, comandos de a uno), "Cuando necesitás una aprobación" y el formato de reporte al PM.
- **Todo el texto en español; nombres de código en inglés.**

## 4. Registrar

1. Agregar el plugin a `.claude-plugin/marketplace.json`.
2. Agregar el departamento a la tabla de plugins del `README.md`.
3. Registrar el cambio en `CHANGELOG.md` como versión menor (por ejemplo 0.2.0 → 0.3.0).

## 5. Probar antes de publicar

```bash
claude plugin validate plugins/dept-<área>
```

Después probalo en un proyecto real instalando el marketplace desde la carpeta local (los cambios se ven sin publicar una versión):

```bash
claude plugin marketplace add ~/dev/dev-office
claude plugin install dept-<área>@dev-office --scope project
```

Hacé una tarea chica con el PM y verificá que:

- El PM active al departamento nuevo para tareas de su área, y no para otras.
- El ciclo developer → tester → QA funcione.
- No aparezcan pedidos de permiso inesperados.
