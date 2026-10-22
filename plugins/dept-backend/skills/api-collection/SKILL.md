---
name: api-collection
description: Cómo crear y mantener la colección de Postman del proyecto (REST y GraphQL), una sola por proyecto y en una carpeta fija del repo, con autorización, scripts de login y variables de entorno, para que el frontend la use y el CEO pruebe la API a mano. Usar cada vez que se crea, cambia, depreca o borra un endpoint o una operación de GraphQL, para revisar que la colección esté al día, o para generarla desde cero si el proyecto todavía no tiene.
---

# Colección de Postman del proyecto

El proyecto tiene **una sola colección** de Postman con toda su API, guardada en el repo. Cada vez que cambia un endpoint, la colección cambia en el mismo trabajo, así el frontend y el CEO siempre tienen la API de su rama lista para importar y probar. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## Dónde vive

Por defecto en `docs/api/`. Si el `CLAUDE.md` del proyecto tiene una sección "Colección de API", usá la carpeta, los entornos y la autorización que diga ahí.

```
docs/api/
  README.md                              cómo importarla y qué no incluye
  <proyecto>.postman_collection.json     la colección, una sola
  environments/
    local.postman_environment.json       siempre
    <entorno>.postman_environment.json   los demás que defina el proyecto (por ejemplo staging)
```

- Nunca se crea una segunda colección (ni por épica, ni por ticket, ni por módulo). Lo nuevo se agrega a la que existe.
- El nombre del archivo es el nombre del proyecto en minúsculas con guiones. Una vez creado, no se cambia.
- Formato **Postman Collection v2.1** (`info.schema` = `https://schema.getpostman.com/json/collection/v2.1.0/collection.json`).
- `info._postman_id` se genera una sola vez (un UUID) y no se cambia nunca: con el mismo id, Postman ofrece reemplazar la colección importada en lugar de duplicarla.

## Cuándo se actualiza

- **Se crea, cambia o borra un endpoint REST:** ruta, método, parámetros, body, respuesta, errores o permisos.
- **Cambia el esquema de GraphQL:** queries, mutations, sus argumentos o los campos que devuelven.
- **Se agrega un webhook que el proyecto recibe:** va como request, para poder simular la llamada del proveedor en local.
- **Cambia la autenticación:** login, refresh, cookies, API keys o headers obligatorios.

Si el cambio no toca nada de eso (lógica interna, refactor sin cambios de contrato), la colección no se toca.

### La primera vez: generarla completa

Si la carpeta no existe o no tiene colección, generala **completa**, no solo con lo del encargo actual:

1. Hacé un inventario de toda la API leyendo el código: archivos de rutas y controladores (por ejemplo Express, Fastify, NestJS, rutas de API de Next.js, Hono), el esquema de GraphQL (`*.graphql`, `typeDefs` o los resolvers), los middlewares de autenticación y los esquemas de validación de cada entrada.
2. Si el proyecto ya tiene una especificación OpenAPI o un esquema de GraphQL generado, usalo como base y verificalo contra el código.
3. Armá la colección con todo el inventario, los entornos y el README.
4. En tu reporte, decí cuántos endpoints y operaciones encontraste y cuáles no pudiste documentar del todo (por ejemplo, un body que no tiene validación y no se puede deducir).

### Las siguientes veces: cambios puntuales

1. Leé la colección y los entornos actuales enteros antes de tocarlos.
2. Cambiá solo los requests afectados. No reescribas ni reordenes el resto: cada línea de más en el diff es un conflicto posible entre ramas.
3. **Respetá lo que agregó una persona** (scripts, ejemplos, descripciones, requests de prueba): si alguien exportó la colección desde Postman y la subió, esos cambios son criterio. Solo corregí lo que contradiga el código.

## Estructura de la colección

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

Los scripts usan la API de Postman (`pm.*`). Mantenelos cortos y con un comentario que diga qué hacen.

## Variables y entornos

- Cada variable `{{...}}` que usa la colección se declara en **todos** los entornos, aunque sea vacía (las que llenan los scripts, como `accessToken`, van vacías).
- `baseUrl` lleva la URL de cada entorno (en `local`, la del servidor de desarrollo según el `CLAUDE.md` o la configuración del proyecto).
- Los ids de ejemplo (`productId`) pueden llevar un valor de prueba.
- **Secretos siempre vacíos:** tokens, contraseñas, API keys, client secrets y el usuario de prueba van con `"value": ""` y `"type": "secret"`. Cada persona los carga en su Postman. Nunca copies un valor de un `.env` ni de ningún otro lado.
- Solo creá los entornos que el proyecto define. Si no define ninguno, solo `local`. No crees uno de producción salvo que el `CLAUDE.md` lo pida.

## El README de la carpeta

`docs/api/README.md`, en el idioma del proyecto, corto:

- **Cómo importarla:** en Postman, Import → elegir el archivo de la colección y los de `environments/`. Al volver a importar, elegir "Reemplazar" para no duplicarla.
- **Cómo empezar:** elegir el entorno, cargar los secretos (en el valor actual de cada variable), correr el login.
- **Variables:** cuáles hay y qué va en cada una.
- **Fuera de la colección:** lo que no entra en el formato (ver arriba).

## Antes de devolver

Corré el script de revisión que está en la misma carpeta que este archivo, primero con `--fix` (deja el formato fijo: claves ordenadas, sangría de 2 espacios, finales de línea LF) y después sin él:

```bash
bash <carpeta de esta skill>/check-collection.sh --fix docs/api
bash <carpeta de esta skill>/check-collection.sh docs/api
```

Usá la carpeta que corresponda si el proyecto define otra. El script revisa que haya una sola colección y al menos un entorno, el formato v2.1, nombres repetidos, URLs sin `{{baseUrl}}`, secretos escritos, variables sin declarar y el formato fijo. Si reporta problemas, corregilos y volvé a correrlo hasta que pase. Si no lo podés correr (por ejemplo, falta `jq`), decilo en tu reporte.

El script no sabe si la colección refleja el código: eso lo revisás vos comparando el inventario de rutas con los requests.

## En tu reporte al PM

Agregá una sección **Colección de API**:

- **Archivo:** la ruta de la colección.
- **Cambios:** requests agregados, modificados y borrados, por carpeta, y variables nuevas (para que el CEO las cargue en su Postman).
- **Fuera de la colección:** lo que quedó solo en el README, si hay.
- **Revisión:** resultado de `check-collection.sh`.

## Lo que nunca hacés

- Crear una segunda colección o una por épica.
- Escribir un secreto real, un token o datos reales de usuarios, ni en los entornos ni en los ejemplos (en los ejemplos usá `<token>` o datos inventados).
- Pedirle a la API real o a cualquier servidor para "probar" la colección: no hacés pedidos de red.
- Subir la colección a Postman en la nube o a cualquier otro servicio.
