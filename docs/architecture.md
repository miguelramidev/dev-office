# Arquitectura de la oficina

## Roles

| Rol       | Quién                   | Modelo | Qué hace                                                                                                                    |
| --------- | ----------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| CEO       | Vos                     | —      | Decide qué se hace. Solo habla con el PM.                                                                                   |
| PM        | `office:pm`             | Opus   | Conversa con el CEO, planifica, activa departamentos, coordina el ciclo de calidad y entrega el informe. No escribe código. |
| Developer | `dept-<área>:developer` | Sonnet | Escribe el código de su área siguiendo las reglas del proyecto. No escribe tests.                                           |
| Tester    | `dept-<área>:tester`    | Sonnet | Escribe y corre los tests de su área. No toca código de producción.                                                         |
| QA        | `office:qa`             | Opus   | El enemigo de la app: busca cómo romper el trabajo de cualquier departamento y verifica las reglas. No corrige.             |

Cada departamento trae su propio tester, porque un tester que conoce su área prueba mejor. Los departamentos que no producen código testeable (por ejemplo, diseño) no llevan tester. QA es uno solo para toda la oficina.

### Por qué estos modelos

- **PM en Opus:** razona con el CEO y coordina; un error de planificación se multiplica en todos los departamentos.
- **QA en Opus:** es el último filtro antes de que el código llegue al proyecto.
- **Developers y testers en Sonnet:** siguen instrucciones detalladas con buena calidad y a menor costo.
- **Haiku no se usa para código:** con código de varios archivos y muchas reglas se equivoca más, y cada error cuesta una vuelta completa developer → tester → QA. Queda para tareas mecánicas futuras.

## Modos del PM

1. **Reunión:** el CEO y el PM discuten qué cambiar o mejorar. El PM opina con hechos (lee el proyecto antes), señala riesgos y costos y presenta opciones con su recomendación. No activa a nadie hasta que el CEO decida.
2. **Ejecución:** con la decisión tomada, el PM presenta un plan, el CEO lo aprueba y el PM activa a los departamentos necesarios.

## Ciclo de calidad

```
PM → developer ─→ tester ──falla──→ developer   (máx. 3 vueltas)
                    └─pasa─→ QA ──bloqueante──→ developer → tester   (máx. 3 vueltas)
                              └─aprobado─→ PM → informe al CEO
```

- **QA clasifica sus hallazgos** en bloqueantes (vuelven al developer), importantes (el PM los consulta al CEO) y mejoras (se anotan).
- **Cada bloqueante corregido termina en un test nuevo**, para que no vuelva a aparecer.
- **Si se agotan las vueltas**, el PM frena y le explica al CEO qué falla y qué opciones hay.

## Comunicación

- **Los agentes no hablan entre ellos.** Todo pasa por el PM: cada agente le devuelve un reporte y el PM decide el siguiente paso.
- **Los agentes arrancan sin contexto.** No ven la conversación entre el CEO y el PM, así que cada encargo incluye objetivo, archivos, decisiones tomadas, criterio de terminado y límites.
- **Aprobaciones.** Si un agente necesita algo que requiere aprobación (instalar dependencias, commits, costos, decisiones de diseño importantes), frena y termina su reporte con "Necesito aprobación". El PM se lo consulta al CEO.

## Departamentos

- **Cada departamento es un plugin** llamado `dept-<área>`, con un agente `developer` y, si corresponde, un `tester`.
- **Todos dependen del plugin `office`.**
- **El PM elige a quién activar según la descripción de cada agente.** Por eso cada descripción tiene que decir con claridad de qué área es y qué hace.
- **Un departamento instalado que no se usa casi no consume tokens:** de cada agente solo se carga su nombre y descripción, y sus instrucciones completas se cargan recién cuando el PM lo activa.
- **Orden entre departamentos:** base de datos antes que backend, backend antes que frontend, diseño antes que frontend. En paralelo solo si su trabajo es independiente y no tocan los mismos archivos.

## Qué va en el plugin y qué en el proyecto

| En dev-office                                        | En cada proyecto                                      |
| ---------------------------------------------------- | ----------------------------------------------------- |
| Agentes genéricos                                    | `CLAUDE.md` y las reglas del proyecto                 |
| Hooks de protección y de registro de actividad       | Permisos y modo de permisos (`.claude/settings.json`) |
| Skills genéricas (por ejemplo, scraping responsable) | Skills propias del proyecto                           |

Los agentes leen el `CLAUDE.md` del proyecto (y lo que este importe) antes de trabajar. Así el mismo equipo respeta las reglas de cada proyecto.

## Limitaciones de Claude Code que condicionan el diseño

- **Un plugin no puede definir permisos.** Por eso la skill `office-setup` los crea en el `.claude/settings.json` de cada proyecto.
- **En los agentes de un plugin se ignora `permissionMode`.** El modo (`acceptEdits` o `auto`) se define en el proyecto con `defaultMode`, y los subagentes lo heredan de la sesión principal.
- **Escribir en `.git` o `.claude` siempre pide confirmación** (rutas protegidas), aunque el modo sea automático.
- **Las reglas `ask` siempre preguntan**, sin importar el modo: commit, push, instalar paquetes o comandos de la nube pasan por el CEO.

## Decisiones descartadas

- **"Agent teams" de Claude Code** (agentes que se mandan mensajes entre sí): es experimental y gasta bastante más tokens. El ciclo en orden lo resuelve el PM con subagentes.
- **Un plugin único con todos los departamentos:** no permite elegir qué departamentos tiene cada proyecto.
