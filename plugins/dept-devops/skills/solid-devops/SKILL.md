---
name: solid-devops
description: Reglas para construir y cambiar CI/CD, despliegues, infraestructura como código, contenedores y servidores sin romper producción ni filtrar secretos - qué nunca se hace, pipelines reproducibles y rápidos, seguridad de GitHub Actions (permisos, secretos, acciones fijadas, disparadores peligrosos), despliegues por entorno con aprobación y vuelta atrás, migraciones en el despliegue, infraestructura como código, Docker, procesos en servidores, observabilidad y costos. Usar al crear o cambiar workflows, scripts de despliegue, infraestructura, Dockerfiles o configuración de servidores, al diagnosticar un pipeline o un deploy que falla, y al validarlos.
---

# DevOps sólido

Un buen pipeline es aburrido: hace lo mismo cada vez, falla rápido y claro, nunca filtra un secreto y nunca despliega a producción sin que alguien lo decida. Un error acá no rompe una función: rompe todo el producto a la vez, o expone las llaves de la cuenta. Si las reglas del proyecto (su `CLAUDE.md`) dicen algo distinto, mandan las del proyecto.

## 1. Lo que nunca se hace

- Nunca desplegar, aplicar infraestructura ni ejecutar nada contra una cuenta real (`sst deploy`, `terraform apply`, `pulumi up`, `cdk deploy`, `kubectl apply`, `serverless deploy`, `pm2` o `systemctl` en un servidor). Eso lo hace el CEO, o un pipeline que él aprueba.
- Nunca destruir recursos (`terraform destroy`, `sst remove`, `pulumi destroy`, borrar buckets, bases o colas).
- Nunca leer, imprimir, copiar ni escribir el valor de un secreto: ni en código, ni en logs, ni en el reporte. Se trabaja con sus **nombres**. Crear o cambiar un secreto (`gh secret set`, `sst secret set`, gestores de secretos de la nube) lo hace el CEO.
- Nunca conectarse por SSH a un servidor ni ejecutar comandos remotos.
- Nunca disparar un workflow que despliega (`gh workflow run`, re-ejecutar un deploy) sin aprobación del CEO.
- Nunca subir costos sin aprobación: instancias más grandes, más réplicas, más memoria, más ejecuciones programadas, logs sin retención.

## 2. Pipelines reproducibles y rápidos

- **Versiones fijas:** la del runtime (Node, Python) igual a la de producción, la del gestor de paquetes fijada (por ejemplo `packageManager` con corepack) y el lockfile commiteado. La instalación en CI es estricta: `npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`.
- **El mismo orden que en local:** instalar → lint → typecheck → tests → build. Un paso que falla corta el pipeline.
- **Caché** de dependencias con la clave del lockfile. Nunca cachear artefactos con secretos.
- **`concurrency`** por rama para cancelar corridas viejas, y nunca para cancelar un deploy a medias.
- **`timeout-minutes`** en cada job. Un job colgado consume minutos de CI.
- **Servicios para tests** (bases, colas) como `services:` del job o contenedores efímeros, nunca contra entornos reales.
- **Mensajes claros:** si un paso falla por configuración (falta una variable, falta un permiso), que el error lo diga.

## 3. Seguridad de GitHub Actions

- **`permissions:` mínimos** en cada workflow (por ejemplo `contents: read`) y solo lo que cada job necesita. Nunca `write-all`.
- **Acciones de terceros fijadas** a un commit (SHA) o, como mínimo, a una versión exacta. Nunca `@main` ni `@master`.
- **`pull_request_target` y `workflow_run`** corren con secretos y permisos de escritura: nunca hacen checkout ni ejecutan código del PR.
- **Inyección:** nunca interpolar entradas que controla otro (`github.event.pull_request.title`, nombres de ramas, comentarios) directo en `run:`. Pasarlas por `env:` y usarlas entre comillas.
- **Secretos:** solo en los pasos que los usan, nunca en `echo` ni en `set -x`. Los forks no reciben secretos: los workflows de PR no deben necesitarlos.
- **Credenciales de la nube por OIDC** (rol asumido con identidad federada) en lugar de llaves fijas guardadas como secretos, cuando la nube lo permite.

## 4. Despliegues

- **Por entorno:** cada entorno (desarrollo, producción) tiene su rama o disparador, sus secretos y su configuración. Producción no comparte credenciales con desarrollo.
- **Producción solo con aprobación:** un `environment` con revisores obligatorios, un disparador manual o un tag. Nunca automático desde cualquier push.
- **Mismo artefacto:** lo que se probó es lo que se despliega. Se construye una vez y se promueve.
- **Vuelta atrás:** cada despliegue tiene un camino documentado para volver a la versión anterior (redeploy del commit anterior, alias, imagen previa).
- **Verificación después del deploy:** un health check o una prueba de humo, y avisar si falla.
- **Migraciones de base de datos:** compatibles con la versión anterior del código (expandir y después contraer), corridas como paso explícito y antes del código que las necesita. Nunca un deploy que borra datos.
- **Sin cortes:** si el servicio lo permite, despliegues graduales o con reemplazo progresivo.

