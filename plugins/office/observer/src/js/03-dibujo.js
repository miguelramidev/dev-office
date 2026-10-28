  // --- Tablero del ticket, en el pasillo -------------------------------------------
  const BOARD = { x: 146, y: 188, w: 96, h: 26 };
  const VERDICT_COLOR = v => !v ? "#9aa3b5" : /PASA|APROBADO|LISTO|merged|open/.test(v) ? "#5cc98a" : /FALLA|RECHAZADO|closed/.test(v) ? "#ef6b5b" : "#f2c14e";
  // Ticket, rama, últimos resultados del tester y de QA, y el PR, si se abrió.
  function boardInfo() {
    let b;
    if (mode === "live") b = (state.live && state.live.board) || {};
    else {
      const ph = state.phase;
      b = { ticket: "PROJ-123", branch: "feature/PROJ-123-pedidos", base: "epic/PROJ-100-checkout", tests: ph >= 3 ? (state.rounds && ph === 3 ? "FALLA" : "PASA") : null, qa: ph >= 5 ? "APROBADO" : null, pr: ph >= 6 ? { number: 42, state: "open", url: "" } : null };
    }
    const pr = b.pr ? "#" + b.pr.number + (b.pr.state === "merged" ? " mergeado" : b.pr.state === "closed" ? " cerrado" : "") : "sin PR";
    return Object.assign({}, b, { prText: pr, lights: [{ label: "tests", v: b.tests, color: VERDICT_COLOR(b.tests) }, { label: "QA", v: b.qa, color: VERDICT_COLOR(b.qa) }, { label: "PR", v: b.pr && b.pr.state, color: VERDICT_COLOR(b.pr && b.pr.state) }] });
  }
  function drawBoardText() {
    const b = boardInfo(), { x, y, h } = BOARD;
    text(shortText(b.ticket || "Sin ticket", 14), x + 3, y + 1.5, { size: 4.5, color: "#f6f2e7" });
    text(shortText(b.branch || "", 26), x + 3, y + 9, { size: 4, color: "#3a3f4a", font: "'Space Mono', monospace" });
    b.lights.forEach((l, i) => text(l.label === "PR" ? shortText(b.prText, 10) : l.label, x + 10 + i * 30, y + h - 7.5, { size: 4, color: "#3a3f4a" }));
  }
  function openBoard() {
    const b = boardInfo(), v = x => x || "todavía no";
    openDoc({ kind: "Tablero del ticket", title: b.ticket || "Sin ticket", at: Date.now() / 1000, t: state.t,
      text: `- **Rama:** \`${b.branch || "—"}\`${b.base ? " → \`" + b.base + "\`" : ""}\n- **Último resultado del tester:** ${v(b.tests)}\n- **Último veredicto de QA:** ${v(b.qa)}\n- **PR:** ${b.pr ? "#" + b.pr.number + " (" + ({ open: "abierto", merged: "mergeado", closed: "cerrado" }[b.pr.state] || b.pr.state) + ")" + (b.pr.url ? "\n  " + b.pr.url : "") : "todavía no se abrió"}` });
  }

  // --- Dibujo ------------------------------------------------------------------
  const canvas = document.getElementById("office");
  const ctx = canvas.getContext("2d");
  const world = document.createElement("canvas");
  world.width = W; world.height = H;
  let g = world.getContext("2d");
  let S = 2;

  const px = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(Math.round(x), Math.round(y), w, h); };
  // Aclara (+) u oscurece (-) un color hex.
  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    const f = v => Math.max(0, Math.min(255, Math.round(v + amt * (amt > 0 ? 255 - v : v))));
    return "#" + [n >> 16, (n >> 8) & 255, n & 255].map(v => f(v).toString(16).padStart(2, "0")).join("");
  }
  const OUT = "#15111c"; // contorno

  // Aspecto de cada persona: piel, pelo, peinado y ropa.
  const SKINS = [
    { s: "#f3cfa8", d: "#dcae86", h: "#fbe2c6" }, { s: "#e2b28b", d: "#c4936b", h: "#efc8a6" },
    { s: "#c58d61", d: "#a4724c", h: "#d9a57a" }, { s: "#93603f", d: "#77492e", h: "#a8744f" },
    { s: "#f7dcc2", d: "#e0bd9b", h: "#fdeedd" },
  ];
  const HAIRS = ["#2a1c14", "#5b3a20", "#1b1b22", "#8a6a3a", "#a8442b", "#d9bf86", "#3b3f52", "#6b2f45"];
  const look = n => ({ skin: SKINS[n % SKINS.length], hair: HAIRS[(n * 3 + 1) % HAIRS.length], style: (n * 7 + 3) % 5, glasses: n % 4 === 2 });

  // Cara de frente, 16 x 13. o contorno, s piel, d sombra, h luz, b ceja, p pupila,
  // w brillo del ojo, n nariz, c mejilla. La boca se dibuja aparte según el ánimo.
  const HEAD = [
    "....oooooooo....",
    "...oshhhhhhso...",
    "..oshhssssssso..",
    ".osssssssssssso.",
    ".osbbssssssbbso.",
    ".osspwsssspwsso.",
    ".ossppssssppsso.",
    ".osssssnnssssso.",
    ".occsssssssscco.",
    ".odssssssssssdo.",
    "..oddssssssddo..",
    "...oddddddddo...",
    "....oooooooo....",
  ];
  // Peinados: filas desde 4 píxeles arriba de la cabeza. H pelo, L reflejo, D sombra.
  const HAIR = [
    [ // corto
      "................",
      ".....HLLLLH.....",
      "...HHLLLLLLHH...",
      "..HHHHHLLHHHHH..",
      ".HHHHHHHHHHHHHH.",
      ".HHDDHHHHHHDDHH.",
      ".HD..........DH.",
      ".H............H.",
    ],
    [ // largo
      "................",
      ".....HLLLLH.....",
      "...HHLLLLLLHH...",
      "..HHHHHLLHHHHH..",
      ".HHHHHHHHHHHHHH.",
      ".HHHDDHHHHDDHHH.",
      "HHD..........DHH",
      "HH............HH",
      "HH............HH",
      "HH............HH",
      "HH............HH",
      "HD............DH",
      "HD............DH",
      "DD............DD",
      ".D............D.",
    ],
    [ // rodete
      "......HLLH......",
      ".....HLLLLH.....",
      "...HHHDDDDHHH...",
      "..HHHHHLLHHHHH..",
      ".HHHHHHHHHHHHHH.",
      ".HHDDHHHHHHDDHH.",
      ".HD..........DH.",
      "................",
    ],
    [ // parado
      "...H..H..H..H...",
      "..HLH.HLHHLH.H..",
      "..HHLHHLHHLHHH..",
      ".HHHHHHHHHHHHHH.",
      ".HHHHHHHHHHHHHH.",
      ".HDHDDHHHHDDHDH.",
      ".HD..........DH.",
      "................",
    ],
    [ // rulos
      "....H.HH.HH.H...",
      "...HLHLLHLLHLH..",
      "..HLHHLHHLHHLHH.",
      ".HHLHHHHHHHHLHH.",
      ".HLHHHHHHHHHHLH.",
      ".HHDHHHHHHHHDHH.",
      ".HH..........HH.",
      ".HD..........DH.",
    ],
  ];

  function sprite(x, y, rows, pal) {
    for (let r = 0; r < rows.length; r++) {
      const row = rows[r];
      for (let c = 0; c < row.length; c++) {
        const col = pal[row[c]];
        if (col) px(x + c, y + r, 1, 1, col);
      }
    }
  }

  // Cabeza completa. mood: "focus" (trabaja), "happy", "sad" o "calm".
  function drawHead(x, y, lk, o = {}) {
    const sk = lk.skin, hr = lk.hair;
    const look = o.facing > 0 ? 1 : o.facing < 0 ? -1 : 0;
    sprite(x, y, HEAD, { o: OUT, s: sk.s, d: sk.d, h: sk.h, b: shade(hr, -0.2), n: sk.d, c: "#e9a08e" });
    // Ojos: con brillo, mirando hacia donde camina, o cerrados al parpadear.
    if (o.blink) {
      px(x + 4, y + 6, 2, 1, "#221a26"); px(x + 10, y + 6, 2, 1, "#221a26");
    } else {
      px(x + 4, y + 5, 2, 2, sk.s); px(x + 10, y + 5, 2, 2, sk.s);
      px(x + 4 + look, y + 5, 2, 2, "#221a26"); px(x + 10 + look, y + 5, 2, 2, "#221a26");
      px(x + 5 + look, y + 5, 1, 1, "#ffffff"); px(x + 11 + look, y + 5, 1, 1, "#ffffff");
    }
    // Boca según el ánimo.
    const m = "#7a3240";
    if (o.mood === "happy") { px(x + 6, y + 9, 1, 1, m); px(x + 9, y + 9, 1, 1, m); px(x + 7, y + 10, 2, 1, m); px(x + 7, y + 9, 2, 1, "#f2d6d0"); }
    else if (o.mood === "sad") { px(x + 7, y + 9, 2, 1, m); px(x + 6, y + 10, 1, 1, m); px(x + 9, y + 10, 1, 1, m); px(x + 3, y + 4, 2, 1, shade(hr, -0.2)); }
    else if (o.mood === "focus") { px(x + 7, y + 9, 2, 1, m); px(x + 3, y + 4, 2, 1, shade(hr, -0.35)); px(x + 11, y + 4, 2, 1, shade(hr, -0.35)); }
    else { px(x + 7, y + 9, 2, 1, m); }
    if (lk.glasses || o.glasses) {
      const fr = "#2c2f3a";
      px(x + 3, y + 4, 4, 1, fr); px(x + 3, y + 7, 4, 1, fr); px(x + 3, y + 4, 1, 4, fr); px(x + 6, y + 4, 1, 4, fr);
      px(x + 9, y + 4, 4, 1, fr); px(x + 9, y + 7, 4, 1, fr); px(x + 9, y + 4, 1, 4, fr); px(x + 12, y + 4, 1, 4, fr);
      px(x + 7, y + 5, 2, 1, fr);
      px(x + 4, y + 5, 1, 1, "rgba(255,255,255,0.35)"); px(x + 10, y + 5, 1, 1, "rgba(255,255,255,0.35)");
    }
    // Pelo.
    const rows = HAIR[o.style !== undefined ? o.style : lk.style];
    const top = rows === HAIR[2] ? -7 : -4;
    if (rows === HAIR[2]) sprite(x, y - 7, ["......HLLH......", ".....HHHHHH.....", "......DDDD......"], { H: hr, L: shade(hr, 0.25), D: shade(hr, -0.3) });
    sprite(x, y + (rows === HAIR[2] ? -4 : top), rows, { H: hr, L: shade(hr, 0.25), D: shade(hr, -0.3) });
  }

  // Ropa por rol: buzo (developers), camisa y corbata (arquitectos), chomba (testers),
  // polera (designer), guardapolvo (QA), saco (PM y CEO), cárdigan (base de datos).
  const OUTFIT = { courier: "polo", developer: "hoodie", architect: "shirt", tester: "polo", designer: "turtle", qa: "coat", pm: "suit", ceo: "suit", "pm (asesor)": "suit", lead: "vest" };
  function outfitOf(a) {
    if (a.id === "ddev") return "cardigan";
    const r = (a.role || a.id || "").split(".").pop();
    return OUTFIT[r] || OUTFIT[a.role] || "shirt";
  }

  // Torso de 24 x 16, con x en el centro.
  function drawTorso(x, y, a, colorKey) {
    const d = dress(a, colorKey), kind = d.kind;
    const c = d.c, cD = shade(c, -0.3), cL = shade(c, 0.2), white = "#efe9dd", whiteD = "#cfc7b8";
    px(x - 12, y, 24, 16, OUT);
    const [main, mainD] = kind === "coat" || kind === "astro" ? [white, whiteD] : kind === "denim" ? ["#4a6da0", "#3a5784"] : kind === "gala" ? ["#16131f", "#0d0b12"] : [c, cD];
    const mainL = shade(main, 0.2);
    px(x - 11, y + 1, 22, 15, main);
    px(x - 11, y + 1, 3, 15, mainD); px(x + 8, y + 1, 3, 15, mainD);
    px(x - 8, y + 1, 16, 1, mainL);
    px(x - 3, y, 6, 1, OUT);
    if (kind === "hoodie") {
      px(x - 7, y + 1, 14, 3, cD); px(x - 4, y + 1, 8, 2, OUT);                // capucha
      px(x - 2, y + 3, 1, 5, white); px(x + 1, y + 3, 1, 5, white);            // cordones
      px(x - 6, y + 10, 12, 5, cD); px(x - 6, y + 10, 12, 1, cL);               // bolsillo
    } else if (kind === "shirt") {
      px(x - 4, y + 1, 8, 4, white); px(x - 4, y + 1, 2, 3, whiteD); px(x + 2, y + 1, 2, 3, whiteD);
      px(x - 1, y + 3, 2, 10, shade(c, -0.45)); px(x - 1, y + 13, 2, 1, OUT);   // corbata
      px(x - 6, y + 8, 4, 1, cD);                                               // bolsillo
    } else if (kind === "polo") {
      px(x - 5, y + 1, 10, 2, cL); px(x - 1, y + 2, 2, 5, cD);
      px(x, y + 3, 1, 1, white); px(x, y + 5, 1, 1, white);
      px(x + 4, y + 8, 4, 3, cD);
    } else if (kind === "turtle") {
      px(x - 5, y, 10, 4, cD); px(x - 5, y, 10, 1, cL);
      px(x - 7, y + 9, 14, 1, cD); px(x - 7, y + 12, 14, 1, cD);                // rayas
    } else if (kind === "coat") {
      px(x - 3, y + 1, 6, 7, c); px(x - 1, y + 2, 2, 6, cD);                    // camisa de abajo
      px(x - 4, y + 1, 1, 9, whiteD); px(x + 3, y + 1, 1, 9, whiteD);           // solapas
      px(x - 9, y + 8, 4, 4, whiteD); px(x - 8, y + 7, 1, 2, "#4a78d6"); px(x - 7, y + 7, 1, 2, "#cf4b47"); // lapiceras
    } else if (kind === "suit") {
      px(x - 3, y + 1, 6, 8, white);
      px(x - 1, y + 2, 2, 9, colorKey === "gold" ? "#d8b04a" : "#f2c14e"); px(x - 1, y + 11, 2, 1, OUT);
      px(x - 4, y + 1, 1, 10, cD); px(x + 3, y + 1, 1, 10, cD);                 // solapas
      px(x - 6, y + 12, 1, 1, cL); px(x + 5, y + 12, 1, 1, cL);
    } else if (kind === "vest") {
      px(x - 4, y + 1, 8, 15, white); px(x - 4, y + 1, 2, 3, whiteD); px(x + 2, y + 1, 2, 3, whiteD); // camisa
      px(x - 1, y + 3, 2, 9, "#2a3142"); px(x - 1, y + 12, 2, 1, OUT);                         // corbata
      px(x - 5, y + 1, 1, 15, cD); px(x + 4, y + 1, 1, 15, cD);                                 // chaleco
      px(x - 9, y + 5, 3, 3, "#f2c14e"); px(x - 8, y + 4, 1, 1, "#f2c14e"); px(x - 8, y + 8, 1, 1, "#f2c14e"); // estrella
    } else if (kind === "cardigan") {
      px(x - 3, y + 1, 6, 15, "#efe9dd"); px(x - 1, y + 4, 1, 1, OUT); px(x - 1, y + 8, 1, 1, OUT); px(x - 1, y + 12, 1, 1, OUT);
    } else if (kind === "stripes") {
      for (let k = 3; k < 16; k += 3) px(x - 11, y + k, 22, 1, c === "#e9e4d8" ? "#2b2d36" : "#efe9dd");
    } else if (kind === "hawaii") {
      [[-8, 3], [3, 4], [-4, 8], [6, 10], [-9, 12], [0, 13]].forEach(([dx, dy], i) => { px(x + dx, y + dy, 2, 2, i % 2 ? "#f2c14e" : "#efe9dd"); px(x + dx + 2, y + dy + 1, 1, 1, "#47a865"); });
      px(x - 3, y + 1, 2, 3, cL); px(x + 1, y + 1, 2, 3, cL);
    } else if (kind === "denim") {
      px(x - 4, y + 1, 8, 15, c); px(x - 5, y + 1, 1, 15, "#c9a777"); px(x + 4, y + 1, 1, 15, "#c9a777"); px(x - 9, y + 5, 3, 3, "#3a5784"); px(x + 6, y + 5, 3, 3, "#3a5784");
    } else if (kind === "xmas") {
      for (let i = -10; i < 11; i += 4) { px(x + i, y + 5, 2, 2, "#efe9dd"); px(x + i + 2, y + 11, 2, 2, "#efe9dd"); }
      px(x - 11, y + 8, 22, 1, "#47a865"); px(x - 1, y + 2, 2, 2, "#f2c14e");
    } else if (kind === "heart") {
      sprite(x - 3, y + 5, [".X.X.", "XXXXX", ".XXX.", "..X.."], { X: c === "#cf4b47" ? "#efe9dd" : "#cf4b47" });
    } else if (kind === "gala") {
      px(x - 3, y + 1, 6, 9, white); px(x - 2, y + 2, 4, 2, "#16131f"); px(x - 1, y + 5, 1, 1, OUT); px(x - 1, y + 8, 1, 1, OUT);
      px(x - 4, y + 1, 1, 11, "#16131f"); px(x + 3, y + 1, 1, 11, "#16131f"); px(x + 5, y + 4, 3, 2, "#efe9dd");
    } else if (kind === "armor") {
      for (let k = 3; k < 16; k += 4) px(x - 11, y + k, 22, 1, shade(c, -0.35)); px(x - 2, y + 4, 4, 6, shade(c, 0.35)); px(x - 11, y + 1, 4, 3, shade(c, 0.3)); px(x + 7, y + 1, 4, 3, shade(c, 0.3));
    } else if (kind === "astro") {
      px(x - 5, y + 4, 10, 6, "#9aa3b5"); px(x - 4, y + 5, 2, 1, "#ef6b5b"); px(x - 1, y + 5, 2, 1, "#5cc98a"); px(x + 2, y + 5, 2, 1, "#6f9cff");
      px(x - 9, y + 3, 3, 3, c); px(x - 11, y + 13, 22, 1, "#9aa3b5");
    }
    // Credencial del proveedor colgando del cuello.
    if (a.provider) {
      const pc = PROVIDERS[a.provider].color;
      px(x + 3, y + 1, 1, 6, shade(pc, -0.35));
      px(x + 3, y + 7, 6, 7, OUT); px(x + 4, y + 8, 4, 5, pc); px(x + 4, y + 8, 4, 1, shade(pc, 0.3));
    }
  }

  function drawArms(x, y, a, sk, working, now, colorKey) {
    const [, cD] = sleeve(dress(a, colorKey));
    const f = working ? Math.floor(now * 10 + a.look) % 3 : 0;
    // Mangas.
    px(x - 15, y + 2, 5, 12, OUT); px(x - 14, y + 3, 3, 10, cD);
    px(x + 10, y + 2, 5, 12, OUT); px(x + 11, y + 3, 3, 10, cD);
    // Manos sobre el teclado.
    const ly = y + 12 - (f === 1 ? 2 : 0), ry = y + 12 - (f === 2 ? 2 : 0);
    px(x - 11, ly, 6, 4, OUT); px(x - 10, ly + 1, 4, 2, sk.s); px(x - 10, ly + 2, 4, 1, sk.d);
    px(x + 5, ry, 6, 4, OUT); px(x + 6, ry + 1, 4, 2, sk.s); px(x + 6, ry + 2, 4, 1, sk.d);
  }

  // Accesorios por rol.
  function drawAccessory(x, headY, a, now) {
    const r = (a.role || "").split(".").pop();
    if (r === "developer" && a.provider) {
      // Auriculares con el color del proveedor.
      const pc = PROVIDERS[a.provider].color;
      px(x - 8, headY - 5, 16, 2, OUT); px(x - 7, headY - 5, 14, 1, "#3a3f4a");
      px(x - 10, headY + 3, 4, 6, OUT); px(x - 9, headY + 4, 2, 4, pc);
      px(x + 6, headY + 3, 4, 6, OUT); px(x + 7, headY + 4, 2, 4, pc);
      px(x - 9, headY - 3, 1, 6, "#3a3f4a"); px(x + 8, headY - 3, 1, 6, "#3a3f4a");
    } else if (r === "architect") {
      px(x + 8, headY - 1, 1, 5, "#f2c14e"); px(x + 8, headY - 2, 1, 1, "#e07a52"); // lápiz en la oreja
    } else if (r === "lead") {
      // Vincha con micrófono: coordina al equipo.
      px(x - 8, headY - 5, 16, 1, "#3a3f4a");
      px(x - 10, headY + 2, 3, 6, OUT); px(x - 9, headY + 3, 1, 4, "#2f9e8f");
      px(x - 8, headY + 9, 5, 1, "#3a3f4a"); px(x - 4, headY + 8, 2, 2, "#2f9e8f");
    } else if (r === "courier") {
      // Gorra del repartidor.
      px(x - 8, headY - 6, 16, 8, OUT); px(x - 7, headY - 5, 14, 6, "#cf4b47"); px(x - 7, headY - 5, 14, 1, "#ef6b5b"); px(x - 2, headY - 3, 4, 2, "#f2c14e");
      px(x - 10, headY + 1, 20, 2, OUT); px(x - 9, headY + 1, 18, 1, "#a83a36");
    } else if (r === "designer") {
      // Boina.
      px(x - 8, headY - 6, 15, 4, OUT); px(x - 7, headY - 6, 13, 3, "#d771a8"); px(x - 7, headY - 6, 13, 1, "#e9a0c8"); px(x - 1, headY - 8, 2, 2, OUT);
    }
  }

  function moodOf(a) {
    if (a.status === "working") return "focus";
    if (a.status === "pass") return "happy";
    if (a.status === "fail") return "sad";
    return "calm";
  }

  // Persona sentada detrás de su escritorio, mirando hacia nosotros.
  function drawSeated(a, now) {
    const s = seatOf(a), lk = look(a.look);
    if (a.pos) { drawChair(s.x, s.y, a.room); drawDesk(s.x, s.y + 10, a, now, false); return; } // se levantó
    const working = a.status === "working";
    const pz = a.pose ? a.pose.kind : null;
    const bob = pz === "celebrate" ? -Math.abs(Math.round(Math.sin(now * 12) * 2)) : working ? 0 : Math.round(Math.sin(now * 1.4 + s.x * 0.1));
    drawChair(s.x, s.y, a.room);
    const ty = s.y - 2 + bob;
    drawTorso(s.x, ty, a, a.color);
    const hy = ty - 13;
    drawHead(s.x - 8, hy, lk, {
      mood: pz === "celebrate" ? "happy" : pz === "scratch" ? "sad" : a.say ? "happy" : moodOf(a),
      blink: pz === "stretch" || Math.floor(now * 2.2 + s.x) % 17 === 0,
      glasses: (a.role || "").endsWith("architect"), facing: a.say ? a.facing : 0,
    });
    if (!hasHat(a)) drawAccessory(s.x, hy, a, now);
    drawWear(a, s.x, ty, now);
    // Piernas: se ven debajo de las mesas sin frente.
    const pants = ["#2b3142", "#3a3328", "#26313a", "#3b2c3a"][a.look % 4];
    px(s.x - 8, s.y + 18, 7, 18, OUT); px(s.x - 7, s.y + 18, 5, 17, pants); px(s.x + 1, s.y + 18, 7, 18, OUT); px(s.x + 2, s.y + 18, 5, 17, pants);
    px(s.x - 8, s.y + 34, 7, 3, "#3a2418"); px(s.x + 1, s.y + 34, 7, 3, "#3a2418");
    drawDesk(s.x, s.y + 10, a, now, working);
    if (pz) drawPoseArms(s.x, ty, a, lk.skin, pz, now);
    else drawArms(s.x, ty, a, lk.skin, working, now, a.color);
  }

  // Brazos arriba: festeja, se estira o se rasca la cabeza.
  function drawPoseArms(x, y, a, sk, kind, now) {
    const [, cD] = sleeve(dress(a, a.color));
    const up = (ax, top) => { px(ax, top, 5, 15, OUT); px(ax + 1, top + 3, 3, 11, cD); px(ax + 1, top + 1, 3, 2, sk.s); };
    if (kind === "scratch") {
      px(x - 15, y + 2, 5, 12, OUT); px(x - 14, y + 3, 3, 10, cD);
      px(x - 11, y + 12, 6, 4, OUT); px(x - 10, y + 13, 4, 2, sk.s);
      up(x + 9, y - 14 + (Math.floor(now * 8) % 2));
    } else {
      const wide = kind === "stretch" ? 3 : 0, f = kind === "celebrate" ? Math.floor(now * 8) % 2 : 0;
      up(x - 16 - wide, y - 12 - f);
      up(x + 11 + wide, y - 12 - (1 - f));
    }
  }

  // Alguien de pie: camina con cuatro cuadros, gesticula cuando habla y puede llevar algo.
  function drawWalker(a, now) {
    const p = a.pos, lk = look(a.look);
    const fx = Math.round(p.x), fy = Math.round(p.y);
    const walking = a.path.length > 0;
    const f = walking ? Math.floor(now * 9 + a.look) % 4 : 0;
    const legA = [0, 2, 0, -2][f], armA = [0, -2, 0, 2][f], lift = walking && f % 2 ? 1 : 0;
    const pants = ["#2b3142", "#3a3328", "#26313a", "#3b2c3a"][a.look % 4], pantsD = shade(pants, -0.25);
    px(fx - 11, fy - 2, 22, 4, "rgba(0,0,0,0.3)");
    px(fx - 8, fy - 13, 7, 13 + Math.min(0, legA), OUT); px(fx - 7, fy - 13, 5, 11 + legA, pants); px(fx - 7, fy - 13, 1, 11 + legA, pantsD);
    px(fx + 1, fy - 13, 7, 13 - Math.max(0, legA), OUT); px(fx + 2, fy - 13, 5, 11 - legA, pants); px(fx + 6, fy - 13, 1, 11 - legA, pantsD);
    px(fx - 8, fy - 2 + legA, 7, 3, OUT); px(fx - 7, fy - 2 + legA, 5, 2, "#3a2418");
    px(fx + 1, fy - 2 - legA, 7, 3, OUT); px(fx + 2, fy - 2 - legA, 5, 2, "#3a2418");
    const ty = fy - 28 - lift;
    drawTorso(fx, ty, a, a.color);
    const [, cD] = sleeve(dress(a, a.color));
    const gest = a.say && !walking && Math.floor(now * 3) % 2;
    px(fx - 15, ty + 2 + armA, 5, 12, OUT); px(fx - 14, ty + 3 + armA, 3, 10, cD); px(fx - 14, ty + 13 + armA, 3, 2, lk.skin.s);
    if (gest) { px(fx + 10, ty - 3, 5, 12, OUT); px(fx + 11, ty, 3, 8, cD); px(fx + 11, ty - 2, 3, 2, lk.skin.s); }
    else { px(fx + 10, ty + 2 - armA, 5, 12, OUT); px(fx + 11, ty + 3 - armA, 3, 10, cD); px(fx + 11, ty + 13 - armA, 3, 2, lk.skin.s); }
    const hx = fx + (a.facing > 0 ? 13 : -13);
    if (a.prop === "pizza") { // la caja de la pizza, con las dos manos
      px(fx - 11, ty + 7, 22, 6, OUT); px(fx - 10, ty + 8, 20, 4, "#e9d29a"); px(fx - 10, ty + 8, 20, 1, "#f6e9c0");
      px(fx - 3, ty + 9, 6, 2, "#cf4b47"); px(fx - 1, ty + 9, 2, 2, "#f2c14e");
    } else if (a.prop === "cup") {
      px(hx - 3, ty + 9, 7, 7, OUT); px(hx - 2, ty + 10, 5, 5, ["#d9534f", "#4a78d6", "#e9e4d8", "#47a865"][a.look % 4]); px(hx - 2, ty + 10, 5, 1, "#3a2418");
      if (Math.floor(now * 2) % 2) px(hx, ty + 5, 1, 3, "rgba(255,255,255,0.4)");
    } else if (a.prop === "snack") { // el paquete de la máquina
      px(hx - 3, ty + 8, 7, 8, OUT); px(hx - 2, ty + 9, 5, 6, ["#cf4b47", "#f2c14e", "#47a865", "#4a78d6"][a.look % 4]); px(hx - 2, ty + 9, 5, 1, "#e9e4d8"); px(hx - 1, ty + 11, 3, 2, "#f6f2e7");
    } else if (/\.lead$/.test(a.role || "") || a.role === "qa") {
      px(hx - 4, ty + 6, 9, 11, OUT); px(hx - 3, ty + 7, 7, 9, "#c9a777"); px(hx - 2, ty + 8, 5, 7, "#f6f2e7");
      px(hx - 1, ty + 9, 3, 1, a.role === "qa" ? "#cf4b47" : "#2f9e8f"); px(hx - 1, ty + 11, 3, 1, "#98a1b3"); px(hx - 1, ty + 6, 3, 2, "#5e4229");
    } else if (/\.tester$/.test(a.role || "") && a.status === "fail") {
      px(hx - 3, ty + 7, 8, 9, OUT); px(hx - 2, ty + 8, 6, 7, "#f6f2e7"); px(hx - 1, ty + 9, 4, 1, "#cf4b47"); px(hx - 1, ty + 11, 3, 1, "#98a1b3");
    }
    drawHead(fx - 8, ty - 13, lk, { mood: a.status === "fail" ? "sad" : "happy", facing: walking || a.say ? a.facing : 0, blink: Math.floor(now * 2.2 + a.look) % 19 === 0, glasses: (a.role || "").endsWith("architect") });
    if (!hasHat(a)) drawAccessory(fx, ty - 13, a, now);
    drawWear(a, fx, ty, now);
  }

  // La silla de la oficina: la comprada o una de plástico.
  function drawChair(x, y, roomId) {
    const st = roomOf(roomId).chair;
    if (st) { st.kind.draw(x, y, st.v); return; }
    px(x - 11, y - 12, 22, 22, OUT); px(x - 10, y - 11, 20, 20, "#6c727d");
    px(x - 10, y - 11, 20, 2, "#8a909c"); px(x + 8, y - 11, 2, 20, "#5a5f69");
  }

  function drawDesk(cx, y, a, now, working) {
    px(cx - 35, y + 26, 70, 4, "rgba(0,0,0,0.25)"); // sombra
    // El escritorio comprado para la oficina o una mesa plegable.
    const st = roomOf(a.room).desk;
    if (st) st.kind.draw(cx, y, st.v, now);
    else { slabDesk(cx, y, "#9aa0ab", "#4a4f5a"); px(cx - 29, y + 18, 58, 1, "#4a4f5a"); }
    // Monitor.
    const mx = cx - 31, my = y - 22;
    px(mx - 1, my - 1, 26, 19, OUT);
    px(mx, my, 24, 17, "#2a2f3c"); px(mx, my, 24, 1, "#3a4152");
    const scr = working ? "#0e2a20" : a.status === "fail" ? "#3a1416" : a.status === "pass" ? "#11281c" : "#151b27";
    px(mx + 2, my + 2, 20, 12, scr);
    if (working) {
      for (let i = 0; i < 6; i++) {
        const len = 4 + ((Math.floor(now * 5) + i * 5 + a.seat[0]) % 11);
        const ind = (i % 3) * 2;
        px(mx + 3 + ind, my + 3 + i * 2, Math.min(len, 17 - ind), 1, ["#7fd6a4", "#f2c14e", "#9ab8ff", "#7fd6a4", "#e9e4d8", "#f28b7b"][i]);
      }
      px(mx + 2, my + 2, 20, 1, "rgba(255,255,255,0.06)");
    } else if (a.status === "fail") {
      px(mx + 8, my + 4, 8, 8, "#ef6b5b"); px(mx + 9, my + 5, 6, 6, "#3a1416"); px(mx + 11, my + 6, 2, 3, "#ef6b5b"); px(mx + 11, my + 10, 2, 1, "#ef6b5b");
    } else if (a.status === "pass") {
      px(mx + 7, my + 8, 2, 2, "#5cc98a"); px(mx + 9, my + 10, 2, 2, "#5cc98a"); px(mx + 11, my + 8, 2, 2, "#5cc98a"); px(mx + 13, my + 6, 2, 2, "#5cc98a"); px(mx + 15, my + 4, 2, 2, "#5cc98a");
    } else {
      const sx = (Math.floor(now * 3) + a.seat[0]) % 16;
      px(mx + 3 + sx, my + 7, 2, 2, "#2f3a52");
    }
    px(mx + 20, my + 15, 2, 1, working ? "#5cc98a" : "#3a4152"); // luz de encendido
    px(mx + 10, my + 17, 4, 4, "#2a2f3c"); px(mx + 7, my + 20, 10, 2, "#2a2f3c");
    // Teclado y mouse.
    px(cx - 11, y + 2, 22, 6, OUT); px(cx - 10, y + 3, 20, 4, "#cfc8ba");
    for (let r = 0; r < 2; r++) for (let i = 0; i < 9; i++) px(cx - 9 + i * 2, y + 3 + r * 2, 1, 1, "#9d968a");
    px(cx + 14, y + 3, 4, 5, OUT); px(cx + 15, y + 4, 2, 3, "#e9e4d8");
    // Taza.
    px(cx + 22, y - 6, 7, 8, OUT); px(cx + 23, y - 5, 5, 6, ["#d9534f", "#4a78d6", "#e9e4d8", "#47a865"][a.look % 4]); px(cx + 23, y - 5, 5, 1, "#3a2418"); px(cx + 29, y - 4, 2, 4, OUT);
    if (working && Math.floor(now * 2) % 2) { px(cx + 24, y - 10, 1, 2, "rgba(255,255,255,0.35)"); px(cx + 26, y - 13, 1, 3, "rgba(255,255,255,0.25)"); }
    // La pizza de compensación, abierta sobre el teclado; se va terminando de a poco.
    const pz = state.pizza[a.id];
    if (pz > state.t) {
      const left = Math.max(0.15, (pz - state.t) / 150), w = Math.max(3, Math.round(12 * left));
      px(cx - 9, y - 10, 18, 7, OUT); px(cx - 8, y - 9, 16, 6, "#d9c39a"); px(cx - 3, y - 7, 6, 2, "#cf4b47");
      px(cx - 9, y - 3, 18, 10, OUT); px(cx - 8, y - 2, 16, 8, "#e9d29a");
      px(cx - 7, y - 1, w, 6, "#d9a04a"); px(cx - 6, y, Math.max(1, w - 2), 4, "#f2c84b");
      [[-5, 0], [-2, 2], [1, 0], [3, 3], [-4, 3]].forEach(([dx, dy]) => { if (cx + dx < cx - 6 + w - 2) px(cx + dx, y + dy, 2, 1, "#c0392b"); });
    }
    // La torta del cumpleaños, con la vela encendida.
    const cake = state.cake && state.cake.id === a.id;
    if (cake) {
      px(cx + 15, y - 9, 16, 10, OUT); px(cx + 16, y - 8, 14, 8, "#f6e9d8"); px(cx + 16, y - 8, 14, 2, "#ef8fbf"); px(cx + 18, y - 4, 2, 1, "#cf4b47"); px(cx + 25, y - 3, 2, 1, "#4a78d6");
      px(cx + 22, y - 14, 2, 5, "#9ad3ef"); px(cx + 22, y - 17 + (Math.floor(now * 6) % 2), 2, 3, "#f2c14e");
    }
    // Algo propio de cada puesto sobre el escritorio (la torta ocupa ese lugar).
    const r = (a.role || "").split(".");
    const dept = r[0], job = r[1];
    if (cake) { /* nada más */ }
    else if (job === "lead") { // tablero con tarjetas
      px(cx + 17, y - 9, 14, 12, OUT); px(cx + 18, y - 8, 12, 10, "#f6f2e7");
      px(cx + 19, y - 7, 3, 3, "#f2c14e"); px(cx + 23, y - 7, 3, 3, "#6f9cff"); px(cx + 19, y - 3, 3, 3, "#5cc98a"); px(cx + 23, y - 3, 3, 3, working ? "#ef6b5b" : "#5cc98a");
      px(cx + 27, y - 7, 2, 7, "#98a1b3"); px(cx + 23, y + 3, 2, 3, "#5e4229");
    } else if (job === "tester") { // planilla con tildes
      px(cx + 20, y + 2, 10, 7, OUT); px(cx + 21, y + 3, 8, 5, "#f6f2e7");
      px(cx + 22, y + 4, 2, 1, "#47a865"); px(cx + 22, y + 6, 2, 1, a.status === "fail" ? "#cf4b47" : "#47a865"); px(cx + 25, y + 4, 3, 1, "#98a1b3"); px(cx + 25, y + 6, 3, 1, "#98a1b3");
    } else if (a.role === "qa") { // lupa
      px(cx + 19, y + 1, 7, 7, OUT); px(cx + 20, y + 2, 5, 5, "#9ad3ef"); px(cx + 21, y + 3, 1, 1, "#ffffff"); px(cx + 25, y + 7, 4, 2, "#5e4229");
    } else if (dept === "database") { // base de datos de juguete
      px(cx + 20, y - 4, 9, 11, OUT); for (let i = 0; i < 3; i++) { px(cx + 21, y - 3 + i * 3, 7, 3, "#d4a933"); px(cx + 21, y - 3 + i * 3, 7, 1, "#ecc95a"); }
    } else if (job === "designer") { // tableta con lápiz
      px(cx + 18, y + 2, 12, 7, OUT); px(cx + 19, y + 3, 10, 5, "#2a2f3c"); px(cx + 21, y + 4, 4, 2, "#d771a8"); px(cx + 27, y + 1, 1, 6, "#ebe5d8");
    } else if (job === "architect") { // plano enrollado
      px(cx + 17, y + 3, 13, 4, OUT); px(cx + 18, y + 4, 11, 2, "#7fb6e6"); px(cx + 18, y + 4, 11, 1, "#a9d1f2");
    }
  }

  // El PM, de pie: camina con cuatro cuadros.
  function drawPM(now) {
    const p = state.pm, lk = { skin: SKINS[0], hair: "#2a1c14", style: 0, glasses: false };
    const fx = Math.round(p.x), fy = Math.round(p.y);
    const walking = p.path.length > 0;
    const f = walking ? Math.floor(now * 9) % 4 : 0;
    const legA = [0, 2, 0, -2][f], armA = [0, -2, 0, 2][f], lift = walking && f % 2 ? 1 : 0;
    const c = ROLE_COLORS.purple, cD = shade(c, -0.3), cL = shade(c, 0.2);
    const pants = "#2b3142", pantsD = "#1f2431";
    px(fx - 11, fy - 2, 22, 4, "rgba(0,0,0,0.3)");
    // Piernas y zapatos.
    px(fx - 8, fy - 13, 7, 13 + Math.min(0, legA), OUT); px(fx - 7, fy - 13, 5, 11 + legA, pants); px(fx - 7, fy - 13, 1, 11 + legA, pantsD);
    px(fx + 1, fy - 13, 7, 13 - Math.max(0, legA), OUT); px(fx + 2, fy - 13, 5, 11 - legA, pants); px(fx + 6, fy - 13, 1, 11 - legA, pantsD);
    px(fx - 8, fy - 2 + legA, 7, 3, OUT); px(fx - 7, fy - 2 + legA, 5, 2, "#3a2418");
    px(fx + 1, fy - 2 - legA, 7, 3, OUT); px(fx + 2, fy - 2 - legA, 5, 2, "#3a2418");
    // Saco.
    const ty = fy - 29 - lift;
    px(fx - 11, ty, 22, 17, OUT);
    px(fx - 10, ty + 1, 20, 16, c);
    px(fx - 10, ty + 1, 3, 16, cD); px(fx + 7, ty + 1, 3, 16, cD); px(fx - 7, ty + 1, 14, 1, cL);
    px(fx - 3, ty + 1, 6, 9, "#efe9dd");
    px(fx - 1, ty + 2, 2, 10, "#f2c14e"); px(fx - 1, ty + 12, 2, 1, OUT);
    px(fx - 4, ty + 1, 1, 11, cD); px(fx + 3, ty + 1, 1, 11, cD);
    px(fx - 10, ty + 14, 20, 2, "#1f2431"); px(fx - 1, ty + 14, 2, 2, "#c9a777"); // cinturón
    px(fx + 4, ty + 4, 3, 1, "#efe9dd"); // pañuelo
    // Brazos, manos y la carpeta.
    const side = p.facing > 0 ? 1 : -1;
    px(fx - 14, ty + 2 + armA, 5, 12, OUT); px(fx - 13, ty + 3 + armA, 3, 10, cD); px(fx - 13, ty + 13 + armA, 3, 2, lk.skin.s);
    px(fx + 9, ty + 2 - armA, 5, 12, OUT); px(fx + 10, ty + 3 - armA, 3, 10, cD); px(fx + 10, ty + 13 - armA, 3, 2, lk.skin.s);
    const cx = fx + side * 13;
    px(cx - 4, ty + 5, 9, 11, OUT); px(cx - 3, ty + 6, 7, 9, "#c9a777"); px(cx - 2, ty + 7, 5, 7, "#f6f2e7"); px(cx - 1, ty + 8, 3, 1, "#8b6cd6"); px(cx - 1, ty + 10, 3, 1, "#98a1b3"); px(cx - 1, ty + 5, 3, 2, "#5e4229");
    // Cabeza.
    drawHead(fx - 8, ty - 13, lk, { mood: p.status === "waiting" ? "calm" : "happy", facing: walking ? p.facing : 0, blink: Math.floor(now * 2.2) % 19 === 0 });
    if (!hasHat(p)) px(fx - 6, ty - 18, 12, 1, shade("#2a1c14", 0.25)); // brillo del peinado
    drawWear(p, fx, ty, now);
  }

  // --- Escenario ----------------------------------------------------------------
  function drawHall(now) {
    drawHallFloor(now);
    // El agua y la cafetera: las básicas o las mejoradas en la tienda.
    const hallR = roomOf("hall");
    if (hallR.water) hallR.water.kind.draw(18, 216, hallR.water.v, now);
    else { px(10, 188, 16, 28, OUT); px(11, 189, 14, 26, "#d4dbe5"); px(13, 190, 10, 9, "#7fb6e6"); px(14, 191, 3, 6, "#a9d1f2"); px(16, 202, 4, 3, "#3a3f4a"); }
    if (hallR.coffee) hallR.coffee.kind.draw(733, 216, hallR.coffee.v, now);
    else {
      px(722, 188, 22, 28, OUT); px(723, 189, 20, 26, "#3a3f4a"); px(726, 192, 14, 7, "#1d2028"); px(728, 194, 4, 2, "#ef6b5b"); px(729, 204, 8, 6, "#1d2028");
      if (Math.floor(now * 1.5) % 2) px(732, 199, 2, 3, "rgba(255,255,255,0.3)");
    }
    drawHallItems(now);
    // Tablero del ticket: el texto lo escribe drawLabels; acá, el pizarrón y las luces de estado.
    const { x: bx, y: by, w: bw, h: bh } = BOARD, b = boardInfo();
    px(bx - 1, by - 1, bw + 2, bh + 2, OUT); px(bx, by, bw, bh, "#e9e4d8"); px(bx + 1, by + 1, bw - 2, bh - 2, "#f6f2e7");
    px(bx + 1, by + 1, bw - 2, 6, "#3a3f4a");
    b.lights.forEach((l, i) => { const lx = bx + 3 + i * 30; px(lx, by + bh - 7, 5, 5, OUT); px(lx + 1, by + bh - 6, 3, 3, l.color); });
    drawHallCeiling(now);
  }

  // La oficina básica (piso de cemento y pared lisa) o lo que se compró para ella.
  function drawRoom(r, now) {
    const st = roomOf(r.id), c1 = "#3b3e46";
    if (st.floor) st.floor.kind.draw(r.x, r.y + BACK, RW, RH - BACK, st.floor.v, now); else concrete(r.x, r.y + BACK, RW, RH - BACK);
    const wall = "#2a3142", wallL = "#363f55", wallD = "#1f2533";
    if (st.paint) st.paint.kind.draw(r.x, r.y, RW, BACK, st.paint.v, now);
    else { px(r.x, r.y, RW, BACK, wall); px(r.x, r.y, RW, 2, wallL); px(r.x, r.y + BACK - 3, RW, 3, wallD); }
    px(r.x, r.y, 3, RH, wallD); px(r.x + RW - 3, r.y, 3, RH, wallD);
    if (r.top) {
      for (let i = 0; i < 2; i++) {
        const wx = r.x + 112 + i * 36, wy = r.y + 4;
        px(wx - 1, wy - 1, 30, 20, OUT); px(wx, wy, 28, 18, "#18243c");
        px(wx, wy + 11, 28, 7, "#121b2e");
        for (let b = 0; b < 4; b++) { const bh = 4 + ((b * 7 + r.x) % 6); px(wx + 2 + b * 7, wy + 18 - bh, 5, bh, "#0c1220"); if ((Math.floor(now / 2) + b + i) % 3) px(wx + 3 + b * 7, wy + 18 - bh + 1, 1, 1, "#f2c14e"); }
        px(wx + 13, wy, 2, 18, OUT);
        if ((i + Math.floor(now)) % 7 === 0) px(wx + 5, wy + 3, 1, 1, "#ebe5d8");
      }
      const wy = r.y + RH - 6;
      px(r.x, wy, RW, 6, wallD); px(r.x, wy, RW, 1, wallL);
      px(doorX(r) - 18, wy, 36, 6, c1);
      px(doorX(r) - 19, wy - 2, 2, 8, "#6b5236"); px(doorX(r) + 17, wy - 2, 2, 8, "#6b5236");
    } else {
      px(doorX(r) - 18, r.y, 36, BACK, "#5d4733");
      px(doorX(r) - 20, r.y, 2, BACK, "#6b5236"); px(doorX(r) + 18, r.y, 2, BACK, "#6b5236");
      px(r.x, r.y + RH - 4, RW, 4, wallD);
    }
    if (st.kit) drawDeco(r, now);
    drawRoomItems(r, now);
    if (r.id === "meet") drawEmployeeOfMonth(r, now);
  }

  // Decoración propia de cada departamento.
  function drawDeco(r, now) {
    const x = r.x, y = r.y;
    const blink = Math.floor(now * 3);
    if (r.deco === "meet") {
      px(x + 12, y + 4, 54, 22, OUT); px(x + 13, y + 5, 52, 20, "#f6f2e7");
      px(x + 16, y + 8, 22, 2, "#4a78d6"); px(x + 16, y + 12, 30, 2, "#cf4b47"); px(x + 16, y + 16, 18, 2, "#47a865"); px(x + 16, y + 20, 26, 2, "#8b6cd6");
    } else if (r.deco === "design") {
      px(x + 12, y + 4, 40, 22, OUT); px(x + 13, y + 5, 38, 20, "#f6f2e7");
      px(x + 16, y + 8, 12, 9, "#d771a8"); px(x + 30, y + 8, 18, 3, "#36a9bb"); px(x + 30, y + 13, 14, 3, "#36a9bb"); px(x + 16, y + 19, 32, 3, "#98a1b3");
      ["#d771a8", "#36a9bb", "#f2c14e", "#47a865", "#4a78d6"].forEach((c, i) => px(x + 58 + i * 8, y + 10, 6, 6, c));
    } else if (r.deco === "back") {
      px(x + 12, y + 2, 26, 26, OUT); px(x + 13, y + 3, 24, 24, "#20242e");
      for (let i = 0; i < 4; i++) { px(x + 15, y + 5 + i * 6, 20, 4, "#2c3240"); px(x + 31, y + 6 + i * 6, 2, 2, (blink + i) % 3 ? "#5cc98a" : "#1d3a2a"); px(x + 27, y + 6 + i * 6, 2, 2, (blink + i) % 4 ? "#f2c14e" : "#3a3220"); }
      px(x + 46, y + 6, 40, 16, OUT); px(x + 47, y + 7, 38, 14, "#1b2230");
      px(x + 50, y + 10, 8, 2, "#5cc98a"); px(x + 60, y + 10, 20, 2, "#98a1b3"); px(x + 50, y + 15, 10, 2, "#f2c14e"); px(x + 62, y + 15, 16, 2, "#98a1b3");
    } else if (r.deco === "front") {
      px(x + 12, y + 3, 30, 24, OUT); px(x + 13, y + 4, 28, 22, "#ebe5d8");
      px(x + 15, y + 6, 24, 3, "#4a78d6"); px(x + 15, y + 11, 11, 11, "#c9c1b0"); px(x + 28, y + 11, 11, 4, "#d771a8"); px(x + 28, y + 17, 11, 5, "#c9c1b0");
      px(x + 48, y + 6, 28, 18, OUT); px(x + 49, y + 7, 26, 16, "#20242e"); px(x + 59, y + 9, 6, 12, "#ebe5d8"); px(x + 60, y + 10, 4, 9, "#6f9cff");
    } else if (r.deco === "db") {
      for (let i = 0; i < 2; i++) { px(x + 10 + i * 18, y + 4, 16, 24, OUT); px(x + 11 + i * 18, y + 5, 14, 22, "#6b7486"); px(x + 11 + i * 18, y + 12, 14, 1, OUT); px(x + 11 + i * 18, y + 19, 14, 1, OUT); px(x + 16 + i * 18, y + 8, 4, 1, "#c9c1b0"); px(x + 16 + i * 18, y + 15, 4, 1, "#c9c1b0"); px(x + 16 + i * 18, y + 22, 4, 1, "#c9c1b0"); }
      px(x + 52, y + 4, 22, 22, OUT); px(x + 53, y + 5, 20, 20, "#ebe5d8");
      for (let i = 0; i < 3; i++) { px(x + 56, y + 7 + i * 6, 14, 4, "#d4a933"); px(x + 56, y + 7 + i * 6, 14, 1, "#e9c768"); }
    } else if (r.deco === "scrap") {
      px(x + 14, y + 4, 22, 22, OUT); px(x + 15, y + 5, 20, 20, "#2a5c8a"); px(x + 18, y + 9, 6, 5, "#47a865"); px(x + 26, y + 14, 6, 6, "#47a865"); px(x + 15, y + 14, 20, 1, "#7fb6e6");
      px(x + 124, y + 5, 36, 20, OUT); px(x + 125, y + 6, 34, 18, "#ebe5d8");
      [[129, 10], [143, 9], [151, 16], [135, 18]].forEach(([dx, dy], i) => px(x + dx, y + dy, 3, 3, i === blink % 4 ? "#cf4b47" : "#4a78d6"));
    } else if (r.deco === "ops") {
      px(x + 10, y + 5, 66, 18, OUT); px(x + 11, y + 6, 64, 16, "#1b2230");
      ["#5cc98a", "#5cc98a", "#f2c14e", "#3a4152"].forEach((c, i) => { px(x + 14 + i * 16, y + 11, 10, 6, (i === 2 && blink % 2) ? "#3a3220" : c); if (i < 3) px(x + 24 + i * 16, y + 13, 6, 2, "#98a1b3"); });
      px(x + 130, y + 2, 14, 26, OUT); px(x + 131, y + 3, 12, 24, "#20242e"); px(x + 134, y + 6, 6, 2, blink % 2 ? "#5cc98a" : "#1d3a2a"); px(x + 134, y + 12, 6, 2, "#2c3240"); px(x + 134, y + 18, 6, 2, "#2c3240");
    } else if (r.deco === "qa") {
      px(x + 12, y + 3, 24, 24, OUT); px(x + 13, y + 4, 22, 22, "#ebe5d8");
      px(x + 19, y + 9, 10, 12, "#cf4b47"); px(x + 21, y + 7, 6, 3, OUT); px(x + 23, y + 9, 2, 12, OUT);
      px(x + 16, y + 11, 3, 1, OUT); px(x + 29, y + 11, 3, 1, OUT); px(x + 16, y + 16, 3, 1, OUT); px(x + 29, y + 16, 3, 1, OUT);
      px(x + 124, y + 5, 40, 20, OUT); px(x + 125, y + 6, 38, 18, "#f6f2e7");
      px(x + 128, y + 9, 10, 4, "#cf4b47"); px(x + 140, y + 9, 10, 4, "#f2c14e"); px(x + 152, y + 9, 8, 4, "#5cc98a"); px(x + 128, y + 16, 30, 2, "#98a1b3");
    }
  }

  // Mesa de reuniones: va después de las personas para tapar sus piernas.
  function drawMeetingTable() {
    const r = room("meet"), x = r.x, y = r.y;
    px(x + 22, y + 99, 148, 26, OUT); px(x + 23, y + 100, 146, 24, "#8a6440"); px(x + 23, y + 100, 146, 3, "#a67b52"); px(x + 23, y + 118, 146, 6, "#5e4229");
    px(x + 28, y + 125, 4, 8, "#5e4229"); px(x + 160, y + 125, 4, 8, "#5e4229");
    px(x + 82, y + 104, 16, 10, "#ebe5d8"); px(x + 84, y + 106, 12, 1, "#98a1b3"); px(x + 84, y + 108, 9, 1, "#98a1b3"); px(x + 84, y + 110, 11, 1, "#98a1b3");
    px(x + 104, y + 105, 6, 7, OUT); px(x + 105, y + 106, 4, 5, "#e07a52");
  }

  function drawSelection(now) {
    const id = state.selected;
    let x, y, w, h;
    if (id === "pm") { x = state.pm.x - 15; y = state.pm.y - 48; w = 30; h = 50; }
    else if (agent(id).pos) { const p = agent(id).pos; x = p.x - 15; y = p.y - 48; w = 30; h = 50; }
    else { const s = seatOf(agent(id)); x = s.x - 18; y = s.y - 24; w = 36; h = 38; }
    g.strokeStyle = Math.floor(now * 4) % 2 ? "#f2c14e" : "#b98d27";
    g.lineWidth = 2;
    g.strokeRect(Math.round(x), Math.round(y), w, h);
  }

  function render(now) {
    px(0, 0, W, H, "#0b0e14");
    drawHall(now);
    ROOMS.forEach(r => drawRoom(r, now));
    state.agents.forEach(a => {
      if (!a.present) return;
      if (a.room === "meet") drawSeatedMeeting(a, now);
      else drawSeated(a, now);
    });
    ROOMS.forEach(r => { if (r.off) px(r.x, r.y, RW, RH, "rgba(11,14,20,0.62)"); });
    drawMeetingTable();
    drawSelection(now);
    // La gente de pie y el PM, de atrás hacia adelante.
    const standing = state.agents.filter(a => a.present && a.pos && !/^stall/.test(a.doing || "")).map(a => ({ y: a.pos.y, draw: () => drawWalker(a, now) }));
    standing.push({ y: state.pm.y, draw: () => drawPM(now) });
    if (state.courier) standing.push({ y: state.courier.pos.y, draw: () => drawWalker(state.courier, now) });
    if (state.petWalk) standing.push({ y: state.petWalk.pos.y, draw: () => drawPetWalking(state.petWalk, now) });
    standing.sort((p, q) => p.y - q.y).forEach(o => o.draw());
    // Apagón: todo a oscuras, con un par de parpadeos antes de que vuelva la luz.
    const dark = state.blackout - state.t;
    if (dark > 0 && !(dark < 1.2 && Math.floor(now * 10) % 2)) {
      px(0, 0, W, H, "rgba(4,6,10,0.84)");
      state.agents.forEach(a => { if (a.present && !a.pos && a.room !== "meet") { const s = seatOf(a); px(s.x - 29, s.y - 10, 22, 13, "rgba(120,200,255,0.18)"); } });
    }
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(world, 0, 0, W * S, H * S);
    drawLabels();
  }

  // En la sala de reuniones se sientan a la mesa, sin escritorio propio.
  function drawSeatedMeeting(a, now) {
    const s = seatOf(a), lk = look(a.look);
    drawChair(s.x, s.y, "meet");
    if (a.pos) return;
    const ty = s.y - 2;
    drawTorso(s.x, ty, a, a.color);
    drawHead(s.x - 8, ty - 13, lk, { mood: moodOf(a), blink: Math.floor(now * 2.2 + s.x) % 17 === 0, style: a.id === "ceo" ? 0 : undefined });
    if (a.id === "ceo" && !hasHat(a)) px(s.x - 6, ty - 17, 12, 2, "#c9c3b6"); // canas del CEO
    drawWear(a, s.x, ty, now);
    if (a.status === "working") { const f = Math.floor(now * 4) % 2; px(s.x - 7, ty + 10 - f, 5, 3, lk.skin.s); }
  }

  // Texto nítido sobre el canvas escalado.
  function text(t, x, y, o = {}) {
    const size = (o.size || 7) * S;
    ctx.font = (o.bold ? "700 " : "400 ") + size + "px " + (o.font || "Silkscreen, monospace");
    ctx.textAlign = o.align || "left";
    ctx.textBaseline = "top";
    const w = ctx.measureText(t).width;
    const pad = 3 * S;
    const bx = o.align === "center" ? x * S - w / 2 - pad : x * S - pad;
    const by = y * S - pad * 0.7;
    if (o.bg) {
      ctx.fillStyle = o.bg;
      ctx.fillRect(Math.round(bx), Math.round(by), Math.round(w + pad * 2), Math.round(size + pad * 1.4));
      if (o.border) { ctx.strokeStyle = o.border; ctx.lineWidth = S; ctx.strokeRect(Math.round(bx) + S / 2, Math.round(by) + S / 2, Math.round(w + pad * 2) - S, Math.round(size + pad * 1.4) - S); }
      if (o.tail) { ctx.fillStyle = o.border || o.bg; ctx.fillRect(Math.round(x * S - 2 * S), Math.round(by + size + pad * 1.4), 4 * S, 3 * S); }
    }
    ctx.fillStyle = o.color || "#ebe5d8";
    ctx.fillText(t, x * S, y * S);
  }

  function drawLabels() {
    ROOMS.forEach(r => {
      const busy = state.agents.some(a => a.room === r.id && a.status === "working") || (r.id === "meet" && state.pm.room === "meet" && state.pm.status === "working" && !state.pm.walking);
      const ly = r.top ? 190 : 251;
      text(r.name.toUpperCase(), doorX(r), ly, { size: 7, align: "center", color: busy ? "#f2c14e" : "#a9b1c2", bg: "rgba(11,14,20,0.85)", border: busy ? "#7a6326" : "#313b52" });
    });
    drawBoardText();
    text("EMPLEADO DEL MES", room("meet").x + 85, room("meet").y + 27.5, { size: 3.5, align: "center", color: "#1a1406", bg: "#d4a933" });
    ROOMS.forEach(r => { if (r.off) text("SIN INSTALAR", r.x + RW / 2, r.y + RH / 2 - 4, { size: 7, align: "center", color: "#98a1b3", bg: "rgba(11,14,20,0.9)", border: "#313b52" }); });
    state.agents.forEach(a => {
      if (!a.present) return;
      const st = !!a.pos, s = st ? a.pos : seatOf(a);
      const ny = st ? s.y + 4 : a.room === "meet" ? s.y - 34 : s.y + 38;
      text(a.short, s.x, ny, { size: 6.5, align: "center", color: "#cfc8ba", bg: a.room === "meet" || st ? "rgba(11,14,20,0.7)" : null });
      let label = null, color = "#ebe5d8", border = "#313b52", bg = "rgba(11,14,20,0.94)";
      if (a.say) { label = a.say.text; color = "#1a1406"; bg = "#f6f2e7"; border = "#f6f2e7"; }
      else if (a.status === "working" && a.stuck) { label = "¿trabado? " + a.stuck + " min sin novedades"; color = "#1a1406"; bg = "#ef9a5b"; border = "#ef9a5b"; }
      else if (a.status === "working") { label = a.tool; color = "#f2c14e"; border = "#7a6326"; }
      else if (a.status === "waiting") { label = "esperando"; color = "#1a1406"; bg = "#f2c14e"; border = "#f2c14e"; }
      else if (a.bubble) { label = a.bubble; color = a.status === "fail" ? "#ef6b5b" : "#5cc98a"; border = color; }
      if (label) {
        const t = label.length > 30 ? label.slice(0, 29) + "…" : label;
        // El líder sentado habla hacia el espacio libre a su derecha, no sobre el escritorio de arriba.
        const side = !st && /\.lead$/.test(a.role || "") ? 74 : 0;
        text(t, s.x + side, s.y - (st ? 60 : side ? 4 : a.room === "meet" ? 52 : 40), { size: 6.5, align: "center", color, bg, border, tail: true, font: "'Space Mono', monospace" });
      }
    });
    const c = state.courier;
    if (c) {
      text("Repartidor", c.pos.x, c.pos.y + 4, { size: 6.5, align: "center", color: "#ef9a8f", bg: "rgba(11,14,20,0.7)" });
      if (c.say) text(c.say.text, c.pos.x, c.pos.y - 60, { size: 6.5, align: "center", color: "#1a1406", bg: "#f6f2e7", border: "#f6f2e7", tail: true, font: "'Space Mono', monospace" });
    }
    const pm = state.pm;
    text("PM", pm.x, pm.y + 4, { size: 6.5, align: "center", color: "#c9b8f5" });
    if (pm.tool) {
      const waiting = pm.status === "waiting";
      text(pm.tool, pm.x, pm.y - 60, { size: 6.5, align: "center", color: waiting ? "#1a1406" : "#d8ccff", bg: waiting ? "#f2c14e" : "rgba(11,14,20,0.94)", border: waiting ? "#f2c14e" : "#5b4a8a", tail: true, font: "'Space Mono', monospace" });
    }
  }


