---
name: discover-api
description: Descubrir la API interna de un sitio, los pedidos JSON que hace la página para traer sus datos, antes de scrapear el HTML. Graba el tráfico de la página (o resume un HAR grabado a mano), devuelve un resumen corto de cada endpoint sin cookies ni tokens y guarda las respuestas para usarlas de fixtures. Usar al agregar un sitio nuevo o cuando un scraper de HTML se rompe seguido.
---

# Descubrir la API interna de un sitio

Muchos sitios cargan sus datos (listados, precios, stock) desde un JSON propio que pide la página. Si los datos públicos vienen de ahí, ese JSON es mejor fuente que el HTML: cambia menos, pesa menos y no hay que interpretar el diseño. En la skill `responsible-scraping`, es el paso que va después de la fuente oficial y antes del HTML.

## 1. Grabar y resumir

Corré el script que está en la misma carpeta que este archivo, desde la carpeta del proyecto:

```bash
node <carpeta de esta skill>/discover-api.mjs https://sitio.com/categoria/lacteos --scroll 3
```

- Abre la página en un navegador sin ventana, la baja tres veces para que cargue lo diferido y graba los pedidos JSON.
- Deja el resumen en `.office/scraper/<sitio>/summary.md` y una respuesta por endpoint al lado. Los valores de cookies, tokens, claves y encabezados de autenticación no aparecen en ningún lado.
- Los endpoints salen ordenados por lo que parece más útil: primero los que traen la lista más larga.
- Necesita Node 18 o más y Playwright. Si falta, el script dice cómo instalarlo en `~/.cache/dev-office/`, fuera del proyecto. Instalar algo necesita la aprobación del CEO.

Leé el resumen, no las respuestas enteras: es lo que te ahorra tokens. Abrí una respuesta solo cuando vayas a escribir el parseo.

## 2. Cuando el navegador automático no alcanza

- **La página aparece bloqueada** (el resumen lo avisa) o **los datos llegan después de un clic, una búsqueda o un filtro:** pedile al CEO que grabe el tráfico desde su navegador. En Chrome: DevTools (F12) → pestaña Network → hacer lo que trae los datos → clic derecho en la lista → **Save all as HAR**. Después:

  ```bash
  node <carpeta de esta skill>/discover-api.mjs --har ruta/al/archivo.har
  ```

  El HAR tiene las cookies de su sesión: no lo copies al repositorio ni lo pegues en un reporte. Usá solo el resumen.
- **No aparece ningún JSON:** los datos pueden venir dentro del HTML (`<script type="application/json">`, `__NEXT_DATA__`, `window.__INITIAL_STATE__`). Ese JSON embebido también sirve y es más estable que el diseño de la página.

## 3. Elegir el endpoint

- Que traiga los datos públicos que se ven sin iniciar sesión. Si el endpoint pide una cuenta, frená y avisale al PM: no se usan cuentas para scrapear.
- Preferí el que trae más datos por pedido (por ejemplo, un `pageSize` alto que el sitio acepta) y que pagina con un parámetro claro (`page`, `offset`, `cursor`).
- Si manda encabezados propios (`x-...`) o un token que la página genera, anotá de dónde sale (otro pedido, el HTML) y pedilo igual que la página, en el momento. Nunca copies un valor del resumen ni de la grabación al código.
- Revisá `robots.txt` y los términos para esa ruta, como cualquier otra fuente.

## 4. Llevarlo al código

- El endpoint va en el adaptador del sitio y usa el cliente HTTP compartido, con sus pausas y reintentos (`responsible-scraping`, secciones 3, 4 y 7).
- La respuesta guardada sirve de fixture para el tester: recortala a casos representativos, anotá la fecha y el origen, y revisá que no tenga datos personales.
- En tu reporte, poné el endpoint, los parámetros que usás y la ruta del resumen, para que el tester y el PM no tengan que repetir la búsqueda.

## Otra herramienta: reverse-api-engineer

[reverse-api-engineer](https://github.com/kalil0321/reverse-api-engineer) hace algo parecido y además escribe un cliente completo con un modelo. La oficina no lo usa: corre su propio agente, fuera de los hooks, los permisos y el presupuesto de la oficina, y sus instrucciones copian al código las cookies y tokens que encuentra. El CEO lo puede usar a mano para explorar un sitio; del resultado, la oficina toma solo el HAR (`--har`), no el cliente.
