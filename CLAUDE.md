# dev-office

Marketplace de plugins de Claude Code que arma una oficina de desarrollo: un PM que coordina, departamentos (backend, frontend, base de datos, scraping) y un QA. Ver `README.md` y `docs/architecture.md`.

## Regla principal: independiente de cualquier proyecto

dev-office se usa en proyectos distintos, así que nada de los plugins se ata a uno:

- No se nombran proyectos, empresas, países, monedas, zonas horarias ni claves de Jira reales. Los ejemplos usan valores genéricos: `PROJ-123`, `PROJ-100` para una épica, `USD`, `America/Bogota`, `main` y `dev`.
- Las reglas propias de un proyecto (moneda, idioma, formato de números, ramas protegidas, tipos de ticket, comandos) van en el `CLAUDE.md` y en `.claude/` de ese proyecto, no acá. Los agentes y las skills las leen de ahí.
- Un stack concreto (Next.js, Postgres, Drizzle...) puede aparecer como ejemplo o en una lista de opciones, nunca como requisito.

Antes de abrir un PR, buscá referencias a proyectos reales en los archivos cambiados.

## Convenciones

- Instrucciones y documentación en español, con voseo. Commits en inglés con Conventional Commits.
- La página del observer se edita en `plugins/office/observer/src/` (la página, los estilos y el script en partes) y se arma con `bash plugins/office/observer/build.sh`, que deja todo en un solo `index.html`. `tests/observer.test.sh` falla si `index.html` no está al día. three.js y los muebles KayKit de la vista 3D están en `src/vendor/` y se regeneran con `npm install && npm run vendor` en `plugins/office/observer/tools/`.
- Los `.cmd` van con finales de línea CRLF (ver `.gitattributes`); el resto, LF.
- Cada cambio en un plugin sube su versión en `plugin.json` (versionado semántico) y se anota en `CHANGELOG.md`.
- Verificación antes del PR: `claude plugin validate .`, `claude plugin validate plugins/<plugin>`, `bash tests/protect.test.sh`, `bash tests/branch-guard.test.sh`, `bash tests/api-collection.test.sh`, `bash tests/office-agents.test.sh`, `bash tests/run-external.test.sh`, `bash tests/observer.test.sh`, `bash tests/telegram.test.sh` y `bash tests/update-office.test.sh`.
