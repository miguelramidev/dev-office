# Arquitectura de la oficina

## Roles

| Rol       | Quién                   | Modelo | Qué hace                                                                                                                    |
| --------- | ----------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| CEO       | Vos                     | —      | Decide qué se hace. Solo habla con el PM.                                                                                   |
| PM        | `office:pm`             | Opus   | Conversa con el CEO, planifica, activa departamentos, coordina el ciclo de calidad y entrega el informe. No escribe código. |
| Arquitecto | `dept-backend:architect` | Opus | Diseña la API, el flujo de datos y los cambios al modelo antes de programar. Escribe en `docs/design/`. No escribe código.  |
| Designer  | `dept-frontend:designer` | Sonnet | Diseña flujos, pantallas, estados y textos de la web y la app móvil antes de programar. Escribe en `docs/design/`. No escribe código. |
| Developer | `dept-<área>:developer` | Sonnet | Escribe el código de su área siguiendo las reglas del proyecto y el diseño aprobado. No escribe tests.                     |
| Tester    | `dept-<área>:tester`    | Sonnet | Escribe y corre los tests de su área. No toca código de producción.                                                         |
| QA        | `office:qa`             | Opus   | El enemigo de la app: busca cómo romper el trabajo de cualquier departamento y verifica las reglas. No corrige.             |

En base de datos, el developer cumple el rol de DB manager: esquemas, migraciones, índices y consultas pesadas. El modelo de datos lo diseña el arquitecto de backend y lo implementa este departamento.

En DevOps, el developer se encarga de CI/CD, despliegues, infraestructura como código, contenedores y servidores, y diagnostica los pipelines que fallan. Nunca despliega ni aplica cambios en una cuenta real: deja todo listo y el CEO ejecuta. Su tester valida sin desplegar (sintaxis, disparadores, permisos, secretos, build local).

Cada departamento trae su propio tester, porque un tester que conoce su área prueba mejor. Los departamentos que no producen código testeable (por ejemplo, diseño) no llevan tester. QA es uno solo para toda la oficina.

### Por qué estos modelos

- **PM en Opus:** razona con el CEO y coordina; un error de planificación se multiplica en todos los departamentos.
- **QA en Opus:** es el último filtro antes de que el código llegue al proyecto.
- **Arquitecto en Opus:** un mal diseño se multiplica en todo lo que se construye encima, igual que un mal plan del PM.
- **Designer en Sonnet:** sus decisiones son más fáciles de corregir (un texto, una pantalla) y el CEO las revisa a ojo antes de construir.
- **Developers y testers en Sonnet:** siguen instrucciones detalladas con buena calidad y a menor costo.
- **Haiku no se usa para código:** con código de varios archivos y muchas reglas se equivoca más, y cada error cuesta una vuelta completa developer → tester → QA. Queda para tareas mecánicas futuras.

## Modos del PM

1. **Reunión:** el CEO y el PM discuten qué cambiar o mejorar. El PM opina con hechos (lee el proyecto antes), señala riesgos y costos y presenta opciones con su recomendación. No activa a nadie hasta que el CEO decida.
2. **Ejecución:** con la decisión tomada, el PM presenta un plan, el CEO lo aprueba y el PM activa a los departamentos necesarios.

## Fase de diseño

Antes de programar una función nueva o un cambio grande, los roles de diseño de cada departamento escriben una propuesta:

- **Quién:** el arquitecto de backend (API, flujo de datos, modelo, costos) y el designer de frontend (pantallas, estados y textos). Si trabajan los dos, primero el arquitecto, porque el designer necesita la API.
- **Dónde:** `docs/design/<fecha>-<tema>.md` del proyecto, con estado `propuesta`. Si trabajan los dos, es un solo documento: el designer agrega sus secciones al del arquitecto. Queda en el repo como referencia para todo el equipo.
- **Aprobación:** el PM le presenta el diseño al CEO. Si pide cambios, vuelve al mismo rol. Cuando lo aprueba, el developer marca el estado como `aprobado` y lo implementa tal cual.
- **Cuándo no:** bugs, ajustes chicos y cambios que no tocan contratos, datos ni pantallas van directo al developer.

