# Arquitectura de la oficina

## Roles

| Rol       | Quién                   | Modelo | Qué hace                                                                                                                    |
| --------- | ----------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| CEO       | Vos                     | —      | Decide qué se hace. Solo habla con el PM.                                                                                   |
| PM        | `office:pm`             | Opus   | Conversa con el CEO, planifica, activa departamentos, coordina el ciclo de calidad y entrega el informe. No escribe código. |
| Arquitecto de backend | `dept-backend:architect` | Opus | Diseña la API, el flujo de datos y los cambios al modelo antes de programar. Escribe en `docs/design/`. No escribe código.  |
| Arquitecto de frontend | `dept-frontend:architect` | Opus | Diseña la parte técnica del front: estructura, rutas, estado, datos y caché, código compartido entre web y móvil, rendimiento y errores. Escribe en `docs/design/`. No escribe código. |
| Arquitecto de DevOps | `dept-devops:architect` | Opus | Diseña entornos, pipelines, despliegues, credenciales, infraestructura y vuelta atrás. Escribe en `docs/design/`. No escribe código ni configuración. |
| Designer  | `dept-frontend:designer` | Sonnet | Diseña flujos, pantallas, estados y textos de la web y la app móvil antes de programar. Escribe en `docs/design/`. No escribe código. |
| Developer | `dept-<área>:developer` | Sonnet | Escribe el código de su área siguiendo las reglas del proyecto y el diseño aprobado. No escribe tests.                     |
| Tester    | `dept-<área>:tester`    | Sonnet | Escribe y corre los tests de su área. No toca código de producción.                                                         |
| Líder de departamento | `dept-<área>:lead` | Sonnet | Solo en el modo equipos: recibe el encargo del PM, lo reparte entre el developer y el tester de su departamento, coordina las vueltas entre ellos y le entrega al PM el reporte del departamento con las acciones requeridas. No escribe código. |
| QA        | `office:qa`             | Opus   | El enemigo de la app: busca cómo romper el trabajo de cualquier departamento y verifica las reglas. No corrige.             |
| Puente    | `office:external`       | Sonnet | Le pasa a Codex o Gemini el encargo de un rol, revisa lo que hicieron, corre las verificaciones y devuelve el reporte del rol. No escribe código. |

En base de datos, el developer cumple el rol de DB manager: esquemas, migraciones, índices y consultas pesadas. El modelo de datos lo diseña el arquitecto de backend y lo implementa este departamento.

En DevOps, el developer se encarga de CI/CD, despliegues, infraestructura como código, contenedores y servidores, y diagnostica los pipelines que fallan. Nunca despliega ni aplica cambios en una cuenta real: deja todo listo y el CEO ejecuta. Su tester valida sin desplegar (sintaxis, disparadores, permisos, secretos, build local).

Cada departamento trae su propio tester, porque un tester que conoce su área prueba mejor. Los departamentos que no producen código testeable (por ejemplo, diseño) no llevan tester. QA es uno solo para toda la oficina.

### Por qué estos modelos

- **PM en Opus:** razona con el CEO y coordina; un error de planificación se multiplica en todos los departamentos.
- **QA en Opus:** es el último filtro antes de que el código llegue al proyecto.
- **Arquitectos en Opus** (backend, frontend y DevOps): un mal diseño se multiplica en todo lo que se construye encima, igual que un mal plan del PM. Trabajan pocas veces, así que el costo extra es chico.
- **Designer en Sonnet:** sus decisiones son más fáciles de corregir (un texto, una pantalla) y el CEO las revisa a ojo antes de construir.
- **Developers y testers en Sonnet:** siguen instrucciones detalladas con buena calidad y a menor costo.
- **Líderes en Sonnet:** coordinan con reglas claras (a quién encargar, cuántas vueltas, qué reportar) y no diseñan ni programan.
- **Razonamiento medio para todos:** cada agente declara `effort: medium`, igual que los roles en Codex y Gemini. Más razonamiento gasta más tokens y tarda más; un rol que lo necesite se puede subir en su agente o, en otro proveedor, con `office-agents.sh tier`. Claude Code lee el campo `effort` de los agentes, pero todavía no lo documenta: si una versión lo ignora, el agente usa el nivel de la sesión.
- **Haiku no se usa para código:** con código de varios archivos y muchas reglas se equivoca más, y cada error cuesta una vuelta completa developer → tester → QA. Queda para tareas mecánicas futuras.

