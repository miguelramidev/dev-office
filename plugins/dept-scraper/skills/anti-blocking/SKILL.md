---
name: anti-blocking
description: Modo anti-bloqueo para scrapers de datos públicos que el sitio bloquea por huella de cliente o por IP - diagnosticar el tipo de bloqueo, pedidos con la huella TLS y HTTP/2 de un navegador real (impit, curl_cffi, tls-client) y proxies rotativos con sesión fija por sitio, tope de rotaciones y costo controlado. Solo se usa si las reglas del proyecto lo activan. Usar al construir, corregir o probar un scraper de un proyecto con el anti-bloqueo activo.
---

# Anti-bloqueo

Algunos sitios bloquean a los scrapers por cómo se conectan (la huella TLS y HTTP/2 de una librería no es la de un navegador) o por la IP (demasiados pedidos desde la misma dirección, o desde un datacenter). Esta skill dice cómo pasar esos bloqueos para **datos públicos**, sin dejar de ser un buen vecino.

## Cuándo se usa

Solo si las reglas del proyecto (`CLAUDE.md` o `.claude/rules/`) lo activan, con una línea como:

```text
Scraping: anti-bloqueo con huella y proxies. Proxies en SCRAPER_PROXY_URLS. Tope de proxies: 5 GB por mes.
```

| Lo que dicen las reglas | Qué se puede usar |
| --- | --- |
| Nada | Nada de esta skill: un bloqueo se registra y se avisa (`responsible-scraping`, sección 5). |
| `anti-bloqueo con huella` | Nivel 1. |
| `anti-bloqueo con huella y proxies` | Niveles 1 y 2. |

Las reglas pueden limitarlo a algunos sitios ("solo para tienda-a y tienda-b"). Lo que no está activado no se usa, aunque ayude.

**Siempre, con cualquier nivel:**

- Solo datos públicos, los que se ven sin iniciar sesión. Nada de cuentas, ni propias ni ajenas.
- No se resuelven captchas, ni con servicios ni a mano.
- El ritmo de pedidos de `responsible-scraping` (sección 3) se mantiene **por sitio**, no por IP. Más IPs no es más velocidad contra el mismo sitio: es la forma de no tirarlo abajo.
- Cada pasada por el anti-bloqueo queda en el log: qué bloqueo, qué nivel, cuántas rotaciones.

## 0. Diagnosticar antes de cambiar nada

Guardá la respuesta bloqueada (código, encabezados y cuerpo) como fixture y mirá qué es:

| Señal | Qué es | Qué hacer |
| --- | --- | --- |
| `429`, con o sin `Retry-After` | Ritmo: vas demasiado rápido | Bajá el ritmo. No es un caso para esta skill. |
| `403` o `503` con `server: cloudflare`, `cf-ray`, `cf-mitigated: challenge` o "Just a moment..." | Cloudflare | Nivel 1. Si sigue con desafío de JavaScript, ver "Lo que esto no pasa". |
| Cookie `_abck` o `bm_sz`, "Access Denied" con "Reference #" | Akamai | Nivel 1, y si sigue, nivel 2. |
| Encabezado `x-datadome` o cookie `datadome` | DataDome | Nivel 1 y nivel 2 juntos: mira huella e IP. |
| Cookies `_px...`, "Press & Hold" | HUMAN (PerimeterX) | Ver "Lo que esto no pasa". |
| Cookies `incap_ses` o `visid_incap` | Imperva | Nivel 1, y si sigue, nivel 2. |
| `x-amzn-waf-action`, `aws-waf-token` | AWS WAF | Nivel 1, y si sigue, nivel 2. |
| Anda desde tu red y falla desde el servidor | Bloqueo por IP o por rango de datacenter | Nivel 2. |

Un bloqueo también puede venir con código 200: una página de desafío en lugar de los datos (`responsible-scraping`, sección 9). El detector de bloqueos es el mismo para los dos casos.

## 1. Nivel 1: huella de navegador

El cliente HTTP compartido hace los pedidos con la huella TLS y HTTP/2 de Chrome, con una librería hecha para eso:

