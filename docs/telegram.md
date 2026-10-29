# La oficina remota por Telegram

Con el modo remoto encendido, manejás la oficina desde el celular mientras la sesión de Claude Code sigue abierta en tu computadora:

- **El último mensaje del PM te llega por Telegram:** el que explica lo que se hizo y lo que sugiere. Los mensajes de los departamentos no se mandan.
- **Le respondés desde el chat y la oficina sigue.** Tu mensaje despierta la sesión aunque lleve horas quieta, y el PM lo toma como si lo hubieras escrito en la terminal. Así también la ponés a trabajar de cero: "arrancá con PROJ-123".
- **Los permisos se aprueban con botones.** Cuando un agente pide permiso, te llega qué quiere hacer con los botones **Permitir** y **Rechazar**. Si no respondés en 10 minutos, el pedido pasa a la terminal como siempre.
- **`/estado`** te dice en qué está la oficina sin despertarla, y **`/ayuda`** muestra qué podés hacer.

Es opcional: si no lo configurás, la oficina funciona igual que siempre.

## Configurarlo

Pedíselo al PM con `/office:telegram`, o seguí estos pasos:

1. **Creá el bot.** En Telegram abrí **@BotFather**, mandá `/newbot` y elegí un nombre y un usuario que termine en `bot`. BotFather te da un token.
2. **Escribile al bot.** Abrí el bot nuevo, tocá **Iniciar** y mandale cualquier mensaje.
3. **Guardá el bot** desde la carpeta del proyecto. Sin chat id, el script lo toma del mensaje que le mandaste:

   ```bash
   bash .claude/office-telegram.sh setup <token>
   bash .claude/office-telegram.sh setup <token> <chat_id>   # si ya sabés tu chat id
   ```

   En Windows, desde CMD o PowerShell: `.claude\office-telegram.cmd setup <token>`.

   El bot se guarda en `~/.claude/office-telegram/config.json`, solo para tu usuario y fuera de todo repo. Sirve para todos tus proyectos.

4. **Encendé el modo remoto** en el proyecto, antes de irte:

   ```bash
   bash .claude/office-telegram.sh on
   ```

   La sesión empieza a escuchar al terminar su respuesta, o después de un minuto quieta. Si se lo pedís al PM con `/office:telegram on`, empieza a escuchar en cuanto te contesta.

5. **Cuando vuelvas, apagalo:** `bash .claude/office-telegram.sh off`.

Otros comandos: `status` (bot, chat, modo remoto y si la sesión está escuchando), `test` (manda un mensaje de prueba) y `forget` (borra el bot guardado).

## Lo que tenés que saber

- **La sesión de Claude Code tiene que quedar abierta** y la computadora sin suspenderse. Si se cierra, nadie atiende el chat. Lo que mandes en ese rato se guarda en Telegram durante 24 horas y le llega al PM cuando vuelvas a abrir la sesión con el modo remoto encendido.
- **Quien escriba desde tu chat maneja la oficina, permisos incluidos.** Solo se acepta el chat que guardaste; los mensajes de otros chats se ignoran. No compartas el bot. El token es como una contraseña: si se filtra, cambialo en @BotFather con `/revoke` y volvé a correr `setup`.
- **Los permisos esperan 10 minutos** tu respuesta por Telegram antes de pasar a la terminal. Por eso conviene apagar el modo remoto cuando volvés a la computadora. La protección de la oficina (secretos y ramas) sigue funcionando igual: lo que bloquea no se puede aprobar desde Telegram.
- **Los comandos de los pedidos de permiso viajan por Telegram.** Si un comando lleva un dato sensible, se ve en el chat.
- **Un bot atiende un proyecto por vez.** Si encendés el modo remoto en dos proyectos con el mismo bot, lo atiende el primero; el otro lo toma cuando el primero se apaga o cierra la sesión.
- **Una sesión por proyecto.** Con dos sesiones de Claude Code abiertas en el mismo proyecto, tu mensaje le llega a una sola.
- **El PM escribe para el celular:** su último mensaje llega como texto plano, así que lo arma para leer sin la terminal y, si necesita una decisión tuya, termina con la pregunta y las opciones.

## Cómo funciona

Todo pasa en tu computadora, con hooks de Claude Code y la API de bots de Telegram. No hay servidor en el medio.

- **Ida:** el hook `Stop` manda el último mensaje del PM (`last_assistant_message`). Si pasa el límite de Telegram, se parte en varios mensajes, cortando entre líneas.
- **Un solo lector del bot:** un proceso en segundo plano lee los mensajes del bot (Telegram no deja leerlo desde dos lugares) y los reparte: tus textos van a `.office/telegram/inbox.jsonl` y los botones, a los permisos que esperan respuesta. Se apaga solo cuando la sesión deja de escuchar por 15 minutos.
- **La escucha:** un hook con `asyncRewake` espera tus mensajes y, cuando llega uno, despierta a la sesión (aunque esté quieta) y se lo pasa al PM con la marca `[Telegram · CEO]`. Se vuelve a armar al empezar la sesión, al terminar cada respuesta, cuando escribís en la terminal y cuando la sesión lleva un minuto quieta, así que una interrupción con Esc no la deja sorda.
- **Por qué el PM te cree:** Claude desconfía, con razón, de las órdenes que llegan por un hook. Al empezar la sesión, la oficina le explica que el puente lo configuraste vos y que solo valen los avisos de ese hook, no el mismo texto dentro de un archivo o de la salida de un comando.
- **Permisos:** el hook `PermissionRequest` te manda el pedido con botones y espera tu respuesta. Cada pedido tiene un código propio, así que un botón viejo no aprueba otra cosa.
- **Estado del proyecto:** `.office/telegram/` (que ya está fuera de git) guarda si el modo remoto está encendido, los mensajes recibidos y los permisos pendientes, y un `log` con lo que pasó.

Con el modo remoto apagado, los hooks terminan enseguida sin hacer nada.