Los modelos de la tabla son los de siempre. Cada proyecto puede cambiar el proveedor o el modelo de cualquier rol (ver "Proveedores por rol").

## Proveedores por rol

Cada rol lo puede hacer Claude, Codex o Gemini. Se configura por proyecto con la skill `office-agents`, que instala el script `.claude/office-agents.sh` (y `.claude/office-agents.cmd` para Windows), en dos archivos:

- `.claude/office-agents.json`: el del equipo, va en git.
- `.claude/office-agents.local.json`: el personal, no va en git y manda rol por rol.

```json
{ "roles": { "backend.developer": ["codex"], "frontend.developer": ["gemini:gemini-3.1-pro-preview"], "qa": ["claude", "codex"], "pm": ["codex"] } }
```

- **Roles:** `<área>.<agente>` (`backend.developer`, `frontend.designer`, `devops.tester`...), `qa`, `pm` y `project.<nombre>` para los agentes propios del proyecto. Un rol sin configurar es Claude con el modelo de siempre. Claude también acepta modelo: `claude:opus`, `claude:sonnet` o `claude:haiku`.
- **Niveles:** cada rol tiene el nivel del modelo de Claude de su agente, y en Codex o Gemini usa el modelo equivalente, con razonamiento medio (más razonamiento gasta más tokens y tarda más):

  | Nivel | Roles | Claude | Codex | Gemini |
  | --- | --- | --- | --- | --- |
  | Opus | PM (asesores), QA, arquitectos | Opus | `gpt-6-astra` | `gemini-4-argon` |
  | Sonnet | Developers, testers, designer | Sonnet | `gpt-6.1-sol` | `gemini-3.8-flash` |

  Es la tabla de dev-office (octubre de 2026). Cada proyecto la puede cambiar con `office-agents.sh tier`, porque los nombres de los modelos cambian seguido y no todas las cuentas tienen todos. Un rol con modelo propio (`codex:<modelo>`) no usa la tabla.
- **Gemini se usa con Antigravity CLI** (`agy`): desde el 18 de junio de 2026, Gemini CLI no atiende cuentas personales (gratis, Google AI Pro ni Ultra), y Antigravity es su reemplazo, con inicio de sesión con la cuenta de Google. Además, Gemini 4 Argon está en Antigravity y no en Gemini CLI.
- **El PM es siempre Claude:** es la sesión de Claude Code, la que conversa con el CEO, activa a los agentes y usa las skills y los hooks. En `pm` se configuran sus **asesores**: antes de presentar un plan que no es trivial o un diseño, el PM les pide una segunda opinión (solo leen) y le muestra al CEO en qué coinciden y en qué no.
- **El puente.** Un rol en Codex o Gemini lo activa el PM a través de `office:external` (Sonnet), que usa la skill `external-agents`:
  1. Arma el prompt con las reglas de la oficina para el proveedor, las instrucciones del agente del rol, las skills que ese agente usa y el encargo completo.
  2. Corre el CLI en la carpeta del proyecto, con tope de tiempo: `codex exec` con sandbox `workspace-write` y sin pedir aprobación, o `agy -p` con `--mode accept-edits`, con el modelo del nivel del rol y el razonamiento de la tabla. Los asesores corren en solo lectura.
  3. Compara el repositorio antes y después: marca si tocó secretos, claves o lockfiles, si escribió fuera de lo que permite su rol (QA solo en `.qa/`, arquitectos y designer solo en `docs/design/`), si commiteó o si cambió de rama. No deshace nada: frena y el CEO decide.
  4. Verifica: en un developer corre typecheck, lint y tests (con una vuelta de corrección como máximo); en un tester confirma que el resultado que informa es el real.
  5. Devuelve el reporte con el formato del rol, así el ciclo de calidad no cambia.
