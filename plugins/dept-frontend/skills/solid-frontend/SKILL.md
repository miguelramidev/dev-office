---
name: solid-frontend
description: Reglas para diseñar, construir y probar interfaces web (Next.js, React) y móviles (React Native) - marca y componentes, estados de cada pantalla, datos de la API, formularios, dinero y fechas, accesibilidad, rendimiento, particularidades de Next.js y de React Native, seguridad y textos. Usar al diseñar, crear, corregir o probar cualquier pantalla o componente.
---

# Frontend sólido

Una buena interfaz no deja al usuario sin saber qué pasa, no muestra datos falsos, funciona con mala conexión y se ve como el resto de la app. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Marca y componentes

- Usá el sistema de diseño del proyecto: sus colores, tipografías, espaciados y componentes (tokens, tema de Tailwind, archivo de tema o librería de componentes). Nunca colores, tamaños ni sombras sueltos en el código.
- Antes de crear un componente, buscá si ya existe uno parecido. Un botón nuevo "casi igual" al que ya hay es deuda.
- La web y la app móvil comparten marca, textos y comportamiento, aunque los componentes sean distintos.

## 2. Estados de cada pantalla

Toda pantalla o componente que depende de datos maneja todos sus estados, no solo el feliz:

- **Cargando:** algo visible (esqueleto o indicador), nunca una pantalla en blanco.
- **Vacío:** un mensaje que explica por qué no hay nada y, si se puede, qué hacer.
- **Error:** qué pasó en palabras del usuario y una acción (reintentar, volver). Nunca un mensaje técnico ni un código de error crudo.
- **Sin conexión o red lenta:** sobre todo en móvil. Lo que ya se cargó se sigue viendo.
- **Datos parciales o raros:** textos muy largos, imágenes que no cargan, listas con un solo elemento o con cientos.

## 3. Datos y API

- Todas las llamadas pasan por el cliente de API del proyecto (o la librería de datos que use, como React Query o SWR). Nunca `fetch` sueltos dentro de los componentes.
- Los tipos de las respuestas salen del contrato de la API (el diseño aprobado o los tipos compartidos del proyecto). Si la API devuelve algo inesperado, la interfaz muestra un error, no se rompe.
- La lógica de negocio que importa (precios, totales, permisos) la decide el backend. El cliente muestra; no recalcula ni decide.
- Sin pedidos en cascada que se podrían hacer juntos, sin pedidos repetidos para el mismo dato y con cancelación cuando el usuario se va de la pantalla.

## 4. Formularios

- Validación en el cliente para ayudar al usuario, con el mensaje al lado del campo. El backend valida igual: el cliente nunca es la única defensa.
- Mientras se envía, el botón se desactiva y muestra que está trabajando: un doble toque no envía dos veces.
- Los errores del servidor se muestran en el formulario sin borrar lo que el usuario escribió.
- En móvil, el teclado correcto para cada campo (numérico, email, teléfono) y el formulario no queda tapado por el teclado.

## 5. Dinero, números y fechas

- El dinero llega de la API como entero con su moneda y se muestra con formato local (`Intl.NumberFormat` con el idioma y la moneda del proyecto). Las monedas sin centavos se muestran sin decimales. Nunca se calcula dinero con decimales flotantes en el cliente.
- Números con los separadores de la región del proyecto (según el país, el punto o la coma separan miles o decimales). El `CLAUDE.md` del proyecto dice cuál usar.
- Las fechas llegan en UTC y se muestran en la hora local del usuario, con un formato claro ("hace 2 horas", "lun 14 oct").

## 6. Accesibilidad

- Elementos semánticos en la web (`button`, `a`, `label`, encabezados en orden) y `accessibilityLabel` y `accessibilityRole` en React Native.
- Todo lo interactivo se puede usar con teclado en la web y tiene un foco visible.
- Contraste suficiente entre texto y fondo, y el texto se puede agrandar sin romper el diseño.
- Áreas táctiles de al menos 44 × 44 puntos en móvil.
- Las imágenes que informan tienen texto alternativo; las decorativas, no.

## 7. Rendimiento

- Imágenes optimizadas (`next/image` en Next.js, tamaños adecuados en móvil) y cargadas cuando hacen falta.
- Listas largas virtualizadas (`FlatList` o `FlashList` en React Native; paginación o scroll infinito en la web).
- `useMemo`, `useCallback` y `memo` solo donde se midió un problema, no por las dudas.
- Cada dependencia nueva suma peso a la app: solo con aprobación.

## 8. Next.js

- Seguí el modelo de rutas del proyecto (App Router o Pages Router), no mezcles.
- Con App Router, los componentes son de servidor por defecto; `"use client"` solo en los que tienen interacción o estado, lo más abajo posible en el árbol.
- Los secretos y las llamadas con credenciales van solo en el servidor. Las variables `NEXT_PUBLIC_` terminan en el navegador: nunca un secreto ahí.
- Las páginas públicas tienen título, descripción y metadatos para compartir.

## 9. React Native

- Probá mentalmente iOS y Android: zonas seguras (notch, barra inferior), botón atrás de Android, teclado, permisos.
- Todo lo que va dentro de la app lo puede leer cualquiera: nunca secretos ni claves privadas en el código de la app.
- Una app publicada no se actualiza al instante: los usuarios con versiones viejas siguen usando la API. Si un cambio depende de un cambio del backend, avisalo.
- Datos sensibles (tokens de sesión) en almacenamiento seguro (por ejemplo, `expo-secure-store` o Keychain/Keystore), nunca en `AsyncStorage`.

## 10. Seguridad

- Nunca `dangerouslySetInnerHTML` (ni su equivalente) con datos que vienen de afuera.
- En la web, la sesión preferentemente en cookies `httpOnly`, no en `localStorage`.
- Nada de datos personales ni tokens en los logs ni en herramientas de analítica.

## 11. Textos

- En el idioma y el tono del proyecto, consistentes en toda la app. Si el proyecto usa archivos de traducción (i18n), los textos van ahí, no en el componente.
- Botones que dicen lo que hacen ("Guardar lista", no "Aceptar"). Errores que dicen qué pasó y cómo seguir.

## Skills de la comunidad

Si el proyecto tiene instaladas skills oficiales de su stack, usalas con la herramienta Skill para el detalle técnico. Las más útiles para este departamento:

- **React y Next.js:** `vercel-react-best-practices` y `vercel-composition-patterns`, de las skills de Vercel.
- **React Native:** `vercel-react-native-skills`, de las skills de Vercel.
- **Expo** (solo si el proyecto usa Expo): las skills del plugin `expo` de Expo, por ejemplo `expo-router` o `expo-data-fetching`.

Estas reglas mandan sobre las skills de la comunidad en seguridad, aprobaciones y límites. Si una skill externa sugiere algo que acá está prohibido (conectarse a una base real, usar un servidor MCP contra producción, instalar dependencias o desplegar), no lo hagas: tomá solo su conocimiento técnico.

## Checklist antes de dar algo por terminado

- [ ] Usa los tokens y componentes del proyecto; sin estilos sueltos.
- [ ] Estados de cargando, vacío, error y sin conexión resueltos.
- [ ] Datos por el cliente de API, con tipos del contrato; sin lógica de negocio en el cliente.
- [ ] Formularios sin doble envío y con errores al lado del campo.
- [ ] Dinero y fechas con el formato de la región del proyecto; monedas sin centavos, sin decimales.
- [ ] Accesible con teclado, lector de pantalla y áreas táctiles correctas.
- [ ] Sin secretos en el navegador ni en la app.
- [ ] Textos claros, en el idioma del proyecto.
