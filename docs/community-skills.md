# Skills de la comunidad

Las skills de cada departamento de dev-office (`solid-backend`, `solid-frontend`, `solid-database`, `responsible-scraping`) definen **cómo trabaja la oficina**: qué se puede hacer, qué necesita aprobación y qué se prueba. Para el detalle técnico de cada tecnología, los agentes pueden usar además las skills oficiales que publican los creadores de esa tecnología.

## Por qué no vienen incluidas

- **Se actualizan solas.** Las mantienen Supabase, MongoDB, Vercel y Expo. Instaladas aparte, cada proyecto recibe sus mejoras sin esperar una versión de dev-office.
- **Cada proyecto instala solo lo que usa.** Un proyecto con Postgres no necesita las skills de MongoDB.
- **Licencias.** Copiarlas obligaría a mantener sus avisos de licencia (por ejemplo, Apache 2.0 en las de MongoDB).

## Cuáles recomendamos

Solo skills de los creadores oficiales de cada tecnología, con mantenimiento activo. Hay muchos sitios que republican copias: instalá siempre desde el repositorio original.

| Stack | Skills | Autor y licencia | Departamentos que las usan |
| --- | --- | --- | --- |
| Postgres | `supabase-postgres-best-practices` | [Supabase](https://github.com/supabase/agent-skills), MIT | base de datos, backend |
| MongoDB | `mongodb-schema-design`, `mongodb-query-optimizer` y otras | [MongoDB](https://github.com/mongodb/agent-skills), Apache 2.0 | base de datos, backend |
| React y Next.js | `vercel-react-best-practices`, `vercel-composition-patterns` | [Vercel](https://github.com/vercel-labs/agent-skills), MIT | frontend |
| React Native | `vercel-react-native-skills` | [Vercel](https://github.com/vercel-labs/agent-skills), MIT | frontend |
| Expo | `expo-router`, `expo-data-fetching` y otras | [Expo](https://github.com/expo/skills), MIT | frontend |

La skill de Postgres es de Supabase, pero sirve para cualquier Postgres: no hace falta usar Supabase.

## Cómo instalarlas

La skill `office-setup` mira las dependencias del proyecto y te recomienda las que correspondan. También podés instalarlas a mano, desde la carpeta del proyecto:

```bash
# Postgres
claude plugin marketplace add supabase/agent-skills
claude plugin install postgres-best-practices@supabase-agent-skills --scope project

# MongoDB
claude plugin marketplace add mongodb/agent-skills
claude plugin install mongodb@mongodb-plugins --scope project

# React, Next.js y React Native (instalador interactivo: elegí las que uses)
npx skills add vercel-labs/agent-skills

# Expo
claude plugin marketplace add expo/skills
claude plugin install expo@expo-plugins --scope project
```

Con `--scope project` quedan registradas en `.claude/settings.json`, así que cualquiera que trabaje en el proyecto sabe cuáles usa.

## Cuidado con el servidor MCP de MongoDB

El plugin `mongodb` trae, además de las skills, un servidor MCP que se conecta a una base de datos con la variable `MDB_MCP_CONNECTION_STRING`. Si no la configurás, las skills funcionan igual y el servidor no se conecta a nada.

Si la configurás:

- Usá solo una base local o de pruebas, **nunca producción**.
- Activá el modo de solo lectura con `MDB_MCP_READ_ONLY=true`.

## Quién manda si chocan

Las reglas de dev-office mandan en seguridad, aprobaciones y límites. Si una skill externa sugiere conectarse a una base real, usar un servidor MCP contra producción, instalar dependencias o desplegar, los agentes no lo hacen: toman solo su conocimiento técnico. Así está escrito en la sección "Skills de la comunidad" de cada skill de departamento.

## Proponer una skill nueva

Antes de sumar una skill a esta lista, verificá que:

1. La publique el creador oficial de la tecnología o una organización reconocida.
2. Tenga una licencia abierta y mantenimiento reciente.
3. No ejecute nada por su cuenta contra servicios reales, o que se pueda desactivar.
4. Aporte detalle técnico que no esté ya en las skills de dev-office.
