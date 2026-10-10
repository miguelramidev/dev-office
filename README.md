# dev-office

Una oficina de desarrollo para [Claude Code](https://code.claude.com): vos sos el CEO, un **PM** conversa con vos y coordina, los **departamentos** hacen el trabajo y un **QA** intenta romper todo antes de que llegue a tu código.

> Estado: **v0.1 en construcción**. La API de los plugins puede cambiar entre versiones.

## Cómo funciona

```
                    CEO (vos)
                        │
                   PM (Opus)
          ┌─────────────┼─────────────┐
     Scraping        Backend       Frontend   ...
  developer+tester  (próximamente) (próximamente)
          └─────────────┼─────────────┘
                        │
                   QA (Opus)
              el enemigo de la app
```

1. **Reunión.** Hablás con el PM sobre qué cambiar, mejorar o priorizar. Opina, te contradice si hace falta y te propone opciones. No activa a nadie hasta que decidas.
2. **Ejecución.** Con tu decisión, el PM arma un plan, lo aprobás y activa solo a los departamentos que hacen falta. El resto no trabaja ni gasta tokens.
3. **Calidad.** Todo trabajo pasa por el tester del departamento y después por QA. Si algo falla, vuelve al departamento, con un máximo de 3 vueltas.
4. **Informe.** El PM te entrega un resumen por departamento: qué se hizo, qué archivos cambiaron, resultados de calidad y decisiones pendientes.

Vos solo hablás con el PM.

## Plugins

| Plugin         | Contiene                                                                  | Modelos       |
| -------------- | ------------------------------------------------------------------------- | ------------- |
| `office`       | PM, QA, hooks de protección y registro de actividad, skill `office-setup` | PM y QA: Opus |
| `dept-scraper` | Developer y tester de scraping, skill de scraping responsable             | Sonnet        |

Cada departamento es un plugin aparte: instalás solo los que tu proyecto necesita. Todos dependen de `office`.

## Requisitos

- Claude Code actualizado.
- `git` y `jq` (los usan los hooks).
- Linux, macOS o Windows con WSL2. En Windows, trabajá dentro de WSL, no desde PowerShell.

## Instalación

Dentro de Claude Code, en la carpeta de tu proyecto:

```text
/plugin marketplace add miguelramidev/dev-office
/plugin install office@dev-office
/plugin install dept-scraper@dev-office
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
- [Agregar un departamento](docs/add-department.md)
- [Cambios por versión](CHANGELOG.md)

## Licencia

[MIT](LICENSE)
