  // --- En vivo: los eventos de .office/observer/events.js ------------------------
  // La página se abre desde el disco, sin servidor: el archivo de eventos es JavaScript
  // ("OFFICE_EVENT({...});" por línea) y se vuelve a cargar cada 1,5 segundos.
  let noticeClosed = false;
  let mode = "demo", userPicked = false, liveEvents = [], liveCount = -1, liveFile = false, liveAnimFrom = -1, liveProc = null;
  const ROLE_SEAT = {
    "backend.architect": "barch", "frontend.architect": "farch", "frontend.designer": "dsgn", "devops.architect": "oarch",
    "backend.developer": "bdev", "backend.tester": "btest", "frontend.developer": "fdev", "frontend.tester": "ftest",
    "database.developer": "ddev", "database.tester": "dtest", "scraper.developer": "sdev", "scraper.tester": "stest",
    "devops.developer": "odev", "devops.tester": "otest",
    "backend.lead": "blead", "frontend.lead": "flead", "database.lead": "dlead", "scraper.lead": "slead", "devops.lead": "olead",
  };
  const ROOM_DEPT = { back: "backend", front: "frontend", db: "database", scrap: "scraper", ops: "devops" };
  const DEPTS = ["backend", "frontend", "database", "scraper", "devops"];
  const FAILS = ["FALLA", "RECHAZADO", "PROVEEDOR NO DISPONIBLE", "REGLAS ROTAS", "TIEMPO AGOTADO", "FALLO"];
  const roleFromType = t => {
    if (t === "office:qa") return "qa";
    // Claude Code identifica al líder como "<área>-lead" (en agent_type y from_type), no como "dept-<área>:lead".
    const lead = /^([a-z]+)-lead$/.exec(t || "");
    if (lead) return DEPTS.includes(lead[1]) ? lead[1] + ".lead" : null;
    const m = /^dept-([a-z]+):([a-z-]+)$/.exec(t || "");
    return m ? m[1] + "." + m[2] : null;
  };
  const stripRole = d => String(d || "").replace(/^\[[^\]]*\]\s*/, "");
  const hourOf = t => { if (!t) return "—"; const d = new Date(t * 1000); return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0"); };
  function toolLabel(tool, target) {
    const t = String(target || "");
    const cut = v => (v.length > 34 ? v.slice(0, 33) + "…" : v);
    if (/^(Edit|Write|MultiEdit|NotebookEdit)$/.test(tool)) return "edita " + cut(t);
    if (tool === "Read") return "lee " + cut(t);
    if (tool === "Grep" || tool === "Glob") return "busca " + cut(t);
    if (tool === "Bash") return /run-external\.sh/.test(t) ? "corre el proveedor" : "$ " + cut(t);
    if (tool === "Skill") return "skill " + cut(t.replace(/^office:/, ""));
    if (tool === "WebFetch" || tool === "WebSearch") return "busca en la web";
    return cut(tool + (t ? " " + t : ""));
  }

  function liveReset(sess) {
    const cfg = (sess && sess.config) || {};
    const depts = sess && Array.isArray(sess.departments) ? sess.departments : null;
    ROOMS.forEach(r => { const d = ROOM_DEPT[r.id]; r.off = !!(depts && d && !depts.includes(d)); });
    state.agents.forEach(a => {
      const base = AGENTS.find(b => b.id === a.id);
      Object.assign(a, { status: "idle", tool: "", task: "", tokens: 0, ext: 0, startedAt: null, bubble: null, bubbleUntil: 0, toolList: null, lastAct: 0, lastWhat: "", stuck: 0 }, NO_DOCS());
      let entry = null;
      if (a.id === "qa1" || a.id === "qa2") entry = (cfg.qa || ["claude"])[a.id === "qa1" ? 0 : 1] || null;
      else if (a.id === "adv") entry = (cfg.pm || [])[0] || null;
      else if (/\.lead$/.test(a.role || "")) entry = sess && sess.teams ? "claude" : null; // líderes: solo en el modo equipos
      else if (a.id !== "ceo") entry = (cfg[a.role] || ["claude"])[0];
      const dept = (a.role || "").split(".")[0];
      const deptOff = !!(depts && DEPTS.includes(dept) && !depts.includes(dept));
      a.present = a.id === "ceo" || (!!entry && !deptOff);
      if (entry) {
        const [p, m] = String(entry).split(":");
        a.provider = PROVIDERS[p] ? p : "claude";
        a.model = m || (a.provider === "claude" ? base.tier : "nivel " + base.tier);
      }
      if (a.id === "qa1" || a.id === "qa2") a.label = "QA (" + PROVIDERS[a.provider].name + ")";
    });
  }

  function seatFor(role, provider) {
    if (role === "qa") {
      const qs = ["qa1", "qa2"].map(agent).filter(a => a.present);
      const q = qs.find(a => a.provider === provider) || qs[0];
      return q ? q.id : null;
    }
    if (role === "pm") return agent("adv").present ? "adv" : null;
    const id = ROLE_SEAT[role];
    return id && agent(id).present ? id : null;
  }

  function setPMTarget(target) {
    if (state.pmTarget === target) return;
    state.pmTarget = target;
    const to = Object.assign(target === "door" ? DOOR_SPOT() : target === "ceo" || !agent(target) ? MEET_SPOT() : standSpot(target), { target });
    state.pm.path = planPath(state.pm, to);
    state.pm.dest = to;
  }

  // Reconstruye la oficina con todos los eventos de la sesión. Las animaciones (levantarse,
  // caminar, charlar) salen solo de los eventos nuevos y recientes, no de la historia.
  function liveRebuild() {
    const evs = liveEvents;
    if (liveAnimFrom < 0) liveAnimFrom = evs.length;      // al abrir la página: nada de la historia
    else if (liveAnimFrom > evs.length) liveAnimFrom = 0; // el archivo empezó de nuevo
    const animFrom = liveAnimFrom, nowS = Date.now() / 1000;
    liveAnimFrom = evs.length;
    // La sesión empieza en su último inicio (o /clear). Cuando Claude Code la retoma o
    // compacta la conversación, sigue siendo la misma: los datos del último evento de
    // sesión (rama, proveedores, modo equipos) se actualizan, pero nada vuelve a cero.
    let si = -1, last = -1;
    for (let i = evs.length - 1; i >= 0; i--) if (evs[i].type === "session") { if (last < 0) last = i; if (evs[i].source !== "resume" && evs[i].source !== "compact") { si = i; break; } }
    if (si < 0) si = evs.findIndex(e => e.type === "session");
    const sess = last >= 0 ? Object.assign({}, evs[si], evs[last], { t: evs[si].t }) : null;
    const base = si >= 0 ? si : 0;
    const list = evs.slice(base);
    const t0 = sess ? sess.t : (list[0] ? list[0].t : nowS);
    const sessKey = sess ? sess.t + ":" + base : "none";
    // Solo se procesan los eventos nuevos. Se empieza de cero si cambió la sesión, si el
    // archivo empezó de nuevo o si llegó otro evento de sesión (puede cambiar la configuración).
    let P = liveProc;
    const restart = !P || P.key !== sessKey || P.first !== (evs[0] && evs[0].t) || P.n > evs.length || evs.slice(P.n).some(e => e.type === "session");
    if (restart) {
      if (state.liveSession !== sessKey) { state.liveSession = sessKey; state.agents.forEach(clearAnim); state.holds = {}; state.nextIdle = 0; state.courier = null; state.pizza = {}; }
      liveReset(sess);
      state.live = { t0, sess, teams: !!(sess && sess.teams), pmTokens: 0, claudeSub: 0, ext: { codex: 0, gemini: 0 }, route: [], fails: 0, leads: {},
        board: { ticket: sess && sess.ticket, branch: sess && sess.branch, tests: null, qa: null, pr: null } };
      state.feed = [];
      state.docs = [];
      Object.assign(state.pm, NO_DOCS());
      state.facts = freshFacts();
      state.pizzaWins = {};
      P = liveProc = { key: sessKey, first: evs[0] && evs[0].t, n: base, pending: [], byAgent: {}, pizzaBase: {}, pmTarget: "door", pmStatus: "idle", pmTool: "", pmTask: "" };
    }
    const L = state.live, teams = L.teams, fx = [];
    const { pending, byAgent, pizzaBase } = P;
    let { pmTarget, pmStatus, pmTool, pmTask } = P;
    const tok = u => (u ? (u.i || 0) + (u.o || 0) + (u.cw || 0) : 0);
    const feed = (e, text, kind, doc) => state.feed.unshift({ at: e.t, t: e.t - t0, text, kind: kind || "", doc: doc || null });
    const docOf = (e, kind, title, text, extra) => newDoc(kind, title, text, Object.assign({ at: e.t }, extra));
    const leadSeat = dept => seatFor(dept + ".lead");
    const leadByName = name => { const m = /^([a-z]+)-lead\b/.exec(name || ""); return m ? leadSeat(m[1]) : null; };
    const isLeadRole = r => /\.lead$/.test(r || "");
    // El líder que coordina a un developer o tester, si su departamento trabaja en modo equipos.
    const managedBy = r => { const d = (r || "").split(".")[0]; return teams && /\.(developer|tester)$/.test(r || "") && L.leads[d] ? leadSeat(d) : null; };
    const goTo = seat => { pmTarget = seat; const rn = room(agent(seat).room).name; if (L.route[L.route.length - 1] !== rn) L.route.push(rn); };
    // De quién es un evento: por su agent_id o, si no se conoce, por su tipo de agente (líder).
    const seatOfEvent = (id, type) => {
      if (id && byAgent[id] && byAgent[id].seat) return byAgent[id].seat;
      if (isLeadRole(roleFromType(type))) { const seat = seatFor(roleFromType(type)); if (id && seat) byAgent[id] = { seat, role: roleFromType(type) }; return seat; }
      return null;
    };

    const step = (e, fresh) => {
      if (e.type === "session") { feed(e, e.source === "resume" ? "Se retoma la sesión de la oficina." : e.source === "compact" ? "Claude Code compacta la conversación; la sesión sigue." : "Empieza la sesión de la oficina."); }
      else if (e.type === "prompt") { pmTarget = "ceo"; pmStatus = "working"; pmTool = "conversa con el CEO"; pmTask = "Reunión con el CEO"; feed(e, "El CEO llama al PM."); }
      else if (e.type === "delegate") {
        const role = e.role || roleFromType(e.subagent_type);
        const provider = String(e.provider || "claude").toLowerCase();
        const seat = role ? seatFor(role, provider) : null;
        const dept = (role || "").split(".")[0];
        const what = stripRole(e.description) || "sin descripción";
        // En el modo equipos, el developer y el tester los encarga su líder, no el PM.
        // En el modo equipos, el developer y el tester los encarga su líder, nunca el PM. El PM es la
        // sesión principal y sus eventos no traen agent_id: si el encargo trae uno, es de un compañero
        // de equipo (el líder). Y si el líder del departamento ya está trabajando, también es suyo.
        const fromLead = /\.(developer|tester)$/.test(role || "") && leadSeat(dept) &&
          (isLeadRole(roleFromType(e.from_type)) || (e.from && byAgent[e.from] && isLeadRole(byAgent[e.from].role)) ||
           (teams && !!e.from && !(byAgent[e.from] && byAgent[e.from].seat)) || L.leads[dept]);
        const lead = fromLead ? leadSeat(dept) : null;
        // Un compañero de equipo que no conocíamos: desde ahora sus herramientas y mensajes son del líder.
        if (lead && e.from && !byAgent[e.from]) byAgent[e.from] = { seat: lead, role: dept + ".lead" };
        pending.push({ type: e.subagent_type, seat, role, provider, model: e.xmodel || null, desc: e.description || "", lead });
        const who = seat ? agent(seat).label : (role || e.subagent_type);
        const d = docOf(e, "Encargo", (lead ? agent(lead).label : "PM") + " → " + who + ": " + what, e.prompt);
        keepDoc(seat ? agent(seat) : null, d, "brief");
        keepDoc(lead ? agent(lead) : state.pm, d);
        if (lead) {
          const la = agent(lead);
          Object.assign(la, { status: "working", tool: "coordina: " + what });
          feed(e, la.label + " encarga a " + who + ": " + what + ".", "", d);
          if (fresh && seat) fx.push(() => talkTo(lead, seat, [shortText("Te paso: " + what, 30), "Dale, arranco"]));
          return;
        }
        if (seat) goTo(seat);
        pmStatus = "working";
        pmTool = "encarga: " + (stripRole(e.description) || role || e.subagent_type);
        if (isLeadRole(role) && seat) {
          L.leads[dept] = true;
          Object.assign(agent(seat), { status: "working", task: what, tool: "lee el encargo", startedAt: e.t - t0, bubble: null });
          if (fresh) fx.push(() => agent(seat).acts.push({ k: "wait", d: 2.5 }, { k: "say", text: "Entendido, lo reparto", d: 2.2 }));
        }
        feed(e, "PM encarga a " + who + (PROVIDERS[provider] && provider !== "claude" ? " (" + PROVIDERS[provider].name + ")" : "") + ": " + what + ".", "", d);
        if (fresh && role === "qa" && /valid/i.test(String(e.mode || "") + " " + String(e.description || ""))) fx.push(qaDebate);
      }
      else if (e.type === "start") {
        const role = roleFromType(e.agent_type);
        const i = pending.findIndex(p => p.type === e.agent_type || (isLeadRole(role) && p.role === role));
        const p = i >= 0 ? pending.splice(i, 1)[0] : { type: e.agent_type, seat: role ? seatFor(role, "claude") : null, role, provider: "claude", desc: "" };
        byAgent[e.agent] = p;
        if (p.seat) {
          const a = agent(p.seat);
          a.lastAct = e.t; a.lastWhat = "empieza";
          Object.assign(a, { status: "working", task: stripRole(p.desc) || a.task || "Trabajando", tool: "empieza", startedAt: e.t - t0, bubble: null });
          if (p.model) a.model = p.model;
          if (isLeadRole(p.role)) L.leads[p.role.split(".")[0]] = true;
        }
      }
      else if (e.type === "tool") {
        const label = toolLabel(e.tool, e.target);
        const seat = seatOfEvent(e.agent, e.agent_type);
        if (seat) Object.assign(agent(seat), { tool: label, lastAct: e.t, lastWhat: label });
        else if (!e.agent) {
          pmTool = label;
          if (e.tool === "Skill") feed(e, "PM usa la skill " + String(e.target || "").replace(/^office:/, "") + ".");
        }
      }
      else if (e.type === "stop") {
        const seat = seatOfEvent(e.agent, e.agent_type);
        const p = byAgent[e.agent] || (seat ? { seat, role: roleFromType(e.agent_type) } : null);
        const n = tok(e.usage);
        L.claudeSub += n;
        if (p && p.seat) {
          const a = agent(p.seat), v = e.verdict || "LISTO", bad = FAILS.includes(v);
          a.tokens += n;
          a.tool = "";
          a.status = v === "APROBACION" ? "waiting" : bad ? "fail" : "pass";
          a.bubble = v === "APROBACION" ? "pide aprobación" : v === "FALLO" ? "FALLÓ" : v === "VALIDACION" ? "VALIDÓ" : v;
          a.bubbleUntil = e.t + 12;
          if (v === "FALLA") L.fails += 1;
          if (/\.tester$/.test(p.role || "")) {
            L.board.tests = v;
            factTest(state.facts, v);
            if (v === "FALLA" && state.facts.streak === 3) {
              state.facts.blackout = true;
              feed(e, "Se cortó la luz: tres tests en rojo seguidos. A los pocos segundos volvió.", "alert");
              if (fresh) fx.push(powerCut);
            }
          }
          if (p.role === "qa") { L.board.qa = v; factQa(state.facts, v); }
          state.facts.workers.add(a.id); state.facts.providers.add(p.provider || a.provider);
          if (v === "APROBACION") state.facts.approvals += 1;
          const lead = p.lead || managedBy(p.role);
          const d = keepDoc(a, docOf(e, "Respuesta", a.label + ": " + a.bubble, e.text, { verdict: a.bubble }), "reply");
          keepDoc(lead ? agent(lead) : state.pm, d);
          feed(e, a.label + " terminó: " + a.bubble + (n ? " · " + fmt(n) + " tokens" : "") + ".", bad ? "alert" : v === "APROBACION" ? "warn" : "good", d);
          if (lead) {
            // Modo equipos: el resultado se queda en el departamento.
            if (fresh) fx.push(() => {
              if (v === "FALLA" && /\.tester$/.test(p.role || "")) {
                const dev = seatFor(p.role.replace(/tester$/, "developer"));
                if (dev) { talkTo(p.seat, dev, ["FALLA: mirá esto", "Uh, lo corrijo"]); later(dev, 4.5, "scratch"); }
                else talkTo(p.seat, lead, ["FALLA", "Lo vemos"]);
              } else {
                if (!bad) pose(p.seat, "celebrate", 2);
                talkTo(p.seat, lead, [/\.tester$/.test(p.role || "") ? a.bubble + ": todo en verde" : "Listo, terminé", "¡Bien!"]);
              }
            });
          } else {
            // El PM va a buscar el reporte al departamento que terminó.
            goTo(p.seat);
            pmStatus = "working";
            pmTool = v === "APROBACION" ? "lee el pedido de aprobación" : "busca el reporte de " + room(a.room).name;
            if (fresh && !bad && v !== "APROBACION") fx.push(() => pose(p.seat, "celebrate", 2));
          }
        }
      }
      else if (e.type === "message") {
        const text = e.text || "";
        const toLead = leadByName(e.to);
        let fromSeat = seatOfEvent(e.from, e.from_type);
        if (!fromSeat && !toLead) { const act = Object.keys(L.leads); if (act.length === 1) fromSeat = leadSeat(act[0]); }
        if (fromSeat && isLeadRole(agent(fromSeat).role)) {
          const la = agent(fromSeat), approval = /aprobaci/i.test(text);
          Object.assign(la, { status: approval ? "waiting" : "pass", tool: "", bubble: approval ? "pide aprobación" : /report/i.test(text) ? "REPORTE" : "MENSAJE", bubbleUntil: e.t + 12 });
          goTo(fromSeat);
          pmStatus = "working";
          pmTool = approval ? "lee el pedido de aprobación" : "busca el reporte de " + room(la.room).name;
          const d = keepDoc(state.pm, keepDoc(la, docOf(e, "Mensaje", la.label + " al PM" + (text ? ": " + text : ""), e.body || text)));
          feed(e, la.label + " al PM: " + (text || "mensaje") + ".", approval ? "warn" : "good", d);
          if (fresh) fx.push(() => la.acts.push({ k: "wait", d: 2 }, { k: "say", text: approval ? "Necesito tu OK" : "Acá está el reporte", d: 2.5 }));
        } else if (toLead) {
          const la = agent(toLead);
          Object.assign(la, { status: "working", tool: "lee el mensaje del PM", bubble: null });
          goTo(toLead);
          pmStatus = "working"; pmTool = "habla con " + la.label;
          const d = keepDoc(state.pm, keepDoc(la, docOf(e, "Mensaje", "PM a " + la.label + (text ? ": " + text : ""), e.body || text)));
          feed(e, "PM a " + la.label + ": " + (text || "mensaje") + ".", "", d);
          if (fresh) fx.push(() => la.acts.push({ k: "wait", d: 2.5 }, { k: "say", text: "Recibido", d: 2 }));
        } else if (text || e.body) feed(e, "Mensaje: " + (text || "sin resumen") + ".", "", docOf(e, "Mensaje", "Mensaje" + (e.to ? " a " + e.to : ""), e.body || text));
      }
      else if (e.type === "teammate_idle") {
        const seat = leadByName(e.name);
        if (seat) { const la = agent(seat); if (la.status === "working") { la.status = "idle"; la.tool = ""; } }
      }
      else if (e.type === "pr") {
        const was = L.board.pr;
        L.board.pr = { number: e.number, url: e.url, state: e.state };
        state.facts.pr = true; if (e.state === "merged") state.facts.merged = true;
        if (!was || was.number !== e.number) feed(e, "Se abrió el PR #" + e.number + ".", "good");
        else if (was.state !== e.state && e.state === "merged") feed(e, "Se mergeó el PR #" + e.number + ".", "good");
      }
      else if (e.type === "task") {
        feed(e, (e.state === "completed" ? "Tarea terminada" : "Tarea nueva") + ": " + (e.subject || "sin título") + (e.name ? " (" + e.name + ")" : "") + ".", e.state === "completed" ? "good" : "");
      }
      else if (e.type === "external") {
        const prov = e.provider, n = e.tokens || 0;
        if (prov in L.ext) L.ext[prov] += n;
        const seat = seatFor(e.role, prov);
        if (seat) { const a = agent(seat); a.tokens += n; a.ext += n; if (e.model) a.model = e.model; }
        feed(e, (PROVIDERS[prov] ? PROVIDERS[prov].name : prov) + " (" + e.role + "): " + (e.result || "terminó") + " en " + clock(e.duration || 0) + (n ? " · " + fmt(n) + " tokens" : "") + ".", e.code ? "alert" : "");
      }
      else if (e.type === "external_start") {
        const seat = seatFor(e.role, e.provider);
        if (seat) { const a = agent(seat); if (e.model) a.model = e.model; a.tool = "trabaja en " + (PROVIDERS[e.provider] ? PROVIDERS[e.provider].name : e.provider); a.lastAct = e.t; a.lastWhat = a.tool; }
      }
      else if (e.type === "notify") {
        pmStatus = "waiting";
        const perm = /permis|permission/i.test(e.message || "");
        pmTool = perm ? "te pide un permiso" : "esperando al CEO";
        feed(e, "Claude Code: " + (e.message || "espera al CEO") + ".", "warn");
        if (fresh) alertCEO("permiso", perm ? "Claude Code te pide un permiso" : "El PM te está esperando", e.message || "Mirá la terminal.");
      }
      else if (e.type === "turn_end") {
        L.pmTokens = tok(e.usage) || L.pmTokens;
        pmTarget = "door"; pmStatus = "waiting"; pmTool = "espera que el CEO lo llame";
        const d = keepDoc(state.pm, docOf(e, "Respuesta", "PM al CEO", e.text), "reply");
        feed(e, "El PM le responde al CEO y espera afuera.", "", d);
        if (fresh) alertCEO("pm", "El PM te respondió", shortText(String(e.text || "Mirá la terminal.").replace(/[#*`|>]+/g, " ").replace(/\s+/g, " ").trim(), 140));
        const w = topWorker(pizzaBase);
        if (w) {
          state.facts.pizzas += 1;
          state.pizzaWins[w.a.id] = (state.pizzaWins[w.a.id] || 0) + 1;
          feed(e, pizzaText(w), "good");
          if (fresh) fx.push(() => deliverPizza(w.a.id));
          else if (!(state.courier && state.courier.to === w.a.id)) state.pizza[w.a.id] = Math.max(state.pizza[w.a.id] || 0, e.t - t0 + 150);
        }
      }
    };
    for (let j = P.n; j < evs.length; j++) step(evs[j], j >= animFrom && nowS - evs[j].t < 30);
    P.n = evs.length;
    Object.assign(P, { pmTarget, pmStatus, pmTool, pmTask });
    state.tokens = { claude: L.pmTokens + L.claudeSub, codex: L.ext.codex, gemini: L.ext.gemini };
    stuckCheck(nowS);
    // La partida de la tienda es todo el registro de la sesión (el archivo empieza de nuevo
    // con cada sesión), aunque Claude Code la retome o la compacte en el medio.
    let pmAll = 0;
    liveEarned = evs.reduce((n, e) => { if (e.type === "turn_end" && tok(e.usage)) pmAll = tok(e.usage); return n + (e.type === "stop" ? tok(e.usage) : e.type === "external" ? e.tokens || 0 : 0); }, 0) + pmAll;
    liveGameKey = "live:" + ((sess && sess.project) || "") + ":" + (evs[0] ? evs[0].t : "none");
    if (game && game.key === liveGameKey) mergeShopLog();
    loadPrev();
    Object.assign(state.pm, { status: pmStatus, tool: pmTool, task: pmTask || "Coordina la oficina", tokens: L.pmTokens });
    if (!agent(state.selected) && state.selected !== "pm") state.selected = "pm";
    else if (state.selected !== "pm" && !agent(state.selected).present) state.selected = "pm";
    setPMTarget(pmTarget);
    // Quien recibe trabajo deja el café; después, las animaciones de lo nuevo.
    state.agents.forEach(a => { if (a.status === "working") cancelIdle(a); });
    fx.forEach(f => f());
    $("ticket").innerHTML = sess
      ? "<b>" + esc(sess.project || "proyecto") + "</b>" + (sess.ticket ? " · <b>" + esc(sess.ticket) + "</b>" : "") + (sess.branch ? " · " + esc(sess.branch) : "") + (teams ? " · modo equipos" : "")
      : "Sin sesión todavía";
  }

  // Los dos QA debaten cuando el PM pide la validación cruzada.
  function qaDebate() {
    const qs = ["qa1", "qa2"].map(agent).filter(a => a.present);
    if (qs.length >= 2 && !qs.some(a => a.acts.length && !a.idleTrip)) debate("qa1", "qa2", DEBATE_LINES);
  }

  // Un agente que trabaja y pasa varios minutos sin usar ninguna herramienta puede estar
  // trabado (o esperando un comando largo): se marca en la oficina y en la actividad.
  const STUCK = 8 * 60;
  let lastStuck = 0;
  function stuckCheck(now) {
    let changed = false;
    state.agents.forEach(a => {
      const quiet = a.present && a.status === "working" && a.lastAct ? now - a.lastAct : 0;
      const mins = quiet >= STUCK ? Math.floor(quiet / 60) : 0;
      if (mins !== a.stuck) { a.stuck = mins; changed = true; }
      const at = a.lastAct + STUCK, key = a.id + ":" + a.lastAct;
      if (mins && !state.feed.some(f => f.stuckKey === key)) {
        state.feed.push({ at, t: at - (state.live ? state.live.t0 : at), stuckKey: key, kind: "warn",
          text: a.label + " lleva " + Math.floor(STUCK / 60) + " minutos sin novedades (lo último: " + (a.lastWhat || "empezar") + "). Puede estar trabado o esperando un comando largo." });
        state.feed.sort((p, q) => q.at - p.at);
        if (state.live && now - at < 30) alertCEO("stuck", a.label + " puede estar trabado", "Lleva " + mins + " minutos sin novedades.");
      }
    });
    return changed;
  }
  function liveTick(dt) {
    const now = Date.now() / 1000;
    state.t = state.live ? now - state.live.t0 : 0;
    if (now - lastStuck > 5) { lastStuck = now; stuckCheck(now); }
    movePM(dt);
    state.agents.forEach(a => { if (a.bubble && now > a.bubbleUntil) { a.bubble = null; if (a.status === "pass") a.status = "idle"; } });
    animTick(dt);
  }

  function setMode(m) {
    mode = m;
    liveProc = null;
    if (m === "live") {
      state.pmTarget = null;
      state.agents.forEach(clearAnim);
      state.holds = {}; state.nextIdle = 0;
      liveAnimFrom = liveEvents.length;
      liveRebuild();
    } else {
      ROOMS.forEach(r => { r.off = false; });
      state = freshState();
      startStep();
      for (let i = 0; i < 120; i++) update(0.1);
      $("ticket").innerHTML = "<b>PROJ-123</b> Pedidos con estado · <b>feature/PROJ-123-pedidos</b> → epic/PROJ-100-checkout";
    }
    updateModeUI();
    renderPanel(true);
  }

  function updateModeUI() {
    const live = mode === "live";
    const chip = $("mode-chip");
    chip.textContent = live ? "EN VIVO" : "DEMO";
    chip.classList.toggle("live", live);
    $("btn-live").setAttribute("aria-pressed", String(live));
    $("btn-demo").setAttribute("aria-pressed", String(!live));
    $("demo-controls").hidden = live;
    $("notice").hidden = live || (liveFile && liveCount > 0) || noticeClosed;
  }

  // Cada script del registro junta sus eventos en su propio buffer, así events.js y
  // events.prev.js se pueden leer a la vez sin mezclarse.
  window.OFFICE_EVENT = e => { const sc = document.currentScript; if (sc && sc.officeBuf && e && typeof e === "object") sc.officeBuf.push(e); };
  function poll() {
    const buf = [];
    const sc = document.createElement("script");
    sc.officeBuf = buf;
    sc.src = "events.js?t=" + Date.now();
    sc.onload = () => {
      sc.remove();
      liveFile = true;
      // Un archivo a medio escribir no tiene que borrar lo que ya se ve.
      if (buf.length === 0 && liveCount > 0) return;
      if (buf.length !== liveCount) {
        liveCount = buf.length;
        liveEvents = buf;
        if (mode === "live") liveRebuild();
        else if (!userPicked && buf.length) setMode("live");
      }
      updateModeUI();
    };
    sc.onerror = () => { sc.remove(); liveFile = false; updateModeUI(); };
    document.head.appendChild(sc);
  }

  // La sesión anterior (events.prev.js), para comparar. Se lee una vez por sesión.
  let prevStats = null, prevFor = "";
  function sessionStats(evs) {
    const tk = u => (u ? (u.i || 0) + (u.o || 0) + (u.cw || 0) : 0);
    let tokens = 0, pm = 0, fails = 0, tasks = 0;
    evs.forEach(e => {
      if (e.type === "stop") { tokens += tk(e.usage); tasks += 1; if (e.verdict === "FALLA") fails += 1; }
      else if (e.type === "external") tokens += e.tokens || 0;
      else if (e.type === "turn_end" && tk(e.usage)) pm = tk(e.usage);
    });
    return { tokens: tokens + pm, fails, tasks, minutes: evs.length ? Math.round((evs[evs.length - 1].t - evs[0].t) / 60) : 0 };
  }
  function loadPrev() {
    if (prevFor === liveGameKey) return;
    prevFor = liveGameKey;
    const buf = [], sc = document.createElement("script");
    sc.officeBuf = buf;
    sc.src = "events.prev.js?t=" + Date.now();
    const done = () => { sc.remove(); prevStats = buf.length ? sessionStats(buf) : null; renderPanel(true); };
    sc.onload = done; sc.onerror = done;
    document.head.appendChild(sc);
  }

