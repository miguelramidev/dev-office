---
name: observer
description: Abre el observer de la oficina dev-office - una página local en pixel art donde se ve la oficina en vivo - el PM caminando entre departamentos, qué agente trabaja y con qué proveedor (Claude, Codex o Gemini), qué herramienta está usando, los tokens por agente y por proveedor, los resultados de tester y QA y la actividad de la sesión. Usar cuando el CEO quiere ver la oficina, el observer o el dashboard.
---

Vas a abrir el observer de la oficina. Hablale al CEO en su idioma (si escribe en español, con voseo).

El observer es una página que se abre desde el disco, sin servidor ni instalaciones. Los hooks de la oficina anotan lo que pasa en `.office/observer/events.js` y la página lo lee cada segundo y medio. No llama a ningún modelo: no gasta tokens.

## Pasos

1. Corré el script que está en la misma carpeta que este archivo:

   ```bash
   bash <carpeta de esta skill>/open-observer.sh
   ```

   Copia la página al proyecto (`.office/observer/index.html`) si no está o es de una versión anterior, y la abre en el navegador predeterminado.

2. Decile al CEO en pocas líneas:
   - Dónde quedó la página (la ruta que imprime el script), por si quiere abrirla él o dejarla fija en una pestaña.
   - Que se actualiza sola mientras trabaja la oficina. Si todavía no hubo actividad en esta sesión, muestra una demo.
   - Que puede tocar a cualquier empleado para ver su ficha: proveedor, modelo, tarea, qué está haciendo y tokens.
   - Que los tokens de Claude son exactos (salen de las transcripciones) y los de Codex y Gemini son los que informa cada CLI, si los informa.

Si el script no puede abrir el navegador (por ejemplo, en un servidor sin escritorio), pasale la ruta para que la abra él.

Para apagar el observer en un proyecto: `"OFFICE_OBSERVER": "off"` en el `env` de `.claude/settings.json`.
