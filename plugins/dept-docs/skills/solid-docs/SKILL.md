---
name: solid-docs
description: Reglas para escribir y revisar documentación de un proyecto - para quién se escribe, verificar cada dato contra el código, ejemplos que se pueden copiar, cambios mínimos, README y guías, referencia, changelog, qué no documentar y qué no filtrar. Usar al escribir, actualizar o revisar documentación (README, guías, referencia de comandos y configuración, changelog).
---

# Documentación sólida

Una buena documentación es verdad, se puede seguir sin conocer el proyecto y no envejece sola. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Para quién y para qué

- Antes de escribir, decidí quién lo lee (quien instala, quien usa, quien contribuye, quien opera) y qué quiere lograr. Un documento por propósito: una guía de pasos no es una referencia ni una explicación.
- Cuatro tipos, sin mezclarlos: **tutorial** (aprender haciendo, un camino feliz), **guía** (cómo lograr algo concreto), **referencia** (todas las opciones, seca y exacta) y **explicación** (por qué es así).
- Lo primero que se lee dice qué es y para qué sirve, en dos líneas. Lo que casi todos necesitan va arriba.

## 2. Verdad antes que estilo

- **Cada dato sale del código**, no de la memoria ni de otro documento: nombres de comandos y opciones, rutas, variables de entorno, valores por defecto, endpoints, requisitos de versión. Abrí el archivo y verificalo.
- Si el código y otro documento (o el reporte de otro departamento) dicen distinto, el código manda y se avisa.
- Lo que no podés verificar no se escribe como un hecho: se anota como duda.
- No documentes lo que el código todavía no hace ni lo que "va a hacer": solo lo que hace hoy.

## 3. Se puede seguir

- Los pasos van numerados, en orden, con los requisitos previos al principio y qué se debería ver al terminar cada paso importante.
- Los comandos van en bloques de código, completos y copiables, con lo mínimo que cambia el usuario marcado (`<tu-token>`).
- Un ejemplo vale más que un párrafo. Un ejemplo se prueba: tiene que funcionar tal cual está escrito.
- Qué hacer si falla: los dos o tres errores más comunes y su salida.

## 4. Cambios mínimos

- Un cambio de código toca solo los párrafos que cambiaron. No reescribas ni reordenes documentos que no te pidieron.
- Si un cambio deja viejo un documento, se corrige en el mismo cambio. Buscalo con Grep por el nombre que cambió (comando, opción, variable, ruta).
- Un solo lugar para cada dato: si algo ya está en otro documento, enlazalo en vez de copiarlo. Lo copiado envejece distinto.

## 5. Cada documento en su lugar

- **README:** corto. Qué es, instalación, un ejemplo de uso y enlaces a lo demás. No es el manual.
- **Guías y referencia:** en la carpeta de documentos del proyecto, una por tema, con un índice si hay varias.
- **Changelog:** una entrada por cambio visible para quien usa el proyecto, con el formato y el orden de versiones que ya use (por ejemplo, Keep a Changelog y versionado semántico). Qué cambió y qué tiene que hacer quien actualiza, no el detalle de la implementación.
- **No son tuyos:** los diseños de `docs/design/` (arquitectos y designer), las notas de `docs/decisions/` (el PM con `office:decisions`) y las colecciones de la API (backend).

## 6. Qué no se escribe

- Secretos, claves, tokens, contraseñas, datos de personas reales, direcciones internas o de entornos reales. En los ejemplos, valores de mentira evidentes (`PROJ-123`, `example.com`, `tu-token-aca`).
- Lo que se explica solo leyendo el código ("esta función suma dos números").
- Capturas de pantalla de algo que cambia seguido: se desactualizan. Mejor describí el paso.

## 7. Idioma y voz

- El idioma y el tono que diga el `CLAUDE.md` del proyecto. Un solo tono en todo el documento.
- Oraciones cortas, el verbo adelante ("Corré `npm test`"), los mismos nombres para las mismas cosas en todos los documentos.
- Los nombres de código (comandos, archivos, variables) se dejan tal cual, en formato de código.

## 8. Checklist antes de dar la documentación por terminada

- [ ] Cada nombre, opción, ruta, variable y valor por defecto está verificado contra el código.
- [ ] Los comandos y ejemplos funcionan tal cual están escritos (o están marcados como no ejecutados).
- [ ] Los enlaces, anclas y rutas existen.
- [ ] Los pasos están completos y en orden: se puede llegar al final sin conocer el proyecto.
- [ ] No hay secretos ni datos reales.
- [ ] Lo que el cambio dejó viejo en otros documentos está corregido.
- [ ] El changelog tiene su entrada, con el formato del proyecto.
