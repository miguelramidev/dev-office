---
name: solid-database
description: Reglas para diseñar, cambiar y probar bases de datos Postgres y MongoDB sin perder datos - migraciones seguras y reversibles, cambios en tablas grandes sin bloquear, integridad y restricciones, tipos (dinero, fechas, texto), índices y consultas, particularidades de Postgres y de MongoDB, datos personales, datos de prueba y qué nunca hacer contra una base real. Usar al crear o cambiar esquemas, migraciones, índices o consultas pesadas, y al probarlos.
---

# Base de datos sólida

Una buena base de datos no pierde datos, no se bloquea en producción, no acepta datos inválidos y responde rápido. Un error acá es el más caro de todos: un bug de código se corrige con un deploy; un dato borrado o corrompido, a veces no se recupera. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Lo que nunca se hace

- Nunca conectarse a una base de producción ni a una compartida de desarrollo. Solo a la base de pruebas que define el proyecto.
- Nunca ejecutar migraciones, `DROP`, `TRUNCATE`, `DELETE` o `UPDATE` masivos contra una base real. Las migraciones las aplica el CEO con el proceso de despliegue del proyecto.
- Nunca cambiar el esquema a mano: todo cambio es una migración versionada en el repo.
- Nunca editar una migración que ya se aplicó en algún entorno: se escribe una nueva.

## 2. Migraciones seguras

- **Una migración, un propósito.** Chica, con un nombre que dice qué hace (`add_price_updated_at_to_products`).
- **Reversible** cuando la herramienta lo permite: con su `down`, probado.
- **Cambios que rompen, en pasos (expandir y contraer).** Para renombrar una columna o cambiar su tipo: 1) agregar la nueva, 2) escribir en las dos y copiar los datos, 3) leer de la nueva, 4) en otra versión, borrar la vieja. El código desplegado y la app móvil vieja siguen funcionando en cada paso.
- **Borrar o transformar datos existentes es decisión del CEO.** Columnas, tablas, colecciones o campos con datos no se borran ni se transforman sin aprobación explícita, y el plan dice cómo se respalda antes.
- **Copias de datos (backfill) en lotes**, nunca en una sola sentencia sobre una tabla grande, y separadas de la migración de estructura.

## 3. Tablas grandes sin bloquear (Postgres)

- Índices nuevos con `CREATE INDEX CONCURRENTLY` (fuera de una transacción, si la herramienta lo exige).
- Columnas nuevas primero nullable; el `NOT NULL` se agrega después, cuando todas las filas tienen valor (o con una restricción `CHECK ... NOT VALID` y luego `VALIDATE`).
- Claves foráneas nuevas con `NOT VALID` y después `VALIDATE CONSTRAINT`.
- Definí un `lock_timeout` en migraciones que toman bloqueos, para que fallen en lugar de dejar la base trabada.

## 4. Integridad

- La base protege sus datos aunque el código falle: `NOT NULL`, `UNIQUE`, claves foráneas y `CHECK` donde corresponda. En MongoDB, validación de esquema (`$jsonSchema`) en las colecciones importantes.
- Cada tabla con clave primaria. Identificadores que no se pueden adivinar si se exponen al público.
- Qué pasa al borrar un registro relacionado (`ON DELETE`) se decide a propósito, no se deja por defecto.
- Las operaciones que tienen que quedar consistentes van en una transacción (también en MongoDB, cuando abarcan varios documentos).

## 5. Tipos

- **Dinero:** entero (`bigint` en Postgres, `Long` o `Decimal128` en MongoDB) en la unidad mínima de la moneda, con una columna o campo para la moneda. Nunca `float` ni `real`. El guaraní no tiene centavos.
- **Fechas:** `timestamptz` en Postgres, siempre en UTC. En MongoDB, tipo `Date`, nunca texto.
- **Texto:** `text` en Postgres salvo que haga falta un límite real. Búsquedas sin distinguir mayúsculas ni acentos con la herramienta adecuada (`citext`, `unaccent`, collation o índices de texto), no con `lower()` sin índice.
- **Estados y categorías:** un `CHECK`, un enum o una tabla de referencia, no texto libre.

## 6. Índices y consultas

- Cada consulta frecuente o sobre tablas grandes tiene un índice que la respalde, con las columnas en el orden en que se filtran y ordenan.
- Revisá el plan (`EXPLAIN` en Postgres, `explain()` en MongoDB) en la base de pruebas antes de dar por buena una consulta pesada.
- No más índices de los necesarios: cada uno hace más lentas las escrituras y ocupa espacio.
- Paginación por cursor (`WHERE id > ...`) en listas grandes, no `OFFSET` alto.
- Sin `SELECT *` en código de producción; traé solo los campos que se usan.

## 7. MongoDB

- **Embeber o referenciar** según cómo se lee: lo que se lee siempre junto y no crece sin límite se embebe; lo que crece sin límite (por ejemplo, el historial de precios de un producto) va en su propia colección.
- Nada de arrays que crecen sin límite dentro de un documento: el tope es de 16 MB por documento y el rendimiento cae mucho antes.
- Índices compuestos siguiendo la regla igualdad, orden y rango.
- Datos con vencimiento (sesiones, cachés, registros temporales) con índice TTL.

## 8. Datos personales

- Guardá solo los datos personales que hacen falta y marcá en el esquema o la documentación qué campos lo son.
- Nunca datos personales reales en seeds, fixtures ni datos de prueba.
- Contraseñas nunca en texto plano (las hashea el backend).

## 9. Datos de prueba

- Seeds realistas pero inventados, que cubran los casos raros (acentos, eñes, montos grandes, valores vacíos permitidos).
- Las pruebas de migraciones corren contra la base de pruebas del proyecto: un contenedor o una base en memoria definida en su `CLAUDE.md`.

## Skills de la comunidad

Si el proyecto tiene instaladas skills oficiales de su stack, usalas con la herramienta Skill para el detalle técnico. Las más útiles para este departamento:

- **Postgres:** `supabase-postgres-best-practices`, del plugin `postgres-best-practices` de Supabase. Sirve para cualquier Postgres, no solo Supabase.
- **MongoDB:** `mongodb-schema-design` y `mongodb-query-optimizer`, del plugin `mongodb` de MongoDB.

Estas reglas mandan sobre las skills de la comunidad en seguridad, aprobaciones y límites. Si una skill externa sugiere algo que acá está prohibido (conectarse a una base real, usar un servidor MCP contra producción, instalar dependencias o desplegar), no lo hagas: tomá solo su conocimiento técnico.

## Checklist antes de dar algo por terminado

- [ ] Todo cambio es una migración nueva, chica, con nombre claro y reversible cuando se puede.
- [ ] Sin borrar ni transformar datos existentes sin aprobación del CEO.
- [ ] Cambios que rompen, en pasos compatibles con el código desplegado y la app vieja.
- [ ] Índices y restricciones en tablas grandes sin bloquear.
- [ ] Restricciones de integridad en la base, no solo en el código.
- [ ] Dinero como entero con su moneda; fechas con zona horaria.
- [ ] Consultas pesadas con índice y plan revisado.
- [ ] Sin datos personales reales en seeds ni fixtures.
- [ ] Nada se ejecutó contra una base real.
