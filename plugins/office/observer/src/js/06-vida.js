  // --- Sonidos (opcionales) ----------------------------------------------------------
  // Sintetizados en el navegador, sin archivos. Apagados por defecto; se prenden con el
  // botón "Sonido", que también le da permiso al navegador para sonar.
  let audio = null;
  function sfx(kind) {
    if (!audio || !prefs.sound || document.hidden) return;
    const t = audio.currentTime;
    const tone = (f, d, at = 0, type = "square", vol = 0.05) => {
      const o = audio.createOscillator(), gn = audio.createGain();
      o.type = type; o.frequency.value = f;
      gn.gain.setValueAtTime(vol, t + at); gn.gain.exponentialRampToValueAtTime(0.0001, t + at + d);
      o.connect(gn).connect(audio.destination); o.start(t + at); o.stop(t + at + d + 0.02);
    };
    const noise = (d, at = 0, vol = 0.03) => {
      const buf = audio.createBuffer(1, Math.max(1, Math.floor(audio.sampleRate * d)), audio.sampleRate), ch = buf.getChannelData(0);
      for (let i = 0; i < ch.length; i++) ch[i] = (Math.random() * 2 - 1) * (1 - i / ch.length);
      const src = audio.createBufferSource(), gn = audio.createGain();
      gn.gain.value = vol; src.buffer = buf; src.connect(gn).connect(audio.destination); src.start(t + at);
    };
    if (kind === "type") noise(0.025, 0, 0.015);
    else if (kind === "coffee") { noise(0.7, 0, 0.012); tone(170, 0.6, 0, "sawtooth", 0.008); }
    else if (kind === "bell") { tone(880, 0.35, 0, "sine", 0.08); tone(660, 0.6, 0.3, "sine", 0.08); }
    else if (kind === "level") [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.18, i * 0.1, "square", 0.04));
    else if (kind === "achievement") [784, 988, 1175].forEach((f, i) => tone(f, 0.16, i * 0.08, "triangle", 0.06));
    else if (kind === "birthday") [392, 392, 440, 392, 523, 494].forEach((f, i) => tone(f, 0.25, i * 0.28, "triangle", 0.05));
    else if (kind === "power") { tone(110, 0.7, 0, "sawtooth", 0.05); noise(0.35, 0.1, 0.04); }
  }

  // --- Logros ------------------------------------------------------------------------
  // Hechos de la sesión, que se anotan desde el registro (en vivo) o desde el guion (en la
  // demo). Cada logro suma tokens al saldo de la tienda, pero no al nivel.
  const freshFacts = () => ({ firstTest: null, testFails: 0, streak: 0, passAfterFails: false, qaRejected: false, qaFixed: false,
    pr: false, merged: false, workers: new Set(), providers: new Set(), pizzas: 0, approvals: 0, blackout: false });
  const ACHIEVEMENTS = [
    { id: "verde", name: "Todo en verde a la primera", desc: "El primer resultado del tester de la sesión fue PASA.", bonus: 40000, ok: f => f.firstTest === "PASA" },
    { id: "tercera", name: "A la tercera va la vencida", desc: "El tester falló dos veces seguidas o más y después pasó.", bonus: 60000, ok: f => f.passAfterFails },
    { id: "qa", name: "QA rechazó y se corrigió", desc: "QA rechazó el trabajo y después lo aprobó.", bonus: 60000, ok: f => f.qaFixed },
    { id: "pr", name: "Primer PR", desc: "Se abrió el PR de la sesión.", bonus: 50000, ok: f => f.pr },
    { id: "merge", name: "PR mergeado", desc: "Se mergeó el PR.", bonus: 100000, ok: f => f.merged },
    { id: "equipo", name: "Trabajo en equipo", desc: "Trabajaron cuatro empleados o más.", bonus: 40000, ok: f => f.workers.size >= 4 },
    { id: "multi", name: "Multiproveedor", desc: "Trabajaron Claude y también Codex o Gemini.", bonus: 50000, ok: f => f.providers.has("claude") && (f.providers.has("codex") || f.providers.has("gemini")) },
    { id: "permiso", name: "Con permiso del CEO", desc: "Alguien pidió aprobación antes de seguir.", bonus: 20000, ok: f => f.approvals > 0 },
    { id: "pizza", name: "Pizza party", desc: "Llegaron tres pizzas.", bonus: 50000, ok: f => f.pizzas >= 3 },
    { id: "millon", name: "Millonario", desc: "La sesión gastó un millón de tokens.", bonus: 80000, ok: () => earned() >= 1e6 },
    { id: "decorador", name: "Decorador", desc: "Compraste diez artículos.", bonus: 50000, ok: () => !!game && game.buys.length >= 10 },
    { id: "cumple", name: "¡Feliz cumple!", desc: "Festejaron un cumpleaños en la oficina.", bonus: 30000, ok: () => !!(game && game.bday) },
    { id: "apagon", name: "Sobreviviste al apagón", desc: "Se cortó la luz de tanto test en rojo.", bonus: 30000, ok: f => f.blackout },
  ];
  const bonus = () => game && game.ach ? ACHIEVEMENTS.reduce((n, a) => n + (game.ach[a.id] ? a.bonus : 0), 0) : 0;
  function factTest(f, v) {
    if (f.firstTest === null) f.firstTest = v;
    if (v === "FALLA") { f.testFails += 1; f.streak += 1; }
    else if (v === "PASA") { if (f.streak >= 2) f.passAfterFails = true; f.streak = 0; }
  }
  function factQa(f, v) { if (v === "RECHAZADO") f.qaRejected = true; else if (v === "APROBADO" && f.qaRejected) f.qaFixed = true; }
  function achievementsTick() {
    if (!game || !state.facts) return;
    game.ach = game.ach || {};
    ACHIEVEMENTS.forEach(a => {
      if (game.ach[a.id] || !a.ok(state.facts)) return;
      game.ach[a.id] = Math.round(Date.now() / 1000);
      shopLog("Logro: " + a.name + ". " + a.desc + " (+" + fmtK(a.bonus) + " tokens para la tienda)", "good");
      sfx("achievement");
      gameSave();
    });
  }

  // --- Empleado del mes ---------------------------------------------------------------
  // Un cuadro en Reuniones con el que más pizzas ganó en la sesión (con empate, el que más
  // tokens gastó).
  function employeeOfMonth() {
    const wins = state.pizzaWins || {};
    return state.agents.filter(a => wins[a.id]).sort((p, q) => wins[q.id] - wins[p.id] || q.tokens - p.tokens)[0] || null;
  }
  function drawEmployeeOfMonth(r, now) {
    const top = employeeOfMonth(), fr = framed(r.x + 70, r.y + 2, 30, 24, "#d4a933");
    px(fr.x, fr.y, fr.w, fr.h, top ? "#4a3f5a" : "#3a3f4a");
    if (top) clipped(fr.x, fr.y, fr.w, fr.h, () => { px(fr.x + 3, fr.y + 13, 20, 8, ROLE_COLORS[top.color] || "#8b6cd6"); drawHead(fr.x + 5, fr.y + 3, look(top.look), { mood: "happy" }); });
    else { px(fr.x + 11, fr.y + 4, 4, 2, "#98a1b3"); px(fr.x + 14, fr.y + 6, 2, 3, "#98a1b3"); px(fr.x + 12, fr.y + 9, 2, 2, "#98a1b3"); px(fr.x + 12, fr.y + 13, 2, 2, "#98a1b3"); }
    if (top && Math.floor(now * 2) % 6 === 0) px(fr.x + 2, fr.y + 2, 1, 1, "#ffffff");
  }

  // --- Eventos al azar ----------------------------------------------------------------
  // Corte de luz: el tester falla tres veces seguidas (en la demo, a veces con una falla).
  function powerCut() { state.blackout = state.t + 6; sfx("power"); }
  // Cumpleaños: una vez por partida, en un momento al azar. Hay torta y vienen a saludar.
  function bdayTick() {
    if (!game || game.bday) return;
    const R = rng(hashStr("cumple:" + game.key));
    const live = mode === "live", at = live ? (state.live ? state.live.t0 : Infinity) + (15 + R() * 90) * 60 : 80 + R() * 60;
    if ((live ? Date.now() / 1000 : state.t) < at) return;
    const cands = state.agents.filter(a => a.present && a.provider);
    if (!cands.length) return;
    const b = cands[Math.floor(R() * cands.length)];
    game.bday = { id: b.id, at: Math.round(Date.now() / 1000) };
    gameSave();
    state.cake = { id: b.id, until: state.t + 180 };
    shopLog("Hoy cumple años " + b.label + ": hay torta en " + room(b.room).name + ".", "good");
    sfx("birthday");
    cands.filter(x => x !== b && x.status !== "working" && !x.pos).sort(() => R() - 0.5).slice(0, 2)
      .forEach(x => talkTo(x.id, b.id, ["¡Feliz cumple!", "¡Gracias! Hay torta"]));
  }
  // Mascotas: las que se compraron (gato, perro, robot) salen cada tanto a pasear.
  const PETS = ["gato", "perro", "robot"];
  function petTick(dt) {
    const w = state.petWalk;
    if (w) {
      for (let guard = 0; w.acts.length && guard < 4; guard++) {
        const act = w.acts[0];
        if (act.t0 === undefined) beginAct(w, act);
        if (!stepAct(w, act, dt * 0.6)) return;
        w.acts.shift();
      }
      if (!w.acts.length) state.petWalk = null;
      return;
    }
    if (reduced || state.t < (state.nextPet || 0)) return;
    state.nextPet = state.t + 40 + Math.random() * 50;
    const pets = [];
    Object.entries(placed.rooms).forEach(([rid, R]) => (R.small || []).forEach((it, i) => { if (it && PETS.includes(it.kind.k)) pets.push({ rid, i, it }); }));
    if (!pets.length) return;
    const p = pets[Math.floor(Math.random() * pets.length)], [sx, sy] = SLOTS[p.rid].small[p.i], r = room(p.rid);
    const home = r ? { x: r.x + sx, y: r.y + sy, room: p.rid } : { x: sx, y: sy, room: "hall" };
    const far = { x: 30 + Math.random() * (W - 60), y: HALL_Y + 8, room: "hall" };
    state.petWalk = { rid: p.rid, i: p.i, it: p.it, pos: { x: home.x, y: home.y }, curRoom: home.room, room: home.room, path: [], facing: 1, acts: [{ k: "go", to: far }, { k: "wait", d: 2.5 }, { k: "go", to: home }] };
  }
  const walkingPet = (rid, i) => state.petWalk && state.petWalk.rid === rid && state.petWalk.i === i;
  function drawPetWalking(w, now) {
    const { x, y } = w.pos, step = Math.floor(now * 8) % 2;
    if (w.it.kind.k !== "gato") { w.it.kind.draw(x, y + (step ? -1 : 0), w.it.v, now); return; }
    const [a, b] = w.it.v[0].c, d = w.facing;
    px(x - 6, y - 8, 12, 5, OUT); px(x - 5, y - 7, 10, 3, a);
    px(x - 5 + (step ? 1 : 0), y - 4, 2, 4, a); px(x + 3 - (step ? 1 : 0), y - 4, 2, 4, a);
    const hx = x + d * 6; px(hx - 3, y - 12, 6, 5, OUT); px(hx - 2, y - 11, 4, 3, a); px(hx - 2, y - 13, 1, 2, a); px(hx + 1, y - 13, 1, 2, a); px(hx + d, y - 10, 1, 1, b);
    px(x - d * 7, y - 13 + step, 1, 6, a);
  }
  // Una vez por cuadro: los eventos que no salen del registro.
  function lifeTick(dt) {
    bdayTick();
    achievementsTick();
    petTick(dt);
    if (state.cake && state.t > state.cake.until) state.cake = null;
    if (audio && prefs.sound && Math.random() < dt * 2.5 && state.agents.some(a => a.present && a.status === "working" && !a.pos)) sfx("type");
  }

  // --- Cierre del día -----------------------------------------------------------------
  // Un resumen de la sesión con la foto de la oficina, para mirar o descargar.
  function summaryLines() {
    const f = state.facts || freshFacts(), top = employeeOfMonth(), wins = Object.entries(state.pizzaWins || {}).filter(([id]) => agent(id)).sort((p, q) => q[1] - p[1]);
    const got = ACHIEVEMENTS.filter(a => game && game.ach && game.ach[a.id]);
    return [
      "## La sesión",
      "| Dato | Valor |", "| --- | --- |",
      "| Duración | " + clock(state.t) + " |",
      "| Tokens | " + fmtK(earned()) + " |",
      "| Nivel de la oficina | " + levelOf(earned()) + " |",
      "| Compras | " + (game ? game.buys.length : 0) + " (" + fmtK(spent()) + " tokens) |",
      "| Fallas del tester | " + f.testFails + " |",
      "| PR | " + (f.merged ? "mergeado" : f.pr ? "abierto" : "sin PR") + " |",
      "", "## Empleado del mes", top ? top.label + ", con " + state.pizzaWins[top.id] + (state.pizzaWins[top.id] === 1 ? " pizza" : " pizzas") + "." : "Todavía no llegó ninguna pizza.",
      "", "## Pizzas", ...(wins.length ? wins.map(([id, n]) => "- " + agent(id).label + ": " + n) : ["- Ninguna todavía."]),
      "", "## Logros (" + got.length + " de " + ACHIEVEMENTS.length + ")", ...(got.length ? got.map(a => "- **" + a.name + "** (+" + fmtK(a.bonus) + ")") : ["- Ninguno todavía."]),
    ];
  }
  function openSummary() {
    const lines = summaryLines(), photo = canvas.toDataURL("image/png");
    openDoc({ kind: "Cierre del día", title: mode === "live" ? "Así quedó la oficina hoy" : "Así quedó la oficina de la demo", at: Date.now() / 1000, t: state.t, text: lines.join("\n") });
    $("reader-body").insertAdjacentHTML("afterbegin", `<img class="photo" src="${photo}" alt="Foto de la oficina"><p><button type="button" id="dl-summary">Descargar imagen</button></p>`);
    $("dl-summary").addEventListener("click", () => downloadSummary(photo, lines));
  }
  function downloadSummary(photo, lines) {
    const img = new Image();
    img.onload = () => {
      const text = lines.filter(l => !/^\| ---/.test(l)).map(l => l.replace(/^## /, "").replace(/\*\*/g, "").replace(/^\| (.*) \| (.*) \|$/, "$1: $2")).filter(l => l !== "Dato: Valor");
      const pad = 24, lh = 26, c = document.createElement("canvas");
      c.width = img.width; c.height = img.height + pad * 2 + lh * text.length;
      const x = c.getContext("2d");
      x.fillStyle = "#12151d"; x.fillRect(0, 0, c.width, c.height);
      x.drawImage(img, 0, 0);
      x.font = "18px 'Space Mono', monospace"; x.textBaseline = "top";
      text.forEach((l, i) => { x.fillStyle = /^(La sesión|Empleado del mes|Pizzas|Logros)/.test(l) ? "#f2c14e" : "#ebe5d8"; x.fillText(l, pad, img.height + pad + i * lh); });
      const a = document.createElement("a");
      a.download = "oficina-" + new Date().toISOString().slice(0, 10) + ".png";
      a.href = c.toDataURL("image/png");
      a.click();
    };
    img.src = photo;
  }

