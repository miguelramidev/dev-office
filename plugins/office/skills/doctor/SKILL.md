---
name: doctor
description: Diagnóstico de la oficina dev-office en el proyecto, al estilo de flutter doctor - revisa herramientas (git, jq, gh), plugins y versiones, la configuración del proyecto (modo local o compartido, PM por defecto, permisos de tests, archivos ignorados, scripts viejos), Codex y Gemini, Jira y lo opcional (Telegram, Figma, observer, mapa), y dice cómo arreglar cada cosa que falta. Se usa después de instalar o actualizar la oficina, o cuando algo de la oficina no anda.
---

Vas a revisar cómo está instalada la oficina en este proyecto y a ayudar al CEO a arreglar lo que falte. Hablale en su idioma (si escribe en español, con voseo).

## 1. Corré el diagnóstico

Corré el script que está en la misma carpeta que este archivo. No cambia nada y no llama a ningún modelo:

```bash
bash <carpeta de esta skill>/doctor.sh
```

Revisa, en este orden:

- **Herramientas:** Claude Code, git, jq (sin él no funcionan los hooks) y gh con sesión (para abrir PRs).
- **Plugins:** que `office` esté instalado y activo, qué departamentos hay, si alguno está en dos alcances o en `--scope project` con la oficina local, y si hay versiones más nuevas en el marketplace.
- **Configuración del proyecto:** `CLAUDE.md` o `.claude/rules/`, si se corrió `office-setup` (y en qué modo), el PM como agente por defecto, los comandos de tests, lint y typecheck permitidos, la regla de tests relacionados, que git ignore `.office/` y `.qa/`, archivos de la oficina que git sigue en el modo local y copias viejas de los scripts en `.claude/`.
- **Proveedores:** si algún rol usa Codex o Gemini, que el CLI esté instalado, con sesión y en una versión que sirve, y los permisos de Gemini.
- **Jira:** si `atlassian` está conectado, en qué alcance, con qué cuenta (etiqueta o token), si quedó uno con alcance user o con otro nombre, y si las reglas dicen el sitio.
- **Opcional:** Telegram, Figma (si está el departamento de frontend), el observer y el mapa del proyecto.

Las marcas son: `[✓]` listo, `[!]` aviso (funciona, pero conviene arreglarlo), `[✗]` falta (algo de la oficina no va a funcionar) y `[-]` opcional, sin configurar.

## 2. Mostrale el resultado

Mostrale al CEO la salida tal cual, en un bloque de código. Debajo, en pocas líneas, lo que hay que hacer, empezando por lo que falta (`✗`) y después los avisos (`!`). Lo opcional (`-`) se menciona en una línea, sin insistir.

## 3. Ofrecé arreglarlo

Para cada cosa, la flecha (`→`) dice cómo se arregla. Separá lo que podés hacer vos de lo que hace él:

- **Lo hacés vos, si te dice que sí:**
  - correr `/office:office-setup` (configuración, PM por defecto, archivos ignorados, comandos de verificación, "Comandos rápidos");
  - activar los permisos de Gemini (`office-agents.sh gemini-permissions on`);
  - agregar una línea a las reglas del proyecto (por ejemplo `Sitio de Jira: ...`, preguntándole el sitio), en `.claude/rules/office-project.md` si la oficina es local;
  - `git rm --cached` de los archivos de la oficina que git sigue, mostrándole antes la lista;
  - borrar las copias `.bak`.
- **Los corre él, en su terminal** (dale los comandos listos para copiar; en Windows, PowerShell o Git Bash según el comando): instalar herramientas (jq, gh, Codex, Antigravity), `gh auth login`, `codex login`, `claude plugin install|uninstall|enable`, `claude mcp add|remove`, el login de `/mcp` y `/office:update`. Los comandos de configuración, con `--scope local`, salvo que la oficina sea compartida.

No cambies nada sin preguntarle. Cuando termine, corré el diagnóstico de nuevo y mostrale cómo quedó. Si instaló o actualizó plugins, o cambió un servidor MCP, recordale reiniciar Claude Code (o `/reload-plugins`) antes de volver a correrlo.

## Desde la terminal

El CEO también lo puede correr sin Claude Code: el instalador (`dev-office.sh`, en la raíz del repositorio de dev-office) tiene la opción **Diagnóstico**. O directo, desde la carpeta del proyecto (en Windows, con Git Bash):

```bash
bash "$(find ~/.claude/plugins/cache -path '*office*/skills/doctor/doctor.sh' | sort | tail -n1)"
```
