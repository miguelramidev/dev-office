# Agregar un departamento

Receta para "contratar" un departamento nuevo. El ejemplo de referencia es `plugins/dept-scraper`.

## 1. Nombre

- Plugin: `dept-<área>` en inglés y en minúsculas (`dept-backend`, `dept-frontend`, `dept-database`).
- Agentes: `developer` y, si el área produce código testeable, `tester`. Dentro de Claude Code se llaman `dept-<área>:developer` y `dept-<área>:tester`.

## 2. Estructura

```
plugins/dept-<área>/
├── .claude-plugin/plugin.json
├── agents/
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

Copiá `developer.md` y `tester.md` de `dept-scraper` y adaptá lo específico del área. Reglas obligatorias:

- **`description` empieza con "Departamento de <área>:"** y dice con claridad qué hace. El PM elige a quién activar leyendo esa descripción.
- **`model: sonnet`.**
- **Sin `permissionMode`, `hooks` ni `mcpServers`:** en plugins Claude Code los ignora.
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
