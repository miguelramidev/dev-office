  // --- Avisos al CEO ---------------------------------------------------------------
  // Cuando el PM le responde, Claude Code pide un permiso o un agente parece trabado, la
  // pestaña avisa si está en segundo plano: el título parpadea y, si el CEO activó los
  // avisos, sale una notificación del sistema.
  const baseTitle = document.title;
  // El ícono de la pestaña, con un punto rojo mientras hay un aviso sin ver.
  const ICON = "data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 16 16%22 shape-rendering=%22crispEdges%22%3E%3Crect width=%2216%22 height=%2216%22 rx=%223%22 fill=%22%2312151d%22/%3E%3Crect x=%222%22 y=%223%22 width=%2212%22 height=%229%22 fill=%22%23f2c14e%22/%3E%3Crect x=%223%22 y=%224%22 width=%2210%22 height=%227%22 fill=%22%230e2a20%22/%3E%3Crect x=%224%22 y=%225%22 width=%225%22 height=%221%22 fill=%22%237fd6a4%22/%3E%3Crect x=%225%22 y=%227%22 width=%226%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3Crect x=%224%22 y=%229%22 width=%224%22 height=%221%22 fill=%22%239ab8ff%22/%3E%3Crect x=%227%22 y=%2212%22 width=%222%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3Crect x=%225%22 y=%2213%22 width=%226%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3C/svg%3E", ICON_ALERT = "data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 16 16%22 shape-rendering=%22crispEdges%22%3E%3Crect width=%2216%22 height=%2216%22 rx=%223%22 fill=%22%2312151d%22/%3E%3Crect x=%222%22 y=%223%22 width=%2212%22 height=%229%22 fill=%22%23f2c14e%22/%3E%3Crect x=%223%22 y=%224%22 width=%2210%22 height=%227%22 fill=%22%230e2a20%22/%3E%3Crect x=%224%22 y=%225%22 width=%225%22 height=%221%22 fill=%22%237fd6a4%22/%3E%3Crect x=%225%22 y=%227%22 width=%226%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3Crect x=%224%22 y=%229%22 width=%224%22 height=%221%22 fill=%22%239ab8ff%22/%3E%3Crect x=%227%22 y=%2212%22 width=%222%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3Crect x=%225%22 y=%2213%22 width=%226%22 height=%221%22 fill=%22%23f2c14e%22/%3E%3Ccircle cx=%2212.5%22 cy=%223.5%22 r=%223%22 fill=%22%23ef6b5b%22 stroke=%22%2312151d%22/%3E%3C/svg%3E";
  const setIcon = on => { const l = document.getElementById("favicon"); if (l) l.href = on ? ICON_ALERT : ICON; };
  let alertTimer = 0;
  const prefs = (() => { try { return JSON.parse(localStorage.getItem("dev-office-prefs") || "{}") || {}; } catch (e) { return {}; } })();
  const savePrefs = () => { try { localStorage.setItem("dev-office-prefs", JSON.stringify(prefs)); } catch (e) { /* sin almacenamiento: dura hasta recargar */ } };
  const canNotify = () => typeof Notification !== "undefined" && Notification.permission === "granted";
  function alertCEO(kind, title, body) {
    if (!document.hidden) return;
    let on = false;
    clearInterval(alertTimer);
    setIcon(true);
    alertTimer = setInterval(() => { on = !on; document.title = on ? "● " + title : baseTitle; }, 1000);
    if (prefs.notify && canNotify()) { try { new Notification(title, { body, tag: "dev-office-" + kind }); } catch (e) { /* el navegador no deja: queda el título */ } }
  }
  document.addEventListener("visibilitychange", () => { if (!document.hidden && alertTimer) { clearInterval(alertTimer); alertTimer = 0; document.title = baseTitle; setIcon(false); } });
  function renderAlertBtn() {
    const b = $("btn-alerts"), on = !!prefs.notify;
    b.setAttribute("aria-pressed", String(on));
    b.textContent = on ? "Avisos: sí" : "Avisos: no";
    b.title = on ? (canNotify() ? "Te avisa con una notificación cuando el PM te necesita." : "El navegador no permite notificaciones: solo parpadea el título de la pestaña.") : "Activá para recibir una notificación cuando el PM te necesita.";
  }

  // --- Panel -------------------------------------------------------------------
  const $ = id => document.getElementById(id);
  const fmt = n => Math.round(n).toLocaleString("es-AR");
  const clock = t => String(Math.floor(t / 60)).padStart(2, "0") + ":" + String(Math.floor(t % 60)).padStart(2, "0");
  const STATUS = { working: "TRABAJA", waiting: "ESPERA", pass: "LISTO", fail: "FALLA", idle: "LIBRE" };
  const esc = v => String(v == null ? "" : v).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

  function people() {
    const pm = state.pm;
    return [{ id: "pm", label: "PM", provider: "claude", model: "opus", tier: "opus", role: "pm", status: pm.status, tool: pm.tool, task: pm.task || "Coordina la oficina", tokens: pm.tokens, startedAt: 0, room: pm.room, docs: pm.docs, brief: pm.brief, reply: pm.reply }]
      .concat(state.agents.filter(a => a.provider && a.present));
  }

  function renderPhases() {
    if (mode === "live") {
      const route = state.live ? state.live.route : [];
      $("phases").innerHTML = route.length
        ? route.slice(-9).map((n, i, arr) => `<span class="phase ${i === arr.length - 1 ? "now" : "done"}">${esc(n)}</span>`).join("")
        : `<span class="phase">Todavía no hay encargos en esta sesión</span>`;
      return;
    }
    $("phases").innerHTML = PHASES.map((p, i) => `<span class="phase ${i < state.phase ? "done" : i === state.phase ? "now" : ""}">${i + 1}. ${p}</span>`).join("");
  }

  function compareTile() {
    if (!compareTile.at || compareTile.n !== liveEvents.length) { compareTile.at = sessionStats(liveEvents); compareTile.n = liveEvents.length; }
    const now = compareTile.at, pv = prevStats;
    const pct = pv.tokens ? Math.round((now.tokens - pv.tokens) / pv.tokens * 100) : 0;
    return `<div class="stat"><div class="k">Contra la anterior</div><div class="v" style="color:${pct > 0 ? "var(--accent)" : "var(--ok)"}">${pct > 0 ? "+" : ""}${pct}%</div>
      <div class="s">tokens ${fmtK(now.tokens)} (antes ${fmtK(pv.tokens)}) · fallas ${now.fails} (antes ${pv.fails}) · tareas ${now.tasks} (antes ${pv.tasks})</div></div>`;
  }
  function renderStats() {
    const t = state.tokens, total = t.claude + t.codex + t.gemini;
    const all = people();
    const active = all.filter(p => p.status === "working").length;
    const max = Math.max(1, t.claude, t.codex, t.gemini);
    const prov = k => `<div class="stat"><div class="k">${PROVIDERS[k].name}</div><div class="v">${fmt(t[k])}</div><div class="s">${total ? Math.round(t[k] / total * 100) : 0}% de los tokens</div><div class="bar"><i style="width:${(t[k] / max * 100).toFixed(1)}%;background:${PROVIDERS[k].color}"></i></div></div>`;
    $("stats").innerHTML = `
      <div class="stat"><div class="k">Tokens</div><div class="v">${fmt(total)}</div><div class="s">${mode === "live" ? "entrada, salida y caché escrita" : "en esta sesión"}</div></div>
      ${prov("claude")}${prov("codex")}${prov("gemini")}
      <div class="stat"><div class="k">Trabajando</div><div class="v">${active}</div><div class="s">de ${all.length} en la oficina</div></div>
      ${mode === "live" && prevStats ? compareTile() : ""}
      <div class="stat"><div class="k">Tiempo</div><div class="v">${clock(state.t)}</div><div class="s">${mode === "live" ? (state.live ? state.live.fails : 0) + " " + ((state.live && state.live.fails === 1) ? "falla" : "fallas") + " del tester" : (state.rounds + 1) + " " + (state.rounds ? "vueltas" : "vuelta") + " developer → tester"}</div></div>`;
  }

  // El panel se vuelve a pintar varias veces por segundo: solo se toca el HTML si cambió,
  // para no reemplazar un botón mientras alguien lo está tocando.
  const shown = {};
  function setHTML(id, html) { if (shown[id] !== html) { shown[id] = html; $(id).innerHTML = html; } }

  // Markdown simple (títulos, listas, tablas, código, negrita) para leer reportes y respuestas.
  // Todo el texto pasa por esc(): nada de lo que escribe un agente se interpreta como HTML.
  function md(src) {
    const inline = v => esc(v).replace(/`([^`]+)`/g, "<code>$1</code>").replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
      .replace(/(^|[\s(])(https:\/\/[^\s<)]+)/g, '$1<a href="$2" target="_blank" rel="noopener noreferrer">$2</a>');
    const isItem = l => /^\s*([-*+]|\d+[.)])\s+/.test(l);
    const isRow = l => /^\s*\|.*\|\s*$/.test(l);
    const lines = String(src || "").replace(/\r/g, "").split("\n");
    let out = "", i = 0;
    while (i < lines.length) {
      const l = lines[i];
      if (/^\s*```/.test(l)) {
        const buf = [];
        for (i++; i < lines.length && !/^\s*```/.test(lines[i]); i++) buf.push(lines[i]);
        i++;
        out += "<pre><code>" + esc(buf.join("\n")) + "</code></pre>";
      } else if (/^#{1,6}\s+/.test(l)) {
        const n = Math.min(6, /^#+/.exec(l)[0].length + 2);
        out += "<h" + n + ">" + inline(l.replace(/^#+\s+/, "")) + "</h" + n + ">";
        i++;
      } else if (isRow(l) && i + 1 < lines.length && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1])) {
        const cells = (r, tag) => r.trim().replace(/^\||\|$/g, "").split("|").map(c => "<" + tag + ">" + inline(c.trim()) + "</" + tag + ">").join("");
        out += "<div class=\"table\"><table><thead><tr>" + cells(l, "th") + "</tr></thead><tbody>";
        for (i += 2; i < lines.length && isRow(lines[i]); i++) out += "<tr>" + cells(lines[i], "td") + "</tr>";
        out += "</tbody></table></div>";
      } else if (isItem(l)) {
        const tag = /^\s*\d/.test(l) ? "ol" : "ul";
        out += "<" + tag + ">";
        for (; i < lines.length && isItem(lines[i]) && (/^\s*\d/.test(lines[i]) ? "ol" : "ul") === tag; i++) out += "<li>" + inline(lines[i].replace(/^\s*([-*+]|\d+[.)])\s+/, "")) + "</li>";
        out += "</" + tag + ">";
      } else if (!l.trim()) {
        i++;
      } else {
        const buf = [inline(l)];
        for (i++; i < lines.length && lines[i].trim() && !/^\s*(```|#{1,6}\s|\|)/.test(lines[i]) && !isItem(lines[i]); i++) buf.push(inline(lines[i]));
        out += "<p>" + buf.join("<br>") + "</p>";
      }
    }
    return out;
  }

  const docTime = d => d.at ? hourOf(d.at) : clock(d.t);
  const docLine = d => String(d.text).replace(/[#*`|>]+/g, " ").replace(/\s+/g, " ").trim();
  function openDoc(d) {
    if (!d) return;
    const clipped = /\n\[…\]$/.test(d.text);
    $("reader-kind").textContent = d.kind;
    $("reader-title").textContent = d.title;
    $("reader-meta").textContent = [docTime(d), d.verdict].filter(Boolean).join(" · ");
    $("reader-body").innerHTML = md(clipped ? d.text.replace(/\n\[…\]$/, "") : d.text) +
      (clipped ? "<p class=\"clip\">El registro guarda hasta 4000 caracteres de cada texto: el resto quedó afuera. Los reportes de los líderes están completos en <code>.office/reports/</code>.</p>" : "");
    $("reader-body").scrollTop = 0;
    const dlg = $("reader");
    if (typeof dlg.showModal === "function") { if (!dlg.open) dlg.showModal(); } else dlg.setAttribute("open", "");
  }
  function closeDoc() { const dlg = $("reader"); if (typeof dlg.close === "function") dlg.close(); else dlg.removeAttribute("open"); }

  function renderAgents() {
    const list = people().slice().sort((a, b) => (b.status === "working") - (a.status === "working") || b.tokens - a.tokens);
    setHTML("agents", list.map(a => `
      <button type="button" class="agent ${state.selected === a.id ? "sel" : ""}" data-id="${a.id}">
        <i class="dot" style="background:${PROVIDERS[a.provider].color}"></i>
        <span class="who"><b>${esc(a.label)}</b><span>${PROVIDERS[a.provider].name} · ${esc(a.model)} · ${fmt(a.tokens)} tokens</span></span>
        <span class="pill ${a.status}">${STATUS[a.status] || "LIBRE"}</span>
      </button>`).join(""));
  }

  const portrait = document.createElement("canvas");
  portrait.width = 56; portrait.height = 56;
  function drawPortrait(a, target) {
    const pg = portrait.getContext("2d");
    const saved = g;
    g = pg;
    const now = performance.now() / 1000;
    px(0, 0, 56, 56, "#232a38");
    px(0, 40, 56, 16, "#1b202b");
    if (a.id === "pm") {
      const lk = { skin: SKINS[0], hair: "#2a1c14", style: 0, glasses: false };
      drawTorso(28, 38, { role: "pm", id: "pm", provider: "claude" }, "purple");
      drawHead(20, 25, lk, { mood: a.status === "working" ? "focus" : "happy", blink: Math.floor(now * 2.2) % 19 === 0 });
      drawWear({ id: "pm" }, 28, 38, now);
    } else {
      const src = agent(a.id), lk = look(src.look);
      drawChair(28, 40, src.room);
      drawTorso(28, 38, src, src.color);
      drawHead(20, 25, lk, { mood: moodOf(src), blink: Math.floor(now * 2.2 + 3) % 17 === 0, glasses: (src.role || "").endsWith("architect") });
      if (!hasHat(src)) drawAccessory(28, 25, src, now);
      drawWear(src, 28, 38, now);
    }
    g = saved;
    const tc = target.getContext("2d");
    tc.imageSmoothingEnabled = false;
    tc.clearRect(0, 0, target.width, target.height);
    tc.drawImage(portrait, 10, 18, 36, 36, 0, 0, target.width, target.height);
  }

  function renderDetail() {
    const list = people();
    const a = list.find(p => p.id === state.selected) || list[0];
    const r = room(a.room);
    const elapsed = a.status === "working" && a.startedAt !== null ? clock(state.t - a.startedAt) : "—";
    const via = a.provider === "claude" ? "agente de Claude" : "por el puente office:external";
    const quote = a.status === "working" ? "“" + esc(a.tool || a.task) + "”" : a.status === "fail" ? "Encontré un problema." : a.status === "pass" ? "Listo." : a.status === "waiting" ? "Esperando al CEO." : "Disponible.";
    const open = (d, html) => d ? `<button type="button" class="open" data-doc="${d.id}">${html}</button>` : html;
    const docBtn = (d, label) => d ? `<button type="button" class="open doc-btn" data-doc="${d.id}"><small>${label} · ${docTime(d)}${d.verdict ? " · " + esc(d.verdict) : ""}</small><span>${esc(docLine(d))}</span></button>` : "—";
    const history = (a.docs || []).filter(d => d !== a.brief && d !== a.reply).slice(0, 8);
    setHTML("detail", `
      <h2>Empleado</h2>
      <div class="head">
        <canvas id="portrait" width="224" height="224" aria-label="Retrato de ${a.label}"></canvas>
        <div>
          <div class="name"><i style="width:12px;height:12px;display:inline-block;background:${PROVIDERS[a.provider].color}"></i>${a.label}</div>
          <div class="quote">${open(a.status === "working" ? a.brief : a.reply || a.brief, quote)}</div>
        </div>
      </div>
      <dl>
        <dt>Rol</dt><dd>${a.role}</dd>
        <dt>Proveedor</dt><dd>${PROVIDERS[a.provider].name}, ${via}</dd>
        <dt>Modelo</dt><dd>${esc(a.model)} · nivel ${a.tier} · razonamiento medio</dd>
        <dt>Oficina</dt><dd>${r ? r.name : "Pasillo"}</dd>
        <dt>Estado</dt><dd><span class="pill ${a.status}">${STATUS[a.status] || "LIBRE"}</span></dd>
        <dt>Tarea</dt><dd>${esc(a.task) || "—"}</dd>
        <dt>Ahora</dt><dd>${esc(a.tool) || "—"}${a.stuck ? ` <span class="pill waiting">${a.stuck} min sin novedades</span>` : ""}</dd>
        <dt>Tiempo</dt><dd>${elapsed}</dd>
        <dt>Tokens</dt><dd>${fmt(a.tokens)}</dd>
        <dt>${a.id === "pm" ? "Último encargo" : "Encargo"}</dt><dd>${docBtn(a.id === "pm" ? (a.docs || []).find(d => d.kind === "Encargo") : a.brief, "Encargo")}</dd>
        <dt>${a.id === "pm" ? "Al CEO" : "Respuesta"}</dt><dd>${docBtn(a.reply, a.id === "pm" ? "Respuesta al CEO" : "Respuesta")}</dd>
      </dl>
      ${history.length ? `<div class="history"><h3>Antes</h3>${history.map(d => `<button type="button" class="open" data-doc="${d.id}"><time>${docTime(d)}</time><span>${esc(d.kind)}: ${esc(d.title)}</span></button>`).join("")}</div>` : ""}`);
    drawPortrait(a, $("portrait"));
  }

  // Tienda: nivel, saldo y la vitrina de esta partida, agrupada por nivel.
  function renderShop() {
    if (!game) return;
    const e = earned(), lv = levelOf(e), next = LEVELS[lv], prev = LEVELS[lv - 1];
    const pct = next ? Math.min(100, (e - prev) / (next - prev) * 100) : 100;
    setHTML("shop-level", `<div class="lv"><b>Nivel ${lv}</b><span>${next ? "faltan " + fmtK(next - e) + " tokens para el nivel " + (lv + 1) : "nivel máximo"}</span></div>
      <div class="bar" role="progressbar" aria-label="Avance al próximo nivel" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(pct)}"><i style="width:${pct.toFixed(1)}%"></i></div>
      <div class="bal">Saldo <b>${fmtK(Math.max(0, e + bonus() - spent()))}</b> tokens · la sesión gastó ${fmtK(e)} · logros +${fmtK(bonus())} · en compras ${fmtK(spent())}</div>
      <div class="ach" aria-label="Logros">${ACHIEVEMENTS.map(a => `<span class="badge${game.ach && game.ach[a.id] ? " on" : ""}" title="${esc(a.desc)} (+${fmtK(a.bonus)} tokens)">${esc(a.name)}</span>`).join("")}</div>`);
    const rooms = shopRooms(), who = shopPeople();
    setHTML("shop-room", '<option value="">Automático</option>' + rooms.map(id => `<option value="${id}">${esc(id === "hall" ? "Pasillo" : room(id).name)}</option>`).join(""));
    setHTML("shop-who", '<option value="">Automático</option>' + who.map(p => `<option value="${p.id}">${esc(p.label)}</option>`).join(""));
    if (document.activeElement !== $("shop-room")) $("shop-room").value = shopRoom();
    if (document.activeElement !== $("shop-who")) $("shop-who").value = shopWho();
    const cats = ["Todo"].concat(CATS.filter(c => game.shop.some(it => it.kind.cat === c)));
    setHTML("shop-cats", cats.map(c => `<button type="button" data-cat="${c}" aria-pressed="${shopSel.cat === c}">${c}</button>`).join(""));
    // Lo que ya se puede comprar, del nivel más alto al más bajo; después, un adelanto
    // de los dos niveles que siguen.
    const show = game.shop.filter(it => (shopSel.cat === "Todo" || it.kind.cat === shopSel.cat) && it.lv <= lv + 2)
      .sort((p, q) => (p.lv > lv) - (q.lv > lv) || (p.lv > lv ? p.lv - q.lv : q.lv - p.lv));
    setHTML("shop-grid", show.length ? '<div class="items">' + show.map(it => {
      const c = canBuy(it), to = targetOf(it), locked = it.lv > lv;
      return `<article class="item${locked ? " locked" : ""}"><span class="lvl">Nivel ${it.lv}</span><img src="${preview(it)}" alt="" width="144" height="104">
        <div class="nm">${esc(it.name)}</div><div class="mt">${esc(it.kind.cat)} · para ${esc(destName(it, to))}</div>
        <button type="button" data-buy="${it.id}"${c.ok ? "" : " disabled"} title="${esc(c.why)}">${esc(c.label)}</button></article>`;
    }).join("") + "</div>" : '<p class="empty">La vitrina de hoy no trae artículos de esta categoría.</p>');
    setHTML("shop-note", `Catálogo general: ${fmt(CATALOG_SIZE)} artículos. Esta partida trae ${game.shop.length}, elegidos al azar para esta sesión, y con cada nivel se desbloquean más. Las compras se guardan en esta pestaña.`);
  }

  function renderFeed() {
    setHTML("feed", state.feed.slice(0, 40).map(e => `<li><time>${mode === "live" ? hourOf(e.at) : clock(e.t)}</time>${e.doc
      ? `<button type="button" class="open ${e.kind}" data-doc="${e.doc.id}" title="Leer en grande">${esc(e.text)}</button>`
      : `<span class="${e.kind}">${esc(e.text)}</span>`}</li>`).join(""));
  }

  let lastPanel = 0;
  function renderPanel(force) {
    if (!force && performance.now() - lastPanel < 250) return;
    lastPanel = performance.now();
    renderHud();
    if (!drawerTab) return;
    renderPhases(); renderStats(); renderAgents(); renderDetail(); renderFeed(); renderShop();
  }

  // --- Interacción -------------------------------------------------------------
  canvas.addEventListener("click", e => {
    const rect = canvas.getBoundingClientRect();
    const wx = (e.clientX - rect.left) / rect.width * W;
    const wy = (e.clientY - rect.top) / rect.height * H;
    if (wx >= BOARD.x && wx <= BOARD.x + BOARD.w && wy >= BOARD.y && wy <= BOARD.y + BOARD.h) { openBoard(); return; }
    let best = null, bestD = 28;
    const pmD = Math.hypot(state.pm.x - wx, state.pm.y - 22 - wy);
    if (pmD < bestD) { best = "pm"; bestD = pmD; }
    state.agents.forEach(a => { if (!a.provider || !a.present) return; const s = a.pos ? { x: a.pos.x, y: a.pos.y - 18 } : seatOf(a); const d = Math.hypot(s.x - wx, s.y - 4 - wy); if (d < bestD) { best = a.id; bestD = d; } });
    if (!best) return;
    state.selected = best;
    // Con la tienda abierta, lo próximo que se compre es para él y para su oficina.
    if (drawerTab === "tienda") { const a = agent(best); shopSel.who = best; shopSel.room = a && !room(a.room).off ? a.room : ""; renderPanel(true); }
    else { shopSel.room = shopSel.who = ""; openDrawer("empleado"); }
  });
  // Los textos completos se abren en grande. Si el panel se volvió a pintar entre que se apretó
  // y se soltó el botón, el click llega al contenedor: se usa el botón que se apretó.
  // Lo mismo con los botones de comprar.
  let pressedDoc = null, pressedBuy = null;
  document.addEventListener("pointerdown", e => {
    const b = e.target.closest("[data-doc]"), c = e.target.closest("[data-buy]");
    pressedDoc = b ? b.dataset.doc : null; pressedBuy = c && !c.disabled ? c.dataset.buy : null;
  });
  document.addEventListener("click", e => {
    const b = e.target.closest("[data-doc]");
    const id = b ? b.dataset.doc : e.target.closest("#detail, #feed") ? pressedDoc : null;
    pressedDoc = null;
    if (id != null && state.docs[Number(id)]) openDoc(state.docs[Number(id)]);
    const c = e.target.closest("[data-buy]");
    const item = c ? (c.disabled ? null : c.dataset.buy) : e.target.closest("#shop-grid") ? pressedBuy : null;
    pressedBuy = null;
    if (item && itemOf(item) && game) { buy(itemOf(item)); renderPanel(true); }
  });
  $("reader-close").addEventListener("click", closeDoc);
  $("reader").addEventListener("click", e => { if (e.target === $("reader")) closeDoc(); }); // tocar afuera cierra

  $("agents").addEventListener("click", e => { const b = e.target.closest(".agent"); if (b) { state.selected = b.dataset.id; shopSel.room = shopSel.who = ""; openDrawer("empleado"); } });
  $("shop-room").addEventListener("change", e => { shopSel.room = e.target.value; renderPanel(true); });
  $("shop-who").addEventListener("change", e => { shopSel.who = e.target.value; renderPanel(true); });
  $("shop-cats").addEventListener("click", e => { const b = e.target.closest("[data-cat]"); if (b) { shopSel.cat = b.dataset.cat; renderPanel(true); } });

  let playing = true, speed = 2;
  $("btn-play").addEventListener("click", () => {
    playing = !playing;
    $("btn-play").textContent = playing ? "Pausa" : "Seguir";
    $("btn-play").setAttribute("aria-pressed", String(!playing));
  });
  document.querySelectorAll("[data-speed]").forEach(b => b.addEventListener("click", () => {
    speed = Number(b.dataset.speed);
    document.querySelectorAll("[data-speed]").forEach(o => o.setAttribute("aria-pressed", String(o === b)));
  }));
  $("btn-restart").addEventListener("click", () => { state = freshState(); startStep(); renderPanel(true); });

  // La oficina ocupa todo el lugar libre de la ventana sin deformarse, debajo de los
  // botones de arriba (y al lado del panel, si está abierto en una pantalla ancha).
  function resize() {
    const st = $("stage"), cs = getComputedStyle(st);
    const top = Math.max($("hud-left").getBoundingClientRect().bottom, $("hud-right").getBoundingClientRect().bottom) + 8;
    st.style.paddingTop = Math.round(top) + "px";
    const aw = st.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    const ah = st.clientHeight - top - parseFloat(cs.paddingBottom);
    const k = Math.max(0.1, Math.min(aw / W, ah / H));
    canvas.style.width = Math.floor(W * k) + "px";
    canvas.style.height = Math.floor(H * k) + "px";
    S = Math.max(1, Math.round(k * (window.devicePixelRatio || 1)));
    canvas.width = W * S; canvas.height = H * S;
  }
  new ResizeObserver(resize).observe($("stage"));
  new ResizeObserver(resize).observe($("hud-right"));
  resize();

  // --- Paneles: el panel lateral con pestañas y la barra de arriba -------------------
  let drawerTab = null, seenFeed = null;
  // La pista de abajo se va con el primer click; el aviso de la demo, cuando lo cierran.
  const dropHint = () => { $("hint").hidden = true; };
  document.addEventListener("pointerdown", dropHint, { once: true });
  $("notice-close").addEventListener("click", () => { noticeClosed = true; updateModeUI(); });
  const app = $("app");
  function openDrawer(tab) {
    drawerTab = tab;
    $("drawer").hidden = false;
    app.classList.add("drawer-open");
    app.classList.toggle("wide", tab === "tienda");
    document.querySelectorAll("[data-panel]").forEach(p => { p.hidden = p.dataset.panel !== tab; });
    document.querySelectorAll("[data-tab]").forEach(b => b.setAttribute("aria-selected", String(b.dataset.tab === tab)));
    document.querySelectorAll("[data-open]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.open === tab)));
    $("drawer").querySelector(".drawer-body").scrollTop = 0;
    renderPanel(true);
  }
  function closeDrawer() {
    drawerTab = null;
    $("drawer").hidden = true;
    app.classList.remove("drawer-open", "wide");
    document.querySelectorAll("[data-open]").forEach(b => b.setAttribute("aria-pressed", "false"));
  }
  $("hud-right").addEventListener("click", e => { const b = e.target.closest("[data-open]"); if (b) { if (drawerTab === b.dataset.open) closeDrawer(); else openDrawer(b.dataset.open); } });
  $("drawer").addEventListener("click", e => { const b = e.target.closest("[data-tab]"); if (b) openDrawer(b.dataset.tab); });
  $("drawer-close").addEventListener("click", closeDrawer);
  function toggleSettings(open) { $("settings").hidden = !open; $("btn-settings").setAttribute("aria-expanded", String(open)); }
  $("btn-settings").addEventListener("click", () => toggleSettings($("settings").hidden));
  document.addEventListener("click", e => { if (!$("settings").hidden && !e.target.closest(".settings-wrap")) toggleSettings(false); });
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape" || $("reader").open) return;
    if (!$("settings").hidden) toggleSettings(false); else if (drawerTab) closeDrawer();
  });
  // Lo que muestran los botones: tokens, nivel y saldo, y novedades sin leer.
  function renderHud() {
    const t = state.tokens;
    $("hud-tokens").textContent = fmtK(t.claude + t.codex + t.gemini);
    $("hud-shop").textContent = game ? "Nv " + levelOf(earned()) + " · " + fmtK(Math.max(0, earned() + bonus() - spent())) : "";
    if (drawerTab === "actividad" || seenFeed === null) seenFeed = state.feed[0] || seenFeed;
    const i = seenFeed ? state.feed.indexOf(seenFeed) : -1, unread = i < 0 ? (seenFeed ? Math.min(state.feed.length, 99) : 0) : i;
    $("hud-unread").hidden = !unread;
    $("hud-unread").textContent = unread > 98 ? "99+" : String(unread);
  }

  // --- Arranque ----------------------------------------------------------------
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  state = freshState();
  startStep();
  for (let i = 0; i < 120; i++) update(0.1); // la primera imagen ya muestra trabajo
  $("btn-live").addEventListener("click", () => { userPicked = true; setMode("live"); });
  $("btn-demo").addEventListener("click", () => { userPicked = true; setMode("demo"); });
  updateModeUI();
  $("btn-alerts").addEventListener("click", () => {
    prefs.notify = !prefs.notify;
    savePrefs();
    if (prefs.notify && typeof Notification !== "undefined" && Notification.permission === "default") Notification.requestPermission().then(renderAlertBtn, renderAlertBtn);
    renderAlertBtn();
  });
  renderAlertBtn();
  function renderSoundBtn() { $("btn-sound").setAttribute("aria-pressed", String(!!prefs.sound)); $("btn-sound").textContent = prefs.sound ? "Sonido: sí" : "Sonido: no"; }
  $("btn-sound").addEventListener("click", () => {
    prefs.sound = !prefs.sound;
    savePrefs();
    if (prefs.sound) { try { audio = audio || new (window.AudioContext || window.webkitAudioContext)(); audio.resume(); sfx("bell"); } catch (e) { audio = null; } }
    renderSoundBtn();
  });
  renderSoundBtn();
  $("btn-summary").addEventListener("click", openSummary);
  renderPanel(true);
  poll();
  setInterval(poll, 1500);

  let last = performance.now();
  function frame(ts) {
    const dt = Math.min(0.1, (ts - last) / 1000);
    last = ts;
    if (mode === "live") update(dt);
    else if (playing) update(dt * speed);
    shopTick();
    lifeTick(mode === "live" ? dt : playing ? dt * speed : 0);
    render(reduced ? Math.floor(ts / 600) : ts / 1000);
    renderPanel(false);
    requestAnimationFrame(frame);
  }
  if (document.fonts) document.fonts.ready.then(() => renderPanel(true));
  requestAnimationFrame(frame);
