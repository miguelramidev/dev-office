---
name: office-setup
description: Prepara un proyecto para trabajar con la oficina dev-office - permisos base, modo de permisos, zona horaria del registro de actividad, .gitignore y recomendación de skills de la comunidad según el stack. Usar una vez al instalar la oficina en un proyecto, o para volver a aplicar la configuración base.
disable-model-invocation: true
---

Vas a preparar este proyecto para trabajar con la oficina dev-office. Hablale al CEO en su idioma (si escribe en español, con voseo).

Los cambios los hace el script `setup.sh` que está en la misma carpeta que este archivo. No edites `.claude/settings.json` ni `.gitignore` a mano.

## Pasos

1. **Explicá qué va a pasar**, en pocas líneas:
   - Se agregan a `.claude/settings.json` permisos base: comandos de git de solo lectura permitidos; commit, push, instalar paquetes y AWS siempre con consulta; leer secretos, forzar push y saltear hooks prohibidos.
   - Se define el modo de permisos.
   - Se agregan a `.gitignore` la carpeta temporal de QA, el registro de actividad y la copia de seguridad.
   - No se borra nada de lo que ya existe, y se guarda una copia del archivo anterior.

2. **Revisá `CLAUDE.md`.** Si el proyecto no lo tiene, avisale al CEO que los agentes lo necesitan para conocer las reglas del proyecto, y preguntale si querés seguir igual.

3. **Comandos de verificación.** Buscá en `CLAUDE.md` y en los archivos del proyecto (por ejemplo `package.json`, `Makefile`, `pyproject.toml`) los comandos de tests, typecheck y lint. Proponé una regla `allow` para cada uno, con su variante con argumentos (por ejemplo `Bash(pnpm test)` y `Bash(pnpm test *)`), para que los testers trabajen sin pedir permiso. Mostrale la lista al CEO y esperá su confirmación. Nunca pongas `*` antes del subcomando (por ejemplo, `Bash(pnpm --filter * test)`): aprobaría cualquier opción en esa posición. Usá el nombre exacto del paquete y el `*` solo al final.

4. **Preguntá al CEO:**
   - **Modo de permisos:** `acceptEdits` (recomendado: los agentes editan archivos sin preguntar; los comandos fuera de la lista se consultan), `auto` (un clasificador aprueba los comandos razonables; solo si su cuenta lo tiene disponible) o `default` (todo se consulta).
   - **Zona horaria** del registro de actividad (opcional, por ejemplo `America/Asuncion`). Si no responde, se usa la del sistema.

5. **Ejecutá el script una sola vez**, con las respuestas. Pasá cada regla extra con su propio `--allow`, entre comillas:

```bash
   bash <carpeta de esta skill>/setup.sh --mode acceptEdits --timezone America/Asuncion --allow "Bash(pnpm test)" --allow "Bash(pnpm test *)"
```

Si falla, mostrale el error al CEO tal cual y no intentes arreglar los archivos a mano.

6. **Mostrá el resultado:** corré `git diff .claude/settings.json .gitignore` y explicale los cambios en pocas líneas.

7. **Recomendá skills de la comunidad.** Mirá las dependencias del proyecto (`package.json` y los de cada aplicación si es un monorepo) y recomendá solo las que correspondan a su stack. No las instales vos: mostrale al CEO los comandos para que decida.

   | Si el proyecto usa | Recomendá | Comandos |
   | --- | --- | --- |
   | Postgres (`pg`, `postgres`, `prisma`, `drizzle-orm`, `knex`, `typeorm` con Postgres) | Skills de Postgres de Supabase | `claude plugin marketplace add supabase/agent-skills` y `claude plugin install postgres-best-practices@supabase-agent-skills --scope project` |
   | MongoDB (`mongodb`, `mongoose`) | Skills de MongoDB | `claude plugin marketplace add mongodb/agent-skills` y `claude plugin install mongodb@mongodb-plugins --scope project` |
   | React o Next.js (`react`, `next`) | Skills de Vercel | `npx skills add vercel-labs/agent-skills`, eligiendo `react-best-practices` y `composition-patterns` |
   | React Native (`react-native`) | Skills de Vercel | el mismo comando, eligiendo también `react-native-skills` |
   | Expo (`expo`) | Skills de Expo | `claude plugin marketplace add expo/skills` y `claude plugin install expo@expo-plugins --scope project` |

   Si recomendás el plugin de MongoDB, avisale que trae un servidor MCP que se conecta a la base con `MDB_MCP_CONNECTION_STRING`: si lo configura, que sea solo con una base local o de pruebas y con `MDB_MCP_READ_ONLY=true`, nunca con producción. Sin esa variable, las skills funcionan igual.

8. **Cerrá con los próximos pasos:**
   - Revisar los cambios y hacer commit de `.claude/settings.json` y `.gitignore`.
   - Instalar las skills de la comunidad que haya elegido.
   - Borrar `.claude/settings.json.bak` cuando esté conforme.
   - Reiniciar Claude Code para que tome la configuración nueva.
