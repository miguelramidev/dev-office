---
name: project-map
description: Mapa e índice del proyecto para dev-office - un mapa corto escrito (docs/project-map.md, qué hay en cada carpeta y dónde vive cada cosa) y un índice de archivos y símbolos que arma un script sin gastar tokens (.office/index/files.tsv). Sirven para que el PM arme encargos con los archivos exactos y los agentes vayan directo, sin recorrer carpetas, aun en una sesión nueva. Se usa para crear el mapa en un proyecto (nuevo o ya empezado, de cualquier tamaño), para actualizarlo al cerrar una tarea que agregó, movió o borró archivos, o para buscar dónde está algo.
---

# Mapa e índice del proyecto

Lo que más gasta en un proyecto que crece es buscar: un agente que no sabe dónde está algo abre carpetas, prueba búsquedas y lee archivos que no eran. Con dos piezas eso se evita, aun en una sesión nueva:

- **El mapa** (`docs/project-map.md`, en git): qué hay en cada carpeta, dónde vive cada cosa y qué archivo sirve de modelo. Lo escribe un agente, es corto y se actualiza al cerrar las tareas que cambian la estructura.
- **El índice** (`.office/index/files.tsv`, fuera de git): cada archivo con lo que exporta o declara (funciones, clases, tipos, tablas). Lo arma `project-index.sh`, que está en la misma carpeta que este archivo, sin ningún modelo. El hook de inicio de sesión lo pone al día solo, y solo procesa lo que cambió.

Si el `CLAUDE.md` del proyecto indica otra ruta para el mapa, usá esa.

## Buscar dónde está algo

1. **El mapa:** leé `docs/project-map.md` (o solo la sección del área, si es largo) para saber en qué carpeta está.
2. **El índice:** usá Grep con el nombre que buscás sobre `.office/index/files.tsv`, nombrando el archivo exacto (por ejemplo, el patrón `createOrder` o `orders/`). Cada línea es `<ruta>	<símbolos>`. No lo leas entero: en un proyecto grande tiene miles de líneas.
3. **Recién después,** si hace falta, Grep o Glob en el código, acotados a la carpeta que te dieron el mapa o el índice.

Si el índice no existe, armalo (ver abajo). Si sospechás que está viejo (cambiaron archivos en esta misma sesión), actualizalo: `bash <carpeta de esta skill>/project-index.sh` tarda segundos.

## Crear el mapa (una vez por proyecto)

Sirve igual para un proyecto que empieza y para uno grande que ya existe: nunca se lee el proyecto entero.

1. **Índice:** `bash <carpeta de esta skill>/project-index.sh --full`. Dice cuántos archivos indexó y cuánto tardó.
2. **Carpetas:** `bash <carpeta de esta skill>/project-index.sh --dirs 1` para ver las áreas principales, y `--dirs 2` si son pocas (hasta unas 120 líneas). En un proyecto grande o un monorepo, quedate en el nivel 1 y bajá un nivel solo en las áreas principales.
3. **Leé poco y lo justo,** como máximo unos 20 archivos:
   - el README y el manifiesto del proyecto (`package.json`, `pyproject.toml`, `go.mod`...);
   - el `CLAUDE.md`;
   - en cada área principal, su README o su archivo de entrada (los que `--dirs` marca después del `·`).

   Para saber qué hace algo, usá el índice antes de abrir archivos.
4. **Escribí `docs/project-map.md`** con la plantilla de abajo, **en hasta 80 líneas**. Si un área es muy grande (un paquete de un monorepo, una app entera), dejá en el mapa una línea por área y abrí su detalle en `docs/project-map/<área>.md` **recién cuando una tarea la toque por primera vez**, no antes.
5. **Anotá el commit** en la primera línea del mapa: `<!-- map-commit: <hash de git rev-parse HEAD> -->`.
6. **Enlazalo** en el `CLAUDE.md` del proyecto (y en el `AGENTS.md`, si existe, para Codex). Mostrale el cambio al CEO antes de hacerlo:

   ```markdown
   ## Dónde está cada cosa
   - Mapa del proyecto: `docs/project-map.md`. Leelo antes de buscar archivos.
   - Índice de archivos y símbolos (generado, fuera de git): buscá un nombre con Grep en `.office/index/files.tsv`.
   ```

**Quién lo hace:** el PM no escribe archivos. Corre el paso 1 y le encarga los pasos 2 a 6 al redactor de documentación (`dept-docs:developer`), si está instalado, o si no al developer del departamento principal del proyecto. Le pasa la salida de `--dirs` y esta skill. Antes, el CEO tiene que aprobarlo, porque se agrega un archivo y se toca el `CLAUDE.md`.

### Plantilla

```markdown
<!-- map-commit: <hash> -->
# Mapa del proyecto

Qué hay en cada carpeta y dónde vive cada cosa. Para buscar un nombre puntual, el índice: Grep en `.office/index/files.tsv`.

## Áreas
| Carpeta | Qué hay | Por dónde entrar |
| --- | --- | --- |
| `src/api/` | Endpoints HTTP, uno por recurso | `src/api/router.ts` |

## Dónde vive cada cosa
- **Pantallas o páginas:** ...
- **Endpoints o rutas:** ...
- **Lógica de negocio:** ...
- **Modelos, esquemas y migraciones:** ...
- **Tipos compartidos:** ...
- **Utilidades:** ...
- **Configuración y variables de entorno:** ...
- **Tests:** dónde están y cómo se llaman.
- **Scripts y tareas:** ...

## Modelos a copiar
- Un endpoint nuevo: como `src/api/orders.ts`.
- Una pantalla nueva: como `app/(shop)/cart/page.tsx`.

## No tocar
Archivos generados o de terceros, y de dónde salen.
```

Solo lo que existe: si el proyecto no tiene alguna de esas cosas, sacá la línea. Nada de explicar cómo funciona el código: el mapa dice **dónde**. Las reglas van en el `CLAUDE.md` y las decisiones en `docs/decisions/`.

## Actualizar el mapa (al cerrar una tarea)

Lo hace el developer que hizo el cambio, en la misma tarea, y va en el mismo PR. Solo si la tarea agregó, movió o borró archivos o carpetas. Si solo cambió el contenido de archivos que ya estaban, el mapa sigue valiendo: el índice se actualiza solo.

1. `bash <carpeta de esta skill>/project-index.sh --changes <commit del map-commit>` lista, por carpeta, lo agregado (`+`), lo borrado (`-`) y lo movido (`↦`).
2. Cambiá solo las líneas del mapa de esas carpetas: un área nueva, una ruta que se movió, un modelo a copiar mejor que el anterior. No reescribas el resto.
3. Actualizá el `map-commit` con el commit actual.

Si `--changes` dice que no encuentra el commit (otra historia, un clon nuevo), revisá el mapa contra `--dirs 1` y corregí lo que no coincida.
