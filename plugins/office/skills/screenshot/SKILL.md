---
name: screenshot
description: Saca una captura del resultado de un cambio visible - la pantalla de una web en el navegador o la de una app móvil en el emulador (iOS o Android) - y se la manda al CEO por Telegram cuando el modo remoto está encendido, para que vea cómo quedó aunque no esté frente a su computadora. Usar cuando un cambio tocó algo que se ve (pantallas, estilos, componentes, textos de la interfaz) y el modo remoto de Telegram está encendido, o cuando el CEO pide ver cómo quedó.
argument-hint: "[qué pantalla o flujo capturar]"
---

Vas a capturar cómo quedó un cambio visible y mandárselo al CEO. Hablale en su idioma (si escribe en español, con voseo).

## Cuándo

- **Sí:** el cambio se ve (pantalla nueva o modificada, estilos, componentes, estados vacíos o de error, textos de la interfaz) y el modo remoto está encendido (`bash .claude/office-telegram.sh status`), o el CEO pidió verlo.
- **No:** cambios que no se ven (backend, base de datos, scraping, DevOps, tests) o con el modo remoto apagado, salvo pedido del CEO. Con el modo remoto apagado `photo` no manda nada, así que no insistas.
- **Cuándo se saca:** con el cambio ya probado (tester en verde) y antes del informe final, para que la captura llegue junto al mensaje del PM.

## Qué no se hace

- No se capturan pantallas con datos reales ni secretos (sesiones de usuarios, tokens, correos, claves en la barra de direcciones). Si la pantalla los muestra, usá datos de prueba o recortá la captura.
- No se instala nada global ni se toca el proyecto para capturar. Si falta una herramienta (navegador, emulador, `adb`), avisale al PM qué falta y no improvises.
- Los comandos de arranque (servidor de desarrollo, URL, emulador, dispositivo, app) son del proyecto: leelos del `CLAUDE.md` y de `.claude/`. Si no están, preguntale al PM antes de adivinar.

## Dónde se guardan

En `.office/screenshots/`, que ya está fuera de git: `.office/screenshots/<ticket o tema>-<pantalla>.png`. El script solo manda imágenes de dentro del proyecto (png, jpg, gif o webp).

## Web

Con el servidor de desarrollo del proyecto andando (el PM o el developer lo levantan; si lo levantás vos, apagalo al terminar):

1. **Si hay un navegador conectado como herramienta** (por ejemplo, la skill `claude-in-chrome` o un MCP de Playwright), usalo: abrí la URL, esperá a que cargue y sacá la captura.
2. **Si no,** con Playwright, si el proyecto ya lo tiene:

   ```bash
   npx playwright screenshot --viewport-size=390,844 --wait-for-timeout=1500 <url> .office/screenshots/<nombre>.png
   ```

   Usá `--full-page` para toda la página. Para una vista de escritorio, `--viewport-size=1280,800`. Si el cambio es responsive y el CEO mira desde el celular, capturá las dos.
3. Para pantallas detrás de un login o con estado, usá los datos de prueba y los pasos que el proyecto documente (un script de e2e que ya exista, por ejemplo).

## Móvil

La app tiene que estar corriendo en el emulador o simulador, en la pantalla a mostrar (cómo se instala y se abre es del proyecto: Expo, React Native, Flutter, nativo...).

- **iOS (simulador, macOS):**

  ```bash
  xcrun simctl io booted screenshot .office/screenshots/<nombre>.png
  ```

  Con varios simuladores, `booted` toma el que está encendido; si hay más de uno, usá su UDID (`xcrun simctl list devices booted`).
- **Android (emulador o dispositivo por USB):**

  ```bash
  adb exec-out screencap -p > .office/screenshots/<nombre>.png
  ```

  Con más de un dispositivo, `adb -s <serial> exec-out screencap -p > ...` (`adb devices` los lista). Si el archivo queda vacío o corrupto, es que `adb` falló: revisá la salida antes de mandarlo.

Si no hay emulador encendido y el proyecto no dice cómo levantarlo, avisale al PM: él le pregunta al CEO.

## Mandar la captura

Mirá la imagen con Read antes de mandarla: que sea la pantalla correcta, que haya cargado y que no tenga datos sensibles. Después:

```bash
bash .claude/office-telegram.sh photo .office/screenshots/<nombre>.png "<qué se ve, en una línea>"
```

El texto dice qué pantalla es y qué cambió (por ejemplo, `PROJ-123 · Login con error de contraseña`). Una captura por pantalla o estado importante, no más de 4 por entrega. Si `photo` falla, informalo en el reporte; no es motivo para frenar el trabajo.

Si el script `.claude/office-telegram.sh` no existe, el CEO no configuró Telegram: avisale al PM y seguí sin mandar.

## Reporte

Devolvé al PM: qué pantallas capturaste (rutas), cómo las sacaste (web o móvil, qué dispositivo o tamaño), si se mandaron por Telegram y, si algo falló, qué.