- **Si un proveedor no está disponible** (no instalado, sin sesión, sin cuota), el PM frena y le pregunta al CEO: reintentar, usar Claude en ese encargo o pausar.
- **Carpeta de trabajo:** cada encargo deja su prompt, el reporte del proveedor y el registro del CLI en `.office/runs/` (ignorada por git), para revisar qué pasó.

### QA con varios proveedores

Si `qa` tiene varios proveedores, el PM los coordina en tres pasos:

1. **Revisión independiente:** cada QA revisa sin ver lo de los otros, uno después del otro.
2. **Validación cruzada:** una sola ronda. Cada QA recibe los hallazgos de los demás y los marca como confirmado (lo reprodujo), refutado (con pruebas) o sin verificar.
3. **Consolidación:** lo confirmado queda con su clasificación; lo de uno solo queda si tiene reproducción; lo refutado con pruebas queda en disputa y va al CEO como importante, con los dos argumentos. Un hallazgo en disputa nunca es bloqueante.

### Límites de Codex y Gemini

- **No pasan por los hooks de la oficina** (`protect.sh` y `branch-guard.sh` solo ven las herramientas de Claude Code). La protección es la del sandbox de cada CLI más la revisión del puente después, que detecta pero no impide. Por eso el tester y QA no se saltean nunca.
- **Gemini (Antigravity) no corre comandos** en `accept-edits`: edita archivos y el puente corre las verificaciones. Como tester o QA rinde menos, porque no puede ejecutar sus pruebas.
- **Modelos por cuenta:** Gemini 4 Argon en Antigravity depende del plan de Google, y GPT-6 Astra necesita Codex CLI 0.153.0 o más nuevo. `office-agents.sh check` lo revisa; si la cuenta no tiene un modelo, el puente lo informa como proveedor no disponible y se elige otro con `tier`.
- **Tiempo:** cada encargo se corta a los 540 segundos (`OFFICE_EXTERNAL_TIMEOUT`), porque la herramienta Bash de Claude Code espera como máximo 10 minutos. Los encargos grandes se dividen.
- **Costo:** cada proveedor se paga con su propia cuenta, y el puente gasta un poco de Claude (Sonnet) para pasar el encargo y revisar el resultado.

## Modo equipos: un líder por departamento

Opcional. Por defecto el PM coordina a cada developer y tester con subagentes. En el modo equipos, cada departamento tiene un líder y el ciclo developer ↔ tester queda adentro del departamento:

```
PM ──encargo──→ líder ──→ developer ──→ tester ──falla──→ developer   (máx. 3 vueltas)
 ↑                                        └─pasa─→ líder
 └──── reporte con las acciones requeridas ──────────┘
```

