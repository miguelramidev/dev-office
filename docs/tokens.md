# Gastar menos tokens

Lo que más gasta en la oficina no es lo que escriben los agentes, sino lo que leen. Cada agente que arranca vuelve a cargar las instrucciones de Claude Code, las de su rol, el `CLAUDE.md` del proyecto, las skills de los plugins instalados y el código que necesita. Cada comando que corre suma su salida a lo que carga en los pasos siguientes. Por eso, lo que más ahorra es que arranquen menos agentes, que lean menos y que los comandos devuelvan poco.

Para ver en qué se fueron los tokens, usá `/office:usage`. Para que la oficina revise tu proyecto y te proponga qué cambiar, usá `/office:save-tokens`.

## Lo que ya hace la oficina

- **Retoma a los mismos agentes** durante la tarea, en vez de lanzar uno nuevo en cada corrección.
- **Los retoques chicos** (un texto, un color) los hace un agente nuevo que lee un solo archivo.
- **El PM pregunta todo junto, antes de ejecutar,** y después no vuelve a consultar salvo que sea imprescindible. Una decisión que cambia a mitad de tarea obliga a rehacer trabajo del developer, del tester y de QA.
- **Sin diseño cuando no hace falta,** ni siquiera para una pantalla o un endpoint nuevo que siguen un patrón que ya existe: el PM le nombra al developer el archivo que tiene que usar de modelo.
- **Tests acotados:**
  - el developer corre solo los tests relacionados con su cambio;
  - el tester corre los relacionados y, al final, la suite completa una vez;
  - QA no vuelve a correr la suite.

  Todos usan la salida corta del runner, si la tiene.
- **El informe del developer** dice qué cambió en cada archivo, así el tester y QA van directo, sin explorar el código.

- **Mapa e índice del proyecto** (skill `office:project-map`): un mapa corto en `docs/project-map.md` dice qué hay en cada carpeta y qué archivo copiar de modelo; un índice en `.office/index/files.tsv`, que arma un script sin gastar tokens y que está siempre activo (se crea y se actualiza solo al empezar cada sesión), dice en qué archivo está cada función, clase o tipo. El PM arma los encargos con las rutas exactas y los agentes no exploran. Es lo que frena que el consumo crezca con el proyecto.

- **Qué depende de cada cambio:** el PM le pasa al tester y a QA la salida de `project-index.sh --impact`, que dice sin gastar tokens qué archivos dependen de lo que cambió y qué tests lo cubren. No exploran el código para averiguarlo.

## Lo que hacés vos

0. **El mapa del proyecto** lo crea el PM en la primera tarea, sin que hagas nada. Si lo querés antes, `/office:project-map`. Sirve igual si el proyecto recién empieza o si ya es grande: nunca se lee entero.
1. **Poné en el `CLAUDE.md` un comando para correr los tests relacionados, con salida corta.** Es lo que más rinde. Si no está, la oficina usa la opción del runner que conozca, pero no siempre la hay. Por ejemplo:

   ```markdown
   - Tests de lo que cambiaste: pnpm vitest related <archivos> --run --reporter=dot
   - Suite completa: pnpm test --reporter=dot
   - Lint de lo que cambiaste: pnpm eslint <archivos>
   ```

2. **Un `CLAUDE.md` corto:** las reglas, los comandos y las convenciones. Las explicaciones y la historia, a `docs/`, donde los agentes las leen solo si les hacen falta. El `CLAUDE.md` y lo que importa con `@` se cargan en cada agente, cada vez.
3. **Solo los departamentos que usás.** Las skills de cada uno se suman al contexto de todos los agentes.
4. **Juntá los ajustes en un mensaje.** Cada mensaje suelto es una vuelta más.
5. **Contestá las preguntas del PM antes de que arranque.** Si una decisión cambia después, el trabajo se rehace.
6. **Menos QA en las tareas normales:** con uno o dos alcanza para la mayoría.

   ```bash
   bash .claude/office-agents.sh set qa claude codex --local
   ```

7. **El developer en Codex:** baja lo que gasta en Claude a lo que gasta el puente, unos 20k por encargo. El tester y QA, en Claude, atrapan lo que se le escape.

   ```bash
   bash .claude/office-agents.sh set frontend.developer codex --local
   ```

8. **Un tope por sesión,** para que no se te vaya sin darte cuenta:

   ```bash
   bash .claude/office-agents.sh budget 2M --local
   ```

En Windows, los mismos comandos con `.claude\office-agents.cmd`.
