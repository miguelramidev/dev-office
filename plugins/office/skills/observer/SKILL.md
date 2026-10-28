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

   Copia la página al proyecto (`.office/observer/index.html`) si no está o es de una versión anterior, y la abre en el navegador predeterminado. En WSL la abre con el navegador de Windows e imprime también el link para Windows (`En Windows: file://wsl.localhost/...`).

2. Decile al CEO en pocas líneas:
   - Dónde quedó la página, por si quiere abrirla él o dejarla fija en una pestaña. En WSL pasale el link de la línea `En Windows:`, no la ruta `/home/...`: el navegador de Windows no puede abrir esa.
   - Que no hace falta correr esto en cada sesión: la pestaña puede quedar abierta y sigue sola. Al empezar una sesión nueva, la oficina empieza un registro nuevo y la página lo toma. Solo después de actualizar la oficina conviene recargar la pestaña (F5) para ver la versión nueva.
   - Que se actualiza sola mientras trabaja la oficina. Si todavía no hubo actividad en esta sesión, muestra una demo.
   - Que puede tocar a cualquier empleado para ver su ficha: proveedor, modelo, tarea, qué está haciendo y tokens. En la ficha, y en la actividad, puede tocar el encargo o la respuesta de cada uno para leerlos en grande.
   - Que con el botón "Avisos" la pestaña le avisa (notificación del sistema y título que parpadea) cuando el PM le responde, Claude Code le pide un permiso o un agente parece trabado.
   - Que el botón "Cierre del día" arma un resumen de la sesión con la foto de la oficina, para descargar, y que "Sonido" prende los sonidos (vienen apagados).
   - Que la oficina crece con los tokens: cada sesión empieza con una oficina básica y, con los tokens que va gastando, puede comprar en la tienda (botón "Tienda", arriba a la derecha) escritorios, sillas, pisos, cuadros, plantas, muebles y ropa para el equipo. El nivel sube con los tokens gastados, y cada sesión trae un catálogo distinto.
   - Que los tokens de Claude son exactos (salen de las transcripciones) y los de Codex y Gemini son los que informa cada CLI, si los informa.

Si el script no puede abrir el navegador (por ejemplo, en un servidor sin escritorio), pasale la ruta para que la abra él (en WSL, el link de `En Windows:`).

Para apagar el observer en un proyecto: `"OFFICE_OBSERVER": "off"` en el `env` de `.claude/settings.json`.
