  // --- Mundo -------------------------------------------------------------------
  const W = 768, H = 448;             // resolución del pixel art (personajes de 32 px)
  const RW = 192, RH = 180;           // tamaño de cada oficina
  const TOP_Y = 4, BOT_Y = 264;       // filas de oficinas
  const HALL_Y = 228;                 // por donde camina el PM
  const BACK = 30;                    // alto de la pared del fondo

  const PROVIDERS = {
    claude: { name: "Claude", color: "#e07a52" },
    codex:  { name: "Codex",  color: "#d6dbe3" },
    gemini: { name: "Gemini", color: "#6f9cff" },
  };
  // Colores de cada agente, los de su definición en la oficina.
  const ROLE_COLORS = { purple: "#8b6cd6", cyan: "#36a9bb", blue: "#4a78d6", green: "#47a865", yellow: "#d4a933", orange: "#e08a3a", pink: "#d771a8", red: "#cf4b47", gold: "#b88d3a", teal: "#2f9e8f" };

  const ROOMS = [
    { id: "meet",   name: "Reuniones",     x: 0,   y: TOP_Y, top: true,  deco: "meet" },
    { id: "design", name: "Diseño",        x: 192, y: TOP_Y, top: true,  deco: "design" },
    { id: "back",   name: "Backend",       x: 384, y: TOP_Y, top: true,  deco: "back" },
    { id: "front",  name: "Frontend",      x: 576, y: TOP_Y, top: true,  deco: "front" },
    { id: "db",     name: "Base de datos", x: 0,   y: BOT_Y, top: false, deco: "db" },
    { id: "scrap",  name: "Scraping",      x: 192, y: BOT_Y, top: false, deco: "scrap" },
    { id: "ops",    name: "DevOps",        x: 384, y: BOT_Y, top: false, deco: "ops" },
    { id: "qa",     name: "QA",            x: 576, y: BOT_Y, top: false, deco: "qa" },
  ];
  const room = id => ROOMS.find(r => r.id === id);
  const doorX = r => r.x + RW / 2;

  // Configuración simulada de proveedores, como la de .claude/office-agents.json.
  const AGENTS = [
    { id: "ceo",   label: "CEO",                     short: "CEO",      room: "meet",   seat: [58, 92],  color: "gold",   provider: null,     model: "—", tier: "—", look: 0 },
    { id: "adv",   label: "Asesor del PM",           short: "Asesor",   room: "meet",   seat: [134, 92], color: "purple", provider: "codex",  model: "gpt-6-astra", tier: "opus", role: "pm (asesor)", look: 5 },
    { id: "barch", label: "Arquitecto de backend",   short: "Arq. BE",  room: "design", seat: [52, 62],  color: "cyan",   provider: "claude", model: "opus", tier: "opus", role: "backend.architect", look: 1 },
    { id: "farch", label: "Arquitecto de frontend",  short: "Arq. FE",  room: "design", seat: [140, 62], color: "cyan",   provider: "claude", model: "opus", tier: "opus", role: "frontend.architect", look: 2 },
    { id: "dsgn",  label: "Designer",                short: "Designer", room: "design", seat: [52, 132], color: "pink",   provider: "claude", model: "sonnet", tier: "sonnet", role: "frontend.designer", look: 3 },
    { id: "oarch", label: "Arquitecto de DevOps",    short: "Arq. Ops", room: "design", seat: [140, 132], color: "cyan",  provider: "claude", model: "opus", tier: "opus", role: "devops.architect", look: 4 },
    { id: "bdev",  label: "Developer de backend",    short: "Dev BE",   room: "back",   seat: [52, 70],  color: "blue",   provider: "codex",  model: "gpt-6.1-sol", tier: "sonnet", role: "backend.developer", look: 6 },
    { id: "btest", label: "Tester de backend",       short: "Test BE",  room: "back",   seat: [140, 70], color: "green",  provider: "claude", model: "sonnet", tier: "sonnet", role: "backend.tester", look: 7 },
    { id: "fdev",  label: "Developer de frontend",   short: "Dev FE",   room: "front",  seat: [52, 70],  color: "blue",   provider: "gemini", model: "gemini-3.8-flash", tier: "sonnet", role: "frontend.developer", look: 8 },
    { id: "ftest", label: "Tester de frontend",      short: "Test FE",  room: "front",  seat: [140, 70], color: "green",  provider: "claude", model: "sonnet", tier: "sonnet", role: "frontend.tester", look: 9 },
    { id: "ddev",  label: "DB manager",              short: "DB",       room: "db",     seat: [52, 70],  color: "yellow", provider: "claude", model: "sonnet", tier: "sonnet", role: "database.developer", look: 10 },
    { id: "dtest", label: "Tester de base de datos", short: "Test DB",  room: "db",     seat: [140, 70], color: "green",  provider: "claude", model: "sonnet", tier: "sonnet", role: "database.tester", look: 11 },
    { id: "sdev",  label: "Developer de scraping",   short: "Dev SC",   room: "scrap",  seat: [52, 70],  color: "blue",   provider: "claude", model: "sonnet", tier: "sonnet", role: "scraper.developer", look: 12 },
    { id: "stest", label: "Tester de scraping",      short: "Test SC",  room: "scrap",  seat: [140, 70], color: "green",  provider: "claude", model: "sonnet", tier: "sonnet", role: "scraper.tester", look: 13 },
    { id: "odev",  label: "Developer de DevOps",     short: "Dev Ops",  room: "ops",    seat: [52, 70],  color: "orange", provider: "claude", model: "sonnet", tier: "sonnet", role: "devops.developer", look: 14 },
    { id: "otest", label: "Tester de DevOps",        short: "Test Ops", room: "ops",    seat: [140, 70], color: "green",  provider: "claude", model: "sonnet", tier: "sonnet", role: "devops.tester", look: 15 },
    // Líderes de departamento: solo en el modo equipos. Siempre Claude (Sonnet).
    { id: "blead", label: "Líder de backend",        short: "Líder BE", room: "back",   seat: [52, 132], color: "teal",   provider: "claude", model: "sonnet", tier: "sonnet", role: "backend.lead", look: 18 },
    { id: "flead", label: "Líder de frontend",       short: "Líder FE", room: "front",  seat: [52, 132], color: "teal",   provider: "claude", model: "sonnet", tier: "sonnet", role: "frontend.lead", look: 19 },
    { id: "dlead", label: "Líder de base de datos",  short: "Líder DB", room: "db",     seat: [52, 132], color: "teal",   provider: "claude", model: "sonnet", tier: "sonnet", role: "database.lead", look: 20 },
    { id: "slead", label: "Líder de scraping",       short: "Líder SC", room: "scrap",  seat: [52, 132], color: "teal",   provider: "claude", model: "sonnet", tier: "sonnet", role: "scraper.lead", look: 21 },
    { id: "olead", label: "Líder de DevOps",         short: "Líder Ops", room: "ops",   seat: [52, 132], color: "teal",   provider: "claude", model: "sonnet", tier: "sonnet", role: "devops.lead", look: 22 },
    { id: "qa1",   label: "QA (Claude)",             short: "QA 1",     room: "qa",     seat: [52, 96],  color: "red",    provider: "claude", model: "opus", tier: "opus", role: "qa", look: 16 },
    { id: "qa2",   label: "QA (Codex)",              short: "QA 2",     room: "qa",     seat: [140, 96], color: "red",    provider: "codex",  model: "gpt-6-astra", tier: "opus", role: "qa", look: 17 },
  ];
  const agent = id => state.agents.find(a => a.id === id);

  // Tokens por segundo mientras trabaja (simulado).
  const RATE = { claude: { opus: 820, sonnet: 640 }, codex: { opus: 900, sonnet: 610 }, gemini: { opus: 860, sonnet: 700 } };

  // Textos de la demo: encargos y respuestas que se pueden abrir en grande.
  const DEMO_TEXT = {
    archBrief: "Ticket: PROJ-123 (épica PROJ-100)\nObjetivo: diseñar la API para que los pedidos tengan estado.\n\n## Contexto\n- Los pedidos hoy no tienen estado: el front lo calcula.\n- La app móvil y la web leen la misma API.\n\n## Criterio de terminado\n- Endpoints, contratos y errores en `docs/design/pedidos.md`.\n- Cambios en los datos para el departamento de base de datos.",
    archReply: "NECESITO APROBACIÓN\n\n## Diseño\nDiseño en `docs/design/pedidos.md`.\n\n| Método | Ruta | Qué hace |\n| --- | --- | --- |\n| GET | `/orders/:id` | Devuelve el pedido con su `status` |\n| PATCH | `/orders/:id/status` | Cambia el estado si la transición es válida |\n\n## Decisiones para el CEO\n1. Estados: `pending`, `paid`, `shipped`, `cancelled`.\n2. Un pedido enviado **no** se puede cancelar.\n\n## Para base de datos\n- Columna `status` con índice en `orders`.",
    devBrief: "Ticket: PROJ-123\nObjetivo: implementar los endpoints de estado según `docs/design/pedidos.md`.\n\n- Validar las transiciones de estado.\n- Actualizar la colección de Postman del proyecto y la de la épica PROJ-100.\n\nNo escribas tests: los escribe el tester.",
    testFail: "FALLA\n\n## Fallas\n1. `PATCH /orders/:id/status` acepta `\"shipped\"` → `\"cancelled\"` y devuelve 200. El diseño dice que no se puede.\n\n```\nexpected 409, received 200\n  at orders.status.test.ts:42\n```\n\n## Para el developer\n- Revisá la tabla de transiciones en `src/orders/schema.ts`.",
    leadReport: "LISTO\n\n## Qué se hizo\n- Endpoints de estado de pedidos, con validación de transiciones.\n- Colecciones de Postman al día.\n\n## Calidad\n- 2 vueltas developer ↔ tester: la primera falló por una transición inválida.\n- Tests, typecheck y lint en verde.\n\n## Para otros departamentos\n- **Frontend:** `GET /orders/:id` ahora trae `status`.\n\n## Acciones requeridas\n- Ninguna.",
    pmReport: "## Informe: PROJ-123\n\nLos pedidos ya tienen estado, de punta a punta.\n\n| Departamento | Resultado |\n| --- | --- |\n| Base de datos | Migración que sube y baja |\n| Backend | Endpoints con transiciones validadas |\n| Frontend | Pantalla de estado del pedido |\n| QA | APROBADO, 1 hallazgo en disputa |\n\n## Necesito tu decisión\n- QA cree que un pedido pagado debería poder cancelarse. ¿Lo cambiamos?\n\n¿Abro el PR con `open-pr`?",
  };

  // --- Guion de la simulación ----------------------------------------------------
  // Pasos: say (mensaje), work (trabaja d segundos), walk (el PM camina; noWait no lo espera),
  // wait (espera al CEO) y run (animaciones de la gente; waitFor espera a que terminen).
  const SCRIPT = [
    { phase: 0, say: "El CEO llama al PM: \"trabajemos en PROJ-123\"." },
    { phase: 0, walk: "ceo", tool: "entra a la reunión" },
    { phase: 0, work: "pm", d: 7, tool: "start-ticket PROJ-123", task: "Reunión con el CEO: pedidos con estado" },
    { phase: 0, say: "start-ticket: rama feature/PROJ-123-pedidos desde la épica PROJ-100. Ticket en curso." },
    { phase: 0, work: "adv", d: 5, tool: "lee el plan", task: "Segunda opinión sobre el plan", result: "pass", resultText: "OPINA" },
    { phase: 0, say: "Asesor (Codex): coincide con el plan; sugiere un índice en orders.status.", kind: "good" },
    { phase: 1, walk: "barch" },
    { phase: 1, work: "barch", d: 9, tool: "escribe docs/design/pedidos.md", task: "Diseño de la API de pedidos", brief: DEMO_TEXT.archBrief, reply: DEMO_TEXT.archReply, result: "waiting", resultText: "pide aprobación" },
    { phase: 1, say: "Arquitecto de backend: diseño listo. Necesito aprobación.", kind: "warn" },
    { phase: 1, walk: "ceo" },
    { phase: 1, wait: 5, waiting: "ceo", say2: "El CEO aprueba el diseño.", tool: "esperando al CEO" },
    // Base de datos: el PM le encarga al líder y el líder reparte.
    { phase: 2, walk: "dlead", say: "Modo equipos: el PM le encarga cada departamento a su líder." },
    { phase: 2, work: "dlead", d: 3, tool: "lee el encargo", task: "Coordinar la migración del estado" },
    { phase: 2, walk: "door", noWait: true, tool: "espera afuera de Reuniones", run: () => talkTo("dlead", "ddev", ["Te paso la migración", "Dale, arranco"]), waitFor: ["dlead"] },
    { phase: 2, work: "ddev", d: 7, tool: "migración add_order_status", task: "Estado del pedido e índice" },
    { phase: 2, run: () => talkTo("dlead", "dtest", ["Probá que suba y baje", "Voy"]), waitFor: ["dlead"] },
    { phase: 2, work: "dtest", d: 5, tool: "migración sube y baja", task: "Probar la migración", result: "pass", resultText: "PASA" },
    { phase: 2, run: () => talkTo("dtest", "dlead", ["PASA: sube y baja", "¡Bien!"]), waitFor: ["dtest"] },
    { phase: 2, work: "dlead", d: 3, tool: "escribe el reporte", task: "Reporte del departamento" },
    { phase: 2, say: "Líder de base de datos: reporte listo en .office/reports/.", kind: "good" },
    { phase: 2, walk: "dlead", tool: "busca el reporte" },
    // Backend: el ciclo developer ↔ tester queda dentro del departamento.
    { phase: 3, walk: "blead" },
    { phase: 3, work: "blead", d: 3, tool: "lee el encargo", task: "Coordinar los endpoints de pedidos" },
    { phase: 3, walk: "door", noWait: true, tool: "espera afuera de Reuniones", run: () => talkTo("blead", "bdev", ["Te paso los endpoints", "Dale, arranco"]), waitFor: ["blead"] },
    { phase: 3, work: "bdev", d: 9, task: "Endpoints de pedidos", brief: DEMO_TEXT.devBrief, from: "blead", tools: ["lee docs/design", "edita src/orders/routes.ts", "edita la colección de Postman", "puente: typecheck y tests"] },
    { phase: 3, run: () => talkTo("bdev", "blead", ["Endpoints listos", "Pasáselos al tester"]), waitFor: ["bdev"] },
    { phase: 3, run: () => talkTo("blead", "btest", ["Probá los endpoints", "Voy"]), waitFor: ["blead"] },
    { phase: 3, work: "btest", d: 6, tool: "tests de contrato", task: "Probar los endpoints", result: "fail", resultText: "FALLA", reply: DEMO_TEXT.testFail },
    { phase: 3, say: "Tester de backend: FALLA. Se lo lleva al developer, no al PM.", kind: "alert", run: () => { talkTo("btest", "bdev", ["FALLA: acepta un estado inválido", "Uh, lo corrijo"]); later("bdev", 4.5, "scratch"); }, waitFor: ["btest"] },
    { phase: 3, work: "bdev", d: 6, task: "Corregir la validación del estado", tools: ["edita src/orders/schema.ts", "puente: typecheck y tests"], round: true },
    { phase: 3, work: "btest", d: 5, tool: "tests de contrato", task: "Volver a probar", result: "pass", resultText: "PASA" },
    { phase: 3, run: () => talkTo("btest", "blead", ["PASA: todo en verde", "¡Excelente!"]), waitFor: ["btest"] },
    { phase: 3, work: "blead", d: 4, tool: "escribe el reporte", task: "Reporte del departamento", reply: DEMO_TEXT.leadReport },
    { phase: 3, say: "Líder de backend: reporte listo, con las acciones requeridas.", kind: "good" },
    { phase: 3, walk: "blead", tool: "busca el reporte" },
    // Calidad: dos QA revisan y después debaten los hallazgos.
    { phase: 4, walk: "qa1" },
    { phase: 4, work: ["qa1", "qa2"], d: 8, tool: "ataques en .qa/", task: "Revisión independiente" },
    { phase: 4, say: "Validación cruzada: los QA debaten los hallazgos.", run: () => debate("qa1", "qa2", DEBATE_LINES), waitFor: ["qa1", "qa2"] },
    { phase: 4, say: "QA: APROBADO. 2 mejoras confirmadas y 1 hallazgo en disputa, que va al CEO.", kind: "good", result: ["qa1", "qa2"], resultText: "APROBADO" },
    // Frontend.
    { phase: 5, walk: "flead" },
    { phase: 5, work: "flead", d: 3, tool: "lee el encargo", task: "Coordinar la pantalla de estado" },
    { phase: 5, walk: "door", noWait: true, tool: "espera afuera de Reuniones", run: () => talkTo("flead", "fdev", ["Te paso la pantalla", "Dale"]), waitFor: ["flead"] },
    { phase: 5, work: "fdev", d: 9, task: "Pantalla de estado del pedido", tools: ["lee la colección de Postman", "edita app/orders/page.tsx", "puente: typecheck y tests"] },
    { phase: 5, work: "ftest", d: 6, tool: "tests de la pantalla", task: "Probar estados y textos", result: "pass", resultText: "PASA" },
    { phase: 5, run: () => talkTo("ftest", "flead", ["PASA: estados y textos", "¡Bien!"]), waitFor: ["ftest"] },
    { phase: 5, work: "flead", d: 3, tool: "escribe el reporte", task: "Reporte del departamento" },
    { phase: 5, walk: "flead", tool: "busca el reporte" },
    { phase: 6, walk: "ceo" },
    { phase: 6, work: "pm", d: 6, tool: "arma el informe", task: "Informe al CEO", reply: DEMO_TEXT.pmReport },
    { phase: 6, say: "Informe listo. Ofrece abrir el PR con open-pr.", kind: "good", run: () => pizzaForTop() },
    { phase: 6, wait: 5, waiting: "ceo", say2: "El CEO lee el informe.", tool: "leyendo el informe" },
    { phase: 6, walk: "door", tool: "sale de la reunión", say: "Fin del ticket. El PM espera afuera hasta que el CEO lo llame." },
  ];
  const PHASES = ["Reunión", "Diseño", "Base de datos", "Backend", "Calidad", "Frontend", "Informe"];

