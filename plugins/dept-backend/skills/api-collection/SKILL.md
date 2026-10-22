---
name: api-collection
description: Cómo crear y mantener las colecciones de Postman del proyecto (REST y GraphQL) en una carpeta fija del repo - una del proyecto con toda la API como referencia, y una por épica con sus flujos en orden y con tests para correrlos con el Collection Runner - con autorización, scripts de login y variables de entorno compartidas. Usar cada vez que se crea, cambia, depreca o borra un endpoint o una operación de GraphQL, para revisar que las colecciones estén al día, o para generar la del proyecto desde cero si todavía no existe.
---

# Colecciones de Postman del proyecto

El proyecto guarda en el repo dos tipos de colección de Postman, que comparten los mismos entornos:

- **La del proyecto**, una sola, con toda la API ordenada por recurso. Es la referencia para el frontend.
- **Una por épica**, con los flujos de esa épica en orden y con tests en cada paso, para probarlos de punta a punta con el Collection Runner de Postman. Cuando la épica se integra, queda como prueba de regresión.

Cada vez que cambia un endpoint, las colecciones cambian en el mismo trabajo, así el frontend y el CEO siempre tienen la API de su rama lista para importar y probar. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## Dónde vive

Por defecto en `docs/api/`. Si el `CLAUDE.md` del proyecto tiene una sección "Colección de API", usá la carpeta, los entornos y la autorización que diga ahí.

```
docs/api/
  README.md                              cómo importarla y qué no incluye
  <proyecto>.postman_collection.json     la del proyecto, una sola
  epics/
    PROJ-100-<resumen>.postman_collection.json   una por épica
  environments/
    local.postman_environment.json       siempre
    <entorno>.postman_environment.json   los demás que defina el proyecto (por ejemplo staging)
```

- La del proyecto es una sola: nunca se crea otra por módulo o por ticket. Las de épica van siempre en `epics/`, una por épica, nunca por ticket.
- El archivo del proyecto se llama como el proyecto, en minúsculas con guiones; el de una épica, con su clave y un resumen corto (`PROJ-100-checkout.postman_collection.json`). Una vez creados, no se renombran.
- Formato **Postman Collection v2.1** (`info.schema` = `https://schema.getpostman.com/json/collection/v2.1.0/collection.json`).
- `info._postman_id` se genera una sola vez por colección (un UUID nuevo, nunca copiado de otra) y no se cambia nunca: con el mismo id, Postman ofrece reemplazar la colección importada en lugar de duplicarla.

## Cuándo se actualiza

- **Se crea, cambia o borra un endpoint REST:** ruta, método, parámetros, body, respuesta, errores o permisos.
- **Cambia el esquema de GraphQL:** queries, mutations, sus argumentos o los campos que devuelven.
- **Se agrega un webhook que el proyecto recibe:** va como request, para poder simular la llamada del proveedor en local.
- **Cambia la autenticación:** login, refresh, cookies, API keys o headers obligatorios.

Si el cambio no toca nada de eso (lógica interna, refactor sin cambios de contrato), las colecciones no se tocan.

Qué colecciones se actualizan:

- **Siempre la del proyecto.**
- **La de la épica**, si el ticket pertenece a una (el encargo del PM trae la clave de la épica). Si no existe, se crea (ver "Colecciones de épica").
- **Cualquier otra que use el endpoint que cambió**, incluidas las de épicas ya integradas: buscá la ruta (o el nombre de la operación de GraphQL) con Grep en toda la carpeta de colecciones y actualizá cada una.

Si el ticket no tiene épica, o el proyecto no usa épicas, solo se actualiza la del proyecto (y las que usen el endpoint).

### La primera vez: generar la del proyecto completa

Si la carpeta no existe o no tiene la colección del proyecto, generala **completa**, no solo con lo del encargo actual:

1. Hacé un inventario de toda la API leyendo el código: archivos de rutas y controladores (por ejemplo Express, Fastify, NestJS, rutas de API de Next.js, Hono), el esquema de GraphQL (`*.graphql`, `typeDefs` o los resolvers), los middlewares de autenticación y los esquemas de validación de cada entrada.
2. Si el proyecto ya tiene una especificación OpenAPI o un esquema de GraphQL generado, usalo como base y verificalo contra el código.
3. Armá la colección con todo el inventario, los entornos y el README.
4. En tu reporte, decí cuántos endpoints y operaciones encontraste y cuáles no pudiste documentar del todo (por ejemplo, un body que no tiene validación y no se puede deducir).

### Las siguientes veces: cambios puntuales

1. Leé las colecciones que vas a tocar y los entornos enteros antes de cambiarlos.
2. Cambiá solo los requests afectados. No reescribas ni reordenes el resto: cada línea de más en el diff es un conflicto posible entre ramas.
3. **Respetá lo que agregó una persona** (scripts, ejemplos, descripciones, requests de prueba): si alguien exportó la colección desde Postman y la subió, esos cambios son criterio. Solo corregí lo que contradiga el código.

## Estructura de la colección del proyecto