Los diseños no pasan por tester ni QA: los revisa el CEO.

## Ciclo de calidad

```
PM → developer ─→ tester ──falla──→ developer   (máx. 3 vueltas)
                    └─pasa─→ QA ──bloqueante──→ developer → tester   (máx. 3 vueltas)
                              └─aprobado─→ PM → informe al CEO
```

- **QA clasifica sus hallazgos** en bloqueantes (vuelven al developer), importantes (el PM los consulta al CEO) y mejoras (se anotan).
- **Cada bloqueante corregido termina en un test nuevo**, para que no vuelva a aparecer.
- **Si se agotan las vueltas**, el PM frena y le explica al CEO qué falla y qué opciones hay.

## Ramas y tickets

- **Ramas protegidas.** Cada proyecto define en `OFFICE_PROTECTED_BRANCHES` (en `.claude/settings.json`) las ramas donde nunca se trabaja directamente, con nombres o patrones, por ejemplo `main dev epic/*`. Si no la define, se protegen `main` y `master`. El hook `branch-guard.sh` bloquea editar archivos del proyecto, commitear o mergear sobre esas ramas, y hacer push hacia ellas desde cualquier rama.
- **Tickets de Jira.** La skill `start-ticket` trae el ticket con el servidor MCP de Atlassian (que el proyecto configura en `.mcp.json` con el nombre `atlassian`) y decide todo a partir de él. El PM la usa cuando el CEO nombra un ticket.

  | Lo que dice el ticket | Decide |
  | --- | --- |
  | Tipo (Epic, Feature, Tarea, Error o Flaw, Refactor) | El prefijo: `epic/`, `feature/`, `task/`, `fix/`, `refactor/` |
  | Tipo Hotfix, o la etiqueta `hotfix` | Prefijo `hotfix/`: sale de producción y el PR va a producción y a la rama base |
  | Épica padre | Sale de la rama de la épica y el PR va a ella |
  | Sin épica | Sale de la rama base y el PR va a ella |
  | Subtarea | Se trabaja en la rama de su padre |

  Las épicas son ramas de integración: reciben los PRs de sus tickets y, cuando están completas, se integran a la rama base. Conviene actualizarlas con la rama base seguido, para que no se alejen.
- **Jira es de solo lectura para la oficina.** Cambiar el estado de un ticket, asignarlo o comentar lo decide el CEO. La excepción es lo que el flujo del proyecto autoriza por escrito, como pasar el ticket a revisión al abrir el PR.
- **La rama base, la de producción, los prefijos y el proyecto de Jira** van en el flujo de trabajo del proyecto (`CLAUDE.md` o `.claude/rules/`). Si el proyecto no los define, `start-ticket` usa los valores por defecto de la tabla.

## Pull requests y revisiones

- **`open-pr`** abre el PR de la rama actual con `gh`: corre las verificaciones del proyecto, elige el destino con la misma tabla de `start-ticket` (la épica, la base o producción si es hotfix), arma el título y la descripción con la clave del ticket y se los muestra al CEO. Solo con su confirmación sube la rama y abre el PR. En un hotfix ofrece el segundo PR hacia la base. Si el flujo del proyecto lo define, después mueve el ticket al estado de revisión (por ejemplo, REVIEWING) sin preguntar, para que el CEO sepa qué tiene que revisar.
- **`review-fixes`** junta lo que dejó la revisión: los hilos de comentarios sin resolver (con la API GraphQL de GitHub, que dice cuáles están resueltos o desactualizados), las reseñas, los checks que fallan y los commits que el CEO hizo a mano en la rama (los que no tienen la línea `Co-Authored-By: Claude`). Arma una lista, el CEO la confirma y el PM encarga cada punto al departamento que corresponde, con el ciclo de calidad de siempre. Las correcciones a mano del CEO son criterio: no se deshacen y se proponen para el resto del PR.
- **Límites.** Commit, push, abrir PRs y comentar en GitHub piden confirmación (reglas `ask` de `office-setup`). Mergear un PR está prohibido para los agentes (regla `deny`): lo hace siempre el CEO. Los hilos de revisión los resuelve quien revisó.

