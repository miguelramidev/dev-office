---
name: solid-backend
description: Reglas para diseñar, construir y probar un backend sólido - contratos y validación, errores, autenticación y permisos, dinero y fechas, base de datos, servicios externos, seguridad, costos en la nube, logs y estructura del código. Usar al diseñar, crear, corregir o probar cualquier parte del backend (API, tareas programadas, colas, integraciones).
---

# Backend sólido

Un buen backend no miente, no pierde datos, no expone secretos y no genera costos sorpresa. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Contratos y validación

- Toda entrada externa se valida con un esquema (por ejemplo, Zod) en el borde: body, query, params, headers, mensajes de colas y respuestas de servicios externos. Adentro del sistema se trabaja con datos ya validados y tipados.
- Lo que no pasa la validación se rechaza con un error claro (400 o 422), nunca se completa con valores por defecto que oculten el problema.
- El contrato de cada endpoint (método, ruta, entrada, salida y errores posibles) se define antes de programarlo y no cambia sin avisar: un cambio que rompe a los clientes (el front web o la app móvil) es una decisión del CEO.
- Las listas siempre van paginadas, con un tope máximo de elementos por página.

## 2. Errores

- Un formato de error único en toda la API, por ejemplo `{ "error": { "code": "PRODUCT_NOT_FOUND", "message": "..." } }`. El `code` es estable y en inglés; el cliente decide qué mostrar.
- Códigos HTTP correctos: 400/422 entrada inválida, 401 sin sesión, 403 sin permiso, 404 no existe, 409 conflicto, 429 demasiados pedidos, 5xx solo para fallas del servidor.
- Nunca devolver al cliente trazas, consultas SQL ni mensajes internos. Eso va al log.
- Nunca tragarse un error con un `catch` vacío. Si se maneja, se registra; si no se puede manejar, se propaga.

## 3. Autenticación y permisos

- Cada endpoint declara quién lo puede usar. Lo que no es público requiere sesión, y además se verifica que el usuario sea dueño del recurso o tenga el permiso (no alcanza con estar logueado).
- Los identificadores que vienen del cliente nunca reemplazan al usuario de la sesión: el `userId` sale de la sesión, no del body.
- Contraseñas solo con un algoritmo hecho para eso (argon2 o bcrypt), nunca con hashes rápidos.

## 4. Dinero, números y fechas

- Dinero como entero en la unidad mínima de la moneda, siempre junto a su moneda (`{ amount: 15900, currency: "PYG" }`). Nunca decimales flotantes. El guaraní no tiene centavos: la unidad mínima es el guaraní entero.
- Fechas guardadas en UTC con zona horaria explícita (ISO 8601). La conversión a la hora local se hace al mostrar. Las tareas programadas declaran en qué zona horaria corren.
- Los cálculos que redondean definen cómo redondean y en qué paso.

## 5. Base de datos

- Consultas siempre parametrizadas o con el ORM/query builder del proyecto. Nunca concatenar texto del usuario en una consulta (SQL o filtros de Mongo con operadores que vienen del cliente).
- Sin consultas dentro de bucles (el problema N+1): traer lo necesario en una consulta o en lote.
- Las operaciones que modifican varias cosas que tienen que quedar consistentes van en una transacción.
- Toda consulta que se usa seguido o filtra tablas grandes tiene un índice que la respalde. Si falta, se pide (ver "Cambios de esquema").
- **Cambios de esquema:** siempre con migraciones versionadas, nunca a mano. Si el proyecto tiene departamento de base de datos, el esquema y las migraciones son suyos; el backend los usa. Una migración que borra o transforma datos existentes es una decisión del CEO.

## 6. Servicios externos y tareas en segundo plano

- Toda llamada externa tiene timeout. Reintentos solo ante errores de red, timeout, 429 o 5xx, con espera creciente, variación aleatoria y un tope.
- Las operaciones que se pueden repetir (reintentos, mensajes de cola que llegan dos veces, el usuario que toca dos veces el botón) tienen que ser idempotentes: repetirlas no duplica datos ni cobros.
- Un mensaje de cola que falla siempre no se reintenta para siempre: después del tope va a una cola de errores (dead-letter) y se avisa.
- Las tareas largas no bloquean la respuesta HTTP: se encolan y se informa el estado.

## 7. Seguridad

- Secretos solo desde variables de entorno o un gestor de secretos. Nunca en el código, en los logs ni en los mensajes de error.
- Límite de pedidos (rate limit) en los endpoints públicos y en los de autenticación.
- CORS solo para los orígenes propios. Cabeceras de seguridad activadas.
- Nada que venga del usuario se ejecuta, se usa como ruta de archivo o como URL a la que el servidor hace pedidos sin validarlo antes.
- Las dependencias nuevas se agregan solo con aprobación y se prefieren las mantenidas y conocidas.

## 8. Costos en la nube

- Nada corre más veces ni más tiempo del necesario: sin bucles de sondeo cortos, sin reintentos sin tope, sin funciones serverless que esperan sin hacer nada.
- Las consultas caras o repetidas se cachean con un tiempo de vida definido.
- Todo recurso nuevo en la nube (instancias, colas, buckets, bases de datos) o un cambio que suba la factura es una decisión del CEO.

## 9. Logs

- Logs estructurados (JSON) con nivel, mensaje y contexto (id del pedido, ruta, usuario cuando corresponde).
- Nunca registrar contraseñas, tokens, datos de tarjetas ni el contenido completo de datos personales.
- Cada error registrado tiene que permitir entender qué pasó sin reproducirlo.

## 10. Estructura del código

- Funciones chicas con una sola responsabilidad. Las dependencias (base de datos, cliente HTTP, reloj, logger, colas) se reciben por parámetro, para poder probar sin servicios reales.
- La lógica de negocio no depende del framework HTTP: el handler valida, llama a la lógica y arma la respuesta.
- Sin capas, clases ni abstracciones que no hagan falta hoy.
- Seguí la estructura y los patrones que ya usa el proyecto antes de inventar uno nuevo.

## Skills de la comunidad

Si el proyecto tiene instaladas skills oficiales de su stack, usalas con la herramienta Skill para el detalle técnico. Las más útiles para este departamento:

- **Postgres:** `supabase-postgres-best-practices`, del plugin `postgres-best-practices` de Supabase. Sirve para cualquier Postgres, no solo Supabase.
- **MongoDB:** `mongodb-schema-design` y `mongodb-query-optimizer`, del plugin `mongodb` de MongoDB.

Estas reglas mandan sobre las skills de la comunidad en seguridad, aprobaciones y límites. Si una skill externa sugiere algo que acá está prohibido (conectarse a una base real, usar un servidor MCP contra producción, instalar dependencias o desplegar), no lo hagas: tomá solo su conocimiento técnico.

## Checklist antes de dar algo por terminado

- [ ] Entradas validadas con esquema; contrato documentado y sin cambios que rompan clientes sin aprobación.
- [ ] Errores con el formato y el código HTTP correctos, sin detalles internos.
- [ ] Permisos verificados por recurso, no solo por sesión.
- [ ] Dinero como entero con su moneda; fechas en UTC.
- [ ] Consultas parametrizadas, sin N+1, con índices; cambios de esquema con migración.
- [ ] Llamadas externas con timeout y reintentos con tope; operaciones repetibles idempotentes.
- [ ] Sin secretos en el código ni en los logs.
- [ ] Sin costos nuevos en la nube sin aprobación.