- **Cómo se activa:** `bash .claude/office-agents.sh teams on` (o `--local`, solo para vos). Anota `"teams": true` en la configuración y `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` en el `env` de `.claude/settings.json`. `teams off` lo deshace. Hay que reiniciar Claude Code.
- **Por qué agent teams:** un subagente no puede encargarle trabajo a otro subagente. Con agent teams, el PM crea al líder como compañero de equipo (`dept-<área>:lead`, con nombre `<área>-lead`) y el líder sí puede encargarles al developer y al tester como subagentes. En los eventos de los hooks, Claude Code identifica al líder por su nombre (`<área>-lead`, en `agent_type`), no por `dept-<área>:lead`; el observer y el resumen de tokens reconocen los dos. El equipo es plano: los líderes no crean más líderes.
- **El líder:** lee el `CLAUDE.md` y la configuración de proveedores, encarga a su developer y a su tester (por el puente si el rol va en Codex o Gemini), manda las fallas del tester de vuelta al developer y escribe el reporte en `.office/reports/<fecha>-<área>.md`: qué se hizo, archivos, calidad, qué necesitan otros departamentos, acciones requeridas y pendientes. Después le avisa al PM por mensaje.
- **El PM:** sigue con la fase de diseño, QA, los asesores y el informe al CEO. Cuando un líder avisa, lee su reporte. Las aprobaciones siguen pasando por el CEO. Los bloqueantes de QA vuelven al líder del departamento.
- **Departamentos en paralelo:** si su trabajo es independiente, el PM puede tener varios líderes trabajando a la vez.
- **Costo:** cada líder es una sesión más de Claude (Sonnet) que lee el contexto del departamento: gasta más tokens que el modo normal. Conviene para tickets con varios departamentos o con muchas vueltas developer ↔ tester.
- **Si no está disponible** (Claude Code sin agent teams, o el flag sin activar), el PM trabaja como siempre. Al empezar la sesión lo confirma: si la configuración tiene `"teams": true` pero la sesión arrancó sin `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, el hook `teams-check.sh` se lo avisa (con qué falta: correr `teams on` o reiniciar Claude Code), y el PM se lo dice al CEO en su primera respuesta. Si la configuración no lo pide o todo está bien, el hook no imprime nada.
- **Los líderes son siempre Claude**, como el PM: no se configuran con `set`.

## Observer

La oficina en pixel art, en vivo, para ver qué pasa sin leer registros.

- **Datos.** El hook `observer.sh` escucha SessionStart, UserPromptSubmit, PreToolUse, PostToolUse (solo `gh pr create` y `gh pr view`, para anotar el link del PR), SubagentStart, SubagentStop, Notification y Stop (y en el modo equipos TeammateIdle, TaskCreated y TaskCompleted), y anota cada evento como una línea `OFFICE_EVENT({...});` en `.office/observer/events.js`:
  - qué le encarga el PM a cada departamento, o cada líder a su gente (con el rol y el proveedor, si el encargo va por el puente);
  - los mensajes entre el PM y los líderes (un resumen de una línea y el texto completo);
  - el texto completo de cada encargo, de la respuesta de cada agente y de la respuesta del PM al CEO, hasta 4000 caracteres cada uno (lo que sobra se corta y se marca con `[…]`);
  - qué herramienta usa cada agente (el nombre del archivo, no su contenido);
  - el veredicto de cada agente al terminar (PASA, FALLA, APROBADO, RECHAZADO, pide aprobación, PROVEEDOR NO DISPONIBLE...), sacado de su último mensaje;
  - los tokens exactos, leídos de las transcripciones que Claude Code guarda en el disco: entrada, salida y caché, contando una sola vez cada mensaje.

  El puente agrega el inicio y el fin de cada encargo a Codex o Gemini, con los tokens que informe el CLI. Al empezar la sesión se anotan la rama, el ticket, los proveedores por rol y los departamentos instalados.
- **Sin costo.** El hook no imprime nada (en algunos eventos, lo que imprime un hook le llega al modelo) y no llama a ningún modelo: no gasta tokens. Nunca bloquea. Lo único que suma es el tiempo de correr un script por evento.
- **En una pantalla.** La oficina ocupa toda la ventana y se ajusta a su tamaño sin deformarse, sin scroll. Arriba a la izquierda están el título, el modo y el ticket; arriba a la derecha, los botones Equipo, Actividad (con las novedades sin leer), Tokens, Tienda (con el nivel y el saldo), Cierre del día y Ajustes (avisos, sonido, en vivo o demo y los controles de la demo). Cada botón abre un panel lateral con pestañas; en una pantalla ancha la oficina se achica a su lado, así sigue a la vista. Tocar un empleado abre su ficha, salvo que esté abierta la tienda: ahí la compra pasa a ser para él y para su oficina. Esc cierra el panel.
- **La página.** Se escribe en `office/observer/src/`: `page.html`, `style.css` y el script en partes (`js/01-mundo.js` … `js/08-panel.js`), que `build.sh` junta en un solo `index.html`, porque con `file://` el navegador no deja cargar módulos de otros archivos. Con cada evento nuevo procesa solo lo que llegó, no el registro entero. `office/observer/index.html` se copia a `.office/observer/` al empezar cada sesión y se abre desde el disco, sin servidor: como el registro es JavaScript, la página lo vuelve a cargar cada 1,5 segundos. Muestra las ocho oficinas, con los empleados según los proveedores configurados y los departamentos sin instalar apagados. Si no hay actividad, muestra una demo.
- **La oficina crece con los tokens.** Cada sesión de Claude Code es una partida nueva: la oficina empieza básica, con piso de cemento, mesas plegables y sillas de plástico, y se amuebla con lo que el CEO compra en la tienda (botón "Tienda" de arriba a la derecha). La moneda son los tokens que gastó la sesión, y lo comprado se descuenta del saldo. El nivel, del 1 al 10, sube con el total gastado y nunca baja: 100k, 300k, 600k, 1M, 1,6M, 2,5M, 4M, 6M y 9M tokens.
  - **Catálogo.** El catálogo general combina unos 180 tipos de artículo con sus variantes (colores, maderas, marcos, macetas, paletas): son más de 3.000 artículos. Están los escritorios, las sillas, el piso y la pintura de cada oficina; cuadros, plantas, muebles y adornos, en los lugares libres de la pared y del piso; lo del pasillo (ver abajo); el equipamiento de cada departamento (sus servidores, pizarras y tableros); y ropa, gorros, anteojos y collares para cada empleado.
  - **Pasillo.** Tiene su categoría en la tienda y siempre va al pasillo: contra los bordes, sin cortar el paso, entran una máquina expendedora, un dispensador de agua, bancos, sillones, casilleros, una tele con el avance del sprint y una cabina telefónica, entre otros (10 lugares); la alfombra del medio se cambia por otra a rayas, a cuadros, una línea de señalización, una alfombra roja o un camino de luces; y del techo cuelgan guirnaldas, banderines, lámparas, plantas, un tubo de neón o bolas de espejos. Además entran plantas y adornos chicos (12 lugares) y cualquier piso del catálogo. Quien está libre a veces va a la máquina expendedora, a la de chicles o al dispensador que estén contra el borde de arriba.
  - **Vitrina.** Cada partida elige al azar unos 90 artículos, entre 9 y 14 por nivel, siempre los mismos para esa partida. Con cada nivel se desbloquean los suyos, y la tienda muestra un adelanto de los dos niveles que siguen.
  - **Compras.** Van a la oficina y al empleado elegidos en la tienda. En "Automático", que es lo que viene elegido, se reparten: cada artículo va a la oficina con lugar que menos cosas tiene, y la ropa, a quien todavía no tiene esa prenda y lleva menos puesto. Lo de la categoría Pasillo va siempre al pasillo, y el equipamiento, a su departamento. Se guardan en el almacenamiento de la pestaña, por partida, para no perderlas al recargar; una sesión nueva empieza de cero.
  - **Demo.** En la demo, el CEO compra solo cada tanto, hasta que alguien compra a mano.
