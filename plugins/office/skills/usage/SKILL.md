---
name: usage
description: Resumen de tokens y de tiempo de la sesión de la oficina dev-office - cuántos tokens gastó cada agente en cada tarea, el total por agente y por proveedor (Claude, Codex, Gemini), separando lo que gasta el puente. Lo usa el PM al final de su informe al CEO, y el CEO cuando quiere ver en qué se van los tokens para decidir qué roles mover a otro proveedor o qué activar o desactivar.
---

Vas a armar el resumen de tokens de la sesión. Hablale al CEO en su idioma (si escribe en español, con voseo).

Corré el script que está en la misma carpeta que este archivo:

```bash
bash <carpeta de esta skill>/token-report.sh
```

Con `--prev` muestra la sesión anterior.

Imprime una sección "Consumo de tokens y tiempo" en Markdown, con estas partes:

- **Por tarea:** qué hizo cada agente, con qué proveedor, su resultado, sus tokens y cuánto tardó. En los roles que van por Codex o Gemini, separa lo que gastó el proveedor y lo que gastó Claude en el puente, y entre paréntesis lo que tardó el proveedor.
- **Por agente:** cantidad de tareas, tokens de Claude, de Codex o Gemini, el total, el promedio por tarea y el tiempo total.
- **El total de la sesión** por proveedor, con lo que gastó el PM aparte, y el tiempo: de la sesión, del trabajo de los agentes y de cada proveedor.

Los datos salen del registro del observer (`.office/observer/events.js`): los de Claude son exactos, porque se leen de las transcripciones, y los de Codex y Gemini son los que informa cada CLI. El script no llama a ningún modelo. Si el observer está apagado, avisa que no hay datos.

## Cómo usarlo

- **En el informe del PM:** pegá la salida tal cual al final del informe, como última sección. No la resumas ni cambies los números.
- **Si el CEO lo pide:** mostrale la salida y, si te pregunta qué conviene cambiar, señalá los agentes que más gastan. Por ejemplo: un developer en Claude que gasta mucho se puede mover a Codex con `office-agents`; el modo equipos y los QA extra suman tokens de Claude.