- **`info`:** `name` con el nombre del proyecto y `description` con una línea de qué es y un link al `docs/api/README.md`.
- **Carpetas** por recurso o módulo, siguiendo cómo está organizado el código (por ejemplo `Auth`, `Products`, `Orders`), en orden alfabético. GraphQL va en su propia carpeta, con subcarpetas `Queries` y `Mutations`.
- **Requests** dentro de cada carpeta, ordenados por ruta y después por método (GET, POST, PUT, PATCH, DELETE). Al agregar uno, insertalo en su lugar; no lo pongas al final.
- **Nombres** cortos en el idioma del proyecto, que digan qué hace: "Listar productos", "Crear pedido". Nunca dos con el mismo nombre en la misma carpeta.

### Cada request

- **URL** siempre con `{{baseUrl}}`, nunca una dirección escrita: `{{baseUrl}}/products/:id`. Las variables de ruta (`:id`) van en `url.variable` con un valor que sea otra variable (`{{productId}}`), para que se puedan encadenar.
- **Query params:** todos los que acepta el endpoint, con su descripción. Los opcionales, desactivados (`"disabled": true`).
- **Body:** un ejemplo válido y realista, con los campos obligatorios y los opcionales más usados. JSON en modo `raw` con el header `Content-Type: application/json`; archivos en modo `formdata` con `src` vacío.
- **Autorización:** si usa la de la colección, no pongas nada. Si es pública (login, registro, health), `"auth": {"type": "noauth"}`.
- **Descripción** (markdown): qué hace, quién lo puede usar, los errores posibles con su código, y una última línea `Último cambio: PROJ-123` con la clave del ticket, si la hay.
- **Ejemplos de respuesta** (`response`): uno del caso exitoso y uno por cada error importante (validación, sin permiso, no existe), con su código HTTP y un body con datos de ejemplo inventados. Son la referencia que usa el frontend para programar contra la API.

### GraphQL

- Un request por operación, `POST` a la URL de GraphQL del proyecto (por ejemplo `{{baseUrl}}/graphql`), con `body.mode` = `graphql`: la operación en `graphql.query` (con nombre: `query ListProducts(...)`) y sus variables como texto JSON en `graphql.variables`.
- Pedí los campos que el frontend usa normalmente, no todo el tipo.
- Las **subscriptions** (WebSocket) no entran en el formato v2.1: anotalas en el README.

### Lo que no entra en la colección

WebSocket, gRPC, Server-Sent Events y subscriptions de GraphQL no se exportan bien en el formato v2.1. Anotá cada uno en la sección "Fuera de la colección" del README, con su URL, cómo se autentica y qué mensajes manda y recibe.

## Colecciones de épica

Sirven para probar los flujos de la épica en orden, no como referencia: no repiten toda la API, solo los pasos que forman cada flujo.

- **Cuándo se crea:** la primera vez que un ticket de la épica toca endpoints. Con cada ticket siguiente se agregan los pasos o flujos nuevos.
- **`info`:** `name` = `PROJ-100 · <título de la épica>`, y en `description` qué flujos cubre y cómo correrla (ver abajo).
- **Carpetas = flujos.** Una por flujo, con un nombre que diga qué prueba: "Flujo: compra completa", "Flujo: cancelar pedido". Si hay casos de error importantes del flujo (sin sesión, sin permiso, datos inválidos), van en su propia carpeta: "Errores: compra".
- **Pasos en orden.** Dentro de cada flujo, los requests van en el orden en que se ejecutan, numerados: `01 Login`, `02 Crear carrito`, `03 Agregar producto`. Acá no se ordena alfabéticamente.
- **El primer paso de cada flujo es el login** (o lo que haga falta para tener sesión), así cada flujo se puede correr solo.
- **Cada paso es una copia del request** de la colección del proyecto (misma URL, método, body y autorización), más su script de test.
- **Cada paso verifica su respuesta y guarda lo que usa el siguiente:**

  ```javascript
  // 02 Crear carrito: verifica la respuesta y guarda el id para los pasos siguientes.
  pm.test("crea el carrito", () => pm.response.to.have.status(201));
  const body = pm.response.json();
  pm.test("devuelve el id", () => pm.expect(body.id).to.be.a("string"));
  pm.environment.set("cartId", body.id);
  ```

  Verificá el código HTTP y los campos que el flujo necesita, no la respuesta completa. Los pasos de error verifican el código y el `code` del error.
- **Se puede correr muchas veces.** Los datos que crea el flujo usan valores únicos con variables dinámicas de Postman (`{{$timestamp}}`, `{{$randomEmail}}`), para no chocar con una corrida anterior. Si la API permite borrar lo creado, el último paso del flujo lo borra.
- **Cómo se corre:** en Postman, la colección de la épica → Run (Collection Runner), con el entorno elegido. Ponelo en la `description` de la colección y en el README.
- **Después de integrar la épica**, la colección se queda y se mantiene: es la prueba de regresión de esos flujos. Si más adelante cambia un endpoint que usa, se actualiza como cualquier otra.

## Autorización y scripts

La autorización se define **una vez, a nivel colección**, según lo que use el proyecto:

- **Bearer token (JWT u otro):** `"auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{accessToken}}", "type": "string"}]}`.
- **API key:** `"type": "apikey"`, con el nombre del header en `key` y el valor como `{{apiKey}}`.
- **Cookie de sesión:** sin auth de colección. Postman guarda la cookie que devuelve el login; decilo en el README.

El request de login (y el de refresh, si existe) guarda los tokens en el entorno con un script de `test`, para que el resto funcione sin copiar nada a mano:

```javascript
// Guarda los tokens del login en el entorno activo.
const body = pm.response.json();
if (pm.response.code === 200 && body.accessToken) {
  pm.environment.set("accessToken", body.accessToken);
  if (body.refreshToken) pm.environment.set("refreshToken", body.refreshToken);
}
```

Usá los nombres de campo reales de la respuesta del proyecto. Del mismo modo, los requests que crean algo guardan el id creado (`pm.environment.set("productId", body.id)`), así se puede probar un flujo completo en orden.

Si el token vence seguido y el proyecto tiene refresh, podés agregar un script de `prerequest` a nivel colección que lo renueve cuando falte poco para que venza. Hacelo solo si el flujo de refresh existe en el código.

Los scripts usan la API de Postman (`pm.*`). Mantenelos cortos y con un comentario que diga qué hacen. Las colecciones de épica definen la misma autorización a nivel colección que la del proyecto.

## Variables y entornos

- Los entornos son los mismos para todas las colecciones. Cada variable `{{...}}` que usa cualquiera de ellas se declara en **todos** los entornos, aunque sea vacía (las que llenan los scripts, como `accessToken`, van vacías).
- `baseUrl` lleva la URL de cada entorno (en `local`, la del servidor de desarrollo según el `CLAUDE.md` o la configuración del proyecto).
- Los ids de ejemplo (`productId`) pueden llevar un valor de prueba.
- **Secretos siempre vacíos:** tokens, contraseñas, API keys, client secrets y el usuario de prueba van con `"value": ""` y `"type": "secret"`. Cada persona los carga en su Postman. Nunca copies un valor de un `.env` ni de ningún otro lado.
- Solo creá los entornos que el proyecto define. Si no define ninguno, solo `local`. No crees uno de producción salvo que el `CLAUDE.md` lo pida.

## El README de la carpeta

`docs/api/README.md`, en el idioma del proyecto, corto:

- **Cómo importarlas:** en Postman, Import → elegir la colección del proyecto, las de `epics/` que se quieran y los entornos de `environments/`. Al volver a importar, elegir "Reemplazar" para no duplicarlas.
- **Épicas:** una lista de las colecciones de `epics/` con los flujos que cubre cada una, y cómo correrlas con el Collection Runner.
- **Cómo empezar:** elegir el entorno, cargar los secretos (en el valor actual de cada variable), correr el login.
- **Variables:** cuáles hay y qué va en cada una.
- **Fuera de la colección:** lo que no entra en el formato (ver arriba).

## Antes de devolver

Corré el script de revisión que está en la misma carpeta que este archivo, primero con `--fix` (deja el formato fijo: claves ordenadas, sangría de 2 espacios, finales de línea LF) y después sin él:

```bash
bash <carpeta de esta skill>/check-collection.sh --fix docs/api
bash <carpeta de esta skill>/check-collection.sh docs/api
```

Usá la carpeta que corresponda si el proyecto define otra. El script revisa la colección del proyecto y todas las de `epics/`: que haya una sola del proyecto y al menos un entorno, el formato v2.1, que cada una tenga su propio `_postman_id`, nombres repetidos, URLs sin `{{baseUrl}}`, secretos escritos, que cada paso de una épica tenga su script de test, variables sin declarar y el formato fijo. Si reporta problemas, corregilos y volvé a correrlo hasta que pase. Si no lo podés correr (por ejemplo, falta `jq`), decilo en tu reporte.

El script no sabe si las colecciones reflejan el código ni si los tests de un flujo están bien pensados: eso lo revisás vos comparando el inventario de rutas con los requests y leyendo cada flujo de punta a punta.

## En tu reporte al PM

Agregá una sección **Colección de API**:

- **Archivos:** las colecciones que tocaste (la del proyecto, la de la épica y otras que usaban el endpoint).
- **Cambios:** requests agregados, modificados y borrados, por carpeta; flujos nuevos o modificados de la épica; y variables nuevas (para que el CEO las cargue en su Postman).
- **Fuera de la colección:** lo que quedó solo en el README, si hay.
- **Revisión:** resultado de `check-collection.sh`.

## Lo que nunca hacés

- Crear una segunda colección del proyecto, o una colección por ticket.
- Escribir un secreto real, un token o datos reales de usuarios, ni en los entornos ni en los ejemplos (en los ejemplos usá `<token>` o datos inventados).
- Pedirle a la API real o a cualquier servidor para "probar" las colecciones o correr los flujos: no hacés pedidos de red. Los corre el CEO o el equipo en su Postman.
- Subir las colecciones a Postman en la nube o a cualquier otro servicio.