- **Tablero del ticket.** El pizarrón del pasillo muestra el ticket, la rama y tres luces: el último resultado del tester, el último veredicto de QA y el PR (abierto, mergeado o cerrado). Al tocarlo se abre en grande, con el link del PR.
- **Avisos.** Cuando el PM le responde al CEO, Claude Code pide un permiso o un agente parece trabado, la pestaña avisa si está en segundo plano: el ícono de la pestaña (un monitor en pixel art) muestra un punto rojo, el título parpadea y, con el botón "Avisos" activado, sale una notificación del sistema (si el navegador la permite).
- **Agentes trabados.** Si un agente que trabaja pasa 8 minutos sin usar ninguna herramienta, aparece con un globo de "¿trabado?" y un aviso en la actividad con lo último que hizo. Puede ser un comando largo, como una corrida de tests.
- **Contra la sesión anterior.** La página lee también `events.prev.js` y compara tokens, fallas del tester y tareas con la sesión anterior.
- **Sesiones retomadas o compactadas.** La sesión empieza en su último inicio (o `/clear`): cuando Claude Code la retoma o compacta la conversación, la oficina sigue con lo que tenía.
- **La vida en la oficina.**
  - **Empleado del mes:** un cuadro en Reuniones con el retrato del que más pizzas ganó en la sesión.
  - **Logros:** trece, como "Todo en verde a la primera", "A la tercera va la vencida", "QA rechazó y se corrigió", "PR mergeado" o "Pizza party". Cada uno suma tokens al saldo de la tienda, no al nivel, y se ven como insignias en la tienda.
  - **Eventos:** un cumpleaños por sesión en un momento al azar, con torta y compañeros que van a saludar; un corte de luz cuando el tester falla tres veces seguidas; y las mascotas compradas (gato, perro, robot) salen a pasear por el pasillo.
  - **Sonidos:** opcionales y apagados por defecto, sintetizados en el navegador: teclado, cafetera, timbre del repartidor, nivel, logro, cumpleaños y apagón.
  - **Cierre del día:** el botón abre un resumen de la sesión (duración, tokens, nivel, compras, fallas, PR, empleado del mes, pizzas y logros) con la foto de la oficina, que se puede descargar como imagen.
