---
name: responsible-scraping
description: Reglas para construir y probar scrapers responsables - elegir la fuente, identificarse, ritmo de pedidos, reintentos con límite, no evadir bloqueos, controlar costos, separar descarga y parseo, fixtures, validación de lo extraído, codificación y dinero. Usar al crear, corregir o probar cualquier scraper.
---

# Scraping responsable

Un buen scraper no molesta al sitio, no se hace bloquear, no inventa datos y no genera costos sorpresa. Si las reglas del proyecto definen algo distinto (por ejemplo, otra pausa mínima), mandan las del proyecto.

## 1. Antes de scrapear: elegir la fuente

1. Buscá primero una fuente oficial: API, feed, exportación o lista de precios en TXT, CSV o JSON. Es más estable, más liviana y más respetuosa que el HTML.
2. Revisá `robots.txt` y los términos del sitio. Si prohíben el acceso automatizado a lo que necesitás, frená y pedí aprobación.
3. Elegí el formato más simple que tenga los datos, en este orden: archivo plano (TXT, CSV, JSON) → HTML estático → navegador automatizado. Un navegador es lento y caro: solo si no hay otra forma.

## 2. Identificarse

- Usá un User-Agent propio con el nombre del proyecto y una URL o email de contacto (por ejemplo `MiProyectoBot/1.0 (+https://miproyecto.com/bot)`).
- Nunca te hagas pasar por un navegador real para esconderte.

## 3. Ritmo de pedidos

- Un pedido a la vez por sitio. Nunca pedidos en paralelo al mismo sitio.
- Pausa entre pedidos: mínimo 2 segundos más una variación aleatoria.
- Si el sitio responde con `Retry-After`, respetalo (con un tope razonable, por ejemplo 60 segundos).
- Si es posible, correr en horarios de poco tráfico.

## 4. Reintentos

- Reintentar solo ante errores de red, timeout, 429 o 5xx, con espera creciente (backoff exponencial) y variación aleatoria.
- Tope de reintentos por pedido (por ejemplo, 3) y por sitio en cada corrida (por ejemplo, 10). Al agotarlo, se corta la corrida de ese sitio con un error claro.
- Nunca reintentar otros 4xx. Un 403 o un 401 es una respuesta del sitio, no un error pasajero.

## 5. Bloqueos: no evadir

- Si un sitio bloquea (403, desafío anti-bots, captcha), se registra y se avisa. No se intenta evadir.
- Prohibido: rotar IPs o proxies, cambiar el User-Agent para engañar, resolver captchas o simular comportamiento humano para pasar un bloqueo.
- Un bloqueo es una decisión para el CEO, no un problema técnico a esquivar.

## 6. Costos

- No correr scrapers en servicios que cobran por tiempo de ejecución mientras el scraper espera (por ejemplo, funciones serverless como AWS Lambda): las pausas y los reintentos se pagan. Un servidor chico con una tarea programada es más barato y predecible.
- Correr desde una región cercana a los sitios: menos latencia, menos timeouts y menos reintentos.
- Descargar solo lo necesario: si hay una lista completa en un archivo, no recorrer página por página.

## 7. Estructura del código

- **Descarga y parseo separados.** La función que interpreta los datos recibe el texto ya descargado y no hace pedidos. Así se prueba con fixtures, sin red.
- **Un adaptador por sitio**, con una interfaz común. Agregar un sitio es agregar un archivo, sin tocar los demás.
- **El cliente HTTP es uno solo y compartido.** Ahí viven las pausas, los reintentos y el User-Agent; los adaptadores nunca usan `fetch` o equivalentes directos.

## 8. Fixtures

- Un fixture es una copia real de lo que devuelve el sitio, guardada en el repo para los tests.
- Si el original es enorme, recortalo manteniendo casos representativos: normales, raros y los que se descartan.
- Sin datos personales.
- Anotá en un comentario o en la documentación la fecha y el origen del fixture.
- Si el sitio cambia de formato, se agrega un fixture nuevo; el viejo se conserva mientras siga siendo útil.

## 9. Validar lo extraído

- Validá cada elemento con un esquema (por ejemplo, Zod) antes de usarlo.
- Lo que no pasa la validación se descarta con un aviso en el log (qué fila y por qué), nunca se completa con valores inventados.
- Detectá respuestas engañosas: una página de error o de bloqueo devuelta con código 200 (tamaño anormal, marcadores como "access denied" o "captcha", cero elementos extraídos) tiene que terminar en error, no en una lista vacía silenciosa.
- Si la cantidad de elementos cae de golpe respecto a corridas anteriores, es una señal de que el sitio cambió: avisá.

## 10. Texto, números y dinero

- Detectá la codificación: muchos archivos antiguos vienen en Latin-1 (ISO-8859-1). Decodificá desde los bytes con la codificación correcta, nunca asumas UTF-8.
- Normalizá espacios, saltos de línea y caracteres invisibles antes de parsear.
- Números: interpretá el formato del sitio ("1.250,00" o "1,250.00") de forma explícita, sin adivinar.
- Dinero: siempre como entero en la unidad mínima de la moneda (centavos, o la moneda entera si no tiene centavos). Nunca decimales flotantes. Guardá siempre la moneda junto al monto.

## 11. Datos personales

- No recolectes datos personales (nombres, emails, teléfonos de personas) salvo que el proyecto lo requiera explícitamente y esté aprobado.
- Nunca guardes credenciales ni cookies de sesión en el repo.

## Checklist antes de dar un scraper por terminado

- [ ] Fuente elegida con criterio (oficial o la más simple) y `robots.txt` revisado.
- [ ] User-Agent propio con contacto.
- [ ] Un pedido a la vez, con pausa y respeto de `Retry-After`.
- [ ] Reintentos con tope por pedido y por corrida; sin reintentar 4xx.
- [ ] Sin evasión de bloqueos.
- [ ] Descarga y parseo separados; parseo probado con fixture real.
- [ ] Validación con esquema; descartes con aviso; respuestas engañosas detectadas.
- [ ] Codificación correcta y dinero como entero con su moneda.
