---
name: ui-checks
description: Pruebas visuales de regresión y de accesibilidad para interfaces web y móviles - comparar capturas contra una referencia aprobada para detectar cambios de diseño no pedidos, y correr una herramienta de accesibilidad (axe y similares) más lo que ninguna herramienta cubre (teclado, foco, tamaño de toque, lector de pantalla). Usar cuando el tester de frontend prueba un cambio que se ve, o cuando el CEO pide revisar la accesibilidad o los cambios visuales.
---

# Pruebas visuales y de accesibilidad

Dos revisiones que casi no gastan tokens, porque las hace una herramienta del proyecto y el modelo solo lee lo que falla. Si el `CLAUDE.md` del proyecto dice otra cosa, manda el proyecto.

**Regla común:** usá las herramientas que el proyecto ya tiene. No agregues dependencias ni configuraciones nuevas por tu cuenta: si faltan, terminá tu reporte con "Necesito aprobación" y proponé la más simple para el stack (ver más abajo). Todo contra un entorno de prueba, con datos simulados, nunca producción.

## 1. Regresión visual

Compara una captura de la pantalla contra una **referencia aprobada**. Detecta lo que los tests por rol y por texto no ven: un margen roto, un color cambiado, un componente que se desplazó.

**Qué herramienta:** la que el proyecto ya use. Por ejemplo, `toHaveScreenshot` de Playwright, el test-runner de Storybook, Chromatic o Percy, `jest-image-snapshot`. Sin ninguna, la opción más liviana en web es `toHaveScreenshot` si ya hay Playwright; en móvil, la que ofrezca su herramienta de e2e (Detox, Maestro). Proponela, no la instales.

**Cómo se arma para que no dé falsos positivos:**

- Tamaño de pantalla (viewport o dispositivo) fijo y declarado en el test. Si el cambio es responsive, un tamaño de teléfono y uno de escritorio.
- Datos simulados y fijos; reloj congelado; animaciones apagadas; esperar a que carguen fuentes e imágenes.
- Las referencias se generan en el mismo sistema donde corren los tests (el render cambia entre macOS, Linux y Windows). Si el proyecto las corre en CI de Linux, las referencias de Linux son las que valen: preguntale al PM antes de generarlas en otro lado.
- Un test visual no es la única verificación de una pantalla: los estados y los textos se prueban igual.

**Cuando algo cambia:**

1. **No actualices la referencia vos.** Una diferencia es un hallazgo hasta que el CEO diga que fue a propósito.
2. Reportá **FALLA** con la lista de pantallas que difieren y la ruta de la imagen de la diferencia. Mirá con Read solo las que fallan, no todas.
3. Si el cambio era lo pedido (un rediseño, un color nuevo), el PM se lo confirma al CEO y recién entonces se actualizan **solo las referencias de esas pantallas**, en un cambio aparte y fácil de revisar.
4. Si la diferencia no tiene que ver con lo pedido, es un bug del developer: va de vuelta con la imagen.

Las referencias son archivos del proyecto: se commitean con el código, y las aprueba el CEO como cualquier otro cambio.

## 2. Accesibilidad

**La parte automática.** La herramienta del proyecto, o la más simple para su stack:

- **Web:** `@axe-core/playwright` (con Playwright), `jest-axe` o `vitest-axe` (en tests de componentes) y `eslint-plugin-jsx-a11y` en el lint.
- **React Native:** `eslint-plugin-react-native-a11y` y, en los tests, buscar por rol y por etiqueta con React Native Testing Library (si algo no se encuentra así, un lector de pantalla tampoco lo va a encontrar).

Corré la herramienta sobre cada pantalla y cada estado importante (cargando, vacío, error, modal abierto). Qué cuenta:

- **Crítico o serio:** **FALLA**, con el elemento, la regla y cómo se corrige.
- **Moderado o menor:** se reporta como no bloqueante.
- Nunca silencies una regla para que pase. Si hay una excepción justificada, que quede escrita al lado, con el motivo.

**Lo que ninguna herramienta cubre** (las automáticas encuentran una parte de los problemas: no digas "es accesible", decí "no tiene fallas detectables"). Revisalo leyendo el código y con los tests de interacción:

- **Teclado (web):** se llega a todo con Tab, en un orden lógico; el foco se ve; un modal atrapa el foco y lo devuelve al cerrar; Escape cierra lo que tiene que cerrar.
- **Etiquetas:** cada campo tiene su etiqueta; cada imagen con significado, su texto alternativo (y las decorativas, vacío); cada botón de solo ícono, un nombre.
- **Errores:** el mensaje se asocia al campo y se anuncia, no solo cambia de color.
- **Color:** el estado nunca se comunica solo con color; el contraste de texto sobre imágenes o degradados se mira a ojo.
- **Móvil:** áreas de toque de al menos 44 pt (iOS) o 48 dp (Android); el texto crece con el tamaño de letra del sistema sin cortarse; cada control tiene `accessibilityLabel` y `accessibilityRole`.
- **Movimiento:** las animaciones respetan "reducir movimiento".

Lo que no se puede probar sin una persona (cómo suena con VoiceOver o TalkBack, cómo se siente en un teléfono real) va en "Casos no cubiertos" del reporte, para que el CEO lo revise a ojo.

## En el reporte

Sumá al reporte del tester, cuando el cambio se ve:

- **Visual:** cuántas pantallas se compararon y cuáles difieren (con la ruta de la diferencia), o "sin referencias en el proyecto".
- **Accesibilidad:** fallas críticas y serias (bloquean), el resto (no bloquean) y lo que quedó sin cubrir.
