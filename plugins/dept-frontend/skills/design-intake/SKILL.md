---
name: design-intake
description: Cómo leer un diseño que ya existe (entregado por un cliente o un equipo de diseño) y convertirlo en una especificación que el developer pueda construir sin adivinar - desde imágenes (capturas o exportaciones de Figma, Sketch, Adobe XD, etc.) guardadas en el proyecto o desde links de Figma si el servidor MCP de Figma está conectado. Usar cuando el encargo trae imágenes o links de diseño, o cuando el CLAUDE.md del proyecto dice que los diseños los entrega otro.
---

# Leer diseños entregados

Cuando el diseño ya existe, el trabajo no es proponer una experiencia nueva sino **traducir fielmente** lo que otro diseñó a una especificación construible, y señalar lo que falta. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Las fuentes

Usá, en este orden, lo que el encargo traiga:

1. **Imágenes en el proyecto.** Por defecto en `docs/design/references/<tema>/` (o la ruta que diga el encargo o el `CLAUDE.md`). Leé **cada** imagen con la herramienta Read: la ves como imagen. Formatos: PNG, JPG, WebP o PDF.
2. **Links de Figma**, solo si tenés disponibles herramientas del servidor MCP `figma` (`mcp__figma__*`). Ver sección 4.
3. **Nada de lo anterior:** no inventes la pantalla. Frená y pedí las imágenes o los links.

Las imágenes que el CEO pega en el chat **no te llegan**: solo las ve la sesión principal. Si el encargo las menciona pero no hay archivos, pedí que se guarden en la carpeta de referencias.

Cómo conviene exportar (para recomendárselo al CEO si las imágenes no alcanzan): cada pantalla como PNG a 2x desde Figma (*Export* del frame) o una captura nítida, una imagen por pantalla y por estado, con nombres que digan qué son (`login.png`, `login-error.png`, `historial-vacio.png`).

## 2. Qué sacar de cada imagen

Por cada pantalla, anotá:

- **Estructura:** de arriba hacia abajo, cada bloque y su orden. Qué es fijo (encabezado, barra inferior) y qué se desplaza.
- **Textos exactos:** títulos, etiquetas, botones, placeholders, mensajes. Copialos tal cual, con mayúsculas y signos. Si un texto no se lee bien, marcalo como `[ilegible]`, no lo completes.
- **Componentes:** cuáles existen ya en el proyecto (buscalos en el código) y cuáles son nuevos. Botones primarios y secundarios, campos, tarjetas, listas, chips, íconos.
- **Colores:** si el proyecto ya tiene tokens, asociá cada color al token más cercano. Si no, anotá el valor aproximado y marcalo **aprox.**: un color leído de una imagen nunca es exacto (compresión, perfil de color, transparencias).
- **Tipografía:** jerarquía (título, subtítulo, cuerpo, nota) y peso relativo. La fuente y los tamaños exactos casi nunca se pueden saber por la imagen: si no están en el proyecto, van a "Faltantes".
- **Espaciados y tamaños:** estimalos en la escala del proyecto (por ejemplo, múltiplos de 4 u 8) y marcalos **aprox.**
- **Estados que muestra la imagen:** normal, cargando, vacío, error, deshabilitado, seleccionado.
- **Interacciones que se deducen:** qué es tocable, a dónde lleva, qué se despliega.

## 3. Lo que falta también es parte del trabajo

Un diseño entregado casi nunca cubre todo. Listá en "Faltantes" lo que el developer va a necesitar y no está:

- Estados sin diseñar (cargando, vacío, error, sin conexión, textos muy largos).
- Pantallas o pasos del flujo que se nombran pero no tienen imagen.
- Valores que la imagen no da con certeza: fuente, tamaños, colores exactos, íconos.
- Comportamientos ambiguos (qué pasa al tocar algo, validaciones de formularios).

Para cada faltante, proponé una solución **coherente con el resto del diseño** y marcala como propuesta, para que el CEO decida si la acepta o se la pide al dueño del diseño. Nunca la presentes como si viniera del diseño original.

## 4. Figma (si está conectado)

Si tenés herramientas `mcp__figma__*` y el encargo trae links de Figma:

- **Cuidá las llamadas:** muchas cuentas tienen un límite bajo (por ejemplo, pocas llamadas por mes con asientos de solo lectura). Pedí solo los nodos del encargo, nunca el archivo entero, y no repitas llamadas.
- **Orden:** `get_metadata` del frame para ver su estructura, `get_screenshot` para verlo, `get_variable_defs` **una sola vez** por archivo para los tokens (colores, tipografías, espaciados) y `get_design_context` solo para un nodo puntual que no se entienda.
- **Guardá lo que obtenés** en la especificación (tokens con sus valores, textos, medidas), para que nadie tenga que volver a consultar Figma.
- Los valores que vienen de Figma son exactos: no lleves la marca **aprox.**
- Si una llamada falla por permisos o límite, no reintentes: decilo en tu reporte y seguí con imágenes.
- Nunca uses herramientas que escriben en Figma.

## 5. La especificación

Va en el documento de diseño de la tarea (`docs/design/<fecha>-<tema>.md`), con estas secciones en lugar de las de una propuesta nueva:

```markdown
# <Tema>

- **Estado:** especificación (diseño entregado)
- **Fecha:** <fecha>
- **Fuente:** <rutas de las imágenes o links de Figma>

## Pantallas
Por cada pantalla: referencia a su imagen, estructura, componentes (existentes y nuevos), interacciones y estados que muestra.

## Textos
Todos los textos, tal como se ven en el diseño.

## Estilos
Colores, tipografía y espaciados, asociados a tokens del proyecto. Lo aproximado, marcado como **aprox.**

## Faltantes
Lo que el diseño no define, con una propuesta marcada como propuesta.

## Decisiones para el CEO
Faltantes que necesitan respuesta del dueño del diseño, componentes nuevos grandes y diferencias con lo que ya existe en la app.
```

## 6. Fidelidad

- Si el diseño entregado choca con lo que ya existe en la app (otro estilo de botón, otro color), **gana el diseño entregado** salvo que el `CLAUDE.md` diga otra cosa, pero anotalo en "Decisiones para el CEO".
- No "mejores" el diseño por tu cuenta (otro orden, otros textos, otro color). Si creés que algo está mal, proponelo en "Decisiones para el CEO" y especificá igual lo que está diseñado.
