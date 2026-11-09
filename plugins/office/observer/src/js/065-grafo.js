  // --- Proyecto: el grafo de archivos e imports, y por dónde pasa cada agente -----------------
  // Los datos salen de .office/observer/graph.js, que arma project-index.sh sin ningún modelo
  // (OFFICE_GRAPH({files, edges})). Las carpetas se abren con un click; cada lectura o edición de
  // un agente ilumina su archivo (o la carpeta que lo contiene) con el color del agente.
  const GRAPH_MAX_FILES = 40;      // archivos sueltos que se muestran por carpeta abierta
  const GRAPH_ROOT_FILES = 12;     // en la raíz suelen ser configuraciones: se agrupan antes
  const G = {
    data: null, loadedAt: 0, failed: false, tree: null, open: false,
    expanded: new Set([""]), showAll: new Set(), nodes: [], byId: {}, links: [], pos: {},
    touches: {}, pulses: [], sel: null, hover: null, impact: null, alpha: 0,
    cam: { x: 0, y: 0, k: 1 }, drag: null, w: 0, h: 0, dpr: 1, fit: true,
  };
  const gdir = p => { const i = p.lastIndexOf("/"); return i < 0 ? "" : p.slice(0, i); };
  const gname = p => p ? p.slice(p.lastIndexOf("/") + 1) : "(raíz)";
  const gtop = p => p.split("/")[0] || "";
  const ghue = s => { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360; return h; };

  // Lo que hacen los agentes. En la historia (fresh = false) solo suma calor, sin animación.
  function graphReset() { G.touches = {}; G.pulses = []; }
  function graphTouch(path, who, color, kind, t, fresh) {
    if (!path || typeof path !== "string") return;
    const k = G.touches[path] || (G.touches[path] = { n: 0, t: 0, who: "", color: "", edit: false, log: [] });
    k.n += 1; k.t = t; k.who = who; k.color = color; if (kind === "edit") k.edit = true;
    k.log.push({ who, color, kind, t }); if (k.log.length > 6) k.log.shift();
    if (fresh) { G.pulses.push({ path, who, color, kind, t0: performance.now() }); if (G.pulses.length > 40) G.pulses.shift(); }
  }

  function graphSetData(g) {
    if (!g || !Array.isArray(g.files) || !Array.isArray(g.edges)) return;
    const same = G.data && G.data.t === g.t;
    G.data = g; G.failed = false; G.loadedAt = Date.now();
    if (!same) { graphBuildTree(); graphLayout(); }
  }
  window.OFFICE_GRAPH = graphSetData;
  function graphLoad() {
    const sc = document.createElement("script");
    sc.src = "graph.js?t=" + Date.now();
    sc.onload = () => { sc.remove(); graphStatus(); };
    sc.onerror = () => { sc.remove(); if (!G.data) G.failed = true; graphStatus(); };
    document.head.appendChild(sc);
  }

  function graphBuildTree() {
    const files = G.data.files, dirs = {}, count = {};
    const ensure = d => {
      if (dirs[d]) return dirs[d];
      dirs[d] = { dirs: new Set(), files: [] };
      if (d !== "") ensure(gdir(d)).dirs.add(d);
      return dirs[d];
    };
    ensure("");
    files.forEach((f, i) => {
      ensure(gdir(f)).files.push(i);
      for (let d = gdir(f); ; d = gdir(d)) { count[d] = (count[d] || 0) + 1; if (d === "") break; }
    });
    const out = files.map(() => []), inn = files.map(() => []);
    G.data.edges.forEach(([a, b]) => { if (files[a] != null && files[b] != null) { out[a].push(b); inn[b].push(a); } });
    const idx = {}; files.forEach((f, i) => { idx[f] = i; });
    G.tree = { dirs, count, out, inn, idx };
    // Si hay pocas carpetas arriba, se abre un nivel más para que se vea algo útil de entrada.
    if (dirs[""].dirs.size <= 3) dirs[""].dirs.forEach(d => G.expanded.add(d));
  }

  // Nodos visibles: carpetas cerradas, archivos de carpetas abiertas y grupos de "más archivos".
  function graphLayout() {
    if (!G.tree) return;
    const T = G.tree, nodes = [], byId = {};
    const add = n => { nodes.push(n); byId[n.id] = n; };
    const walk = (d, depth) => {
      const node = T.dirs[d];
      [...node.dirs].sort().forEach(sd => {
        if (G.expanded.has(sd)) walk(sd, depth + 1);
        else add({ id: "d:" + sd, kind: "dir", path: sd, count: T.count[sd] || 0, parent: d, depth });
      });
      const limit = G.showAll.has(d) ? Infinity : (d === "" ? GRAPH_ROOT_FILES : GRAPH_MAX_FILES);
      if (node.files.length > limit) add({ id: "g:" + d, kind: "group", path: d, count: node.files.length, parent: d, depth });
      else node.files.forEach(i => add({ id: "f:" + G.data.files[i], kind: "file", path: G.data.files[i], fi: i, parent: d, depth }));
    };
    walk("", 0);
    // Posición inicial: donde estaba antes, o cerca de su carpeta.
    nodes.forEach(n => {
      const p = G.pos[n.id] || G.pos["d:" + n.parent] || null;
      const a = Math.random() * Math.PI * 2, r = p ? 18 + Math.random() * 30 : 60 + Math.random() * 220;
      n.x = p ? p.x + (G.pos[n.id] ? 0 : Math.cos(a) * r) : Math.cos(a) * r;
      n.y = p ? p.y + (G.pos[n.id] ? 0 : Math.sin(a) * r) : Math.sin(a) * r;
      n.vx = 0; n.vy = 0;
      n.r = n.kind === "dir" ? Math.min(34, 7 + 2.2 * Math.sqrt(n.count)) : n.kind === "group" ? Math.min(20, 6 + Math.sqrt(n.count)) : 4.5;
      const top = gtop(n.path);
      n.hue = ghue(top || n.path);
    });
    G.nodes = nodes; G.byId = byId;
    // Aristas agregadas entre nodos visibles.
    const w = {};
    G.data.edges.forEach(([a, b]) => {
      const na = graphNodeFor(G.data.files[a]), nb = graphNodeFor(G.data.files[b]);
      if (!na || !nb || na === nb) return;
      const key = na.id < nb.id ? na.id + "|" + nb.id : nb.id + "|" + na.id;
      w[key] = (w[key] || 0) + 1;
    });
    G.links = Object.keys(w).map(k => { const [a, b] = k.split("|"); return { a: byId[a], b: byId[b], w: w[k] }; }).filter(l => l.a && l.b);
    G.alpha = 1;
  }
  // El nodo visible que contiene un archivo (o una carpeta, en las búsquedas).
  function graphNodeFor(path) {
    if (!path) return null;
    if (G.byId["f:" + path]) return G.byId["f:" + path];
    if (G.byId["d:" + path]) return G.byId["d:" + path];
    for (let d = gdir(path); ; d = gdir(d)) {
      if (G.byId["d:" + d]) return G.byId["d:" + d];
      if (G.byId["g:" + d]) return G.byId["g:" + d];
      if (d === "") return null;
    }
  }

  // Simulación de fuerzas, solo mientras se acomoda (alpha baja sola).
  function graphStep() {
    if (G.alpha < 0.01) return;
    const ns = G.nodes, n = ns.length, a = G.alpha;
    for (let i = 0; i < n; i++) {
      const p = ns[i];
      for (let j = i + 1; j < n; j++) {
        const q = ns[j]; let dx = p.x - q.x, dy = p.y - q.y, d2 = dx * dx + dy * dy + 0.01;
        const min = p.r + q.r + 10;
        const f = (p.parent === q.parent ? 900 : 1600) / d2 + (d2 < min * min ? 0.6 : 0);
        dx *= f; dy *= f; p.vx += dx; p.vy += dy; q.vx -= dx; q.vy -= dy;
      }
    }
    G.links.forEach(l => {
      const dx = l.b.x - l.a.x, dy = l.b.y - l.a.y, d = Math.sqrt(dx * dx + dy * dy) || 1;
      const k = (d - (l.a.r + l.b.r + 50)) / d * 0.02 * Math.min(3, 1 + Math.log(l.w));
      l.a.vx += dx * k; l.a.vy += dy * k; l.b.vx -= dx * k; l.b.vy -= dy * k;
    });
    // Los hermanos se atraen entre sí (se ven las carpetas) y todo, un poco hacia el centro.
    const cx = {}, cy = {}, cn = {};
    ns.forEach(p => { cx[p.parent] = (cx[p.parent] || 0) + p.x; cy[p.parent] = (cy[p.parent] || 0) + p.y; cn[p.parent] = (cn[p.parent] || 0) + 1; });
    ns.forEach(p => {
      p.vx += (cx[p.parent] / cn[p.parent] - p.x) * 0.012 - p.x * 0.002;
      p.vy += (cy[p.parent] / cn[p.parent] - p.y) * 0.012 - p.y * 0.002;
      p.vx *= 0.6; p.vy *= 0.6;
      p.x += Math.max(-30, Math.min(30, p.vx * a * 4)); p.y += Math.max(-30, Math.min(30, p.vy * a * 4));
      G.pos[p.id] = { x: p.x, y: p.y };
    });
    G.alpha *= 0.985;
    // Mientras se acomoda, la cámara sigue al archivo elegido o encuadra todo, hasta que el
    // usuario mueve o hace zoom por su cuenta.
    if (G.follow) { G.cam.x += (G.w / 2 - G.follow.x * G.cam.k - G.cam.x) * 0.2; G.cam.y += (G.h / 2 - G.follow.y * G.cam.k - G.cam.y) * 0.2; }
    else if (G.fit) graphFit(true);
  }
  function graphFit(soft) {
    if (!G.nodes.length) return;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    G.nodes.forEach(n => { x0 = Math.min(x0, n.x - n.r); y0 = Math.min(y0, n.y - n.r); x1 = Math.max(x1, n.x + n.r); y1 = Math.max(y1, n.y + n.r); });
    const k = Math.min(2.2, Math.max(0.15, Math.min(G.w / (x1 - x0 + 80), G.h / (y1 - y0 + 80))));
    const to = { k, x: G.w / 2 - (x0 + x1) / 2 * k, y: G.h / 2 - (y0 + y1) / 2 * k };
    if (soft) { G.cam.k += (to.k - G.cam.k) * 0.15; G.cam.x = G.w / 2 - (x0 + x1) / 2 * G.cam.k; G.cam.y = G.h / 2 - (y0 + y1) / 2 * G.cam.k; }
    else G.cam = to;
  }

  // Calor de cada nodo: cuántas veces lo tocaron los agentes, y el último que pasó.
  function graphHeat() {
    const heat = {};
    Object.keys(G.touches).forEach(p => {
      const n = graphNodeFor(p); if (!n) return;
      const h = heat[n.id] || (heat[n.id] = { n: 0, t: 0, color: "", who: "", edit: false });
      const k = G.touches[p]; h.n += k.n; if (k.edit) h.edit = true;
      if (k.t >= h.t) { h.t = k.t; h.color = k.color; h.who = k.who; }
    });
    return heat;
  }
  // Impacto: lo que depende del archivo elegido, hasta dos niveles (lo mismo que --impact).
  function graphImpactOf(fi) {
    const T = G.tree, lvl = new Map([[fi, 0]]), q = [fi];
    for (let h = 0; h < q.length; h++) { const c = q[h]; if (lvl.get(c) >= 2) continue; T.inn[c].forEach(x => { if (!lvl.has(x)) { lvl.set(x, lvl.get(c) + 1); q.push(x); } }); }
    lvl.delete(fi);
    return lvl;
  }

  function graphDraw() {
    const cv = $("graph-canvas"); if (!cv || !G.open) return;
    const ctx = cv.getContext("2d");
    ctx.setTransform(G.dpr, 0, 0, G.dpr, 0, 0);
    ctx.fillStyle = "#12151d"; ctx.fillRect(0, 0, G.w, G.h);
    if (!G.data) return;
    graphStep();
    const { k, x: ox, y: oy } = G.cam, now = performance.now();
    ctx.save(); ctx.translate(ox, oy); ctx.scale(k, k);
    // Carpetas abiertas: un rótulo en el centro de sus archivos.
    const groups = {};
    G.nodes.forEach(n => { if (n.parent !== "" && G.expanded.has(n.parent)) { const g = groups[n.parent] || (groups[n.parent] = { x: 0, y: 0, n: 0, r: 0, ns: [] }); g.x += n.x; g.y += n.y; g.n++; g.ns.push(n); } });
    G.hulls = Object.keys(groups).map(d => {
      const g = groups[d]; g.x /= g.n; g.y /= g.n;
      g.ns.forEach(n => { g.r = Math.max(g.r, Math.hypot(n.x - g.x, n.y - g.y) + n.r + 12); });
      ctx.fillStyle = "hsla(" + ghue(gtop(d)) + ",45%,55%,0.05)"; ctx.strokeStyle = "hsla(" + ghue(gtop(d)) + ",45%,60%,0.18)";
      ctx.lineWidth = 1 / k; ctx.beginPath(); ctx.arc(g.x, g.y, g.r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = "rgba(235,229,216,0.55)"; ctx.font = (11 / Math.max(k, 0.6)) + "px monospace"; ctx.textAlign = "center";
      ctx.fillText(d + "/  ✕", g.x, g.y - g.r - 4 / k);
      return { path: d, x: g.x, y: g.y - g.r - 8 / k, r: g.r };
    });
    // Aristas.
    const imp = G.impact;
    G.links.forEach(l => {
      const hot = G.sel && (l.a === G.sel || l.b === G.sel);
      ctx.strokeStyle = hot ? "rgba(242,193,78,0.8)" : "rgba(152,161,179," + Math.min(0.5, 0.08 + 0.05 * Math.log(1 + l.w)) + ")";
      ctx.lineWidth = (hot ? 2 : Math.min(4, 0.6 + Math.log(1 + l.w) * 0.5)) / k;
      ctx.beginPath(); ctx.moveTo(l.a.x, l.a.y); ctx.lineTo(l.b.x, l.b.y); ctx.stroke();
    });
    // Nodos, con su calor.
    const heat = graphHeat();
    G.nodes.forEach(n => {
      const h = heat[n.id];
      if (h) {
        const glow = Math.min(n.r + 14, n.r + 3 + Math.log(1 + h.n) * 3);
        ctx.fillStyle = h.color || "#f2c14e"; ctx.globalAlpha = 0.28;
        ctx.beginPath(); ctx.arc(n.x, n.y, glow, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
      }
      let fill = "hsl(" + n.hue + "," + (n.kind === "file" ? "30%,62%" : "40%,48%") + ")";
      if (imp && n.kind === "file" && imp.has(n.fi)) fill = imp.get(n.fi) === 1 ? "#e08a3a" : "#b8862f";
      ctx.fillStyle = fill; ctx.strokeStyle = n === G.sel ? "#f2c14e" : n === G.hover ? "#ebe5d8" : "#0b0d12";
      ctx.lineWidth = (n === G.sel || n === G.hover ? 2.5 : 1.2) / k;
      ctx.beginPath();
      if (n.kind === "group") ctx.rect(n.x - n.r, n.y - n.r, n.r * 2, n.r * 2); else ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
      ctx.fill(); ctx.stroke();
      if (h && h.edit) { ctx.fillStyle = "#cf4b47"; ctx.fillRect(n.x + n.r * 0.5, n.y - n.r - 3 / k, 5 / k, 5 / k); }
      const label = n.kind === "dir" || n.kind === "group" || n === G.sel || n === G.hover || k > 1.6 || (h && k > 0.9);
      if (label) {
        ctx.fillStyle = "#ebe5d8"; ctx.font = (n.kind === "file" ? 10 : 11) / Math.max(k, 0.7) + "px monospace"; ctx.textAlign = "center";
        const txt = n.kind === "group" ? "+" + n.count + " archivos" : gname(n.path) + (n.kind === "dir" ? "/ · " + n.count : "");
        ctx.fillText(txt, n.x, n.y + n.r + 12 / Math.max(k, 0.7));
      }
    });
    // Pulsos: lo que acaba de pasar, con el nombre del agente.
    G.pulses = G.pulses.filter(p => now - p.t0 < 4000);
    G.pulses.forEach(p => {
      const n = graphNodeFor(p.path); if (!n) return;
      const f = (now - p.t0) / 4000;
      ctx.strokeStyle = p.color || "#f2c14e"; ctx.globalAlpha = 1 - f; ctx.lineWidth = 3 / k;
      ctx.beginPath(); ctx.arc(n.x, n.y, n.r + 4 + f * 30, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = p.color || "#f2c14e"; ctx.font = "bold " + 11 / Math.max(k, 0.7) + "px monospace"; ctx.textAlign = "center";
      ctx.fillText(p.who + (p.kind === "edit" ? " edita" : " lee"), n.x, n.y - n.r - (8 + f * 14) / Math.max(k, 0.7));
      ctx.globalAlpha = 1;
    });
    ctx.restore();
  }

  function graphStatus() {
    const st = $("graph-status"); if (!st) return;
    if (!G.data) {
      st.textContent = G.failed ? "Todavía no hay grafo de este proyecto: se arma solo al empezar una sesión con la oficina (o con project-index.sh --full)." : "Cargando el grafo…";
      return;
    }
    const mins = Math.round((Date.now() / 1000 - (G.data.t || 0)) / 60);
    st.textContent = G.data.files.length + " archivos · " + G.data.edges.length + " imports · índice de hace " + (mins < 1 ? "menos de un minuto" : mins < 120 ? mins + " min" : Math.round(mins / 60) + " h") + " · click: abrir carpeta o ver archivo · rueda: zoom · arrastrar: mover";
    const who = {};
    Object.values(G.touches).forEach(k => k.log.forEach(l => { who[l.who] = l.color; }));
    $("graph-legend").innerHTML = Object.keys(who).map(w => '<span><i style="background:' + who[w] + '"></i>' + esc(w) + "</span>").join("") + '<span><i class="edit"></i>editado</span>';
  }

  function graphSide() {
    const box = $("graph-side"), n = G.sel;
    if (!n) { box.hidden = true; return; }
    box.hidden = false;
    const T = G.tree, list = (arr, title) => arr.length ? "<h4>" + title + " (" + arr.length + ")</h4><ul>" + arr.slice(0, 40).map(i => { const f = G.data.files[i]; return '<li><button type="button" data-file="' + esc(f) + '" title="' + esc(f) + '"><b>' + esc(gname(f)) + "</b> <small>" + esc(gdir(f)) + "</small></button></li>"; }).join("") + (arr.length > 40 ? "<li>…y " + (arr.length - 40) + " más</li>" : "") + "</ul>" : "";
    let html = '<button type="button" class="close" id="graph-side-close" aria-label="Cerrar">✕</button><h3>' + esc(n.path) + "</h3>";
    const crumbs = []; for (let d = gdir(n.path); d !== ""; d = gdir(d)) crumbs.unshift(d);
    if (crumbs.length) html += '<p class="crumbs">' + crumbs.map(d => '<button type="button" data-collapse="' + esc(d) + '" title="Cerrar esta carpeta">' + esc(gname(d)) + "/</button>").join("") + "</p>";
    if (n.kind === "file") {
      const tk = G.touches[n.path];
      if (tk) html += "<h4>Actividad</h4><ul>" + tk.log.slice().reverse().map(l => '<li><i style="background:' + l.color + '"></i>' + esc(l.who) + (l.kind === "edit" ? " lo editó" : " lo leyó") + " · " + new Date(l.t * 1000).toLocaleTimeString() + "</li>").join("") + "</ul>";
      const impN = G.impact ? G.impact.size : 0;
      html += "<p>Si cambia, dependen de él <b>" + impN + "</b> archivos (hasta 2 niveles), marcados en naranja.</p>";
      html += list(T.out[n.fi], "Importa") + list(T.inn[n.fi], "Lo importan");
    } else {
      html += "<p>" + n.count + " archivos. Click en el nodo para abrir" + (n.kind === "group" ? " todos sus archivos." : " la carpeta.") + "</p>";
    }
    box.innerHTML = html;
  }
  function graphSelectFile(path) {
    for (let d = gdir(path); ; d = gdir(d)) { G.expanded.add(d); if (d === "") break; }
    G.showAll.add(gdir(path));
    graphLayout();
    const n = G.byId["f:" + path];
    if (n) { G.sel = n; G.impact = graphImpactOf(n.fi); G.follow = n; G.fit = false; G.cam.k = Math.max(G.cam.k, 1.1); }
    graphSide();
  }

  function graphHit(mx, my) {
    const { k, x, y } = G.cam, wx = (mx - x) / k, wy = (my - y) / k;
    for (let i = G.nodes.length - 1; i >= 0; i--) { const n = G.nodes[i]; if (Math.hypot(n.x - wx, n.y - wy) <= n.r + 3 / k) return { node: n }; }
    for (const h of G.hulls || []) if (Math.abs(wx - h.x) < 60 / k && Math.abs(wy - h.y) < 10 / k) return { hull: h };
    return null;
  }
  function graphOpen(open) {
    G.open = open;
    $("graph").hidden = !open;
    $("btn-graph").setAttribute("aria-pressed", String(open));
    if (open) { graphResize(); graphLoad(); graphStatus(); }
  }
  function graphResize() {
    const cv = $("graph-canvas"), r = cv.getBoundingClientRect();
    G.dpr = window.devicePixelRatio || 1; G.w = r.width; G.h = r.height;
    cv.width = Math.round(r.width * G.dpr); cv.height = Math.round(r.height * G.dpr);
  }

  function graphInit() {
    const cv = $("graph-canvas"); if (!cv) return;
    $("btn-graph").addEventListener("click", () => graphOpen(!G.open));
    $("graph-close").addEventListener("click", () => graphOpen(false));
    $("graph-collapse").addEventListener("click", () => { G.expanded = new Set([""]); G.showAll.clear(); G.sel = null; G.impact = null; G.follow = null; G.fit = true; graphLayout(); graphSide(); });
    $("graph-center").addEventListener("click", () => { G.follow = null; G.fit = true; graphFit(); });
    $("graph-search").addEventListener("change", ev => {
      const q = ev.target.value.trim().toLowerCase(); if (!q || !G.data) return;
      const f = G.data.files.find(p => p.toLowerCase().endsWith(q)) || G.data.files.find(p => p.toLowerCase().includes(q));
      if (f) graphSelectFile(f);
    });
    $("graph-side").addEventListener("click", ev => {
      const b = ev.target.closest("button"); if (!b) return;
      if (b.id === "graph-side-close") { G.sel = null; G.impact = null; graphSide(); }
      else if (b.dataset.file) graphSelectFile(b.dataset.file);
      else if (b.dataset.collapse) { const d = b.dataset.collapse; G.expanded.forEach(x => { if (x === d || x.startsWith(d + "/")) G.expanded.delete(x); }); G.sel = null; G.impact = null; graphLayout(); graphSide(); }
    });
    window.addEventListener("resize", () => { if (G.open) graphResize(); });
    window.addEventListener("keydown", ev => { if (ev.key === "Escape" && G.open) graphOpen(false); });
    cv.addEventListener("wheel", ev => {
      ev.preventDefault();
      const r = cv.getBoundingClientRect(), mx = ev.clientX - r.left, my = ev.clientY - r.top;
      G.fit = false; G.follow = null;
      const f = Math.exp(-ev.deltaY * 0.0015), k = Math.min(6, Math.max(0.08, G.cam.k * f));
      G.cam.x = mx - (mx - G.cam.x) * (k / G.cam.k); G.cam.y = my - (my - G.cam.y) * (k / G.cam.k); G.cam.k = k;
    }, { passive: false });
    cv.addEventListener("pointerdown", ev => { G.drag = { x: ev.clientX, y: ev.clientY, cx: G.cam.x, cy: G.cam.y, moved: false }; cv.setPointerCapture(ev.pointerId); });
    cv.addEventListener("pointermove", ev => {
      const r = cv.getBoundingClientRect();
      if (G.drag) {
        const dx = ev.clientX - G.drag.x, dy = ev.clientY - G.drag.y;
        if (Math.abs(dx) + Math.abs(dy) > 4) G.drag.moved = true;
        if (G.drag.moved) { G.fit = false; G.follow = null; G.cam.x = G.drag.cx + dx; G.cam.y = G.drag.cy + dy; }
      } else {
        const hit = graphHit(ev.clientX - r.left, ev.clientY - r.top);
        G.hover = hit && hit.node || null;
        cv.style.cursor = hit ? "pointer" : "grab";
        cv.title = G.hover ? G.hover.path + (G.hover.kind === "file" ? "" : " · " + G.hover.count + " archivos") : hit && hit.hull ? "Cerrar " + hit.hull.path + "/" : "";
      }
    });
    cv.addEventListener("pointerup", ev => {
      const d = G.drag; G.drag = null; if (!d || d.moved) return;
      const r = cv.getBoundingClientRect(), hit = graphHit(ev.clientX - r.left, ev.clientY - r.top);
      if (!hit) { G.sel = null; G.impact = null; graphSide(); return; }
      if (hit.hull) { const p = hit.hull.path; G.expanded.forEach(x => { if (x === p || x.startsWith(p + "/")) G.expanded.delete(x); }); G.showAll.delete(p); G.sel = null; G.impact = null; graphLayout(); graphSide(); return; }
      const n = hit.node;
      if (n.kind === "dir") { G.expanded.add(n.path); graphLayout(); }
      else if (n.kind === "group") { G.showAll.add(n.path); graphLayout(); }
      else { G.sel = n; G.impact = graphImpactOf(n.fi); graphSide(); }
    });
    // Se recarga el grafo cada 30 segundos mientras está abierto (el índice se actualiza al
    // empezar cada sesión) y se dibuja en cada cuadro.
    setInterval(() => { if (G.open) { graphLoad(); } }, 30000);
    const loop = () => { if (G.open) { graphDraw(); if (Math.random() < 0.05) graphStatus(); } requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
  }

