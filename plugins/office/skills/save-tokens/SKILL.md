---
name: save-tokens
description: Revisión de consumo de la oficina dev-office - busca en el proyecto y en la configuración lo que más tokens hace gastar a cada agente (un CLAUDE.md largo, sin comando para tests relacionados ni salida corta, departamentos que no se usan, QA o asesores de más, modo equipos) y propone qué cambiar. Se usa cuando el CEO quiere gastar menos tokens o pregunta por qué una tarea gastó tanto.
---

Vas a revisar qué hace gastar tokens en este proyecto y a proponer cambios concretos. Hablale al CEO en su idioma (si escribe en español, con voseo).

## 1. Corré la revisión

Corré el script que está en la misma carpeta que este archivo. No llama a ningún modelo:

```bash
bash <carpeta de esta skill>/token-check.sh
```

Revisa:

- **El `CLAUDE.md`** y lo que importa con `@`: cuánto pesa, que se carga en cada agente cada vez que arranca, si tiene un comando para correr solo los tests relacionados y si usa una salida corta del runner.
- **Los departamentos instalados:** las skills de cada uno se suman al contexto de todos los agentes.
- **La configuración de la oficina:** cuántos QA, asesores del PM y el modo equipos.
- **Lo que más gastó en la sesión,** si el observer tiene registro.

## 2. Proponé los cambios

Mostrale al CEO lo que encontró y, por cada punto marcado, el cambio concreto, en orden de impacto:

1. **Comando de tests relacionados y salida corta en el `CLAUDE.md`.** Fijate en el `package.json` (o el archivo del stack) qué runner usa el proyecto y armá el comando real, por ejemplo `pnpm vitest related <archivos> --run --reporter=dot`, `npx jest --findRelatedTests <archivos> --silent` o `pytest <archivos> -q`. Hacé lo mismo con el lint, si se puede correr sobre los archivos cambiados.
2. **Un `CLAUDE.md` más corto,** si pasa de unos 6k tokens. Proponé qué queda (reglas, comandos, convenciones) y qué pasa a `docs/` (explicaciones, historia, decisiones), donde los agentes lo leen solo si les hace falta. No borres reglas: se mueven.
3. **Desinstalar los departamentos que el proyecto no usa,** según lo que ves en el código. Por ejemplo, el de scraping en un proyecto sin scrapers.
4. **Menos QA o sin asesores,** si los tiene configurados y no le aportan. Proponelo con `--local`, salvo que pida cambiarlo para todo el equipo.
5. **Mover el developer que más gasta a Codex,** si es de Claude y está entre lo que más gastó.

## 3. Aplicá solo lo que confirme

- El `CLAUDE.md` es del proyecto: mostrale el cambio exacto antes de hacerlo, y hacelo solo si lo confirma.
- Los comandos de `office-agents.sh` y de `claude plugin`, pasáselos para que los corra él. O corrélos vos si te lo pide.
- No hagas commits.

Al final, sugerile medir la próxima tarea con `/office:usage` para ver la diferencia.
