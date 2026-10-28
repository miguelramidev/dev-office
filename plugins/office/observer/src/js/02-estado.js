  // --- Estado ------------------------------------------------------------------
  let state;
  const MEET_SPOT = () => { const r = room("meet"); return { x: r.x + 96, y: r.y + 156, room: "meet" }; };
  // Donde espera el PM: en el pasillo, al lado de la puerta de Reuniones, hasta que el CEO lo llama.
  const DOOR_SPOT = () => ({ x: doorX(room("meet")) + 26, y: 214, room: "hall" });
  function freshState() {
    const m = DOOR_SPOT();
    return {
      t: 0, step: -1, stepT: 0, phase: 0, rounds: 0, nextIdle: 3, holds: {}, demoRun: Date.now().toString(36),
      courier: null, pizza: {}, pizzaBase: {}, pizzaWins: {}, facts: freshFacts(), blackout: 0, cake: null, petWalk: null, nextPet: 30,
      tokens: { claude: 0, codex: 0, gemini: 0 },
      feed: [], selected: "pm", docs: [],
      pm: { id: "pm", x: m.x, y: m.y, path: [], facing: 1, walking: false, status: "idle", tool: "", task: "", tokens: 0, startedAt: 0, room: "hall", label: "PM", ...NO_DOCS() },
      agents: AGENTS.map(a => ({ ...a, present: true, ext: 0, status: "idle", tool: "", task: "", tokens: 0, startedAt: null, bubble: null, bubbleUntil: 0, toolList: null, ...NO_DOCS(),
        pos: null, path: [], acts: [], say: null, pose: null, prop: null, curRoom: a.room, facing: 1, idleTrip: false })),
    };
  }
  function addFeed(text, kind = "", doc = null) { state.feed.unshift({ t: state.t, text, kind, doc }); if (state.feed.length > 60) state.feed.pop(); }

  // --- Textos completos ----------------------------------------------------------
  // Encargos, respuestas y mensajes que se pueden leer en grande. Cada persona guarda los
  // últimos en "docs", su encargo actual en "brief" y su última respuesta en "reply".
  // state.docs los numera para que los botones del panel los encuentren.
  function NO_DOCS() { return { docs: [], brief: null, reply: null }; }
  function newDoc(kind, title, text, extra) {
    if (!text || !String(text).trim()) return null;
    const d = Object.assign({ kind, title, text: String(text), at: null, t: state.t }, extra || {});
    d.id = state.docs.push(d) - 1;
    return d;
  }
  // as: "brief" (lo que le encargaron), "reply" (lo que respondió) o nada (solo el historial).
  function keepDoc(p, d, as) {
    if (!p || !d) return d;
    if (!p.docs.includes(d)) { p.docs.unshift(d); if (p.docs.length > 12) p.docs.pop(); }
    if (as) p[as] = d;
    return d;
  }

  const seatOf = a => { const r = room(a.room); return { x: r.x + a.seat[0], y: r.y + a.seat[1] }; };
  function standSpot(target) {
    if (target === "ceo") return MEET_SPOT();
    if (target === "door") return DOOR_SPOT();
    const a = agent(target), s = seatOf(a);
    return { x: s.x + (a.seat[0] < 96 ? 44 : -44), y: s.y + 26, room: a.room };
  }
  const insideDoor = r => ({ x: doorX(r), y: r.top ? r.y + RH - 16 : r.y + BACK + 14 });
  // Camino entre dos puntos: por las puertas y el pasillo si cambia de oficina; dentro de
  // una oficina, en L por el pasillo del medio, para no pasar por arriba de los escritorios.
  function planPath(from, to) {
    const pts = [];
    if (from.room !== to.room) {
      const rf = room(from.room), rt = room(to.room);
      if (rf) pts.push(insideDoor(rf), { x: doorX(rf), y: HALL_Y });
      else pts.push({ x: from.x, y: HALL_Y });
      if (rt) pts.push({ x: doorX(rt), y: HALL_Y }, insideDoor(rt));
      else pts.push({ x: to.x, y: HALL_Y });
    } else if (room(to.room) && Math.abs(from.x - to.x) > 2 && Math.abs(from.y - to.y) > 2) {
      const cx = room(to.room).x + RW / 2;
      pts.push(Math.abs(from.x - cx) <= Math.abs(to.x - cx) ? { x: from.x, y: to.y } : { x: to.x, y: from.y });
    }
    pts.push({ x: to.x, y: to.y });
    return pts;
  }
  const personById = id => id === "pm" ? state.pm : agent(id);
  const providerName = a => a.provider ? PROVIDERS[a.provider].name : "—";

  function startStep() {
    state.step = (state.step + 1) % SCRIPT.length;
    if (state.step === 0 && state.t > 1) {
      state.agents.forEach(a => { a.status = "idle"; a.tool = ""; a.task = ""; a.bubble = null; clearAnim(a); Object.assign(a, NO_DOCS()); });
      Object.assign(state.pm, NO_DOCS());
      state.docs = [];
      state.rounds = 0;
    }
    state.stepT = 0;
    const s = SCRIPT[state.step];
    state.phase = s.phase;
    if (s.say) addFeed(s.say, s.kind || "");
    if (s.result && !s.work) [].concat(s.result).forEach(id => { showResult(agent(id), "pass", s.resultText); if (agent(id).role === "qa") factQa(state.facts, s.resultText); });
    if (s.walk) {
      const to = Object.assign(standSpot(s.walk), { target: s.walk });
      state.pm.path = planPath(state.pm, to);
      state.pm.dest = to;
      state.pm.walking = true;
      state.pm.status = "working";
      state.pm.tool = s.tool || "va a " + (s.walk === "ceo" || s.walk === "door" ? "Reuniones" : room(agent(s.walk).room).name);
      state.pm.clearOnArrive = !!s.noWait;
      if (s.walk !== "ceo" && s.walk !== "door" && !s.tool) addFeed("PM encarga a " + agent(s.walk).label + " (" + providerName(agent(s.walk)) + ").");
      else if (s.tool === "busca el reporte") addFeed("El PM va a buscar el reporte de " + room(agent(s.walk).room).name + ".");
    }
    if (s.run) s.run();
    if (s.work) {
      [].concat(s.work).forEach(id => {
        const p = personById(id);
        p.status = "working";
        p.tool = s.tools ? s.tools[0] : s.tool;
        p.toolList = s.tools || null;
        p.task = s.task;
        p.startedAt = state.t;
        p.bubble = null;
        if (id !== "pm") cancelIdle(p);
        const d = keepDoc(p, newDoc("Encargo", (s.from ? agent(s.from).label : id === "pm" ? "CEO" : "PM") + " → " + p.label + ": " + s.task, s.brief), "brief");
        if (id !== "pm" && !s.say) addFeed(p.label + ": " + s.task + ".", "", d);
      });
      if (s.round) { state.rounds += 1; addFeed("Vuelta " + (state.rounds + 1) + " del ciclo developer → tester.", "warn"); }
    }
    if (s.wait) {
      const p = personById(s.waiting);
      p.status = "waiting"; p.tool = s.tool;
      state.pm.status = "waiting"; state.pm.tool = s.tool;
    }
  }
  function showResult(p, kind, text) { p.status = kind; p.bubble = text; p.bubbleUntil = state.t + 4; }
  function finishStep() {
    const s = SCRIPT[state.step];
    if (s.work) {
      [].concat(s.work).forEach(id => {
        const p = personById(id);
        p.tool = "";
        const d = keepDoc(p, newDoc("Respuesta", (id === "pm" ? "PM al CEO" : p.label) + ": " + (s.resultText || s.task), s.reply, { verdict: s.resultText || null }), "reply");
        if (d) addFeed((id === "pm" ? "PM: " + s.task : p.label + " terminó: " + (s.resultText || "LISTO")) + ".", s.result === "fail" ? "alert" : s.result === "waiting" ? "warn" : "good", d);
        if (id === "pm") { if (s.phase === 6) state.facts.pr = true; p.status = "idle"; return; }
        state.facts.workers.add(id); if (p.provider) state.facts.providers.add(p.provider);
        if (/\.tester$/.test(p.role || "") && s.resultText) {
          factTest(state.facts, s.resultText);
          if (s.resultText === "FALLA" && Math.random() < 0.5) { powerCut(); state.facts.blackout = true; addFeed("Se cortó la luz de tanto test en rojo. A los pocos segundos volvió.", "alert"); }
        }
        if (s.result === "waiting") state.facts.approvals += 1;
        if (s.result) showResult(p, s.result, s.resultText);
        else { p.status = "pass"; p.bubble = "LISTO"; p.bubbleUntil = state.t + 3; }
        if (s.result === "pass" && p.room !== "meet") pose(id, "celebrate", 2);
      });
    }
    if (s.wait) {
      personById(s.waiting).status = "idle";
      state.pm.status = "idle"; state.pm.tool = "";
      if (s.say2) addFeed(s.say2, "good");
    }
    if (s.walk && !s.noWait) { state.pm.walking = false; state.pm.status = "idle"; state.pm.tool = ""; }
  }
  function stepDone() {
    const s = SCRIPT[state.step];
    if (s.run) return s.waitFor ? state.stepT > 0.3 && s.waitFor.every(id => !agent(id).acts.length) : state.stepT >= 1.2;
    if (s.walk && !s.noWait) return state.pm.path.length === 0;
    if (s.work) return state.stepT >= s.d;
    if (s.wait) return state.stepT >= s.wait;
    return state.stepT >= 1.2;
  }

  function update(dt) {
    if (mode === "live") { liveTick(dt); return; }
    state.t += dt;
    state.stepT += dt;
    const pm = state.pm;
    movePM(dt);
    const pmRate = pm.status === "working" && !pm.walking ? 300 : 40;
    pm.tokens += pmRate * dt;
    state.tokens.claude += pmRate * dt;
    simAgents(dt);
    animTick(dt);
    if (stepDone()) { finishStep(); startStep(); }
  }

  function movePM(dt) {
    const pm = state.pm;
    if (pm.path.length) {
      const target = pm.path[0];
      const dx = target.x - pm.x, dy = target.y - pm.y, dist = Math.hypot(dx, dy);
      const step = 92 * dt;
      if (Math.abs(dx) > 0.5) pm.facing = dx > 0 ? 1 : -1;
      if (dist <= step) { pm.x = target.x; pm.y = target.y; pm.path.shift(); }
      else { pm.x += dx / dist * step; pm.y += dy / dist * step; }
      if (!pm.path.length && pm.dest) pm.room = pm.dest.room;
      else if (pm.y > 184 && pm.y < 264) pm.room = "hall";
      if (!pm.path.length && pm.clearOnArrive) { pm.clearOnArrive = false; pm.tool = ""; pm.status = "idle"; }
    }
  }

  function simAgents(dt) {
    state.agents.forEach(a => {
      if (a.status === "working" && a.provider) {
        const r = RATE[a.provider][a.tier] * dt * (0.8 + 0.4 * Math.random());
        a.tokens += r;
        state.tokens[a.provider] += r;
        if (a.toolList) a.tool = a.toolList[Math.min(a.toolList.length - 1, Math.floor((state.t - a.startedAt) / 3))];
      }
      if (a.bubble && state.t > a.bubbleUntil) { a.bubble = null; if (a.status === "pass") a.status = "idle"; }
    });
  }

  // --- Vida en la oficina: levantarse, caminar, hablar ------------------------------
  // Cada persona tiene una fila de acciones (acts): go (caminar a un lugar), home (volver al
  // escritorio), talk (charla de a dos, con globos que se alternan), hold (espera que termine
  // una charla), wait, say, pose (festeja, se estira o se rasca la cabeza) y prop (taza).
  const SPEED = 64;
  const COFFEE = [{ x: 733, y: 224, room: "hall" }, { x: 18, y: 224, room: "hall" }];
  const DEBATE = [[100, 62], [136, 62]];
  const DEBATE_LINES = ["Este hallazgo es real", "No coincido: ya valida", "Mirá el PATCH sin estado", "Ok, ese lo confirmo", "¿Y el del índice?", "Ese queda en disputa"];
  // Charlas de los ratos libres: entre compañeros del mismo departamento y con otros.
  const CHATS = [
    ["¿Un café?", "Dale, en un rato"],
    ["¿Ya pusheaste?", "Recién, mirá el PR"],
    ["Ese test tarda una eternidad", "Hay que mockear la base"],
    ["¿Cerraste el ticket viejo?", "Lo dejé en revisión"],
    ["¿Me hacés pair un rato?", "Dale, traé la silla"],
    ["Encontré un TODO de hace dos años", "Dejalo, es patrimonio histórico"],
    ["¿Qué versión de Node usamos?", "La del .nvmrc", "¿Hay .nvmrc?", "Ahora sí"],
    ["El linter me odia", "Te quiere enseñar"],
    ["¿Revisaste los logs?", "Nada raro", "Raro que no haya nada raro"],
    ["Hoy no se rompió nada", "No lo digas en voz alta"],
    ["¿Le ponemos un test a eso?", "Mejor dos"],
    ["¿Viste el último PR?", "Sí, quedó bien"],
    ["¿Cómo vas?", "Ahí, avanzando"],
    ["¿Corriste los tests?", "Todos en verde"],
    ["¿Almorzamos?", "Termino esto y vamos"],
    ["¿Me prestás el cargador?", "Tomá, devolvémelo"],
    ["Ese bug era un typo", "Clásico", "Tres horas por una coma", "Nos pasa a todos"],
    ["¿Usamos tabs o espacios?", "Lo que diga el linter"],
    ["¿Quién rompió el build?", "Yo no fui", "El historial dice otra cosa", "Ups"],
    ["Hoy me rindió el día", "¡Bien ahí!"],
    ["¿Probaste el modo oscuro?", "Ya no vuelvo atrás"],
    ["¿Hiciste el refactor?", "A medias", "¿Lo terminás hoy?", "Mañana seguro"],
    ["Me encanta este diseño", "Al CEO también"],
    ["¿Tenés un minuto?", "Contame"],
    ["Encontré un caso borde", "Anotalo para el tester"],
    ["¿Ya actualizaste?", "Anoche, todo bien"],
    ["El café está fuerte hoy", "Justo lo que necesitaba"],
    ["¿Pair programming?", "Dale, traé tu silla"],
    ["¿Leíste el diseño?", "Dos veces", "¿Y?", "Tiene sentido"],
    ["¿Cuántos tests van?", "Ciento y pico"],
    ["Necesito vacaciones", "Después del release"],
    ["¿Merge o rebase?", "Rebase, siempre"],
    ["¿Qué estás escuchando?", "Lo-fi para programar"],
    ["La migración tarda", "Paciencia, ya baja"],
    ["¿Viste el nuevo monitor?", "Envidia total"],
    ["¿Me revisás esto?", "Pasame el link"],
    ["Cerré tres tickets", "Máquina", "Faltan otros diez", "Bueno, de a poco"],
    ["¿Escribiste la doc?", "Está en el README"],
    ["Me trabé con un tipo", "Mostrame el error"],
    ["Hoy no hay reunión, ¿no?", "Por suerte no"],
    ["¿Pedimos pizza?", "¡Sí!", "¿Mitad y mitad?", "Obvio"],
    ["El linter me odia", "Él te quiere, en serio"],
    ["¿Funciona en tu máquina?", "En la mía sí", "Clásico", "Probá limpiando la caché"],
    ["Ese nombre de variable…", "Lo cambio, lo cambio"],
    ["¿Ya viene el viernes?", "Falta poco"],
    ["Aprendí un atajo nuevo", "¡Enseñame!"],
    ["¿Subiste los cambios?", "Están en mi rama"],
    ["Gracias por la ayuda", "Para eso estamos"],
    ["¿Te gusta la nueva silla?", "Mi espalda dice que sí"],
    ["¿Otra vez los tests lentos?", "Los voy a paralelizar"],
    ["Borré 200 líneas", "La mejor clase de commit"],
    ["¿Comentarios o código claro?", "Código claro primero"],
    ["¿Quién tiene el ticket?", "Lo tomo yo"],
    ["Se cortó internet", "Hora del café, entonces"],
    ["Probé la app en el celu", "¿Y qué tal?", "Vuela", "¡Bien!"],
    ["¿Agregamos un test?", "Siempre suma uno más"],
    ["Ya entendí el bug", "Contame qué era", "Una fecha sin zona horaria", "Lo de siempre"],
    ["Me gusta tu fondo", "Lo hice yo"],
    ["¿Qué tal el fin de semana?", "Corto, como siempre"],
    ["Revisá mi comentario", "Ya lo resuelvo"],
  ];
  const CHATS_OTHER = [
    ["¿Cómo viene tu depto?", "Bien, cerrando tests"],
    ["¿Ese endpoint devuelve fechas en UTC?", "Siempre en UTC"],
    ["¿Me mostrás el diseño nuevo?", "Está en el Figma del equipo"],
    ["¿Cuánto tarda la migración?", "Dos minutos en dev"],
    ["¿El scraper respeta el robots.txt?", "Siempre"],
    ["¿Subieron el ambiente de dev?", "Recién terminó el deploy"],
    ["¿Quién tiene la llave del rack?", "DevOps, como siempre"],
    ["QA encontró algo en tu PR", "Voy a mirar", "Es un caso borde", "Mis favoritos"],
    ["¿Hay reunión hoy?", "Si el CEO llama, sí"],
    ["Felicitaciones por el release", "¡Gracias! Fue en equipo"],
    ["¿Me pasás la colección?", "Está en docs/api"],
    ["¿Ya migraron la base?", "Sí, ayer"],
    ["¿Viste el partido?", "¡Qué partido!"],
    ["¿Almorzamos juntos?", "Dale, a las 12"],
    ["¿Quién revisa mi PR?", "Lo miro yo"],
    ["¿La API ya está lista?", "Casi, falta un endpoint"],
    ["¿Ese campo es opcional?", "Opcional, sí"],
    ["El front necesita un filtro", "Pedíselo al PM", "Ya lo hice", "Entonces llega"],
    ["¿Cuándo despliegan?", "Cuando el CEO diga"],
    ["¿Tienen un índice ahí?", "Lo agregamos hoy"],
    ["Vengo a robar café", "Servite"],
    ["¿Me explicás el pipeline?", "Son tres pasos", "¿Nada más?", "Y muchos secretos"],
    ["¿Cambiaron el contrato?", "Solo un nombre", "Avisá, porfa", "Va en el reporte"],
    ["Su sala es más linda", "Tenemos plantas"],
    ["¿Ese error es de ustedes?", "Déjame ver el log", "Es de nosotros", "Gracias por avisar"],
    ["¿Tienen mock de esto?", "En la carpeta de tests"],
    ["¿Qué estás haciendo?", "Un scraper educado"],
    ["¿El QA ya pasó por acá?", "Sí, encontró dos cosas"],
    ["¿Usan la misma versión?", "Sí, la de la rama"],
    ["¿Nos prestan un tester?", "Pedíselo a tu líder"],
    ["¿Ese diseño es nuevo?", "Aprobado ayer"],
    ["¿La pantalla carga rápido?", "Ahora sí, con caché"],
    ["¿Cuántas filas tiene?", "Millones", "¿Paginan?", "Siempre"],
    ["Gracias por el endpoint", "De nada, ¿anda bien?"],
    ["¿El servidor está bien?", "Verde todo"],
    ["¿Me ayudás con un query?", "Mostrámelo"],
    ["¿Ya leyeron el reporte?", "El PM lo está leyendo"],
    ["Cambiaron la paleta", "¿Te gusta?", "Mucho más clara", "Idea del designer"],
    ["¿Tienen reunión hoy?", "Por suerte no"],
    ["¿Esto es un bug o feature?", "Depende a quién preguntes"],
    ["¿Ese botón hace algo?", "Todavía no", "¿Para cuándo?", "Próximo ticket"],
    ["¿Qué tal el líder nuevo?", "Organiza bien"],
    ["¿Ustedes también usan TS?", "Todo tipado"],
    ["Necesito un dato de prueba", "Usá el seed"],
    ["¿Me prestás la pizarra?", "Toda tuya"],
    ["¿Ese test es flaky?", "A veces", "Arreglémoslo", "Ahora mismo"],
    ["¿Ya tienen el token?", "Lo guarda el login"],
    ["Vine a saludar", "¡Hola, hola!"],
    ["¿Corrieron la colección?", "Toda en verde"],
    ["¿Quién pidió este cambio?", "El CEO", "Entonces va", "Sí, sí"],
    ["¿Cuánto tarda el build?", "Tres minutos"],
    ["¿El scraper respeta robots?", "Siempre"],
    ["¿Vieron el debate del QA?", "Fue intenso"],
    ["¿Me muestran el panel?", "Mirá, en vivo"],
    ["¿Qué café toman ustedes?", "El de la máquina"],
    ["¿Esto rompe algo?", "Nada, ya lo probé"],
    ["¿Tienen permiso para eso?", "Lo aprobó el CEO"],
    ["Su build está rojo", "¡Ya lo veo!", "¿Necesitás ayuda?", "Dame cinco minutos"],
    ["¿Vamos a la terraza?", "Después del deploy"],
    ["¿Ese endpoint pagina?", "Con cursor"],
    ["Hoy estrené teclado", "Se escucha desde acá"],
    ["¿Ya está el diseño?", "En docs/design"],
    ["¿Me pasás el esquema?", "Te lo mando"],
    ["¿Cómo está el líder?", "Contento con el reporte"],
  ];
  // Ratos libres en otros lugares de la oficina, con sus frases.
  const IDLE_SPOTS = {
    cooler: ["Hay que hidratarse", "Agua fresquita", "Un vasito y vuelvo", "Agua y a seguir"],
    window: ["Lindo día afuera", "¿Va a llover?", "Qué vista", "Cinco minutos de aire"],
    printer: ["¿Quién imprimió 40 páginas?", "Se trabó el papel", "Ya salió", "¿Era a doble faz?"],
    plants: ["Hay que regarla", "Creció un montón", "Está hermosa", "Le hace falta sol"],
  };
  // Charlas de a dos junto al dispensador de agua.
  const COOLER_CHATS = [
    ["¿Viste el último deploy?", "Salió perfecto", "¿Sin rollback?", "Ni uno"],
    ["¿Qué tal el fin de semana?", "Corto, como siempre"],
    ["¿Probaste la cafetera?", "El doble es otra cosa"],
    ["¿Cómo va tu ticket?", "Tests en verde, esperando review"],
    ["¿Te sumás al after?", "Si cierro el PR, sí"],
  ];
  const COFFEE_LINES = ["café", "¡Recién hecho!", "Un cafecito", "Sin azúcar", "Doble, por favor", "Agua y vuelvo", "Ahora sí", "Lo necesitaba", "Último del día", "Café y a seguir"];
  const shortText = (v, n) => { v = String(v || ""); return v.length > n ? v.slice(0, n - 1) + "…" : v; };
  const exitSpot = a => { const s = seatOf(a); return { x: s.x + (a.seat[0] < 96 ? 42 : -42), y: s.y + 28, room: a.room }; };
  function visitSpot(b, from) {
    if (b.pos) { const side = from && from.x < b.pos.x ? -1 : 1; return { x: b.pos.x + side * 24, y: b.pos.y, room: b.curRoom }; }
    return exitSpot(b);
  }
  function resolveSpot(a, to) {
    if (to.visit) return visitSpot(agent(to.visit), a.pos);
    if (to.coffee) { const x = (a.pos || seatOf(a)).x; return COFFEE.slice().sort((p, q) => Math.abs(p.x - x) - Math.abs(q.x - x))[0]; }
    if (to.debate !== undefined) { const r = room("qa"); return { x: r.x + DEBATE[to.debate][0], y: r.y + DEBATE[to.debate][1], room: "qa" }; }
    if (to.spot) {
      if (to.spot === "window" || to.spot === "printer") { const r = room(a.room); return { x: r.x + 96, y: r.y + 52, room: a.room }; }
      const s = { cooler: COFFEE[1], cooler2: { x: 40, y: 230 }, plants: { x: 300, y: 222 } }[to.spot] || COFFEE[0];
      return { x: s.x, y: s.y, room: "hall" };
    }
    return to;
  }
  const posOf = p => p.pos || (p.id === "pm" ? { x: p.x, y: p.y } : seatOf(p));
  function faceTo(p, q) { if (!p || !q) return; p.facing = posOf(q).x >= posOf(p).x ? 1 : -1; }
  function clearAnim(a) { a.pos = null; a.path = []; a.acts = []; a.say = null; a.pose = null; a.prop = null; a.curRoom = a.room; a.idleTrip = false; a.facing = 1; }
  function cancelIdle(a) { if (a && a.idleTrip) { a.acts = [{ k: "home" }, { k: "prop", prop: null }]; a.idleTrip = false; } }
  function pose(id, kind, d) { const a = agent(id); if (a && a.present && !a.pos) a.pose = { kind, until: state.t + d }; }
  function later(id, d, kind) { const a = agent(id); if (a && a.present) a.acts.push({ k: "wait", d }, { k: "pose", pose: kind, d: 2.5 }); }
  // A camina hasta B, charlan (las líneas se alternan: A, B, A...) y A vuelve.
  function talkTo(fromId, toId, lines) {
    const a = agent(fromId), b = agent(toId);
    if (!a || !b || !a.present || !b.present || a === b) return;
    cancelIdle(a); cancelIdle(b);
    a.acts.push({ k: "go", to: { visit: toId } }, { k: "talk", with: toId, lines }, { k: "home" });
  }
  // Pizza de compensación: el que más tokens gastó desde la última pizza (nunca el PM
  // ni el CEO) recibe una, como esos jefes que pagan el trabajo extra con pizza.
  function topWorker(base) {
    let best = null, most = 0;
    state.agents.forEach(a => { const d = a.tokens - (base[a.id] || 0); if (a.present && a.provider && d > most) { most = d; best = a; } });
    state.agents.forEach(a => { base[a.id] = a.tokens; });
    return best && { a: best, n: most };
  }
  const pizzaText = w => "Llega la pizza para " + w.a.label + ", el que más tokens gastó en este encargo (" + fmtK(w.n) + "). El trabajo extra se paga con pizza.";
  function pizzaForTop() {
    const w = topWorker(state.pizzaBase);
    if (!w) return;
    state.facts.pizzas += 1;
    state.pizzaWins[w.a.id] = (state.pizzaWins[w.a.id] || 0) + 1;
    addFeed(pizzaText(w), "good");
    deliverPizza(w.a.id);
  }
  // Entra un repartidor por el pasillo, le da la pizza y se va.
  function deliverPizza(id) {
    const b = agent(id);
    if (!b || !b.present) return;
    if (reduced) { state.pizza[id] = state.t + 150; return; }
    const sx = posOf(b).x < W / 2 ? -14 : W + 14;
    sfx("bell");
    state.courier = { id: "courier", label: "Repartidor", role: "courier", color: "red", look: 4, provider: null, status: "idle", to: id,
      pos: { x: sx, y: HALL_Y }, curRoom: "hall", room: "hall", path: [], facing: sx < 0 ? 1 : -1, say: null, prop: "pizza",
      acts: [{ k: "go", to: { visit: id } }, { k: "say", text: "¡Pizza para vos!", d: 2 }, { k: "give" }, { k: "say", text: "¡Buen provecho!", d: 1.8 },
        { k: "go", to: { x: sx, y: HALL_Y, room: "hall" } }, { k: "gone" }] };
  }
  function courierTick(dt) {
    const c = state.courier;
    if (!c) return;
    if (c.say && state.t > c.say.until) c.say = null;
    for (let guard = 0; c.acts.length && guard < 6; guard++) {
      const act = c.acts[0];
      if (act.k === "gone") { state.courier = null; return; }
      if (act.k === "give") {
        const b = agent(c.to);
        state.pizza[c.to] = state.t + 150;
        c.prop = null;
        if (b) { b.say = { text: "¡Gracias!", until: state.t + 2.2 }; pose(c.to, "celebrate", 2); }
        c.acts.shift();
        continue;
      }
      if (act.t0 === undefined) beginAct(c, act);
      if (!stepAct(c, act, dt)) return;
      c.acts.shift();
    }
  }

  // Dos QA se juntan frente a la pizarra y discuten los hallazgos.
  function debate(id1, id2, lines) {
    const a = agent(id1), b = agent(id2);
    if (!a || !b || !a.present || !b.present) return;
    cancelIdle(a); cancelIdle(b);
    const key = "debate" + Math.random().toString(36).slice(2);
    a.acts.push({ k: "go", to: { debate: 0 } }, { k: "talk", with: id2, lines, key }, { k: "home" });
    b.acts.push({ k: "go", to: { debate: 1 } }, { k: "hold", key }, { k: "home" });
  }

  function beginAct(a, act) {
    act.t0 = state.t;
    if (act.k === "go" || act.k === "home") {
      if (!a.pos) { const e = exitSpot(a); a.pos = { x: e.x, y: e.y }; a.curRoom = a.room; a.pose = null; }
      const to = act.k === "home" ? exitSpot(a) : resolveSpot(a, act.to);
      a.path = planPath({ x: a.pos.x, y: a.pos.y, room: a.curRoom }, to);
      a.dest = to;
    } else if (act.k === "talk") { act.i = -1; act.next = 0; act.waited = 0; }
    else if (act.k === "pose") { if (!a.pos) a.pose = { kind: act.pose, until: state.t + act.d }; }
    else if (act.k === "prop") a.prop = act.prop;
    else if (act.k === "say") a.say = { text: act.text, until: state.t + act.d };
  }
  function stepAct(a, act, dt) {
    const el = state.t - act.t0;
    if (act.k === "go" || act.k === "home") {
      const target = a.path[0];
      if (target) {
        const dx = target.x - a.pos.x, dy = target.y - a.pos.y, dist = Math.hypot(dx, dy), step = SPEED * dt;
        if (Math.abs(dx) > 0.5) a.facing = dx > 0 ? 1 : -1;
        if (dist <= step) { a.pos.x = target.x; a.pos.y = target.y; a.path.shift(); }
        else { a.pos.x += dx / dist * step; a.pos.y += dy / dist * step; }
        if (a.path.length) return false;
      }
      a.curRoom = a.dest.room;
      if (act.k === "home") { a.pos = null; a.curRoom = a.room; a.facing = 1; }
      else if (act.to.visit) faceTo(a, agent(act.to.visit));
      else if (act.to.coffee) a.facing = a.pos.x > W / 2 ? 1 : -1;
      return true;
    }
    if (act.k === "talk") {
      const b = agent(act.with);
      // Si el otro todavía está caminando, lo espera (hasta 20 segundos).
      if (b && b.acts.length && b.acts[0].k === "go" && (act.waited += dt) < 20) return false;
      if (state.t < act.next) return false;
      act.i += 1;
      if (act.i >= act.lines.length) { if (act.key) state.holds[act.key] = true; return true; }
      const speaker = act.i % 2 === 0 || !b ? a : b, other = speaker === a ? b : a;
      speaker.say = { text: act.lines[act.i], until: state.t + 1.9 };
      faceTo(speaker, other); faceTo(other, speaker);
      act.next = state.t + 2.1;
      return false;
    }
    if (act.k === "hold") return !!state.holds[act.key] || el > 40;
    if (act.k === "wait" || act.k === "pose" || act.k === "say") return el >= act.d;
    return true;
  }
  function animTick(dt) {
    state.agents.forEach(a => {
      if (!a.present) { if (a.pos || a.acts.length) clearAnim(a); return; }
      if (a.say && state.t > a.say.until) a.say = null;
      if (a.pose && state.t > a.pose.until) a.pose = null;
      let guard = 0;
      while (a.acts.length && guard++ < 6) {
        const act = a.acts[0];
        if (act.t0 === undefined) beginAct(a, act);
        if (!stepAct(a, act, dt)) break;
        a.acts.shift();
      }
      if (!a.acts.length) a.idleTrip = false;
    });
    courierTick(dt);
    idleLife();
  }
  // Cada tanto, alguien libre va a buscar un café, se estira o charla con alguien libre,
  // de su departamento o de otro.
  function idleLife() {
    if (reduced || state.t < state.nextIdle) return;
    state.nextIdle = state.t + 5 + Math.random() * 6;
    const free = state.agents.filter(a => a.present && a.provider && a.room !== "meet" && a.status === "idle" && !a.pos && !a.acts.length && !a.pose);
    if (!free.length || state.agents.filter(a => a.idleTrip).length >= 3) return;
    // Nadie se va mientras otro viene a hablarle.
    const visited = new Set(state.agents.flatMap(x => x.acts.map(k => k.with || (k.to && k.to.visit)).filter(Boolean)));
    const avail = free.filter(b => !visited.has(b.id));
    if (!avail.length) return;
    const a = avail[Math.floor(Math.random() * avail.length)], r = Math.random();
    const others = avail.filter(b => b !== a);
    const same = others.filter(b => b.room === a.room), far = others.filter(b => b.room !== a.room);
    const goFar = far.length > 0 && (!same.length || Math.random() < 0.55);
    const mates = goFar ? far : same;
    const breaks = hallBreaks(), say = list => ({ k: "say", text: list[Math.floor(Math.random() * list.length)], d: 2.2 });
    if (r < 0.35 && breaks.length && Math.random() < 0.5) {
      // Lo que compraron para el pasillo también se usa: la máquina, el dispensador.
      const b = breaks[Math.floor(Math.random() * breaks.length)];
      a.idleTrip = true;
      a.acts.push({ k: "go", to: { x: b.x, y: b.y, room: "hall" } }, { k: "prop", prop: b.prop }, { k: "say", text: b.lines[Math.floor(Math.random() * b.lines.length)], d: 2.2 }, { k: "home" }, { k: "prop", prop: null });
    } else if (r < 0.2) {
      a.idleTrip = true;
      if (Math.random() < 0.5) setTimeout(() => sfx("coffee"), 2500);
      a.acts.push({ k: "go", to: { coffee: true } }, { k: "prop", prop: "cup" }, say(COFFEE_LINES), { k: "home" }, { k: "prop", prop: null });
    } else if (r < 0.42) {
      // Agua, ventana, impresora o plantas (la ventana y la impresora, en las oficinas de arriba).
      const spots = Object.keys(IDLE_SPOTS).filter(k => (k !== "window" && k !== "printer") || (room(a.room).top && a.room !== "meet"));
      const spot = spots[Math.floor(Math.random() * spots.length)];
      a.idleTrip = true;
      a.acts.push({ k: "go", to: { spot } }, ...(spot === "cooler" ? [{ k: "prop", prop: "cup" }] : []), say(IDLE_SPOTS[spot]), { k: "home" }, { k: "prop", prop: null });
    } else if (r < 0.52 && others.length) {
      // Dos se cruzan en el dispensador y charlan un rato.
      const b = others[Math.floor(Math.random() * others.length)], key = "agua" + Math.random().toString(36).slice(2);
      a.idleTrip = b.idleTrip = true;
      a.acts.push({ k: "go", to: { spot: "cooler" } }, { k: "talk", with: b.id, lines: COOLER_CHATS[Math.floor(Math.random() * COOLER_CHATS.length)], key }, { k: "home" });
      b.acts.push({ k: "go", to: { spot: "cooler2" } }, { k: "hold", key }, { k: "home" });
    } else if (r < 0.85 && mates.length) {
      const lines = goFar ? CHATS_OTHER : CHATS;
      a.idleTrip = true;
      a.acts.push({ k: "go", to: { visit: mates[Math.floor(Math.random() * mates.length)].id } });
      a.acts.push({ k: "talk", with: a.acts[0].to.visit, lines: lines[Math.floor(Math.random() * lines.length)] }, { k: "home" });
    } else {
      a.pose = { kind: "stretch", until: state.t + 2.2 };
    }
  }