| Stack | Librería | Uso |
| --- | --- | --- |
| Node o TypeScript | [`impit`](https://apify.github.io/impit/js) | `new Impit({ browser: "chrome", proxyUrl })` y `impit.fetch(url)` |
| Python | [`curl_cffi`](https://curl-cffi.readthedocs.io/) | `curl_cffi.Session(impersonate="chrome")` |
| Go | [`bogdanfinn/tls-client`](https://github.com/bogdanfinn/tls-client) o [`httpcloak`](https://github.com/sardanioss/httpcloak) | Cliente con el perfil de Chrome más nuevo |

Si el stack no tiene una, no la armes a mano: proponele al PM las opciones (por ejemplo, ese scraper en otro lenguaje) y que decida el CEO. Agregar la librería es una dependencia nueva: necesita aprobación.

Reglas:

- **Perfil "chrome" sin versión fija** (`impersonate="chrome"`, `browser: "chrome"`): la librería lo mantiene al día. Actualizá la librería seguido; una huella vieja se nota.
- **Huella y encabezados coherentes:** dejá que la librería ponga el User-Agent y los encabezados del navegador que imita. Un User-Agent propio con huella de Chrome es lo primero que se detecta. Con el anti-bloqueo activo, esta regla reemplaza a la de identificarse (`responsible-scraping`, sección 2).
- **Una sesión por sitio y por corrida:** guarda las cookies que el sitio manda (por ejemplo, las del desafío) y las reusa en los pedidos siguientes, como un navegador. En memoria, nunca en el repositorio.
- **Entrar como un visitante:** si la API rechaza un pedido directo, pedí primero la página que la llama (la de la categoría o la búsqueda) en la misma sesión, y mandá el `Referer` de esa página.
- **En el cliente compartido, no en el adaptador:** cada sitio declara en su adaptador si usa el anti-bloqueo (`antiBlocking: "fingerprint"` o `"proxies"`, o lo que use el proyecto). Los sitios que no lo necesitan siguen con el cliente común.

## 2. Nivel 2: proxies rotativos

Para los sitios que bloquean por IP. El proveedor lo elige y lo paga el proyecto (residenciales para los sitios estrictos, de datacenter para los demás).

- **Credenciales fuera del código:** las direcciones de los proxies (con usuario y clave) vienen de variables de entorno, por ejemplo `SCRAPER_PROXY_URLS` separadas por comas. Nunca en el repositorio, nunca en los logs: en el log, solo el host del proxy o un número.
- **Solo donde hace falta:** el proxy se usa en los sitios que lo declaran, no en todos.
- **IP fija por sitio en cada corrida:** toda la corrida de un sitio sale por el mismo proxy (o la misma "sesión fija" del proveedor). Cambiar de IP a mitad de camino con las mismas cookies es una señal de bot.
- **Rotar ante un bloqueo, no antes:** ante un 403, un desafío o un 200 bloqueado, se cambia a otro proxy **con una sesión nueva** (cookies vacías), se espera con backoff y se reintenta. Tope de rotaciones por sitio en cada corrida (por ejemplo, 3): al llegar, se corta ese sitio con un error claro.
- **País:** usá proxies del país del sitio. Muchos sitios bloquean o cambian los precios según el país.
- **Costo:** los proxies se cobran por GB. Pedí solo la API o el HTML, nunca imágenes ni recursos. Registrá cuánto bajó cada sitio por proxy en cada corrida. Si las reglas ponen un tope (GB o dinero), el scraper frena al llegar y avisa.

## Lo que esto no pasa

Un desafío que se resuelve con JavaScript en el navegador (el de Cloudflare cuando sigue después del nivel 1, el "Press & Hold" de HUMAN) o un captcha no se pasa con huella ni con proxies. En ese caso:

1. Buscá otra fuente en el mismo sitio con la skill `discover-api`: un JSON o una ruta que no tenga el desafío.
2. Si no hay, registralo y avisale al PM con lo que viste. Es una decisión del CEO: por ejemplo, sumar un nivel con navegador real, o dejar ese sitio.

## Pruebas (tester)

Todo sin red, con un transporte falso y reloj falso:

- El detector clasifica las respuestas bloqueadas guardadas como fixtures (cada proveedor de la tabla que use el proyecto, y el 200 con página de desafío) y no confunde una respuesta normal con un bloqueo.
- Los sitios sin anti-bloqueo usan el cliente común, y los que lo declaran usan el que imita al navegador.
- La sesión guarda las cookies del sitio y las reusa. Al rotar, empieza vacía.
- Ante un bloqueo, rota a otro proxy, espera y reintenta. Al llegar al tope, corta ese sitio con error, sin seguir pidiendo.
- El ritmo por sitio se mantiene aunque cambie el proxy.
- Ni el usuario ni la clave del proxy aparecen en los logs ni en los errores.
- El tope de GB o de costo frena la corrida.
