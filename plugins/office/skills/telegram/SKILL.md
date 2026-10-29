---
name: telegram
description: Configura la oficina remota por Telegram de dev-office - el último mensaje del PM le llega al CEO por un bot de Telegram, que responde desde el celular y la oficina sigue trabajando, y los permisos se aprueban con botones - mientras la sesión de Claude Code queda abierta en su computadora. Instala en el proyecto el script office-telegram.sh (y office-telegram.cmd para Windows), guarda el bot (token y chat id) y enciende o apaga el modo remoto. Usar cuando el CEO quiere manejar la oficina desde Telegram, conectar o cambiar el bot, o encender o apagar el modo remoto.
argument-hint: "[on | off | status | setup <token> [chat_id]]"
---

Vas a configurar la oficina remota por Telegram. Hablale al CEO en su idioma (si escribe en español, con voseo). La guía completa está en `docs/telegram.md` del repositorio de dev-office (https://github.com/miguelramidev/dev-office/blob/main/docs/telegram.md).

Los archivos `office-telegram.sh` y `office-telegram.cmd` están en la misma carpeta que este archivo. Usá siempre el script: no edites a mano los archivos que guarda.

## Cómo funciona

- **Ida:** al terminar cada respuesta, tu último mensaje (el que explica lo que se hizo y lo que sugerís) le llega al CEO por Telegram. Los mensajes de los departamentos no se mandan.
- **Vuelta:** lo que el CEO le escribe al bot despierta la sesión, aunque esté quieta, y te llega como un aviso que empieza con `[Telegram · CEO]`.
- **Permisos:** cuando un agente pide permiso, al CEO le llega el pedido con los botones Permitir y Rechazar. Si no responde en 10 minutos, el pedido pasa a la terminal como siempre.
- **Comandos en el chat:** `/estado` (en qué está la oficina) y `/ayuda`.
- **El bot:** el token y el chat id se guardan en `~/.claude/office-telegram/config.json`, solo para el usuario y fuera de todo repo. El modo remoto se enciende por proyecto, en `.office/telegram/`.
- **Requisitos:** la sesión de Claude Code abierta en la computadora (que no se suspenda), `jq` y `curl`. Funciona en Linux, macOS, WSL y Windows (con el bash de Git for Windows).

## Pasos

1. **Instalá o actualizá el script en el proyecto.** Fijate si existe `.claude/office-telegram.sh` y qué versión tiene (la línea `# office-telegram-version:` del principio). Si no existe o es más vieja que la de esta skill, copiá los dos archivos a `.claude/`:

   ```bash
   cp <carpeta de esta skill>/office-telegram.sh .claude/office-telegram.sh
   cp <carpeta de esta skill>/office-telegram.cmd .claude/office-telegram.cmd
   ```

   Desde la terminal del proyecto se corre con `bash .claude/office-telegram.sh` (macOS, Linux y Git Bash) o `.claude\office-telegram.cmd` (CMD o PowerShell en Windows).

2. **Mirá cómo está:** `bash .claude/office-telegram.sh status`.

3. **Si el bot no está configurado,** guialo:
   1. En Telegram, abrir **@BotFather**, mandar `/newbot` y elegir un nombre y un usuario que termine en `bot`. BotFather le da un token.
   2. Abrir el bot nuevo, tocar **Iniciar** y mandarle cualquier mensaje.
   3. Guardar el bot. Si te pasó el token (con `$ARGUMENTS` o en el chat), corré `bash .claude/office-telegram.sh setup <token>`: espera hasta 2 minutos el mensaje del paso anterior y toma el chat id de ahí. Si ya sabe su chat id: `setup <token> <chat_id>`. Si prefiere no pegar el token en el chat, que corra ese comando con `!` delante.

   Contale que el token es como una contraseña: quien lo tenga puede leer y escribir como el bot. Si se filtra, en @BotFather lo cambia con `/revoke` y vuelve a correr `setup`.

4. **Encendé o apagá el modo remoto** según lo que pida (`$ARGUMENTS` puede traer `on` u `off`):

   ```bash
   bash .claude/office-telegram.sh on
   bash .claude/office-telegram.sh off
   ```

   Antes de encender, contale:
   - **La sesión tiene que quedar abierta** y la computadora sin suspenderse. Si Claude Code se cierra, no hay quien atienda los mensajes; los que mande en ese rato llegan cuando vuelva a abrir la sesión con el modo remoto encendido.
   - **Quien escriba desde ese chat maneja la oficina**, permisos incluidos. Solo se acepta su chat: que no comparta el bot.
   - **Los permisos esperan 10 minutos su respuesta** por Telegram antes de pasar a la terminal. Cuando vuelva a la computadora, conviene apagar el modo remoto para que no esperen.
   - **Los comandos de los pedidos de permiso viajan por Telegram.** La protección de la oficina sigue bloqueando los secretos, pero si un comando lleva un dato sensible, se ve en el chat.
   - **Un bot atiende un proyecto por vez.** Si el modo remoto está encendido en dos proyectos con el mismo bot, lo atiende el primero; el otro lo toma cuando ese se apague.

   La sesión empieza a escuchar al terminar esta respuesta: no hace falta reiniciar. Con `on`, le llega al chat un aviso de que el modo remoto quedó encendido.

5. **Probá:** `bash .claude/office-telegram.sh test` manda un mensaje de prueba. Proponele que le escriba al bot una pregunta corta para ver la vuelta.

6. **Cerrá:** mostrale `status` otra vez. Recordale que lo apaga con `office-telegram off` (o pidiéndotelo) y que `/estado` en el chat le dice en qué está la oficina.