## 5. Infraestructura como código

- Todo recurso vive en el código del proyecto (SST, Terraform, CDK, Pulumi, CloudFormation o lo que use). Nunca cambios a mano en la consola: si alguien los hizo, se documentan y se pasan al código.
- Un cambio de infraestructura se revisa con su **plan o diff** antes de aplicarse. Si generarlo necesita credenciales reales, lo corre el CEO.
- Recursos con datos (bases, buckets) con protección contra borrado y retención en producción.
- Nombres y etiquetas que dicen a qué entorno y proyecto pertenecen, para poder ver los costos.
- Permisos de cada recurso al mínimo (políticas IAM específicas, nunca `*` en acciones y recursos a la vez).

## 6. Contenedores

- Imagen base oficial y con versión fija, lo más chica que sirva (`-slim`, `-alpine` si las dependencias lo permiten).
- Construcción en etapas: las herramientas de build no llegan a la imagen final.
- Usuario sin privilegios (`USER`), sin secretos en la imagen ni en `ARG`/`ENV`, y un `.dockerignore` que excluya `.env`, `.git` y `node_modules`.
- `HEALTHCHECK` o el equivalente del orquestador.
- En `docker compose` de desarrollo, volúmenes con nombre y puertos solo en `localhost` cuando no hace falta exponerlos.

## 7. Procesos en servidores

- El proceso se define en un archivo del proyecto (`ecosystem.config.js` de PM2, unidad de systemd, compose), no con comandos sueltos que nadie recuerda.
- Reinicio automático con límite, y logs con rotación.
- Zona horaria, variables de entorno y versión del runtime declaradas, no heredadas del servidor por casualidad.
- La actualización de un servidor es un script versionado (traer el código, instalar, construir, reiniciar) que corre el CEO.

## 8. Observabilidad y costos

- Cada servicio deja logs estructurados y sin datos personales ni secretos, con retención definida.
- Alertas para lo que importa: un deploy que falla, un proceso que se reinicia en bucle, errores por encima de lo normal, una tarea programada que no corrió.
- Cada tarea programada declara en qué zona horaria corre y qué pasa si se ejecuta dos veces.
- Antes de proponer un recurso nuevo, estimá su costo mensual y decilo en el reporte.

## 9. Diagnosticar un pipeline o un deploy que falla

1. Leé el log del paso que falló, entero (`gh run view <id> --log-failed` o el de la plataforma). El primer error es el que importa; los siguientes suelen ser consecuencia.
2. Separá la causa: código (el test falla también en local), entorno (versión de runtime, dependencia que cambió, caché vieja), configuración (falta una variable, un secreto o un permiso) o la plataforma (caída, límite de uso).
3. Reproducilo en local con la misma versión y los mismos comandos, si se puede.
4. Proponé el arreglo más chico que ataca la causa. Si la causa está en la configuración de la cuenta o en un secreto, decí exactamente qué tiene que cambiar el CEO, sin pedirle el valor.

## Skills de la comunidad

Si el proyecto tiene instaladas skills oficiales de su herramienta de infraestructura, usalas con la herramienta Skill para el detalle técnico. Por ejemplo, para Terraform y Packer, las de HashiCorp (`terraform-code-generation`, `terraform-module-generation` y otras, del marketplace `hashicorp/agent-skills`).

Estas reglas mandan sobre las skills de la comunidad en seguridad, aprobaciones y límites. Si una skill externa sugiere algo que acá está prohibido (aplicar cambios en una cuenta real, desplegar, leer secretos, conectarse a un servidor), no lo hagas: tomá solo su conocimiento técnico.

## Checklist antes de dar algo por terminado

- [ ] Nada se desplegó, aplicó ni destruyó en una cuenta real, y no se tocó ningún servidor.
- [ ] Ningún valor de secreto aparece en el código, los logs ni el reporte.
- [ ] Workflows con `permissions:` mínimos, acciones fijadas y sin interpolar entradas externas en `run:`.
- [ ] Versiones de runtime y gestor de paquetes fijadas, instalación estricta con lockfile.
- [ ] Producción solo con aprobación, y un camino documentado para volver atrás.
- [ ] Migraciones compatibles con la versión anterior y antes del código que las usa.
- [ ] Costos nuevos estimados y señalados.
- [ ] Validado con las herramientas locales disponibles (sintaxis, linters, build).
