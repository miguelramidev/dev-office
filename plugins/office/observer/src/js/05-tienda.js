  // --- La partida ---
  let game = null, placed = { rooms: {}, wear: {} }, liveEarned = 0, liveGameKey = "none";
  const shopSel = { room: "", who: "", cat: "Todo" };
  const gameKey = () => mode === "live" ? liveGameKey : "demo:" + state.demoRun;
  const earned = () => mode === "live" ? liveEarned : Math.round(state.tokens.claude + state.tokens.codex + state.tokens.gemini);
  const spent = () => game ? game.buys.reduce((n, b) => n + (b.price || 0), 0) : 0;
  const fmtK = n => n >= 1e6 ? (Math.round(n / 1e5) / 10).toLocaleString("es-AR") + "M" : n >= 1000 ? (Math.round(n / 100) / 10).toLocaleString("es-AR") + "k" : String(Math.round(n));
  const roomOf = id => placed.rooms[id] || { wall: [], small: [], big: [] };

  function gameLoad(key) {
    let data = null;
    try { data = JSON.parse(sessionStorage.getItem("dev-office-shop:" + key) || "null"); } catch (e) { data = null; }
    const ok = data && Array.isArray(data.buys);
    game = { key, buys: ok ? data.buys.filter(b => b && itemOf(b.item)) : [], lastLevel: ok ? data.lastLevel || 0 : 0, manual: ok && !!data.manual,
      log: ok && Array.isArray(data.log) ? data.log.slice(-40) : [], shop: buildShop(key), nextAuto: 8,
      ach: ok && data.ach && typeof data.ach === "object" ? data.ach : {}, bday: ok ? data.bday || null : null };
    placed = { rooms: {}, wear: {} };
    game.buys.forEach(place);
    if (mode === "live") mergeShopLog();
  }
  function gameSave() {
    try { sessionStorage.setItem("dev-office-shop:" + game.key, JSON.stringify({ buys: game.buys, lastLevel: game.lastLevel, manual: game.manual, log: game.log.slice(-40), ach: game.ach, bday: game.bday })); } catch (e) { /* sin almacenamiento: la partida dura hasta recargar */ }
  }
  function place(b) {
    const it = itemOf(b.item), s = it.kind.slot;
    if (WEAR.includes(s)) { (placed.wear[b.to] = placed.wear[b.to] || {})[s] = it; return; }
    const R = placed.rooms[b.to] = placed.rooms[b.to] || { wall: [], small: [], big: [] };
    if (ROOM_ONE.includes(s) || s === "kit") R[s] = it; else R[s][b.slot] = it;
  }
  function freeSlot(roomId, slot) {
    const list = (SLOTS[roomId] || {})[slot] || [], R = roomOf(roomId);
    for (let i = 0; i < list.length; i++) if (!R[slot][i] && !(slot === "wall" && R.kit && kitBlocks(roomId, list[i]))) return i;
    return -1;
  }
  function shopLog(text, kind) {
    const at = Date.now() / 1000;
    game.log.push({ at, text, kind });
    if (mode === "live") state.feed.unshift({ at, t: at - (state.live ? state.live.t0 : at), text, kind });
    else addFeed(text, kind);
  }
  function mergeShopLog() {
    if (!game || !state.live) return;
    state.feed = state.feed.filter(e => !e.shop);
    game.log.forEach(e => state.feed.push({ at: e.at, t: e.at - state.live.t0, text: e.text, kind: e.kind, shop: true }));
    state.feed.sort((p, q) => q.at - p.at);
  }

  // Para quién es la compra: la oficina y el empleado elegidos en la tienda o, si no
  // eligió nada, los del empleado seleccionado en la oficina.
  function shopRooms() { return ROOMS.filter(r => !r.off).map(r => r.id).concat("hall"); }
  function shopPeople() { return people().filter(p => p.id === "pm" || p.id === "ceo" || p.provider); }
  function shopRoom() {
    if (shopSel.room && shopRooms().includes(shopSel.room)) return shopSel.room;
    const sel = state.selected === "pm" ? null : agent(state.selected);
    return sel && !room(sel.room).off ? sel.room : "meet";
  }
  function shopWho() {
    const ids = shopPeople().map(p => p.id);
    if (shopSel.who && ids.includes(shopSel.who)) return shopSel.who;
    return ids.includes(state.selected) ? state.selected : "pm";
  }
  const whoName = id => id === "pm" ? "el PM" : (agent(id) || {}).label || id;
  function targetOf(it) {
    const s = it.kind.slot;
    if (WEAR.includes(s)) return shopWho();
    if (s === "kit") return it.v[0].c;
    return shopRoom();
  }
  function destName(it, to) { return WEAR.includes(it.kind.slot) ? whoName(to) : placeName(to); }

  // ¿Se puede comprar? Devuelve { ok, label, why, to, slot }.
  function canBuy(it, to) {
    const s = it.kind.slot, lv = levelOf(earned()), bal = earned() + bonus() - spent();
    to = to || targetOf(it);
    if (it.lv > lv) return { ok: false, label: "Nivel " + it.lv, why: "Se desbloquea en el nivel " + it.lv + "." };
    let slot = 0;
    if (WEAR.includes(s)) {
      if (to === "pm" && s === "top") return { ok: false, label: "El PM no", why: "El PM no se saca su traje: probá con un gorro, anteojos o algo para el cuello." };
      const w = placed.wear[to];
      if (w && w[s] === it) return { ok: false, label: "Ya lo tiene", why: whoName(to) + " ya lo tiene puesto." };
    } else {
      if (to !== "hall" && room(to) && room(to).off) return { ok: false, label: "No instalada", why: "Esa oficina no está instalada." };
      if (to === "hall" && s !== "small") return { ok: false, label: "Solo en oficinas", why: "En el pasillo solo entran plantas y adornos chicos." };
      const R = roomOf(to);
      if (s === "kit") {
        if (R.kit) return { ok: false, label: "Ya está", why: "Esa oficina ya tiene su equipamiento." };
        if ((SLOTS[to].wall || []).some((x, i) => R.wall[i] && kitBlocks(to, x))) return { ok: false, label: "Sin lugar", why: "Los cuadros de esa pared no dejan lugar para el equipamiento." };
      } else if (ROOM_ONE.includes(s)) {
        if (R[s] === it) return { ok: false, label: "Ya está", why: "Ya está puesto en " + placeName(to) + "." };
      } else {
        slot = freeSlot(to, s);
        if (slot < 0) return { ok: false, label: "Sin lugar", why: (SLOTS[to][s] || []).length ? "No queda lugar en " + placeName(to) + ": probá en otra oficina." : "No entra en " + placeName(to) + ": probá en otra oficina." };
      }
    }
    if (bal < it.price) return { ok: false, label: fmtK(it.price), why: "Todavía no te alcanza el saldo." };
    return { ok: true, label: "Comprar · " + fmtK(it.price), why: "Va para " + destName(it, to) + ".", to, slot };
  }
  function buy(it, to, auto) {
    const c = canBuy(it, to);
    if (!c.ok) return false;
    const b = { item: it.id, to: c.to, slot: c.slot, price: it.price, at: Math.round(Date.now() / 1000) };
    game.buys.push(b);
    if (!auto) game.manual = true;
    place(b);
    shopLog((auto ? "Demo: el CEO compra " : "Compraste ") + it.name + " para " + destName(it, c.to) + " (−" + fmtK(it.price) + " tokens).", "good");
    gameSave();
    return true;
  }

  function shopTick() {
    const key = gameKey();
    if (!game || game.key !== key) gameLoad(key);
    const lv = levelOf(earned());
    if (lv > game.lastLevel) {
      if (game.lastLevel > 0) { shopLog("¡La oficina sube al nivel " + lv + "! Hay artículos nuevos en la tienda.", "warn"); sfx("level"); }
      game.lastLevel = lv;
      gameSave();
    }
    // En la demo, el CEO compra solo hasta que alguien compra a mano.
    if (mode === "demo" && !game.manual && state.t > game.nextAuto) {
      game.nextAuto = state.t + 18 + Math.random() * 12;
      const R = Math.random, rooms = shopRooms(), who = shopPeople().map(p => p.id), had = new Set(game.buys.map(b => b.item));
      const opts = game.shop.filter(it => it.lv <= lv && !had.has(it.id)).sort(() => R() - 0.5);
      for (const it of opts) {
        const to = WEAR.includes(it.kind.slot) ? who[Math.floor(R() * who.length)] : it.kind.slot === "kit" ? it.v[0].c : rooms[Math.floor(R() * rooms.length)];
        if (buy(it, to, true)) break;
      }
    }
  }

  // --- Dibujar lo comprado ---
  function concrete(x, y, w, h) {
    px(x, y, w, h, "#3b3e46");
    for (let yy = y; yy < y + h; yy += 48) px(x, yy, w, 1, "#33363d");
    for (let xx = x + 47; xx < x + w; xx += 48) px(xx, y, 1, h, "#33363d");
    for (let i = 0; i < 40; i++) px(x + (i * 53 + x) % w, y + (i * 37 + y) % h, 1, 1, i % 2 ? "#44474f" : "#35383f");
  }
  function drawRoomItems(r, now) {
    const S = SLOTS[r.id], R = roomOf(r.id);
    S.wall.forEach((x, i) => { const it = R.wall[i]; if (it) it.kind.draw(r.x + x, r.y + 3, it.v, now); });
    S.big.forEach(([x, y], i) => { const it = R.big[i]; if (it) it.kind.draw(r.x + x, r.y + y, it.v, now); });
    S.small.forEach(([x, y], i) => { const it = R.small[i]; if (it && !walkingPet(r.id, i)) it.kind.draw(r.x + x, r.y + y, it.v, now); });
  }
  function drawHallItems(now) {
    const R = roomOf("hall");
    SLOTS.hall.small.forEach(([x, y], i) => { const it = R.small[i]; if (it && !walkingPet("hall", i)) it.kind.draw(x, y, it.v, now); });
  }
  // Ropa comprada: la prenda y su color, o la de su rol.
  function dress(a, colorKey) {
    const w = placed.wear[a.id], top = w && w.top;
    return top ? { kind: top.kind.top, c: top.v[0].c } : { kind: outfitOf(a), c: ROLE_COLORS[colorKey] || ROLE_COLORS.purple };
  }
  const sleeve = d => d.kind === "coat" ? ["#efe9dd", "#cfc7b8"] : d.kind === "denim" ? ["#4a6da0", "#3a5784"] : d.kind === "astro" ? ["#e9e4d8", "#c9c3b6"] : d.kind === "gala" ? ["#16131f", "#16131f"] : [d.c, shade(d.c, -0.3)];
  const hasHat = a => !!(placed.wear[a.id] && placed.wear[a.id].hat);
  function drawWear(a, cx, ty, now) {
    const w = placed.wear[a.id];
    if (!w) return;
    if (w.neck) w.neck.kind.draw(cx, ty, w.neck.v, now);
    if (w.face) w.face.kind.draw(cx - 8, ty - 13, w.face.v, now);
    if (w.hat) w.hat.kind.draw(cx, ty - 13, w.hat.v, now);
  }

  // Vista previa de cada artículo, dibujada una vez.
  const previewCache = {};
  function preview(it) {
    if (previewCache[it.id]) return previewCache[it.id];
    const c = document.createElement("canvas");
    c.width = 72; c.height = 52;
    const saved = g;
    g = c.getContext("2d");
    try { drawPreview(it); } catch (e) { /* una vista previa rota no frena la tienda */ }
    g = saved;
    return previewCache[it.id] = c.toDataURL();
  }
  function drawPreview(it) {
    const s = it.kind.slot, v = it.v;
    px(0, 0, 72, 52, "#232a38");
    if (s === "wall") { px(0, 0, 72, 30, "#2a3142"); concrete(0, 30, 72, 22); it.kind.draw(19, 3, v, 0); }
    else if (s === "kit") { px(0, 0, 72, 30, "#2a3142"); concrete(0, 30, 72, 22); drawDeco({ deco: v[0].c, x: -6, y: 1 }, 0); }
    else if (s === "small") { concrete(0, 0, 72, 52); it.kind.draw(36, 46, v, 0); }
    else if (s === "big") { concrete(0, 0, 72, 52); it.kind.draw(36, 50, v, 0); }
    else if (s === "desk") { concrete(0, 0, 72, 52); it.kind.draw(36, 16, v, 0); }
    else if (s === "chair") { concrete(0, 0, 72, 52); it.kind.draw(36, 34, v, 0); }
    else if (s === "floor") it.kind.draw(0, 0, 72, 52, v, 0);
    else if (s === "paint") { it.kind.draw(0, 0, 72, 30, v, 0); concrete(0, 30, 72, 22); }
    else {
      const fake = { id: "__preview", role: "backend.developer", look: 6, provider: null };
      placed.wear.__preview = { [s]: it };
      drawTorso(36, 34, fake, "blue");
      drawHead(28, 21, look(6), { mood: "happy" });
      drawWear(fake, 36, 34, 0);
      delete placed.wear.__preview;
    }
  }