- **Leer en grande.** En la ficha de cada empleado están su encargo y su última respuesta, y debajo, los textos anteriores. Al tocarlos, o al tocar un ítem de la actividad, el texto se abre en grande en la página, con formato: títulos, listas, tablas y código. Nada de lo que escribe un agente se interpreta como HTML.
- **Animaciones.** El PM va a buscar el reporte a cada departamento que termina. En el modo equipos, el líder se levanta a pasarle el encargo a su developer o tester, quien termina le lleva el resultado al líder y el tester le lleva la falla al developer. Con dos QA o más, en la validación cruzada se juntan en la pizarra a debatir. El PM espera en el pasillo, al lado de la puerta de Reuniones, y entra cuando el CEO le escribe. Quien está libre a veces va por un café, se estira o charla con alguien libre, de su departamento o de otro. Cuando el PM le entrega un informe al CEO, el empleado que más tokens gastó en ese encargo (nunca el PM ni el CEO) recibe una pizza de compensación: entra un repartidor por el pasillo, se la lleva al escritorio y la pizza queda ahí un rato, como esos jefes que pagan el trabajo extra con pizza. Las animaciones salen solo de los eventos nuevos: al abrir la página no se repite la historia.
- **Consumo de tokens.** La skill `usage` arma, con el mismo registro, una tabla de tokens por tarea de cada agente, el total por agente (separando lo que gasta el puente de lo que gasta Codex o Gemini) y por proveedor, con el PM aparte. El PM la pega al final de su informe. Tampoco llama a ningún modelo.
- **Privacidad.** No se guarda lo que escribe el CEO ni el contenido de los archivos. Sí se guardan los encargos y las respuestas completas, que pueden citar lo que pidió el CEO o fragmentos de código. Todo queda en `.office/`, que no va en git. Las compras de la tienda quedan solo en la pestaña del navegador.
- **Apagarlo:** `OFFICE_OBSERVER=off` en el `env` del proyecto.

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
- **Tickets de Jira.** La skill `start-ticket` trae el ticket con el servidor MCP de Atlassian (que el proyecto configura en `.mcp.json` con el nombre `atlassian`) y decide todo a partir de él. Con la rama lista, pasa el ticket a "en curso" sin preguntar. El PM la usa cuando el CEO nombra un ticket.

  | Lo que dice el ticket | Decide |
  | --- | --- |
  | Tipo (Epic, Feature, Tarea, Error o Flaw, Refactor) | El prefijo: `epic/`, `feature/`, `task/`, `fix/`, `refactor/` |
  | Tipo Hotfix, o la etiqueta `hotfix` | Prefijo `hotfix/`: sale de producción y el PR va a producción y a la rama base |
  | Épica padre | Sale de la rama de la épica y el PR va a ella |
  | Sin épica | Sale de la rama base y el PR va a ella |
  | Subtarea | Se trabaja en la rama de su padre |

  Las épicas son ramas de integración: reciben los PRs de sus tickets y, cuando están completas, se integran a la rama base. Conviene actualizarlas con la rama base seguido, para que no se alejen.