## Comunicación

- **Los agentes no hablan entre ellos.** Todo pasa por el PM: cada agente le devuelve un reporte y el PM decide el siguiente paso.
- **Los agentes arrancan sin contexto.** No ven la conversación entre el CEO y el PM, así que cada encargo incluye objetivo, archivos, decisiones tomadas, criterio de terminado y límites.
- **Aprobaciones.** Si un agente necesita algo que requiere aprobación (instalar dependencias, commits, costos, decisiones de diseño importantes), frena y termina su reporte con "Necesito aprobación". El PM se lo consulta al CEO.

## Departamentos

- **Cada departamento es un plugin** llamado `dept-<área>`, con un agente `developer` y, si corresponde, un `tester` y un rol de diseño (`architect` en backend, `designer` en frontend).
- **Todos dependen del plugin `office`.**
- **El PM elige a quién activar según la descripción de cada agente.** Por eso cada descripción tiene que decir con claridad de qué área es y qué hace.
- **Un departamento instalado que no se usa casi no consume tokens:** de cada agente solo se carga su nombre y descripción, y sus instrucciones completas se cargan recién cuando el PM lo activa.
- **Orden entre departamentos:** diseño → base de datos → backend → frontend. En paralelo solo si su trabajo es independiente y no tocan los mismos archivos.

## Qué va en el plugin y qué en el proyecto

| En dev-office                                        | En cada proyecto                                      |
| ---------------------------------------------------- | ----------------------------------------------------- |
| Agentes genéricos                                    | `CLAUDE.md` y las reglas del proyecto                 |
| Hooks de protección y de registro de actividad       | Permisos y modo de permisos (`.claude/settings.json`) |
| Skills genéricas (por ejemplo, scraping responsable) | Skills propias del proyecto                           |
| Plantilla de los documentos de diseño                | Los diseños aprobados (`docs/design/`)                |
| Valores por defecto y ejemplos genéricos (`PROJ-123`) | Moneda, idioma, zona horaria, clave de Jira, ramas protegidas y convenciones |

Los agentes leen el `CLAUDE.md` del proyecto (y lo que este importe) antes de trabajar. Así el mismo equipo respeta las reglas de cada proyecto.

**dev-office no se ata a ningún proyecto.** Nada de lo que está en los plugins nombra un proyecto, una empresa, un país, una moneda ni un stack concreto como obligatorio: lo propio de cada proyecto va en su `CLAUDE.md` y en `.claude/`. Los ejemplos usan valores genéricos (`PROJ-123`, `USD`, `main`/`dev`).

## Limitaciones de Claude Code que condicionan el diseño

- **Un plugin no puede definir permisos.** Por eso la skill `office-setup` los crea en el `.claude/settings.json` de cada proyecto.
- **En los agentes de un plugin se ignora `permissionMode`.** El modo (`acceptEdits` o `auto`) se define en el proyecto con `defaultMode`, y los subagentes lo heredan de la sesión principal.
- **Escribir en `.git` o `.claude` siempre pide confirmación** (rutas protegidas), aunque el modo sea automático.
- **Las reglas `ask` siempre preguntan**, sin importar el modo: commit, push, instalar paquetes o comandos de la nube pasan por el CEO.

## Decisiones descartadas

- **"Agent teams" de Claude Code** (agentes que se mandan mensajes entre sí): es experimental y gasta bastante más tokens. El ciclo en orden lo resuelve el PM con subagentes.
- **Un plugin único con todos los departamentos:** no permite elegir qué departamentos tiene cada proyecto.