- **Jira es de solo lectura para la oficina.** Cambiar el estado de un ticket, asignarlo o comentar lo decide el CEO. La excepción es lo que el flujo del proyecto autoriza por escrito, como pasar el ticket a revisión al abrir el PR.
- **Los tickets nuevos los pide el CEO.** Antes de crear uno, el agente le pregunta a quién se asigna (o si queda sin asignar); nunca lo asume.
- **Avisos a otros equipos (`handoff-ticket`).** Cuando un cambio obliga a otro equipo a adaptarse (por ejemplo, el backend cambió la API y el front web o la app móvil no se tocaron en esa rama), `open-pr` usa la skill `handoff-ticket` después de abrir el PR. Por cada equipo afectado busca su ticket: primero los vinculados al ticket de origen, después los de la misma épica con el componente, etiqueta o prefijo de ese equipo (definidos en el flujo del proyecto), y por último por texto.
  - El CEO elige el ticket, o crear uno nuevo en la misma épica, o no avisar.
  - Al ticket se le agrega a la descripción una sección "Cambios de API desde PROJ-123" (qué cambió, endpoints, qué tiene que hacer ese equipo, compatibilidad y las colecciones de Postman), un comentario corto para que se entere quien lo sigue, y un vínculo con el ticket de origen.
  - Antes de escribir, le muestra el texto al CEO y espera su confirmación. Si el ticket no tiene responsable, pregunta a quién se asigna.
  - No cambia el estado de esos tickets.
- **La rama base, la de producción, los prefijos y el proyecto de Jira** van en el flujo de trabajo del proyecto (`CLAUDE.md` o `.claude/rules/`). Si el proyecto no los define, `start-ticket` usa los valores por defecto de la tabla.

## Colección de API

- **Dos tipos, en el repo.** Las colecciones de Postman (formato v2.1) viven en `docs/api/` o la carpeta que defina el `CLAUDE.md` del proyecto, con un archivo por entorno en `environments/` (compartidos) y un README. Cada rama tiene las colecciones de su propio código, y llegan a las demás con los merges.
  - **La del proyecto**, una sola: toda la API ordenada por recurso, como referencia para el frontend.
  - **Una por épica**, en `epics/`: los flujos de la épica, con los pasos en orden, encadenados y con un test cada uno, para correrlos con el Collection Runner. Cuando la épica se integra, se mantiene como prueba de regresión. Nunca hay una por ticket.
- **Quién.** Las mantiene el developer de backend en el mismo encargo en que cambia un endpoint (skill `dept-backend:api-collection`): la del proyecto, la de la épica del ticket y cualquier otra que use ese endpoint. Las revisa su tester (script `check-collection.sh`, comparación con el código y lectura de los flujos) y las ataca QA. El PM le pasa la épica al backend en el encargo, le da al frontend las rutas de las colecciones y las incluye en el informe.
- **Primera vez.** Si el proyecto no tiene colección, la del proyecto se genera completa a partir del código (rutas, controladores, esquema de GraphQL, validaciones). La de una épica se crea con el primer ticket de esa épica que toca endpoints.
- **Sin secretos.** Los entornos llevan las variables con los secretos vacíos; cada persona los carga en su Postman. El script falla si encuentra un valor escrito.
- **Diffs chicos.** Formato fijo (claves ordenadas, sangría de 2, LF), requests insertados en su lugar y cambios solo en lo afectado, para reducir los conflictos entre ramas.
- **Fuera del formato.** WebSocket, gRPC, SSE y subscriptions de GraphQL se documentan en el README de la carpeta.
- **No se sube a la nube de Postman.** El equipo la importa desde el repo.

## Pull requests y revisiones

- **`open-pr`** abre el PR de la rama actual con `gh`: corre las verificaciones del proyecto, elige el destino con la misma tabla de `start-ticket` (la épica, la base o producción si es hotfix), arma el título y la descripción con la clave del ticket y se los muestra al CEO. Solo con su confirmación sube la rama y abre el PR. En un hotfix ofrece el segundo PR hacia la base. Después mueve el ticket al estado de revisión sin preguntar (el que defina el flujo del proyecto, por ejemplo REVIEWING, o uno de revisión que encuentre por su nombre), para que el CEO sepa qué tiene que revisar.
- **`review-fixes`** junta lo que dejó la revisión: los hilos de comentarios sin resolver (con la API GraphQL de GitHub, que dice cuáles están resueltos o desactualizados), las reseñas, los checks que fallan y los commits que el CEO hizo a mano en la rama (los que no tienen la línea `Co-Authored-By: Claude`). Arma una lista, el CEO la confirma y el PM encarga cada punto al departamento que corresponde, con el ciclo de calidad de siempre. Las correcciones a mano del CEO son criterio: no se deshacen y se proponen para el resto del PR.
- **Límites.** Commit, push, abrir PRs y comentar en GitHub piden confirmación (reglas `ask` de `office-setup`). Mergear un PR está prohibido para los agentes (regla `deny`): lo hace siempre el CEO. Los hilos de revisión los resuelve quien revisó.

## Comunicación

- **Los agentes no hablan entre ellos.** Todo pasa por el PM: cada agente le devuelve un reporte y el PM decide el siguiente paso. En el modo equipos, el developer y el tester le reportan a su líder, y el líder al PM.
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
| Reglas y revisión de las colecciones de API          | Las colecciones de Postman y sus entornos (`docs/api/`) |
| Hook y página del observer                            | Su registro de eventos (`.office/observer/`, fuera de git) |
| Valores por defecto y ejemplos genéricos (`PROJ-123`) | Moneda, idioma, zona horaria, clave de Jira, ramas protegidas y convenciones |

Los agentes leen el `CLAUDE.md` del proyecto (y lo que este importe) antes de trabajar. Así el mismo equipo respeta las reglas de cada proyecto.

**dev-office no se ata a ningún proyecto.** Nada de lo que está en los plugins nombra un proyecto, una empresa, un país, una moneda ni un stack concreto como obligatorio: lo propio de cada proyecto va en su `CLAUDE.md` y en `.claude/`. Los ejemplos usan valores genéricos (`PROJ-123`, `USD`, `main`/`dev`).

## Limitaciones de Claude Code que condicionan el diseño

- **Un plugin no puede definir permisos.** Por eso la skill `office-setup` los crea en el `.claude/settings.json` de cada proyecto.
- **En los agentes de un plugin se ignora `permissionMode`.** El modo (`acceptEdits` o `auto`) se define en el proyecto con `defaultMode`, y los subagentes lo heredan de la sesión principal.
- **Escribir en `.git` o `.claude` siempre pide confirmación** (rutas protegidas), aunque el modo sea automático.
- **Las reglas `ask` siempre preguntan**, sin importar el modo: commit, push, instalar paquetes o comandos de la nube pasan por el CEO.

## Decisiones descartadas

- **"Agent teams" como modo por defecto:** es experimental y gasta bastante más tokens. Por defecto el ciclo en orden lo resuelve el PM con subagentes; los líderes de departamento son un modo opcional (ver "Modo equipos").
- **Un plugin único con todos los departamentos:** no permite elegir qué departamentos tiene cada proyecto.
- **El PM en Codex o Gemini:** el PM es la sesión de Claude Code. Un PM en otro proveedor sería Claude reenviando cada mensaje, con el costo de los dos y sin memoria entre mensajes. En su lugar, el PM puede tener asesores.
