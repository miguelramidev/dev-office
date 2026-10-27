  // --- Tienda: la oficina crece con los tokens -----------------------------------
  // Cada sesión de Claude Code es una partida nueva: la oficina empieza básica (piso de
  // cemento, mesas plegables y sillas de plástico) y se amuebla con lo que compra el CEO.
  // La moneda son los tokens que gastó la sesión; el nivel sube con ese total y nunca baja.
  // El catálogo general combina tipos de artículo con variantes (colores, maderas, marcos,
  // macetas, paletas...): son miles de artículos. Cada partida muestra una parte al azar,
  // distinta en cada sesión. Las compras se guardan en el almacenamiento de la pestaña.

  // Tokens gastados para llegar a cada nivel (del 1 al 10).
  const LEVELS = [0, 100e3, 300e3, 600e3, 1e6, 1.6e6, 2.5e6, 4e6, 6e6, 9e6];
  const levelOf = n => LEVELS.filter(t => n >= t).length;

  // Números al azar con semilla: la misma partida arma siempre la misma vitrina.
  function hashStr(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function rng(seed) {
    let a = seed >>> 0;
    return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }

  // Variantes. n: nombre ([masculino, femenino] en los colores), c: color o datos,
  // p: multiplica el precio, lv: niveles que suma.
  const seq = (n, f) => Array.from({ length: n }, (_, i) => f(i));
  const VARIANTS = {
    color: [["rojo", "roja", "#cf4b47"], ["naranja", "naranja", "#e08a3a"], ["amarillo", "amarilla", "#e3c14a"], ["verde", "verde", "#47a865"],
      ["menta", "menta", "#6fd0b0"], ["celeste", "celeste", "#6fb4e6"], ["azul", "azul", "#4a78d6"], ["violeta", "violeta", "#8b6cd6"],
      ["rosa", "rosa", "#e17aa8"], ["negro", "negra", "#2b2d36"], ["blanco", "blanca", "#e9e4d8"], ["gris", "gris", "#8a909c"],
      ["bordó", "bordó", "#7d2f3f"], ["mostaza", "mostaza", "#c9a13a"], ["turquesa", "turquesa", "#2fa6a6"], ["coral", "coral", "#ef7f6b"]]
      .map(([m, f, c]) => ({ n: [m, f], c })),
    wood: [["de roble", "#a67b52"], ["de nogal", "#6e4a2f"], ["de pino", "#c9a26b"], ["de cerezo", "#9a4f35"], ["de ébano", "#3a2a22", 1.6, 1],
      ["de abedul", "#d9c39a"], ["de bambú", "#c8b46a"], ["de caoba", "#7a3b2a", 1.4, 1]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    frame: [["con marco de madera", "#8a6440"], ["con marco negro", "#22242c"], ["con marco dorado", "#d4a933", 2, 2], ["con marco blanco", "#e9e4d8"],
      ["con marco rojo", "#a83a36"], ["con marco azul", "#3a5ea8"]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    pot: [["en maceta de barro", "#a5603c"], ["en maceta blanca", "#e9e4d8"], ["en maceta negra", "#2b2d36"], ["en maceta azul", "#4a78d6"],
      ["en maceta amarilla", "#e3c14a"], ["en maceta rosa", "#e17aa8"], ["en canasto", "#b08a55"], ["en maceta de cemento", "#8a8f99"]].map(([n, c]) => ({ n, c })),
    flower: [["rojas", "#d9473f"], ["amarillas", "#f2c84b"], ["rosas", "#ef8fbf"], ["violetas", "#9a6cd6"], ["blancas", "#f4efe4"], ["naranjas", "#ef8a3a"]].map(([n, c]) => ({ n, c })),
    fur: [["naranja", ["#e08a3a", "#b8682a"]], ["gris", ["#9aa0ab", "#6c727d"]], ["negro", ["#2b2d36", "#17181d"]], ["blanco", ["#f2eee4", "#cfc8ba"]],
      ["atigrado", ["#b88d5a", "#6e4a2f"]], ["manchado", ["#f2eee4", "#3a2a22"]]].map(([n, c]) => ({ n, c })),
    metal: [["de oro", "#e3b341", 3, 3], ["de plata", "#c9ced8", 1.8, 1], ["de bronce", "#c07a43"]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    leather: [["marrón", "#7a4a2a"], ["negro", "#2b2d36"], ["bordó", "#6e2a35"], ["blanco", "#e9e4d8", 1.3, 1], ["caramelo", "#b0743a"]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    glass: [["transparente", "rgba(190,225,240,0.45)"], ["ahumado", "rgba(60,70,85,0.6)"], ["verde", "rgba(110,200,160,0.45)"], ["azulado", "rgba(110,150,230,0.5)"]].map(([n, c]) => ({ n, c })),
    landscape: [["al atardecer", ["#f28b5b", "#f2c14e", "#7d4a6b", "#4a2f4a"]], ["de día", ["#8fc8f0", "#f6e27a", "#5f8f5a", "#3f6f45"]], ["nocturno", ["#1b2546", "#e9e4d8", "#2e3a5c", "#1a2236"]],
      ["de otoño", ["#e9c79a", "#e08a3a", "#a0522d", "#6b3a1e"]], ["nevado", ["#c9dcef", "#ffffff", "#e9eef5", "#9fb3c8"]], ["de playa", ["#7fd0ef", "#f6e27a", "#e9d29a", "#3fa0c0"]]].map(([n, c]) => ({ n, c })),
    palette: [["vibrante", ["#f6f2e7", "#cf4b47", "#f2c14e", "#4a78d6", "#47a865"]], ["pastel", ["#fbf3ea", "#f4b6c2", "#b8e0d2", "#cdb4f0", "#f9e0a8"]],
      ["monocromo", ["#e9e4d8", "#22242c", "#6c727d", "#a3a9b4", "#3a3f4a"]], ["tierra", ["#efe2c8", "#a0522d", "#c9a26b", "#6b8e4e", "#3a2a22"]],
      ["neón", ["#16131f", "#ff4fd8", "#4ff0ff", "#c8ff4f", "#ffd84f"]], ["océano", ["#e6f4f8", "#1f5f8b", "#3fa0c0", "#7fd0ef", "#f2c14e"]]].map(([n, c]) => ({ n: "en paleta " + n, c })),
    seed24: seq(24, i => ({ n: "n.º " + (i + 1), c: i + 1 })),
    seed12: seq(12, i => ({ n: "n.º " + (i + 1), c: i + 1 })),
    seed6: seq(6, i => ({ n: "n.º " + (i + 1), c: i + 1 })),
    portrait: ["de la fundadora", "del primer cliente", "del gato del CEO", "de la abuela", "del inversor", "de la jefa de QA", "del pasante", "de la tía Marta",
      "del capitán", "de la astronauta", "del chef", "de la campeona", "del mago", "de la pintora", "del poeta", "de la detective"].map((n, i) => ({ n, c: i })),
    poster: ["del cohete", "del café", "del bicho", "de las llaves", "del corazón", "del rayo", "de la estrella", "de la nube", "del planeta"].map((n, i) => ({ n, c: i })),
    paper: [["crema", "#efe6cf"], ["celeste", "#9fd0ea"], ["rosa", "#f2b3c8"], ["amarillo", "#f2d36b"], ["menta", "#a9e3cf"], ["negro", "#22242c"], ["rojo", "#cf4b47"], ["violeta", "#8b6cd6"]].map(([n, c]) => ({ n: "fondo " + n, c })),
    diploma: ["al mejor tester", "a cero bugs", "al deploy de los viernes", "al code review", "al café infinito", "al empleado del mes", "a la paciencia", "al primer commit"].map(n => ({ n, c: 0 })),
    map: [["antiguo", ["#e2cfa3", "#a8865a", "#c9a26b"]], ["político", ["#7fb6e6", "#e3c14a", "#47a865"]], ["nocturno", ["#1b2546", "#3a4a7a", "#f2c14e"]], ["del tesoro", ["#e9d29a", "#8a6440", "#cf4b47"]]].map(([n, c]) => ({ n, c })),
    chart: [["de tokens", 1], ["de usuarios", 1], ["de bugs, en baja", -1], ["de cafés por día", 1]].map(([n, c]) => ({ n, c })),
    neonShape: ["corazón", "rayo", "estrella", "taza", "nube", "planeta"].map((n, i) => ({ n: "con forma de " + n, c: [4, 5, 6, 1, 7, 8][i] })),
    neonColor: [["rosa", "#ff5fc8"], ["celeste", "#5fe8ff"], ["verde", "#8bff6a"], ["amarillo", "#ffe35f"], ["violeta", "#b48bff"], ["naranja", "#ff9a4f"]].map(([n, c]) => ({ n, c })),
    lights: [["multicolor", ["#ef6b5b", "#f2c14e", "#5cc98a", "#6f9cff"]], ["cálidas", ["#ffd27a", "#ffb35a", "#ffe9a8", "#ffc46b"]], ["frías", ["#9ad3ef", "#c8f0ff", "#8fb3ff", "#e9f6ff"]],
      ["navideñas", ["#e0443a", "#47a865", "#f2c14e", "#e0443a"]], ["arcoíris", ["#ef6b5b", "#f2a14e", "#f2e14e", "#5cc98a", "#6f9cff", "#b48bff"]]].map(([n, c]) => ({ n, c })),
    flags: [["de colores", ["#ef6b5b", "#f2c14e", "#5cc98a", "#6f9cff"]], ["rojos y blancos", ["#cf4b47", "#f6f2e7"]], ["pastel", ["#f4b6c2", "#b8e0d2", "#cdb4f0", "#f9e0a8"]],
      ["de fiesta", ["#ff5fc8", "#5fe8ff", "#ffe35f"]], ["verdes", ["#2f7a47", "#56aa70", "#9ad8a8"]], ["azules", ["#1f5f8b", "#4a78d6", "#9ad3ef"]]].map(([n, c]) => ({ n, c })),
    dartboard: [["clásica", ["#2b2d36", "#efe6cf", "#cf4b47", "#47a865"]], ["neón", ["#16131f", "#ff5fc8", "#5fe8ff", "#c8ff4f"]], ["de madera", ["#5e4229", "#c9a26b", "#cf4b47", "#e3c14a"]]].map(([n, c]) => ({ n, c })),
    kitRoom: [["meet", "de Reuniones"], ["design", "de Diseño"], ["back", "de Backend"], ["front", "de Frontend"], ["db", "de Base de datos"], ["scrap", "de Scraping"], ["ops", "de DevOps"], ["qa", "de QA"]].map(([c, n]) => ({ n, c })),
    floorPair: [["gris", ["#3c4150", "#363a48"]], ["azul", ["#2b3750", "#263148"]], ["violeta", ["#3a3350", "#342d48"]], ["verde", ["#2a3a33", "#25342d"]], ["bordó", ["#462c31", "#3f272c"]],
      ["arena", ["#5a4e3a", "#524633"]], ["petróleo", ["#22414a", "#1e3a42"]], ["ciruela", ["#47304a", "#402a43"]], ["mostaza", ["#5c4a22", "#53421e"]], ["grafito", ["#26282e", "#212328"]]].map(([n, c]) => ({ n, c })),
    tile: [["blancas", ["#d9d4c8", "#b9b3a6"]], ["grises", ["#7a808c", "#5f6572"]], ["terracota", ["#a65f3f", "#7f4730"]], ["verde agua", ["#7fc9b8", "#5fa898"]], ["azules", ["#4f6fa8", "#3c5788"]], ["negras", ["#2b2d36", "#1d1f26"]]].map(([n, c]) => ({ n, c })),
    checker: [["blanco y negro", ["#e9e4d8", "#22242c"]], ["rojo y crema", ["#b8433d", "#efe6cf"]], ["verde y crema", ["#3f7a55", "#efe6cf"]], ["azul y blanco", ["#3a5ea8", "#e9e4d8"]], ["amarillo y gris", ["#d9b443", "#5f6572"]]].map(([n, c]) => ({ n, c })),
    marble: [["blanco", ["#e6e2da", "#c9c3b8"]], ["negro", ["#2b2d36", "#5a5e6a"]], ["verde", ["#4f7a62", "#89b39a"]], ["rosa", ["#e3c3c0", "#c99a96"]]].map(([n, c]) => ({ n, c })),
    stripes: [["azul y blanco", ["#3a5ea8", "#d9d4c8"]], ["rojo y crema", ["#a83a36", "#e6dcc2"]], ["verde y arena", ["#3f7a55", "#cdbb93"]], ["gris y negro", ["#5f6572", "#2b2d36"]], ["violeta y rosa", ["#6a4fa8", "#e3a6c8"]]].map(([n, c]) => ({ n, c })),
    brick: [["rojo", ["#8a4a3a", "#6e382b", "#b9a58a"]], ["blanco", ["#d9d4c8", "#bdb6a8", "#9a9488"]], ["gris", ["#5f6572", "#4a4f5a", "#8a909c"]]].map(([n, c]) => ({ n, c })),
    chalk: seq(6, i => ({ n: "n.º " + (i + 1), c: i + 1 })),
    deskColor: [["blanco", "#e6e2da"], ["negro", "#2b2d36"], ["gris", "#8a909c"], ["celeste", "#9fd0ea"], ["verde", "#7fbf8f"], ["rosa", "#f2b3c8"]].map(([n, c]) => ({ n, c })),
    glow: [["roja", "#ff4f4f"], ["verde", "#4fff8a"], ["azul", "#4f9aff"], ["violeta", "#b04fff"], ["cian", "#4ff0ff"], ["arcoíris", null, 1.5, 1]].map(([n, c, p, lv]) => ({ n: "con luces " + n, c, p: p || 1, lv: lv || 0 })),
    pair: [["rojo y negro", ["#cf4b47", "#22242c"]], ["azul y negro", ["#4a78d6", "#22242c"]], ["verde y negro", ["#47a865", "#22242c"]], ["blanco y rosa", ["#e9e4d8", "#e17aa8"]], ["naranja y gris", ["#e08a3a", "#5f6572"]], ["violeta y blanco", ["#8b6cd6", "#e9e4d8"]]].map(([n, c]) => ({ n, c })),
    teams: [["rojo contra azul", ["#cf4b47", "#4a78d6"]], ["amarillo contra verde", ["#e3c14a", "#47a865"]], ["negro contra blanco", ["#2b2d36", "#e9e4d8"]]].map(([n, c]) => ({ n, c })),
    water: [["de agua clara", "#5fb8e0"], ["de agua verde", "#4fa88a"], ["tropical", "#3fc8c8"]].map(([n, c]) => ({ n, c })),
    piano: [["negro", "#1f2028"], ["blanco", "#ece8e0", 1.5, 1], ["de madera", "#6e4a2f"]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    statue: [["de mármol", "#e6e2da"], ["de bronce", "#a0703a", 1.5, 1], ["de oro", "#e3b341", 3, 3]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
    espresso: [["roja", "#cf4b47"], ["negra", "#2b2d36"], ["cromada", "#c9ced8", 1.4, 1]].map(([n, c, p, lv]) => ({ n, c, p: p || 1, lv: lv || 0 })),
  };
  const colorName = (v, g) => Array.isArray(v.n) ? v.n[g === "f" ? 1 : 0] : v.n;

  // --- Ayudantes de dibujo para la tienda ---
  const box = (x, y, w, h, c) => { px(x - 1, y - 1, w + 2, h + 2, OUT); px(x, y, w, h, c); };
  function disc(cx, cy, r, c) { for (let dy = -r; dy <= r; dy++) { const w = Math.floor(Math.sqrt(r * r - dy * dy + r * 0.8)); px(cx - w, cy + dy, w * 2 + 1, 1, c); } }
  function tri(cx, top, h, c) { for (let i = 0; i < h; i++) px(cx - i, top + i, i * 2 + 1, 1, c); }
  // Cuadro con marco: devuelve el área de adentro.
  function framed(x, y, w, h, fr) {
    px(x - 1, y - 1, w + 2, h + 2, OUT); px(x, y, w, h, fr); px(x, y, w, 1, shade(fr, 0.3)); px(x, y + h - 1, w, 1, shade(fr, -0.3));
    px(x + 2, y + 2, w - 4, h - 4, OUT);
    return { x: x + 2, y: y + 2, w: w - 4, h: h - 4 };
  }
  function clipped(x, y, w, h, f) { g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip(); f(); g.restore(); }
  // Íconos de 9 x 9 para pósters y neones. X tinta, A relleno, R rojo.
  const ICONS = [
    ["....X....", "...XAX...", "...XAX...", "..XAAAX..", "..XAXAX..", "..XAAAX..", ".XXAAAXX.", "XX.XXX.XX", "...R.R..."],
    [".........", "..X.X.X..", ".........", "XXXXXXX..", "XAAAAAXXX", "XAAAAAX.X", "XAAAAAXXX", ".XAAAX...", "XXXXXXXX."],
    ["..X...X..", "...XXX...", ".XXAAAXX.", "..XAAAX..", ".XXAAAXX.", "..XAAAX..", ".X.XXX.X.", ".........", "........."],
    ["..XX.XX..", ".X.....X.", ".X.....X.", "X.......X", ".X.....X.", ".X.....X.", "..XX.XX..", ".........", "........."],
    [".XX.XX...", "XAAXAAX..", "XAAAAAX..", ".XAAAX...", "..XAX....", "...X.....", ".........", ".........", "........."],
    ["...XXX...", "..XAX....", ".XAX.....", "XAAAAX...", "..XAX....", ".XAX.....", ".XX......", ".........", "........."],
    ["....X....", "...XAX...", "XXXXAXXXX", ".XAAAAAX.", "..XAAAX..", ".XAX.XAX.", "XX.....XX", ".........", "........."],
    ["...XXX...", ".XXAAAX..", "XAAAAAAXX", "XAAAAAAAX", ".XXXXXXX.", ".........", ".........", ".........", "........."],
    ["...XXX...", "..XAAAX..", "XXXXXXXXX", "..XAAAX..", "...XXX...", ".........", ".........", ".........", "........."],
  ];
  const iconW = rows => Math.max(...rows.map(r => r.replace(/\.+$/, "").length));
  const iconH = rows => rows.filter(r => r.includes("X") || r.includes("A") || r.includes("R")).length;
  function icon(i, cx, cy, ink, fill) {
    const rows = ICONS[i], w = iconW(rows), h = iconH(rows);
    sprite(Math.round(cx - w / 2), Math.round(cy - h / 2), rows, { X: ink, A: fill, R: "#cf4b47" });
  }
  function pot(cx, by, c) {
    px(cx - 6, by - 10, 12, 10, OUT); px(cx - 5, by - 9, 10, 8, c); px(cx - 5, by - 9, 10, 2, shade(c, 0.2)); px(cx - 6, by - 11, 12, 2, OUT); px(cx - 5, by - 11, 10, 1, shade(c, -0.15));
    return by - 11;
  }
  const isNight = () => { const h = new Date().getHours(); return h >= 20 || h < 7; };

  // --- Catálogo general ---
  // slot: dónde va. wall (pared, 34 x 24), kit (equipamiento de un departamento),
  // small (piso, hasta 14 de ancho), big (piso, hasta 60 x 44), desk, chair, floor y
  // paint (uno por oficina), top, hat, face y neck (ropa de un empleado).
  // Precios en tokens; lv es el nivel desde el que se puede comprar.
  const KINDS = [
    // Cuadros y pared.
    { k: "paisaje", cat: "Cuadros", slot: "wall", name: "Paisaje", lv: 1, price: 9000, vars: ["landscape", "frame"],
      draw(x, y, [l, f]) { const r = framed(x + 3, y + 1, 28, 21, f.c), [sky, sun, m1, m2] = l.c; px(r.x, r.y, r.w, r.h, sky); disc(r.x + 18, r.y + 4, 2, sun); tri(r.x + 7, r.y + 5, 8, m1); tri(r.x + 16, r.y + 8, 6, shade(m1, -0.15)); px(r.x, r.y + 13, r.w, r.h - 13, m2); } },
    { k: "abstracto", cat: "Cuadros", slot: "wall", name: "Abstracto", lv: 2, price: 22000, vars: ["seed24", "palette", "frame"],
      draw(x, y, [s, p, f]) { const r = framed(x + 3, y + 1, 28, 21, f.c), R = rng(s.c * 7919), c = p.c; px(r.x, r.y, r.w, r.h, c[0]);
        for (let i = 0; i < 6; i++) { const w = 3 + Math.floor(R() * 9), h = 2 + Math.floor(R() * 7); px(r.x + Math.floor(R() * (r.w - w + 1)), r.y + Math.floor(R() * (r.h - h + 1)), w, h, c[1 + Math.floor(R() * 4)]); }
        if (s.c % 3 === 0) disc(r.x + 6 + Math.floor(R() * 12), r.y + 5 + Math.floor(R() * 6), 3, c[1 + (s.c % 4)]); } },
    { k: "retrato", cat: "Cuadros", slot: "wall", name: "Retrato", lv: 3, price: 30000, vars: ["portrait", "frame"],
      draw(x, y, [s, f]) { const r = framed(x + 4, y, 26, 24, f.c); px(r.x, r.y, r.w, r.h, ["#3a3f4a", "#5a3f3a", "#2f4a45", "#4a3f5a"][s.c % 4]);
        clipped(r.x, r.y, r.w, r.h, () => { const lk = look(s.c * 5 + 2); px(r.x + 3, r.y + 15, 16, 6, ["#8b6cd6", "#cf4b47", "#47a865", "#e3c14a"][s.c % 4]); drawHead(r.x + 3, r.y + 4, lk, { mood: "happy" }); }); } },
    { k: "poster", cat: "Cuadros", slot: "wall", name: "Póster", lv: 1, price: 6000, vars: ["poster", "paper"],
      draw(x, y, [s, p]) { box(x + 7, y + 1, 20, 22, p.c); const dark = ["#22242c", "#cf4b47", "#8b6cd6"].includes(p.c); px(x + 6, y, 4, 2, "rgba(240,235,220,0.7)"); px(x + 24, y, 4, 2, "rgba(240,235,220,0.7)");
        icon(s.c, x + 17, y + 11, dark ? "#f6f2e7" : "#22242c", dark ? "#f2c14e" : "#ffffff"); } },
    { k: "diploma", cat: "Cuadros", slot: "wall", name: "Diploma", lv: 2, price: 12000, vars: ["diploma", "frame"],
      draw(x, y, [s, f]) { const r = framed(x + 3, y + 2, 28, 20, f.c); px(r.x, r.y, r.w, r.h, "#f6f2e7"); px(r.x + 4, r.y + 2, 16, 1, "#3a3f4a"); px(r.x + 3, r.y + 5, 18, 1, "#98a1b3"); px(r.x + 3, r.y + 7, 14, 1, "#98a1b3");
        disc(r.x + 18, r.y + 11, 2, "#cf4b47"); px(r.x + 17, r.y + 13, 1, 3, "#cf4b47"); px(r.x + 19, r.y + 13, 1, 3, "#cf4b47"); px(r.x + 3, r.y + 12, 8, 1, "#3a3f4a"); } },
    { k: "mapa", cat: "Cuadros", slot: "wall", name: "Mapa", lv: 3, price: 20000, vars: ["map", "frame"],
      draw(x, y, [m, f]) { const r = framed(x + 2, y + 2, 30, 20, f.c), [sea, land, mark] = m.c; px(r.x, r.y, r.w, r.h, sea);
        [[2, 2, 7, 5], [4, 7, 4, 6], [12, 3, 5, 4], [13, 7, 4, 7], [19, 2, 6, 5], [21, 8, 4, 3]].forEach(([dx, dy, w, h]) => px(r.x + dx, r.y + dy, w, h, land));
        px(r.x + 20, r.y + 4, 2, 2, mark); } },
    { k: "grafico", cat: "Cuadros", slot: "wall", name: "Gráfico", lv: 2, price: 10000, vars: ["chart", "color"], g: "m",
      draw(x, y, [ch, c]) { const r = framed(x + 3, y + 2, 28, 20, "#3a3f4a"); px(r.x, r.y, r.w, r.h, "#f6f2e7"); px(r.x + 1, r.y + r.h - 2, r.w - 2, 1, "#3a3f4a");
        for (let i = 0; i < 6; i++) { const h = ch.c > 0 ? 3 + i * 2 : 13 - i * 2; px(r.x + 2 + i * 4, r.y + r.h - 2 - h, 3, h, c.c); } } },
    { k: "reloj", cat: "Cuadros", slot: "wall", name: "Reloj de pared", lv: 1, price: 8000, vars: ["color"], g: "m",
      draw(x, y, [c]) { const cx = x + 17, cy = y + 12; disc(cx, cy, 10, OUT); disc(cx, cy, 9, c.c); disc(cx, cy, 7, "#f6f2e7");
        for (let i = 0; i < 12; i += 3) px(cx + Math.round(Math.sin(i / 6 * Math.PI) * 6), cy - Math.round(Math.cos(i / 6 * Math.PI) * 6), 1, 1, "#3a3f4a");
        const d = new Date(), hand = (a, l, col) => { for (let k = 0; k <= l; k++) px(cx + Math.round(Math.sin(a) * k), cy - Math.round(Math.cos(a) * k), 1, 1, col); };
        hand((d.getHours() % 12 + d.getMinutes() / 60) / 6 * Math.PI, 4, "#22242c"); hand(d.getMinutes() / 30 * Math.PI, 6, "#22242c"); hand(d.getSeconds() / 30 * Math.PI, 6, "#cf4b47"); } },
    { k: "corcho", cat: "Cuadros", slot: "wall", name: "Corcho con notas", lv: 1, price: 7000, vars: ["seed12"],
      draw(x, y, [s]) { const r = framed(x + 2, y + 1, 30, 22, "#8a6440"), R = rng(s.c * 104729); px(r.x, r.y, r.w, r.h, "#c9995e");
        for (let i = 0; i < 5; i++) { const nx = r.x + 1 + Math.floor(R() * (r.w - 7)), ny = r.y + 1 + Math.floor(R() * (r.h - 7)); px(nx, ny, 6, 6, ["#f2e27a", "#f4b6c2", "#9fd0ea", "#b8e0d2"][Math.floor(R() * 4)]); px(nx + 1, ny + 2, 4, 1, "#98a1b3"); px(nx + 2, ny, 2, 1, "#cf4b47"); } } },
    { k: "neon", cat: "Cuadros", slot: "wall", name: "Cartel de neón", lv: 4, price: 45000, vars: ["neonShape", "neonColor"],
      draw(x, y, [s, c], now) { box(x + 5, y + 1, 24, 22, "#16131f"); const on = Math.floor(now * 9 + s.c) % 37 !== 0;
        if (on) { px(x + 7, y + 3, 20, 18, shade(c.c, -0.75)); } icon(s.c, x + 17, y + 12, on ? c.c : shade(c.c, -0.6), on ? shade(c.c, 0.5) : shade(c.c, -0.7)); } },
    { k: "guirnalda", cat: "Adornos", slot: "wall", name: "Guirnalda de luces", lv: 2, price: 9000, vars: ["lights"], g: "f",
      draw(x, y, [l], now) { for (let i = 0; i < 34; i++) { const sag = Math.round(Math.sin(i / 33 * Math.PI) * 6); px(x + i, y + 4 + sag, 1, 1, "#3a3f4a");
        if (i % 4 === 1) { const on = (Math.floor(now * 2) + i) % 3 !== 0; px(x + i, y + 5 + sag, 2, 3, on ? l.c[(i >> 2) % l.c.length] : shade(l.c[(i >> 2) % l.c.length], -0.6)); } } } },
    { k: "estante", cat: "Muebles", slot: "wall", name: "Estante de pared", lv: 2, price: 14000, vars: ["wood", "seed6"], g: "m",
      draw(x, y, [w, s]) { const R = rng(s.c * 31337); px(x + 2, y + 17, 30, 3, OUT); px(x + 3, y + 17, 28, 2, w.c); px(x + 6, y + 20, 2, 3, shade(w.c, -0.3)); px(x + 26, y + 20, 2, 3, shade(w.c, -0.3));
        let bx = x + 4; while (bx < x + 26) { const bw = 2 + Math.floor(R() * 3), bh = 7 + Math.floor(R() * 7); px(bx, y + 17 - bh, bw, bh, OUT); px(bx, y + 18 - bh, bw - 1, bh - 1, ["#cf4b47", "#4a78d6", "#47a865", "#e3c14a", "#8b6cd6", "#e9e4d8"][Math.floor(R() * 6)]); bx += bw + (R() < 0.2 ? 3 : 0); }
        if (s.c % 2) { px(x + 27, y + 12, 4, 5, "#a5603c"); px(x + 26, y + 8, 6, 4, "#3f8f5a"); } } },
    { k: "diana", cat: "Adornos", slot: "wall", name: "Diana de dardos", lv: 3, price: 16000, vars: ["dartboard"], g: "f",
      draw(x, y, [d]) { const cx = x + 17, cy = y + 12, c = d.c; disc(cx, cy, 10, OUT); disc(cx, cy, 9, c[0]); disc(cx, cy, 7, c[1]); disc(cx, cy, 5, c[3]); disc(cx, cy, 3, c[1]); disc(cx, cy, 1, c[2]);
        px(cx + 2, cy - 4, 5, 1, "#3a3f4a"); px(cx + 6, cy - 5, 2, 3, "#cf4b47"); px(cx - 3, cy + 1, 4, 1, "#3a3f4a"); px(cx - 5, cy, 2, 3, "#4a78d6"); } },
    { k: "banderines", cat: "Adornos", slot: "wall", name: "Banderines", lv: 1, price: 5000, vars: ["flags"], g: "m",
      draw(x, y, [f]) { for (let i = 0; i < 34; i++) px(x + i, y + 3 + Math.round(Math.sin(i / 33 * Math.PI) * 3), 1, 1, "#3a3f4a");
        for (let i = 0; i < 5; i++) { const fx = x + 2 + i * 6, fy = y + 4 + Math.round(Math.sin((i * 6 + 3) / 33 * Math.PI) * 3); for (let k = 0; k < 4; k++) px(fx + k / 2, fy + k, 5 - k, 1, f.c[i % f.c.length]); } } },
    { k: "calendario", cat: "Adornos", slot: "wall", name: "Calendario", lv: 1, price: 4000, vars: ["color"], g: "m",
      draw(x, y, [c]) { box(x + 9, y + 2, 16, 20, "#f6f2e7"); px(x + 9, y + 2, 16, 5, c.c); px(x + 12, y + 1, 1, 2, OUT); px(x + 21, y + 1, 1, 2, OUT);
        const day = new Date().getDate(); for (let i = 0; i < 20; i++) px(x + 10 + (i % 5) * 3, y + 9 + Math.floor(i / 5) * 3, 2, 2, i === day % 20 ? "#cf4b47" : "#c9c1b0"); } },
    { k: "pizarrita", cat: "Adornos", slot: "wall", name: "Pizarrita con garabatos", lv: 1, price: 6000, vars: ["chalk"], g: "f",
      draw(x, y, [s]) { const r = framed(x + 2, y + 2, 30, 20, "#8a6440"), R = rng(s.c * 7717); px(r.x, r.y, r.w, r.h, "#2f4a3a");
        for (let i = 0; i < 4; i++) { let cx = r.x + 2 + Math.floor(R() * 20), cy = r.y + 2 + Math.floor(R() * 10); for (let k = 0; k < 7; k++) { px(cx, cy, 1, 1, "#e9e4d8"); cx += R() < 0.7 ? 1 : 0; cy += R() < 0.5 ? (R() < 0.5 ? 1 : -1) : 0; } }
        px(r.x + 2, r.y + r.h - 3, 10, 1, "#e9e4d8"); } },
    { k: "kit", cat: "Equipamiento", slot: "kit", name: "Equipamiento", lv: 1, price: 25000, vars: ["kitRoom"], g: "m",
      draw(x, y, [k], now) { drawDeco({ deco: k.c, x, y }, now); } },
  ];

  // Plantas y adornos de piso (slot small): (cx, by) es el centro de la base.
  const leaf = "#2f7a47", leafM = "#3f8f5a", leafL = "#56aa70";
  KINDS.push(
    { k: "planta", cat: "Plantas", slot: "small", name: "Planta", lv: 1, price: 5000, vars: ["pot"], g: "f",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); px(cx - 7, t - 9, 14, 10, leaf); px(cx - 5, t - 14, 10, 6, leafM); px(cx - 2, t - 18, 5, 5, leafL); px(cx - 6, t - 7, 3, 3, leafL); px(cx + 3, t - 11, 3, 3, "#62bf7f"); } },
    { k: "cactus", cat: "Plantas", slot: "small", name: "Cactus", lv: 1, price: 4000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); box(cx - 2, t - 16, 5, 16, "#3f8f5a"); px(cx - 1, t - 15, 1, 14, "#56aa70"); box(cx - 6, t - 11, 3, 5, "#3f8f5a"); box(cx + 4, t - 13, 3, 6, "#3f8f5a"); px(cx - 4, t - 7, 2, 1, "#3f8f5a"); px(cx + 3, t - 8, 2, 1, "#3f8f5a"); px(cx, t - 18, 2, 2, "#ef8fbf"); } },
    { k: "suculenta", cat: "Plantas", slot: "small", name: "Suculenta", lv: 1, price: 4000, vars: ["pot"], g: "f",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); px(cx - 6, t - 3, 12, 3, "#6fb08a"); px(cx - 4, t - 6, 8, 4, "#86c79f"); px(cx - 2, t - 8, 4, 3, "#a3dcb7"); px(cx - 7, t - 2, 2, 1, "#4f8f6a"); px(cx + 5, t - 2, 2, 1, "#4f8f6a"); } },
    { k: "tulipanes", cat: "Plantas", slot: "small", name: "Tulipanes", lv: 2, price: 9000, vars: ["flower", "pot"], g: "m",
      draw(cx, by, [f, p]) { const t = pot(cx, by, p.c); [-4, 0, 4].forEach((d, i) => { const h = 10 + (i % 2) * 4; px(cx + d, t - h, 1, h, leafM); box(cx + d - 1, t - h - 4, 3, 4, f.c); px(cx + d - 1, t - h - 4, 1, 1, shade(f.c, 0.3)); }); px(cx - 3, t - 5, 2, 4, leafL); } },
    { k: "bonsai", cat: "Plantas", slot: "small", name: "Bonsái", lv: 4, price: 32000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { px(cx - 7, by - 5, 14, 5, OUT); px(cx - 6, by - 4, 12, 3, p.c); const t = by - 5; px(cx - 1, t - 6, 2, 6, "#5e4229"); px(cx, t - 9, 3, 3, "#5e4229"); px(cx - 4, t - 8, 3, 2, "#5e4229");
        box(cx - 7, t - 13, 6, 4, leafM); box(cx + 1, t - 15, 6, 5, leafM); box(cx - 3, t - 17, 5, 3, leafL); } },
    { k: "helecho", cat: "Plantas", slot: "small", name: "Helecho", lv: 2, price: 8000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); for (let i = -3; i <= 3; i++) { const lx = cx + i * 2, h = 8 - Math.abs(i); for (let k = 0; k < h; k++) px(lx + Math.sign(i) * Math.floor(k / 3), t - h + k, 2, 1, k % 2 ? leafL : leafM); } } },
    { k: "bambu", cat: "Plantas", slot: "small", name: "Bambú", lv: 3, price: 14000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); [-3, 0, 3].forEach((d, i) => { const h = 18 + i * 3; px(cx + d, t - h, 2, h, "#8fbf5a"); for (let k = 4; k < h; k += 6) px(cx + d, t - k, 2, 1, "#5f8f3a"); px(cx + d + 2, t - h + 2, 3, 2, leafL); }); } },
    { k: "girasol", cat: "Plantas", slot: "small", name: "Girasol", lv: 2, price: 7000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); px(cx, t - 18, 1, 18, leafM); px(cx - 4, t - 9, 4, 2, leafL); px(cx + 1, t - 12, 4, 2, leafL); disc(cx, t - 21, 4, "#f2c84b"); disc(cx, t - 21, 2, "#6e4a2f"); } },
    { k: "lavanda", cat: "Plantas", slot: "small", name: "Lavanda", lv: 2, price: 7000, vars: ["pot"], g: "f",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); for (let i = -4; i <= 4; i += 2) { const h = 9 + ((i + 4) % 3) * 2; px(cx + i, t - h, 1, h, "#6f9a6a"); px(cx + i - 1, t - h - 3, 3, 4, "#9a7fd6"); px(cx + i, t - h - 4, 1, 1, "#b8a6ee"); } } },
    { k: "orquidea", cat: "Plantas", slot: "small", name: "Orquídea", lv: 5, price: 40000, vars: ["flower", "pot"], g: "f",
      draw(cx, by, [f, p]) { const t = pot(cx, by, p.c); px(cx - 5, t - 3, 10, 3, leafM); px(cx, t - 20, 1, 17, "#6f9a6a"); for (let i = 0; i < 4; i++) { const fx = cx + 1 + i * 2, fy = t - 20 + i * 3; px(fx - 1, fy, 3, 3, f.c); px(fx, fy + 1, 1, 1, "#f2c84b"); } } },
    { k: "palmerita", cat: "Plantas", slot: "small", name: "Palmerita", lv: 3, price: 15000, vars: ["pot"], g: "f",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); px(cx - 1, t - 12, 2, 12, "#8a6440"); for (let k = 0; k < 4; k++) px(cx - 1, t - 3 - k * 3, 2, 1, "#5e4229");
        [[-7, 0], [-5, -2], [1, -2], [3, 0]].forEach(([dx, dy]) => px(cx + dx, t - 13 + dy, 5, 2, leafM)); px(cx - 2, t - 16, 4, 3, leafL); px(cx - 8, t - 11, 2, 2, leafM); px(cx + 7, t - 11, 2, 2, leafM); } },
    { k: "monstera", cat: "Plantas", slot: "small", name: "Monstera", lv: 4, price: 26000, vars: ["pot"], g: "f",
      draw(cx, by, [p]) { const t = pot(cx, by, p.c); [[-7, -12], [0, -17], [1, -9]].forEach(([dx, dy]) => { box(cx + dx, t + dy, 7, 6, "#2f7a47"); px(cx + dx + 2, t + dy + 2, 1, 2, "#16131f"); px(cx + dx + 4, t + dy + 1, 1, 2, "#16131f"); px(cx + dx + 3, t + dy, 1, 6, leafL); }); } },
    { k: "lampara", cat: "Adornos", slot: "small", name: "Lámpara de pie", lv: 2, price: 12000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { px(cx - 4, by - 2, 8, 2, OUT); px(cx, by - 26, 1, 24, "#3a3f4a"); px(cx - 6, by - 32, 12, 7, OUT); px(cx - 5, by - 31, 10, 5, c.c); px(cx - 5, by - 31, 10, 1, shade(c.c, 0.3));
        if (isNight()) px(cx - 7, by - 25, 14, 8, "rgba(255,226,140,0.18)"); } },
    { k: "papelera", cat: "Adornos", slot: "small", name: "Papelera", lv: 1, price: 2000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { box(cx - 5, by - 11, 10, 11, c.c); px(cx - 5, by - 11, 10, 1, shade(c.c, 0.3)); px(cx - 3, by - 13, 3, 2, "#e9e4d8"); px(cx + 1, by - 12, 2, 2, "#cfc8ba"); } },
    { k: "pelota", cat: "Adornos", slot: "small", name: "Pelota de yoga", lv: 1, price: 6000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { disc(cx, by - 7, 7, OUT); disc(cx, by - 7, 6, c.c); px(cx - 3, by - 11, 2, 2, shade(c.c, 0.4)); } },
    { k: "guitarra", cat: "Adornos", slot: "small", name: "Guitarra", lv: 3, price: 18000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { disc(cx, by - 5, 5, OUT); disc(cx, by - 5, 4, c.c); disc(cx, by - 11, 4, OUT); disc(cx, by - 11, 3, c.c); disc(cx, by - 7, 1, "#22242c"); px(cx - 1, by - 28, 2, 16, "#5e4229"); px(cx - 2, by - 31, 4, 3, "#3a2a22"); } },
    { k: "gato", cat: "Adornos", slot: "small", name: "Gato dormido", lv: 2, price: 15000, vars: ["fur"], g: "m",
      draw(cx, by, [f], now) { const [a, b] = f.c, br = Math.round(Math.sin(now * 2) * 0.6 + 0.5); px(cx - 7, by - 6 - br, 14, 6 + br, OUT); px(cx - 6, by - 5 - br, 12, 4 + br, a); px(cx - 6, by - 5 - br, 12, 1, shade(a, 0.2));
        px(cx + 3, by - 8, 5, 5, OUT); px(cx + 4, by - 7, 3, 3, a); px(cx + 4, by - 9, 1, 2, a); px(cx + 6, by - 9, 1, 2, a); px(cx + 4, by - 6, 1, 1, b); px(cx + 6, by - 6, 1, 1, b); px(cx - 8, by - 3, 4, 2, b); } },
    { k: "perro", cat: "Adornos", slot: "small", name: "Perro", lv: 3, price: 20000, vars: ["fur"], g: "m",
      draw(cx, by, [f], now) { const [a, b] = f.c, wag = Math.floor(now * 6) % 2; box(cx - 4, by - 10, 8, 10, a); box(cx - 4, by - 17, 8, 7, a); px(cx - 5, by - 17, 2, 5, b); px(cx + 3, by - 17, 2, 5, b);
        px(cx - 2, by - 15, 1, 1, OUT); px(cx + 1, by - 15, 1, 1, OUT); px(cx - 1, by - 13, 2, 1, OUT); px(cx + 4 + wag, by - 5 - wag, 3, 2, a); px(cx - 3, by - 2, 2, 2, b); px(cx + 1, by - 2, 2, 2, b); } },
    { k: "libros", cat: "Adornos", slot: "small", name: "Pila de libros", lv: 1, price: 3000, vars: ["seed6"], g: "f",
      draw(cx, by, [s]) { const R = rng(s.c * 6007); let yy = by; for (let i = 0; i < 4; i++) { const w = 10 + Math.floor(R() * 3), off = Math.floor(R() * 3) - 1; box(cx - w / 2 + off, yy - 3, w, 3, ["#cf4b47", "#4a78d6", "#47a865", "#e3c14a", "#8b6cd6"][Math.floor(R() * 5)]); yy -= 4; } } },
    { k: "globo", cat: "Adornos", slot: "small", name: "Globo terráqueo", lv: 3, price: 16000, vars: ["metal"], g: "m",
      draw(cx, by, [m], now) { px(cx - 4, by - 2, 8, 2, m.c); px(cx, by - 6, 1, 4, m.c); disc(cx, by - 13, 6, OUT); disc(cx, by - 13, 5, "#4a78d6"); const o = Math.floor(now * 2) % 6; px(cx - 3 + (o % 4), by - 16, 3, 3, "#47a865"); px(cx - 1 + ((o + 2) % 4), by - 12, 3, 4, "#47a865"); px(cx + 6, by - 19, 1, 12, m.c); } },
    { k: "trofeo", cat: "Adornos", slot: "small", name: "Trofeo", lv: 4, price: 30000, vars: ["metal"], g: "m",
      draw(cx, by, [m]) { box(cx - 5, by - 4, 10, 4, "#3a2a22"); px(cx - 1, by - 8, 2, 4, m.c); box(cx - 4, by - 16, 8, 7, m.c); px(cx - 7, by - 15, 2, 4, m.c); px(cx + 5, by - 15, 2, 4, m.c); px(cx - 3, by - 15, 2, 4, shade(m.c, 0.4)); } },
    { k: "extintor", cat: "Adornos", slot: "small", name: "Matafuegos", lv: 1, price: 2000, vars: [], g: "m",
      draw(cx, by) { box(cx - 3, by - 14, 6, 14, "#cf4b47"); px(cx - 2, by - 13, 1, 12, "#ef6b5b"); px(cx - 2, by - 17, 4, 3, "#22242c"); px(cx + 2, by - 16, 3, 1, "#22242c"); px(cx - 3, by - 8, 6, 3, "#e9e4d8"); } },
    { k: "paraguero", cat: "Adornos", slot: "small", name: "Paragüero", lv: 2, price: 6000, vars: ["color"], g: "m",
      draw(cx, by, [c]) { box(cx - 4, by - 12, 8, 12, "#3a3f4a"); px(cx - 3, by - 22, 1, 10, "#22242c"); px(cx + 2, by - 20, 1, 8, "#22242c"); px(cx - 5, by - 24, 5, 3, c.c); px(cx + 1, by - 22, 5, 3, shade(c.c, -0.3)); } },
    { k: "robot", cat: "Adornos", slot: "small", name: "Robot de juguete", lv: 3, price: 18000, vars: ["color"], g: "m",
      draw(cx, by, [c], now) { box(cx - 4, by - 10, 8, 8, c.c); box(cx - 3, by - 17, 6, 6, "#c9ced8"); px(cx - 2, by - 15, 1, 1, Math.floor(now * 3) % 2 ? "#ef6b5b" : "#5cc98a"); px(cx + 1, by - 15, 1, 1, "#4ff0ff");
        px(cx, by - 20, 1, 3, "#3a3f4a"); px(cx - 1, by - 21, 3, 1, "#ef6b5b"); px(cx - 3, by - 2, 2, 2, "#3a3f4a"); px(cx + 1, by - 2, 2, 2, "#3a3f4a"); } },
  );

  // Muebles grandes (slot big): (cx, by) es el centro de la base. Hasta 60 x 44.
  KINDS.push(
    { k: "biblioteca", cat: "Muebles", slot: "big", name: "Biblioteca", lv: 3, price: 60000, vars: ["wood", "seed6"], g: "f",
      draw(cx, by, [w, s]) { const R = rng(s.c * 4243), x = cx - 20, y = by - 42; box(x, y, 40, 42, w.c); px(x + 2, y + 2, 36, 38, shade(w.c, -0.45));
        for (let sh = 0; sh < 3; sh++) { const sy = y + 2 + sh * 13; px(x + 2, sy + 11, 36, 2, w.c); let bx = x + 3; while (bx < x + 35) { const bw = 2 + Math.floor(R() * 3), bh = 7 + Math.floor(R() * 4); px(bx, sy + 11 - bh, Math.min(bw, x + 37 - bx), bh, ["#cf4b47", "#4a78d6", "#47a865", "#e3c14a", "#8b6cd6", "#e9e4d8", "#e08a3a"][Math.floor(R() * 7)]); bx += bw + 1; } } } },
    { k: "sofa", cat: "Muebles", slot: "big", name: "Sofá", lv: 4, price: 90000, vars: ["color"], g: "m",
      draw(cx, by, [c]) { const x = cx - 28, y = by - 22, d = shade(c.c, -0.25); box(x + 4, y, 48, 12, d); box(x, y + 6, 8, 14, c.c); box(x + 48, y + 6, 8, 14, c.c); box(x + 6, y + 10, 44, 8, c.c);
        px(x + 6, y + 10, 44, 1, shade(c.c, 0.25)); px(x + 27, y + 10, 1, 8, d); px(x + 10, y + 3, 10, 6, shade(c.c, 0.15)); px(x + 2, y + 20, 3, 2, "#3a2a22"); px(x + 51, y + 20, 3, 2, "#3a2a22"); } },
    { k: "arcade", cat: "Muebles", slot: "big", name: "Arcade", lv: 5, price: 150000, vars: ["color"], g: "m",
      draw(cx, by, [c], now) { const x = cx - 11, y = by - 42; box(x, y, 22, 42, c.c); px(x + 2, y + 2, 18, 5, "#16131f"); px(x + 4, y + 3, 14, 3, "#f2c14e"); box(x + 3, y + 9, 16, 13, "#16131f");
        const f = Math.floor(now * 4); px(x + 5 + (f % 10), y + 14, 2, 2, "#4ff0ff"); px(x + 6, y + 18, 3, 1, "#ff5fc8"); px(x + 12, y + 11 + (f % 6), 2, 2, "#c8ff4f");
        px(x + 3, y + 24, 16, 5, shade(c.c, -0.3)); px(x + 6, y + 25, 2, 2, "#ef6b5b"); px(x + 12, y + 25, 2, 2, "#6f9cff"); px(x + 15, y + 25, 2, 2, "#f2c14e"); px(x + 2, y + 31, 18, 1, shade(c.c, 0.3)); } },
    { k: "acuario", cat: "Muebles", slot: "big", name: "Acuario", lv: 5, price: 130000, vars: ["water"], g: "m",
      draw(cx, by, [w], now) { const x = cx - 22, y = by - 36; box(x + 2, y + 22, 40, 14, "#5e4229"); box(x, y, 44, 22, w.c); px(x, y, 44, 2, shade(w.c, 0.3)); px(x + 2, y + 18, 40, 3, "#d9c39a");
        for (let i = 0; i < 3; i++) { const fx = x + 4 + ((Math.floor(now * (6 + i * 3)) + i * 13) % 34), fy = y + 5 + i * 4; px(fx, fy, 4, 2, ["#f28b3a", "#f2c14e", "#ff5fc8"][i]); px(fx - 1, fy, 1, 2, ["#c9682a", "#c99a2a", "#c94a9a"][i]); }
        px(x + 34, y + 3 + (Math.floor(now * 3) % 12), 1, 1, "#e9f6ff"); px(x + 8, y + 12, 2, 6, "#3f8f5a"); px(x + 11, y + 10, 2, 8, "#56aa70"); } },
    { k: "minibar", cat: "Muebles", slot: "big", name: "Heladerita", lv: 3, price: 50000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { const x = cx - 10, y = by - 30; box(x, y, 20, 30, c.c); px(x, y + 10, 20, 1, OUT); px(x + 16, y + 3, 1, 5, "#c9ced8"); px(x + 16, y + 13, 1, 8, "#c9ced8"); px(x + 3, y + 14, 6, 6, "#f2c14e"); px(x + 4, y + 15, 4, 4, "#cf4b47"); px(x + 1, y + 1, 18, 1, shade(c.c, 0.3)); } },
    { k: "metegol", cat: "Muebles", slot: "big", name: "Metegol", lv: 6, price: 160000, vars: ["teams"], g: "m",
      draw(cx, by, [t], now) { const x = cx - 26, y = by - 26; box(x, y, 52, 18, "#5e4229"); px(x + 3, y + 3, 46, 12, "#3f8f5a"); px(x + 25, y + 3, 1, 12, "#e9e4d8"); px(x + 3, y + 7, 2, 4, "#e9e4d8"); px(x + 47, y + 7, 2, 4, "#e9e4d8");
        for (let i = 0; i < 4; i++) { const rx = x + 9 + i * 11; px(rx, y - 2, 1, 22, "#c9ced8"); px(rx - 1, y + 5 + (Math.floor(now * 2 + i) % 3), 3, 3, t.c[i % 2]); }
        px(x + 4, y + 18, 3, 8, "#3a2a22"); px(x + 45, y + 18, 3, 8, "#3a2a22"); disc(x + 20 + (Math.floor(now * 5) % 12), y + 9, 1, "#ffffff"); } },
    { k: "expendedora", cat: "Muebles", slot: "big", name: "Máquina expendedora", lv: 5, price: 120000, vars: ["color"], g: "f",
      draw(cx, by, [c], now) { const x = cx - 13, y = by - 42; box(x, y, 26, 42, c.c); box(x + 3, y + 3, 15, 30, "#cfe6f0");
        for (let r = 0; r < 4; r++) for (let k = 0; k < 3; k++) px(x + 4 + k * 5, y + 5 + r * 7, 3, 4, ["#cf4b47", "#e3c14a", "#47a865", "#8b6cd6", "#e08a3a"][(r * 3 + k) % 5]);
        px(x + 20, y + 6, 4, 6, "#16131f"); px(x + 21, y + 7, 2, 1, Math.floor(now * 2) % 2 ? "#5cc98a" : "#1d3a2a"); px(x + 3, y + 35, 15, 4, "#16131f"); } },
    { k: "piano", cat: "Muebles", slot: "big", name: "Piano", lv: 7, price: 260000, vars: ["piano"], g: "m",
      draw(cx, by, [p]) { const x = cx - 22, y = by - 32; box(x, y, 44, 26, p.c); px(x + 2, y + 2, 40, 1, shade(p.c, 0.3)); px(x + 2, y + 16, 40, 5, "#f6f2e7");
        for (let k = 0; k < 13; k++) px(x + 3 + k * 3, y + 16, 1, 5, "#9aa0ab"); for (let k = 0; k < 13; k++) if (k % 7 !== 2 && k % 7 !== 6) px(x + 4 + k * 3, y + 16, 2, 3, "#22242c");
        px(x + 3, y + 26, 3, 6, p.c); px(x + 38, y + 26, 3, 6, p.c); box(x + 14, y + 4, 16, 9, "#f6f2e7"); px(x + 16, y + 6, 12, 1, "#3a3f4a"); px(x + 16, y + 9, 10, 1, "#3a3f4a"); } },
    { k: "puf", cat: "Muebles", slot: "big", name: "Puf gigante", lv: 2, price: 30000, vars: ["color"], g: "m",
      draw(cx, by, [c]) { const x = cx - 16; px(x + 2, by - 16, 28, 16, OUT); px(x, by - 12, 32, 12, OUT); px(x + 3, by - 15, 26, 14, c.c); px(x + 1, by - 11, 30, 10, c.c); px(x + 6, by - 14, 12, 3, shade(c.c, 0.25)); px(x + 4, by - 4, 24, 2, shade(c.c, -0.2)); } },
    { k: "ficus", cat: "Muebles", slot: "big", name: "Ficus grande", lv: 3, price: 45000, vars: ["pot"], g: "m",
      draw(cx, by, [p]) { px(cx - 9, by - 13, 18, 13, OUT); px(cx - 8, by - 12, 16, 11, p.c); px(cx - 8, by - 12, 16, 2, shade(p.c, 0.2)); px(cx - 1, by - 28, 3, 15, "#6e4a2f");
        [[-14, -42, 14, 10], [0, -44, 14, 12], [-8, -34, 18, 10], [-16, -30, 10, 8], [6, -32, 12, 9]].forEach(([dx, dy, w, h], i) => { box(cx + dx, by + dy, w, h, i % 2 ? leaf : leafM); px(cx + dx + 2, by + dy + 1, 3, 2, leafL); }); } },
    { k: "archivero", cat: "Muebles", slot: "big", name: "Archivero", lv: 2, price: 25000, vars: ["color"], g: "m",
      draw(cx, by, [c]) { [-17, 1].forEach(d => { const x = cx + d, y = by - 32; box(x, y, 16, 32, c.c); for (let k = 0; k < 3; k++) { px(x, y + 10 + k * 10, 16, 1, OUT); px(x + 6, y + 4 + k * 10, 4, 1, "#c9ced8"); } px(x + 1, y + 1, 14, 1, shade(c.c, 0.3)); }); } },
    { k: "pizarra", cat: "Muebles", slot: "big", name: "Pizarra con ruedas", lv: 2, price: 28000, vars: ["seed12"], g: "f",
      draw(cx, by, [s]) { const x = cx - 22, y = by - 40, R = rng(s.c * 9973); box(x, y, 44, 28, "#f6f2e7"); px(x + 2, y + 26, 40, 2, "#c9c1b0");
        for (let i = 0; i < 5; i++) px(x + 3 + Math.floor(R() * 20), y + 3 + i * 4, 6 + Math.floor(R() * 14), 1, ["#4a78d6", "#cf4b47", "#47a865", "#22242c"][Math.floor(R() * 4)]);
        px(x + 3, y + 28, 2, 10, "#6c727d"); px(x + 39, y + 28, 2, 10, "#6c727d"); px(x, y + 38, 8, 2, "#3a3f4a"); px(x + 36, y + 38, 8, 2, "#3a3f4a"); } },
    { k: "pingpong", cat: "Muebles", slot: "big", name: "Mesa de ping-pong", lv: 6, price: 170000, vars: ["color"], g: "f",
      draw(cx, by, [c]) { const x = cx - 28, y = by - 22; box(x, y, 56, 14, c.c); px(x + 1, y + 6, 54, 1, "#f6f2e7"); px(x + 27, y - 4, 2, 18, "#e9e4d8"); px(x + 27, y - 4, 2, 1, OUT);
        px(x + 3, y + 14, 3, 8, "#3a3f4a"); px(x + 50, y + 14, 3, 8, "#3a3f4a"); disc(x + 12, y + 3, 2, "#cf4b47"); px(x + 13, y + 5, 1, 3, "#5e4229"); disc(x + 42, y + 10, 1, "#ffffff"); } },
    { k: "consola", cat: "Muebles", slot: "big", name: "Tele con consola", lv: 5, price: 110000, vars: ["color"], g: "f",
      draw(cx, by, [c], now) { const x = cx - 22, y = by - 38; box(x + 2, y + 26, 40, 12, "#3a2a22"); box(x, y, 44, 24, "#16131f"); const f = Math.floor(now * 3);
        px(x + 2, y + 2, 40, 20, ["#2a5c8a", "#3f8f5a", "#8b6cd6"][f % 3]); px(x + 6 + (f * 3) % 28, y + 14, 4, 4, "#f2c14e"); px(x + 4, y + 18, 36, 2, "#47a865");
        box(x + 8, y + 29, 10, 4, c.c); px(x + 24, y + 30, 6, 3, "#e9e4d8"); px(x + 26, y + 31, 1, 1, "#ef6b5b"); } },
    { k: "cafetera", cat: "Muebles", slot: "big", name: "Cafetera espresso", lv: 4, price: 70000, vars: ["espresso"], g: "f",
      draw(cx, by, [e], now) { const x = cx - 16, y = by - 34; box(x, y + 16, 32, 4, "#8a6440"); px(x + 2, y + 20, 2, 14, "#5e4229"); px(x + 28, y + 20, 2, 14, "#5e4229");
        box(x + 6, y + 2, 20, 14, e.c); px(x + 8, y + 4, 16, 2, shade(e.c, 0.3)); px(x + 12, y + 9, 8, 2, "#3a3f4a"); px(x + 14, y + 11, 4, 4, "#e9e4d8");
        if (Math.floor(now * 2) % 2) { px(x + 15, y - 1, 1, 3, "rgba(255,255,255,0.35)"); px(x + 17, y - 3, 1, 3, "rgba(255,255,255,0.25)"); } } },
    { k: "telescopio", cat: "Muebles", slot: "big", name: "Telescopio", lv: 6, price: 140000, vars: ["color"], g: "m",
      draw(cx, by, [c]) { px(cx - 10, by - 1, 2, 1, OUT); for (let k = 0; k < 18; k++) { px(cx - 9 + k / 2, by - 1 - k, 1, 1, "#3a3f4a"); px(cx + 9 - k / 2, by - 1 - k, 1, 1, "#3a3f4a"); px(cx, by - 1 - k, 1, 1, "#3a3f4a"); }
        for (let k = 0; k < 22; k++) px(cx - 10 + k, by - 20 - Math.floor(k / 2), 4, 4, k > 18 ? "#22242c" : c.c); px(cx + 12, by - 31, 3, 6, "#9ad3ef"); } },
    { k: "camaperro", cat: "Muebles", slot: "big", name: "Cama con perro", lv: 4, price: 60000, vars: ["color", "fur"], g: "f",
      draw(cx, by, [c, f], now) { const x = cx - 16; box(x, by - 10, 32, 10, c.c); px(x + 3, by - 8, 26, 4, shade(c.c, -0.3)); const [a, b] = f.c, br = Math.round(Math.sin(now * 2) * 0.6 + 0.5);
        px(x + 7, by - 12 - br, 16, 7 + br, a); px(x + 7, by - 12 - br, 16, 1, shade(a, 0.2)); px(x + 20, by - 14, 6, 6, a); px(x + 20, by - 14, 2, 4, b); px(x + 23, by - 11, 1, 1, OUT); px(x + 4, by - 8, 4, 2, b); } },
    { k: "busto", cat: "Muebles", slot: "big", name: "Busto del fundador", lv: 6, price: 150000, vars: ["statue"], g: "m",
      draw(cx, by, [s]) { box(cx - 8, by - 20, 16, 20, "#8a909c"); px(cx - 8, by - 20, 16, 2, "#a3a9b4"); box(cx - 9, by - 30, 18, 9, s.c); box(cx - 5, by - 41, 10, 11, s.c);
        px(cx - 3, by - 37, 2, 1, shade(s.c, -0.4)); px(cx + 1, by - 37, 2, 1, shade(s.c, -0.4)); px(cx - 1, by - 33, 3, 1, shade(s.c, -0.4)); px(cx - 4, by - 41, 8, 2, shade(s.c, 0.3)); } },
    { k: "bateria", cat: "Muebles", slot: "big", name: "Batería", lv: 7, price: 200000, vars: ["color"], g: "f",
      draw(cx, by, [c], now) { const hit = Math.floor(now * 4) % 2; disc(cx, by - 9, 9, OUT); disc(cx, by - 9, 8, c.c); disc(cx, by - 9, 5, "#f6f2e7"); box(cx - 20, by - 18, 9, 7, c.c); box(cx + 11, by - 18, 9, 7, c.c);
        px(cx - 24, by - 30 - hit, 12, 2, "#e3b341"); px(cx - 18, by - 28, 1, 28, "#9aa0ab"); px(cx + 14, by - 26 + hit, 12, 2, "#e3b341"); px(cx + 20, by - 24, 1, 24, "#9aa0ab"); } },
  );

  // Escritorios (slot desk, para toda la oficina): dibujan el mueble; el monitor, el
  // teclado y la taza los pone drawDesk. (cx, y) es el centro del borde de arriba.
  function woodDesk(cx, y, wood, front) {
    const woodL = shade(wood, 0.2), woodD = front || shade(wood, -0.3);
    px(cx - 34, y - 1, 68, 12, OUT); px(cx - 33, y, 66, 10, wood); px(cx - 33, y, 66, 2, woodL);
    for (let i = 0; i < 3; i++) px(cx - 28 + i * 22, y + 4 + (i % 2), 12, 1, shade(wood, -0.12));
    px(cx - 33, y + 10, 66, 12, woodD); px(cx - 34, y + 10, 68, 1, OUT);
    px(cx - 30, y + 13, 14, 6, shade(woodD, 0.12)); px(cx - 24, y + 15, 3, 1, "#c9a777");
    px(cx + 18, y + 13, 12, 6, shade(woodD, 0.12)); px(cx + 22, y + 15, 3, 1, "#c9a777");
    px(cx - 33, y + 22, 4, 6, woodD); px(cx + 29, y + 22, 4, 6, woodD);
  }
  function slabDesk(cx, y, top, legs, thin) {
    px(cx - 34, y - 1, 68, thin ? 6 : 8, OUT); px(cx - 33, y, 66, thin ? 4 : 6, top); px(cx - 33, y, 66, 1, shade(top, 0.25));
    const ly = y + (thin ? 5 : 7);
    px(cx - 31, ly, 2, 28 - (ly - y), legs); px(cx + 29, ly, 2, 28 - (ly - y), legs);
  }
  KINDS.push(
    { k: "escritorio", cat: "Escritorios", slot: "desk", name: "Escritorio clásico", lv: 2, price: 80000, vars: ["wood"], g: "m",
      draw(cx, y, [w]) { woodDesk(cx, y, w.c); } },
    { k: "moderno", cat: "Escritorios", slot: "desk", name: "Escritorio moderno", lv: 2, price: 70000, vars: ["deskColor"], g: "m",
      draw(cx, y, [c]) { slabDesk(cx, y, c.c, "#9aa0ab", true); px(cx + 14, y + 5, 16, 10, OUT); px(cx + 15, y + 5, 14, 9, shade(c.c, -0.1)); px(cx + 20, y + 9, 4, 1, "#c9ced8"); } },
    { k: "vidrio", cat: "Escritorios", slot: "desk", name: "Escritorio de vidrio", lv: 4, price: 150000, vars: ["glass"], g: "m",
      draw(cx, y, [gl]) { px(cx - 34, y - 1, 68, 5, OUT); px(cx - 33, y, 66, 3, gl.c); px(cx - 33, y, 66, 1, "rgba(255,255,255,0.5)");
        for (let k = 0; k < 24; k++) { px(cx - 30 + k / 3, y + 4 + k, 2, 1, "#c9ced8"); px(cx + 28 - k / 3, y + 4 + k, 2, 1, "#c9ced8"); } } },
    { k: "industrial", cat: "Escritorios", slot: "desk", name: "Escritorio industrial", lv: 3, price: 110000, vars: ["wood"], g: "m",
      draw(cx, y, [w]) { slabDesk(cx, y, w.c, "#22242c"); for (let k = 0; k < 18; k++) { px(cx - 30 + k * 1.5, y + 8 + k, 1, 1, "#22242c"); px(cx + 30 - k * 1.5, y + 8 + k, 1, 1, "#22242c"); } px(cx - 31, y + 26, 62, 2, "#22242c"); } },
    { k: "gamer", cat: "Escritorios", slot: "desk", name: "Escritorio gamer", lv: 5, price: 220000, vars: ["glow"], g: "m",
      draw(cx, y, [gl], now) { px(cx - 34, y - 1, 68, 14, OUT); px(cx - 33, y, 66, 12, "#1d1f26"); px(cx - 33, y, 66, 1, "#3a3f4a"); px(cx - 33, y + 12, 66, 10, "#16131f");
        for (let i = 0; i < 66; i += 2) px(cx - 33 + i, y + 11, 2, 1, gl.c || `hsl(${(i * 6 + now * 120) % 360},90%,60%)`);
        px(cx - 31, y + 22, 6, 6, "#16131f"); px(cx + 25, y + 22, 6, 6, "#16131f"); px(cx - 30, y + 24, 4, 1, gl.c || "#ff5fc8"); px(cx + 26, y + 24, 4, 1, gl.c || "#4ff0ff"); } },
    { k: "marmol", cat: "Escritorios", slot: "desk", name: "Escritorio de mármol", lv: 7, price: 380000, vars: ["marble"], g: "m",
      draw(cx, y, [m]) { slabDesk(cx, y, m.c[0], "#e3b341"); for (let i = 0; i < 4; i++) px(cx - 26 + i * 15, y + 2 + (i % 2), 8, 1, m.c[1]); px(cx - 31, y + 26, 4, 2, "#e3b341"); px(cx + 27, y + 26, 4, 2, "#e3b341"); } },
    { k: "retro", cat: "Escritorios", slot: "desk", name: "Escritorio retro", lv: 3, price: 95000, vars: ["color"], g: "m",
      draw(cx, y, [c]) { px(cx - 34, y - 1, 68, 22, OUT); px(cx - 33, y, 66, 20, c.c); px(cx - 33, y, 66, 2, shade(c.c, 0.3)); px(cx - 33, y + 9, 66, 1, "#c9ced8");
        px(cx - 28, y + 12, 16, 6, shade(c.c, -0.2)); px(cx + 12, y + 12, 16, 6, shade(c.c, -0.2)); px(cx - 22, y + 14, 4, 1, "#c9ced8"); px(cx + 18, y + 14, 4, 1, "#c9ced8");
        px(cx - 30, y + 21, 3, 7, "#c9ced8"); px(cx + 27, y + 21, 3, 7, "#c9ced8"); } },
    { k: "nordico", cat: "Escritorios", slot: "desk", name: "Escritorio escandinavo", lv: 3, price: 100000, vars: ["wood"], g: "m",
      draw(cx, y, [w]) { px(cx - 34, y - 1, 68, 6, OUT); px(cx - 33, y, 66, 4, w.c); px(cx - 33, y, 66, 1, shade(w.c, 0.25)); px(cx + 10, y + 5, 22, 12, OUT); px(cx + 11, y + 5, 20, 11, "#efe9dd"); px(cx + 19, y + 10, 4, 1, "#8a909c");
        for (let k = 0; k < 23; k++) { px(cx - 30 - k / 5, y + 5 + k, 2, 1, w.c); px(cx - 22 + k / 5, y + 5 + k, 2, 1, w.c); } } },
    { k: "ejecutivo", cat: "Escritorios", slot: "desk", name: "Escritorio ejecutivo", lv: 6, price: 300000, vars: ["wood"], g: "m",
      draw(cx, y, [w]) { woodDesk(cx, y, w.c, shade(w.c, -0.45)); px(cx - 20, y + 2, 40, 6, "#2f5a3f"); px(cx - 20, y + 2, 40, 1, "#3f7a55"); px(cx - 33, y + 21, 66, 1, "#d4a933"); } },
  );

  // Sillas (slot chair, para toda la oficina): el respaldo, detrás de la persona.
  KINDS.push(
    { k: "silla", cat: "Sillas", slot: "chair", name: "Silla de oficina", lv: 1, price: 30000, vars: ["color"], g: "f",
      draw(x, y, [c]) { const b = shade(c.c, -0.45); px(x - 14, y - 16, 28, 26, OUT); px(x - 13, y - 15, 26, 24, b); px(x - 13, y - 15, 26, 2, shade(b, 0.25)); px(x - 13, y - 15, 2, 24, shade(b, 0.12)); px(x + 11, y - 15, 2, 24, shade(b, -0.2)); px(x - 9, y - 12, 18, 1, c.c); } },
    { k: "sillagamer", cat: "Sillas", slot: "chair", name: "Silla gamer", lv: 4, price: 120000, vars: ["pair"], g: "f",
      draw(x, y, [p]) { const [a, b] = p.c; px(x - 13, y - 22, 26, 32, OUT); px(x - 12, y - 21, 24, 30, b); px(x - 12, y - 21, 5, 30, a); px(x + 7, y - 21, 5, 30, a); px(x - 6, y - 19, 12, 4, a); px(x - 5, y - 18, 10, 2, shade(a, 0.3)); } },
    { k: "malla", cat: "Sillas", slot: "chair", name: "Silla ergonómica", lv: 3, price: 90000, vars: ["color"], g: "f",
      draw(x, y, [c]) { px(x - 13, y - 18, 26, 28, OUT); px(x - 12, y - 17, 24, 26, "#22242c"); for (let i = 0; i < 24; i += 2) for (let j = 0; j < 26; j += 2) px(x - 12 + i + (j % 4 ? 1 : 0), y - 17 + j, 1, 1, c.c); px(x - 13, y - 18, 26, 2, "#3a3f4a"); } },
    { k: "cuero", cat: "Sillas", slot: "chair", name: "Sillón de cuero", lv: 6, price: 200000, vars: ["leather"], g: "m",
      draw(x, y, [l]) { px(x - 16, y - 20, 32, 30, OUT); px(x - 15, y - 19, 30, 28, l.c); px(x - 15, y - 19, 30, 2, shade(l.c, 0.25));
        for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) px(x - 9 + i * 8, y - 14 + j * 7, 2, 2, shade(l.c, -0.35)); px(x - 15, y - 8, 4, 16, shade(l.c, -0.15)); px(x + 11, y - 8, 4, 16, shade(l.c, -0.15)); } },
    { k: "sillamadera", cat: "Sillas", slot: "chair", name: "Silla de madera", lv: 2, price: 45000, vars: ["wood"], g: "f",
      draw(x, y, [w]) { px(x - 12, y - 16, 2, 26, OUT); px(x + 10, y - 16, 2, 26, OUT); px(x - 11, y - 16, 1, 26, w.c); px(x + 10, y - 16, 1, 26, w.c); for (let k = 0; k < 3; k++) { px(x - 11, y - 15 + k * 6, 22, 3, OUT); px(x - 10, y - 14 + k * 6, 20, 2, w.c); } } },
    { k: "huevo", cat: "Sillas", slot: "chair", name: "Silla huevo", lv: 7, price: 260000, vars: ["color"], g: "f",
      draw(x, y, [c]) { disc(x, y - 4, 15, OUT); disc(x, y - 4, 14, c.c); disc(x, y - 2, 10, shade(c.c, -0.3)); px(x - 9, y - 16, 8, 2, shade(c.c, 0.3)); } },
  );

  // Pisos (slot floor) y paredes (slot paint), para toda la oficina: (x, y, w, h) es el área.
  KINDS.push(
    { k: "moqueta", cat: "Pisos", slot: "floor", name: "Moqueta", lv: 1, price: 40000, vars: ["floorPair"], g: "f",
      draw(x, y, w, h, [p]) { const [a, b] = p.c; px(x, y, w, h, a); for (let yy = y; yy < y + h; yy += 8) for (let xx = x + ((yy / 8) % 2 ? 4 : 0); xx < x + w; xx += 8) px(xx, yy, 4, 4, b); } },
    { k: "parquet", cat: "Pisos", slot: "floor", name: "Parquet", lv: 3, price: 110000, vars: ["wood"], g: "m",
      draw(x, y, w, h, [wd]) { px(x, y, w, h, wd.c); for (let yy = y; yy < y + h; yy += 6) for (let xx = x; xx < x + w; xx += 12) { const o = ((yy - y) / 6) % 2 ? 6 : 0; px(xx + o, yy, 1, 6, shade(wd.c, -0.25)); px(xx, yy, 12, 1, shade(wd.c, -0.15)); px(xx + o + 2, yy + 2, 6, 1, shade(wd.c, 0.1)); } } },
    { k: "tablones", cat: "Pisos", slot: "floor", name: "Piso de tablones", lv: 2, price: 80000, vars: ["wood"], g: "m",
      draw(x, y, w, h, [wd]) { px(x, y, w, h, wd.c); for (let yy = y, r = 0; yy < y + h; yy += 10, r++) { px(x, yy, w, 1, shade(wd.c, -0.3)); for (let xx = x + (r * 23) % 40; xx < x + w; xx += 40) px(xx, yy, 1, 10, shade(wd.c, -0.3)); px(x, yy + 4, w, 1, shade(wd.c, 0.06)); } } },
    { k: "baldosas", cat: "Pisos", slot: "floor", name: "Baldosas", lv: 2, price: 70000, vars: ["tile"], g: "f",
      draw(x, y, w, h, [t]) { px(x, y, w, h, t.c[1]); for (let yy = y; yy < y + h; yy += 16) for (let xx = x; xx < x + w; xx += 16) { px(xx + 1, yy + 1, 14, 14, t.c[0]); px(xx + 1, yy + 1, 14, 1, shade(t.c[0], 0.15)); } } },
    { k: "damero", cat: "Pisos", slot: "floor", name: "Piso damero", lv: 4, price: 140000, vars: ["checker"], g: "m",
      draw(x, y, w, h, [c]) { for (let yy = y, r = 0; yy < y + h; yy += 12, r++) for (let xx = x, k = 0; xx < x + w; xx += 12, k++) px(xx, yy, 12, 12, c.c[(r + k) % 2]); } },
    { k: "marmolpiso", cat: "Pisos", slot: "floor", name: "Piso de mármol", lv: 7, price: 320000, vars: ["marble"], g: "m",
      draw(x, y, w, h, [m]) { px(x, y, w, h, m.c[0]); const R = rng(x * 31 + y); for (let i = 0; i < 26; i++) { let vx = x + R() * w, vy = y + R() * h; for (let k = 0; k < 10; k++) { px(vx, vy, 1, 1, m.c[1]); vx += 1; vy += R() < 0.5 ? 1 : 0; } }
        for (let yy = y; yy < y + h; yy += 30) px(x, yy, w, 1, shade(m.c[0], -0.1)); } },
    { k: "cesped", cat: "Pisos", slot: "floor", name: "Césped sintético", lv: 3, price: 90000, vars: [], g: "m",
      draw(x, y, w, h) { px(x, y, w, h, "#3f8f4a"); const R = rng(x * 17 + y); for (let i = 0; i < w * h / 18; i++) px(x + R() * w, y + R() * h, 1, 2, R() < 0.5 ? "#56aa5a" : "#2f7a3c"); } },
    { k: "rayas", cat: "Pisos", slot: "floor", name: "Alfombra a rayas", lv: 2, price: 60000, vars: ["stripes"], g: "f",
      draw(x, y, w, h, [s]) { for (let xx = x, i = 0; xx < x + w; xx += 10, i++) px(xx, y, 10, h, s.c[i % 2]); } },
    { k: "persa", cat: "Pisos", slot: "floor", name: "Alfombra persa", lv: 5, price: 200000, vars: ["floorPair"], g: "f",
      draw(x, y, w, h, [p]) { px(x, y, w, h, "#4a4e58"); const ix = x + 14, iy = y + 10, iw = w - 28, ih = h - 22; px(ix, iy, iw, ih, "#7d2f3f"); px(ix + 3, iy + 3, iw - 6, ih - 6, p.c[0]);
        for (let xx = ix + 6; xx < ix + iw - 6; xx += 8) for (let yy = iy + 6; yy < iy + ih - 6; yy += 8) px(xx, yy, 3, 3, "#d4a933"); for (let xx = ix; xx < ix + iw; xx += 4) { px(xx, iy - 2, 1, 2, "#e9e4d8"); px(xx, iy + ih, 1, 2, "#e9e4d8"); } } },
    { k: "microcemento", cat: "Pisos", slot: "floor", name: "Microcemento", lv: 4, price: 120000, vars: ["deskColor"], g: "m",
      draw(x, y, w, h, [c]) { const b = shade(c.c, -0.55); px(x, y, w, h, b); for (let yy = y; yy < y + h; yy += 4) px(x, yy, w, 2, shade(b, ((yy / 4) % 5 - 2) * 0.02)); } },
    { k: "pintura", cat: "Paredes", slot: "paint", name: "Pared pintada", lv: 1, price: 20000, vars: ["color"], g: "f",
      draw(x, y, w, h, [c]) { const b = shade(c.c, -0.35); px(x, y, w, h, b); px(x, y, w, 2, shade(b, 0.2)); px(x, y + h - 3, w, 3, shade(b, -0.3)); } },
    { k: "pared_rayas", cat: "Paredes", slot: "paint", name: "Pared a rayas", lv: 2, price: 35000, vars: ["stripes"], g: "f",
      draw(x, y, w, h, [s]) { for (let xx = x, i = 0; xx < x + w; xx += 6, i++) px(xx, y, 6, h, shade(s.c[i % 2], -0.25)); px(x, y + h - 3, w, 3, "#1f2533"); } },
    { k: "ladrillo", cat: "Paredes", slot: "paint", name: "Ladrillo visto", lv: 3, price: 60000, vars: ["brick"], g: "m",
      draw(x, y, w, h, [b]) { px(x, y, w, h, b.c[2]); for (let yy = y, r = 0; yy < y + h; yy += 5, r++) for (let xx = x - (r % 2 ? 6 : 0); xx < x + w; xx += 12) px(Math.max(x, xx), yy, Math.min(11, xx + 11 - Math.max(x, xx)), 4, (r + xx) % 3 ? b.c[0] : b.c[1]); } },
    { k: "lunares", cat: "Paredes", slot: "paint", name: "Pared con lunares", lv: 2, price: 30000, vars: ["color"], g: "f",
      draw(x, y, w, h, [c]) { const b = shade(c.c, -0.4); px(x, y, w, h, b); for (let yy = y + 3, r = 0; yy < y + h - 3; yy += 7, r++) for (let xx = x + (r % 2 ? 7 : 3); xx < x + w; xx += 10) px(xx, yy, 2, 2, shade(c.c, 0.2)); } },
    { k: "boiserie", cat: "Paredes", slot: "paint", name: "Boiserie", lv: 5, price: 120000, vars: ["wood"], g: "f",
      draw(x, y, w, h, [wd]) { px(x, y, w, h, shade(wd.c, -0.2)); for (let xx = x + 3; xx < x + w - 10; xx += 16) { px(xx, y + 4, 12, h - 9, OUT); px(xx + 1, y + 5, 10, h - 11, wd.c); } px(x, y + h - 3, w, 3, shade(wd.c, -0.5)); } },
    { k: "floral", cat: "Paredes", slot: "paint", name: "Papel tapiz floral", lv: 4, price: 90000, vars: ["color"], g: "m",
      draw(x, y, w, h, [c]) { const b = shade(c.c, -0.5); px(x, y, w, h, b); for (let yy = y + 3, r = 0; yy < y + h - 3; yy += 9, r++) for (let xx = x + (r % 2 ? 9 : 2); xx < x + w; xx += 16) { px(xx, yy + 1, 3, 1, shade(c.c, 0.2)); px(xx + 1, yy, 1, 3, shade(c.c, 0.2)); px(xx + 1, yy + 1, 1, 1, "#f2c14e"); } } },
    { k: "pizarron", cat: "Paredes", slot: "paint", name: "Pared pizarrón", lv: 3, price: 50000, vars: ["chalk"], g: "f",
      draw(x, y, w, h, [s]) { px(x, y, w, h, "#253a30"); const R = rng(s.c * 271 + x); for (let i = 0; i < w / 14; i++) { let cx = x + R() * w, cy = y + 3 + R() * (h - 8); for (let k = 0; k < 6; k++) { px(cx, cy, 1, 1, "rgba(233,228,216,0.7)"); cx += 1; cy += R() < 0.5 ? 1 : -1; } } } },
  );

  // Ropa. top cambia la prenda (la dibuja drawTorso), con su color; hat, face y neck
  // se dibujan encima: (cx, ty) es el centro arriba del torso y la cabeza empieza en ty - 13.
  const TOPS = [["hoodie", "Buzo", "m", 1, 20000], ["shirt", "Camisa con corbata", "f", 1, 25000], ["polo", "Chomba", "f", 1, 18000], ["turtle", "Polera", "f", 2, 22000],
    ["suit", "Saco", "m", 3, 45000], ["vest", "Chaleco", "m", 2, 28000], ["cardigan", "Cárdigan", "m", 2, 24000], ["coat", "Guardapolvo con camisa", "m", 2, 22000],
    ["stripes", "Remera a rayas", "f", 1, 15000], ["hawaii", "Camisa hawaiana", "f", 3, 35000], ["denim", "Campera de jean con remera", "f", 3, 40000],
    ["xmas", "Suéter navideño", "m", 4, 50000], ["heart", "Remera con corazón", "f", 1, 15000]];
  TOPS.forEach(([kind, name, gn, lv, price]) => KINDS.push({ k: "top_" + kind, cat: "Ropa", slot: "top", name, g: gn, lv, price, vars: ["color"], top: kind }));
  KINDS.push(
    { k: "gorra", cat: "Ropa", slot: "hat", name: "Gorra", lv: 1, price: 10000, vars: ["color"], g: "f",
      draw(cx, ht, [c]) { px(cx - 8, ht - 6, 16, 8, OUT); px(cx - 7, ht - 5, 14, 6, c.c); px(cx - 7, ht - 5, 14, 1, shade(c.c, 0.3)); px(cx - 1, ht - 6, 2, 1, shade(c.c, -0.3)); px(cx - 9, ht + 1, 18, 2, OUT); px(cx - 8, ht + 1, 16, 1, shade(c.c, -0.25)); } },
    { k: "lana", cat: "Ropa", slot: "hat", name: "Gorro de lana", lv: 1, price: 10000, vars: ["color"], g: "m",
      draw(cx, ht, [c]) { px(cx - 8, ht - 6, 16, 9, OUT); px(cx - 7, ht - 5, 14, 7, c.c); px(cx - 7, ht, 14, 2, shade(c.c, -0.2)); for (let i = 0; i < 14; i += 2) px(cx - 7 + i, ht, 1, 2, shade(c.c, -0.35)); px(cx - 2, ht - 9, 4, 4, OUT); px(cx - 1, ht - 8, 2, 2, "#efe9dd"); } },
    { k: "galera", cat: "Ropa", slot: "hat", name: "Galera", lv: 4, price: 40000, vars: ["color"], g: "f",
      draw(cx, ht, [c]) { px(cx - 6, ht - 12, 12, 13, OUT); px(cx - 5, ht - 11, 10, 11, "#22242c"); px(cx - 5, ht - 4, 10, 2, c.c); px(cx - 10, ht, 20, 3, OUT); px(cx - 9, ht + 1, 18, 1, "#22242c"); } },
    { k: "cowboy", cat: "Ropa", slot: "hat", name: "Sombrero de cowboy", lv: 3, price: 30000, vars: ["leather"], g: "m",
      draw(cx, ht, [l]) { px(cx - 6, ht - 7, 12, 7, OUT); px(cx - 5, ht - 6, 10, 6, l.c); px(cx - 1, ht - 7, 2, 1, shade(l.c, -0.3)); px(cx - 5, ht - 2, 10, 1, shade(l.c, -0.45)); px(cx - 12, ht - 1, 24, 3, OUT); px(cx - 11, ht, 22, 1, l.c); px(cx - 12, ht - 2, 2, 1, OUT); px(cx + 10, ht - 2, 2, 1, OUT); } },
    { k: "corona", cat: "Ropa", slot: "hat", name: "Corona", lv: 8, price: 300000, vars: ["metal"], g: "f",
      draw(cx, ht, [m]) { px(cx - 7, ht - 5, 14, 5, OUT); px(cx - 6, ht - 4, 12, 3, m.c); [-7, -2, 3].forEach(d => { px(cx + d, ht - 9, 4, 4, OUT); px(cx + d + 1, ht - 8, 2, 3, m.c); }); px(cx - 1, ht - 3, 2, 2, "#cf4b47"); px(cx - 5, ht - 3, 1, 1, "#4a78d6"); px(cx + 4, ht - 3, 1, 1, "#47a865"); } },
    { k: "vikingo", cat: "Ropa", slot: "hat", name: "Casco vikingo", lv: 5, price: 60000, vars: ["metal"], g: "m",
      draw(cx, ht, [m]) { px(cx - 8, ht - 6, 16, 8, OUT); px(cx - 7, ht - 5, 14, 6, "#9aa3b5"); px(cx - 7, ht - 5, 14, 1, "#c9ced8"); px(cx - 7, ht, 14, 2, m.c);
        px(cx - 11, ht - 4, 3, 2, "#efe9dd"); px(cx - 12, ht - 7, 2, 3, "#efe9dd"); px(cx + 8, ht - 4, 3, 2, "#efe9dd"); px(cx + 10, ht - 7, 2, 3, "#efe9dd"); } },
    { k: "chef", cat: "Ropa", slot: "hat", name: "Gorro de chef", lv: 2, price: 15000, vars: [], g: "m",
      draw(cx, ht) { px(cx - 7, ht - 12, 14, 13, OUT); px(cx - 6, ht - 11, 12, 11, "#f6f2e7"); px(cx - 8, ht - 10, 3, 5, OUT); px(cx - 7, ht - 9, 2, 3, "#f6f2e7"); px(cx + 5, ht - 10, 3, 5, OUT); px(cx + 5, ht - 9, 2, 3, "#f6f2e7"); px(cx - 6, ht - 2, 12, 3, "#e0dbd0"); } },
    { k: "orejas", cat: "Ropa", slot: "hat", name: "Vincha con orejas de gato", lv: 2, price: 12000, vars: ["color"], g: "f",
      draw(cx, ht, [c]) { px(cx - 7, ht - 3, 14, 1, c.c); [-7, 3].forEach(d => { px(cx + d, ht - 7, 4, 4, OUT); px(cx + d + 1, ht - 6, 2, 3, c.c); px(cx + d + 1, ht - 5, 1, 2, "#f4b6c2"); }); } },
    { k: "cumple", cat: "Ropa", slot: "hat", name: "Gorrito de cumpleaños", lv: 1, price: 8000, vars: ["color"], g: "m",
      draw(cx, ht, [c]) { for (let i = 0; i < 9; i++) { const w = Math.floor(i / 2) * 2 + 2; px(cx - w / 2, ht - 9 + i, w, 1, i % 3 === 1 ? "#f2c14e" : c.c); } px(cx - 1, ht - 11, 2, 2, "#ffffff"); } },
    { k: "boina", cat: "Ropa", slot: "hat", name: "Boina", lv: 2, price: 14000, vars: ["color"], g: "f",
      draw(cx, ht, [c]) { px(cx - 8, ht - 6, 15, 4, OUT); px(cx - 7, ht - 6, 13, 3, c.c); px(cx - 7, ht - 6, 13, 1, shade(c.c, 0.3)); px(cx - 1, ht - 8, 2, 2, OUT); } },
    { k: "mago", cat: "Ropa", slot: "hat", name: "Gorro de mago", lv: 6, price: 90000, vars: ["color"], g: "m",
      draw(cx, ht, [c]) { for (let i = 0; i < 13; i++) { const w = Math.floor(i / 2) * 2 + 2; px(cx - w / 2 + Math.floor((12 - i) / 5), ht - 13 + i, w, 1, c.c); } px(cx - 11, ht - 1, 22, 3, OUT); px(cx - 10, ht, 20, 1, c.c); px(cx, ht - 7, 1, 1, "#f2c14e"); px(cx - 3, ht - 3, 1, 1, "#f2c14e"); px(cx + 3, ht - 4, 1, 1, "#ffffff"); } },
    { k: "casco", cat: "Ropa", slot: "hat", name: "Casco de obra", lv: 1, price: 9000, vars: [], g: "m",
      draw(cx, ht) { px(cx - 8, ht - 6, 16, 7, OUT); px(cx - 7, ht - 5, 14, 5, "#e3c14a"); px(cx - 1, ht - 6, 2, 5, "#f2d36b"); px(cx - 10, ht, 20, 2, OUT); px(cx - 9, ht, 18, 1, "#e3c14a"); } },
    { k: "flor", cat: "Ropa", slot: "hat", name: "Flor en el pelo", lv: 1, price: 6000, vars: ["flower"], g: "f",
      draw(cx, ht, [f]) { px(cx + 3, ht - 3, 5, 5, OUT); px(cx + 4, ht - 2, 3, 3, f.c); px(cx + 3, ht - 1, 1, 1, f.c); px(cx + 7, ht - 1, 1, 1, f.c); px(cx + 5, ht - 1, 1, 1, "#f2c84b"); } },
    { k: "paja", cat: "Ropa", slot: "hat", name: "Sombrero de paja", lv: 2, price: 16000, vars: ["color"], g: "m",
      draw(cx, ht, [c]) { px(cx - 6, ht - 5, 12, 5, OUT); px(cx - 5, ht - 4, 10, 4, "#d9bf86"); px(cx - 5, ht - 2, 10, 1, c.c); px(cx - 12, ht - 1, 24, 3, OUT); px(cx - 11, ht, 22, 1, "#d9bf86"); } },
    { k: "auriculares", cat: "Ropa", slot: "hat", name: "Auriculares gamer", lv: 3, price: 35000, vars: ["glow"], g: "m",
      draw(cx, ht, [gl], now) { const c = gl.c || `hsl(${(now * 120) % 360},90%,60%)`; px(cx - 9, ht - 5, 18, 2, OUT); px(cx - 8, ht - 5, 16, 1, "#3a3f4a"); px(cx - 11, ht + 3, 5, 7, OUT); px(cx - 10, ht + 4, 3, 5, c); px(cx + 6, ht + 3, 5, 7, OUT); px(cx + 7, ht + 4, 3, 5, c); } },
    { k: "aureola", cat: "Ropa", slot: "hat", name: "Aureola", lv: 9, price: 400000, vars: [], g: "f",
      draw(cx, ht, _, now) { const b = Math.round(Math.sin(now * 3)); px(cx - 6, ht - 10 + b, 12, 1, "#f2c14e"); px(cx - 7, ht - 9 + b, 1, 1, "#f2c14e"); px(cx + 6, ht - 9 + b, 1, 1, "#f2c14e"); px(cx - 6, ht - 8 + b, 12, 1, "#f2c14e"); px(cx - 5, ht - 9 + b, 10, 1, "rgba(255,240,180,0.5)"); } },
    // Cara: (hx, ht) es la esquina de arriba a la izquierda de la cabeza (16 x 13).
    { k: "lentes_sol", cat: "Ropa", slot: "face", name: "Anteojos de sol", lv: 1, price: 9000, vars: ["color"], g: "m",
      draw(hx, ht, [c]) { [2, 9].forEach(d => { px(hx + d, ht + 4, 5, 4, c.c); px(hx + d + 1, ht + 5, 3, 2, "#1d2028"); px(hx + d + 1, ht + 5, 1, 1, "rgba(255,255,255,0.4)"); }); px(hx + 7, ht + 5, 2, 1, c.c); } },
    { k: "lentes_corazon", cat: "Ropa", slot: "face", name: "Anteojos de corazón", lv: 2, price: 14000, vars: ["color"], g: "m",
      draw(hx, ht, [c]) { [1, 9].forEach(d => sprite(hx + d, ht + 4, [".X.X.", "XXXXX", ".XXX.", "..X.."], { X: c.c })); px(hx + 6, ht + 5, 3, 1, OUT); } },
    { k: "monoculo", cat: "Ropa", slot: "face", name: "Monóculo", lv: 4, price: 30000, vars: ["metal"], g: "m",
      draw(hx, ht, [m]) { px(hx + 9, ht + 4, 4, 4, m.c); px(hx + 10, ht + 5, 2, 2, "rgba(220,240,255,0.5)"); px(hx + 12, ht + 8, 1, 6, m.c); } },
    { k: "bigote", cat: "Ropa", slot: "face", name: "Bigote", lv: 1, price: 7000, vars: ["fur"], g: "m",
      draw(hx, ht, [f]) { const c = f.c[1]; px(hx + 5, ht + 8, 6, 1, c); px(hx + 4, ht + 9, 2, 1, c); px(hx + 10, ht + 9, 2, 1, c); px(hx + 6, ht + 8, 4, 1, shade(c, 0.15)); } },
    { k: "antifaz", cat: "Ropa", slot: "face", name: "Antifaz", lv: 3, price: 16000, vars: ["color"], g: "m",
      draw(hx, ht, [c]) { px(hx + 1, ht + 4, 14, 3, c.c); px(hx + 4, ht + 5, 2, 1, "#221a26"); px(hx + 10, ht + 5, 2, 1, "#221a26"); px(hx, ht + 4, 1, 1, c.c); px(hx + 15, ht + 4, 1, 1, c.c); } },
    { k: "parche", cat: "Ropa", slot: "face", name: "Parche de pirata", lv: 2, price: 9000, vars: [], g: "m",
      draw(hx, ht) { px(hx, ht + 2, 16, 1, "#1d2028"); px(hx + 3, ht + 4, 4, 4, "#1d2028"); px(hx + 4, ht + 3, 2, 1, "#1d2028"); } },
    // Cuello: (cx, ty) es el centro arriba del torso.
    { k: "bufanda", cat: "Ropa", slot: "neck", name: "Bufanda", lv: 1, price: 10000, vars: ["color"], g: "f",
      draw(cx, ty, [c]) { px(cx - 7, ty - 1, 14, 4, OUT); px(cx - 6, ty, 12, 2, c.c); for (let i = 0; i < 12; i += 3) px(cx - 6 + i, ty, 1, 2, shade(c.c, 0.3)); px(cx + 2, ty + 2, 4, 9, OUT); px(cx + 3, ty + 3, 2, 7, c.c); } },
    { k: "mono", cat: "Ropa", slot: "neck", name: "Moño", lv: 2, price: 9000, vars: ["color"], g: "m",
      draw(cx, ty, [c]) { px(cx - 4, ty + 1, 8, 4, OUT); px(cx - 3, ty + 2, 2, 2, c.c); px(cx + 1, ty + 2, 2, 2, c.c); px(cx - 1, ty + 2, 2, 2, shade(c.c, -0.3)); } },
    { k: "perlas", cat: "Ropa", slot: "neck", name: "Collar de perlas", lv: 5, price: 70000, vars: [], g: "m",
      draw(cx, ty) { for (let i = 0; i < 7; i++) px(cx - 6 + i * 2, ty + 1 + (i > 0 && i < 6 ? 1 : 0) + (i > 1 && i < 5 ? 1 : 0), 1, 1, "#f6f2e7"); } },
    { k: "medalla", cat: "Ropa", slot: "neck", name: "Medalla", lv: 3, price: 25000, vars: ["metal"], g: "f",
      draw(cx, ty, [m]) { px(cx - 3, ty, 1, 6, "#cf4b47"); px(cx + 2, ty, 1, 6, "#4a78d6"); px(cx - 2, ty + 6, 4, 4, OUT); px(cx - 1, ty + 7, 2, 2, m.c); } },
    { k: "panuelo", cat: "Ropa", slot: "neck", name: "Pañuelo", lv: 1, price: 8000, vars: ["color"], g: "m",
      draw(cx, ty, [c]) { px(cx - 6, ty, 12, 2, c.c); px(cx - 4, ty + 2, 8, 2, c.c); px(cx - 2, ty + 4, 4, 1, c.c); px(cx - 3, ty + 1, 1, 1, "#ffffff"); px(cx + 2, ty + 2, 1, 1, "#ffffff"); } },
    { k: "collar_flores", cat: "Ropa", slot: "neck", name: "Collar de flores", lv: 2, price: 12000, vars: ["flower"], g: "m",
      draw(cx, ty, [f]) { for (let i = 0; i < 6; i++) px(cx - 7 + i * 3, ty + (i > 0 && i < 5 ? 2 : 0) + (i > 1 && i < 4 ? 1 : 0), 2, 2, i % 2 ? f.c : "#f6f2e7"); } },
  );

  // Lo más caro, para los niveles altos.
  KINDS.push(
    { k: "obra", cat: "Cuadros", slot: "wall", name: "Obra maestra", lv: 8, price: 350000, vars: ["seed24"], g: "f",
      draw(x, y, [s], now) { const r = framed(x + 1, y, 32, 24, "#e3b341"), R = rng(s.c * 2203); px(r.x, r.y, r.w, r.h, "#1b2546");
        for (let i = 0; i < 9; i++) disc(r.x + 3 + Math.floor(R() * 22), r.y + 3 + Math.floor(R() * 14), 1 + Math.floor(R() * 2), ["#f2c14e", "#6fb4e6", "#e9e4d8", "#e17aa8"][Math.floor(R() * 4)]);
        if (Math.floor(now * 2) % 5 === 0) px(r.x + 2, r.y + 2, 1, 1, "#ffffff"); px(x + 13, y + 22, 8, 2, "#e3b341"); } },
    { k: "fuente", cat: "Muebles", slot: "big", name: "Fuente de agua", lv: 8, price: 450000, vars: ["statue"], g: "f",
      draw(cx, by, [s], now) { px(cx - 24, by - 10, 48, 10, OUT); px(cx - 23, by - 9, 46, 8, "#9aa0ab"); px(cx - 21, by - 9, 42, 4, "#5fb8e0"); box(cx - 3, by - 28, 6, 19, s.c); box(cx - 9, by - 32, 18, 4, s.c);
        const f = Math.floor(now * 6); for (let k = 0; k < 4; k++) { px(cx - 10 - k * 2, by - 30 + k * 4 + (f % 2), 1, 2, "#9ad3ef"); px(cx + 9 + k * 2, by - 30 + k * 4 + ((f + 1) % 2), 1, 2, "#9ad3ef"); } px(cx - 1, by - 36 - (f % 3), 2, 4, "#9ad3ef"); } },
    { k: "cohete", cat: "Muebles", slot: "big", name: "Cohete a escala", lv: 9, price: 600000, vars: ["color"], g: "m",
      draw(cx, by, [c], now) { const lift = Math.round(Math.sin(now * 2)); box(cx - 5, by - 40 + lift, 10, 26, "#e9e4d8"); tri(cx, by - 46 + lift, 6, c.c); disc(cx, by - 32 + lift, 2, "#6fb4e6");
        px(cx - 9, by - 20 + lift, 4, 7, c.c); px(cx + 5, by - 20 + lift, 4, 7, c.c); const fl = Math.floor(now * 10) % 3; px(cx - 3, by - 13 + lift, 6, 4 + fl, "#f2c14e"); px(cx - 1, by - 12 + lift, 2, 5 + fl, "#ef6b5b"); box(cx - 12, by - 3, 24, 3, "#3a3f4a"); } },
    { k: "trono", cat: "Sillas", slot: "chair", name: "Trono", lv: 9, price: 700000, vars: ["leather"], g: "m",
      draw(x, y, [l]) { px(x - 16, y - 26, 32, 36, OUT); px(x - 15, y - 25, 30, 34, "#d4a933"); px(x - 11, y - 21, 22, 28, l.c); [-14, -2, 10].forEach(d => { px(x + d, y - 30, 4, 5, OUT); px(x + d + 1, y - 29, 2, 4, "#e3b341"); }); px(x - 1, y - 24, 2, 2, "#cf4b47"); } },
    { k: "oro", cat: "Pisos", slot: "floor", name: "Piso de oro", lv: 9, price: 900000, vars: [], g: "m",
      draw(x, y, w, h, _, now) { px(x, y, w, h, "#c9992e"); for (let yy = y; yy < y + h; yy += 12) for (let xx = x + ((yy - y) / 12 % 2 ? 6 : 0); xx < x + w; xx += 12) { px(xx, yy, 11, 11, "#e3b341"); px(xx, yy, 11, 1, "#f2d36b"); }
        const sp = Math.floor(now * 3) % 9; px(x + 20 + sp * 18, y + 10 + (sp % 4) * 30, 1, 1, "#ffffff"); } },
  );
  KINDS.push(
    { k: "pantalla", cat: "Cuadros", slot: "wall", name: "Pantalla con métricas", lv: 7, price: 260000, vars: ["glow"], g: "f",
      draw(x, y, [gl], now) { box(x + 1, y + 1, 32, 20, "#16131f"); const c = gl.c || `hsl(${(now * 90) % 360},90%,60%)`, f = Math.floor(now * 2);
        for (let i = 0; i < 7; i++) { const h = 3 + ((i * 5 + f) % 9); px(x + 3 + i * 4, y + 18 - h, 3, h, c); } px(x + 3, y + 3, 12, 1, "#e9e4d8"); px(x + 22, y + 3, 8, 3, shade(c, -0.3)); px(x + 15, y + 21, 4, 2, "#3a3f4a"); } },
    { k: "ventanal", cat: "Cuadros", slot: "wall", name: "Ventanal", lv: 8, price: 400000, vars: ["landscape"], g: "m",
      draw(x, y, [l], now) { const r = framed(x + 1, y, 32, 24, "#c9ced8"), [sky, sun, m1, m2] = l.c; px(r.x, r.y, r.w, r.h, sky); disc(r.x + 20, r.y + 5, 3, sun);
        px(r.x + ((Math.floor(now * 2)) % (r.w + 8)) - 8, r.y + 3, 7, 2, "rgba(255,255,255,0.7)"); tri(r.x + 8, r.y + 8, 8, m1); px(r.x, r.y + 14, r.w, r.h - 14, m2); px(r.x + 13, r.y, 2, r.h, "#c9ced8"); } },
    { k: "pool", cat: "Muebles", slot: "big", name: "Mesa de pool", lv: 8, price: 420000, vars: ["color"], g: "f",
      draw(cx, by, [c], now) { const x = cx - 28, y = by - 24; box(x, y, 56, 18, "#5e4229"); px(x + 3, y + 3, 50, 12, c.c); [[3, 3], [27, 3], [51, 3], [3, 13], [27, 13], [51, 13]].forEach(([dx, dy]) => px(x + dx - 1, y + dy - 1, 2, 2, "#16131f"));
        [["#f2c14e", 30, 8], ["#cf4b47", 33, 6], ["#4a78d6", 33, 10], ["#ffffff", 14 + (Math.floor(now) % 3), 9]].forEach(([col, dx, dy]) => px(x + dx, y + dy, 2, 2, col)); px(x + 4, y + 18, 3, 6, "#3a2a22"); px(x + 49, y + 18, 3, 6, "#3a2a22"); } },
    { k: "pochoclera", cat: "Muebles", slot: "big", name: "Máquina de pochoclo", lv: 7, price: 230000, vars: ["color"], g: "f",
      draw(cx, by, [c], now) { const x = cx - 11, y = by - 40; box(x, y + 26, 22, 14, c.c); box(x + 1, y + 6, 20, 20, "rgba(220,240,255,0.35)"); px(x, y + 2, 22, 5, c.c); px(x + 2, y, 18, 2, c.c);
        for (let i = 0; i < 14; i++) px(x + 3 + (i * 7) % 16, y + 16 + (i * 3) % 9 - (Math.floor(now * 4 + i) % 3 === 0 ? 1 : 0), 2, 2, "#f6e9b8"); px(x + 4, y + 30, 14, 3, "#f2c14e"); } },
    { k: "holograma", cat: "Muebles", slot: "big", name: "Holograma del planeta", lv: 10, price: 1200000, vars: ["neonColor"], g: "m",
      draw(cx, by, [c], now) { box(cx - 10, by - 6, 20, 6, "#3a3f4a"); px(cx - 8, by - 6, 16, 1, c.c); for (let k = 0; k < 6; k++) px(cx - 9 + k * 3, by - 30, 1, 24, "rgba(120,220,255,0.12)");
        const r = 9, rot = now * 1.5; for (let dy = -r; dy <= r; dy += 2) { const w = Math.floor(Math.sqrt(r * r - dy * dy)); px(cx - w, by - 22 + dy, w * 2 + 1, 1, shade(c.c, -0.2)); }
        for (let k = 0; k < 3; k++) px(cx + Math.round(Math.sin(rot + k * 2.1) * 7), by - 24 + k * 4, 3, 2, "#ffffff"); px(cx - 13, by - 22, 26, 1, c.c); } },
    { k: "robotasistente", cat: "Muebles", slot: "big", name: "Robot asistente", lv: 9, price: 800000, vars: ["color"], g: "m",
      draw(cx, by, [c], now) { const bob = Math.round(Math.sin(now * 3) * 2), x = cx - 9 + Math.round(Math.sin(now * 0.7) * 14); disc(x + 9, by - 4, 5, "rgba(0,0,0,0.3)");
        box(x + 2, by - 24 + bob, 14, 14, c.c); box(x + 4, by - 36 + bob, 10, 10, "#e9e4d8"); px(x + 6, by - 32 + bob, 2, 2, "#4ff0ff"); px(x + 10, by - 32 + bob, 2, 2, "#4ff0ff"); px(x + 8, by - 39 + bob, 1, 3, "#3a3f4a"); px(x + 7, by - 40 + bob, 3, 1, Math.floor(now * 3) % 2 ? "#ef6b5b" : "#5cc98a"); px(x + 5, by - 19 + bob, 8, 2, shade(c.c, 0.3)); } },
    { k: "trofeocristal", cat: "Adornos", slot: "small", name: "Trofeo de cristal", lv: 8, price: 300000, vars: [], g: "m",
      draw(cx, by, _, now) { box(cx - 5, by - 3, 10, 3, "#3a2a22"); px(cx - 4, by - 22, 8, 19, "rgba(190,230,255,0.55)"); px(cx - 4, by - 22, 8, 1, "#ffffff"); px(cx - 3, by - 20, 1, 15, "rgba(255,255,255,0.7)"); if (Math.floor(now * 3) % 4 === 0) px(cx + 2, by - 18, 1, 1, "#ffffff"); } },
    { k: "pisoled", cat: "Pisos", slot: "floor", name: "Piso de luces", lv: 10, price: 1500000, vars: [], g: "m",
      draw(x, y, w, h, _, now) { px(x, y, w, h, "#16131f"); for (let yy = y, r = 0; yy < y + h; yy += 12, r++) for (let xx = x, k = 0; xx < x + w; xx += 12, k++) if ((r + k + Math.floor(now * 2)) % 4 === 0) px(xx + 1, yy + 1, 10, 10, `hsl(${(r * 40 + k * 25 + now * 60) % 360},80%,45%)`); } },
    { k: "led", cat: "Paredes", slot: "paint", name: "Pared de pantallas", lv: 8, price: 500000, vars: ["glow"], g: "f",
      draw(x, y, w, h, [gl], now) { px(x, y, w, h, "#16131f"); const c = gl.c || `hsl(${(now * 90) % 360},90%,55%)`; for (let xx = x + 2; xx < x + w - 10; xx += 12) { px(xx, y + 3, 10, h - 7, shade(c, -0.6)); px(xx + 1, y + 4 + ((xx + Math.floor(now * 4)) % (h - 9)), 8, 1, c); } } },
    { k: "espacio", cat: "Paredes", slot: "paint", name: "Mural del espacio", lv: 9, price: 700000, vars: [], g: "m",
      draw(x, y, w, h, _, now) { px(x, y, w, h, "#121a33"); const R = rng(x * 13 + 7); for (let i = 0; i < w / 4; i++) px(x + R() * w, y + R() * h, 1, 1, (Math.floor(now * 3) + i) % 7 ? "#e9e4d8" : "#f2c14e"); disc(x + w - 30, y + 14, 6, "#d98a5a"); px(x + w - 40, y + 14, 20, 1, "#e9c79a"); disc(x + 30, y + 10, 3, "#6fb4e6"); } },
    { k: "flotante", cat: "Escritorios", slot: "desk", name: "Escritorio flotante", lv: 9, price: 900000, vars: ["glow"], g: "m",
      draw(cx, y, [gl], now) { const b = Math.round(Math.sin(now * 2)), c = gl.c || `hsl(${(now * 90) % 360},90%,60%)`; px(cx - 34, y - 1 + b, 68, 8, OUT); px(cx - 33, y + b, 66, 6, "#e9e4d8"); px(cx - 33, y + 5 + b, 66, 1, c);
        px(cx - 26, y + 26, 52, 2, shade(c, -0.5)); for (let k = 0; k < 3; k++) px(cx - 20 + k * 18, y + 12 + ((Math.floor(now * 3) + k * 4) % 12), 2, 2, c); } },
    { k: "escritoriooro", cat: "Escritorios", slot: "desk", name: "Escritorio de oro", lv: 10, price: 1400000, vars: [], g: "m",
      draw(cx, y, _, now) { woodDesk(cx, y, "#d4a933", "#b8892a"); px(cx - 33, y, 66, 1, "#f6e27a"); const sp = Math.floor(now * 2) % 6; px(cx - 28 + sp * 11, y + 3, 1, 1, "#ffffff"); px(cx - 24 + sp * 9, y + 15, 1, 1, "#ffffff"); } },
    { k: "masajes", cat: "Sillas", slot: "chair", name: "Sillón masajeador", lv: 8, price: 550000, vars: ["leather"], g: "m",
      draw(x, y, [l], now) { const v = Math.floor(now * 12) % 2; px(x - 16 + v, y - 22, 32, 32, OUT); px(x - 15 + v, y - 21, 30, 30, l.c); px(x - 11 + v, y - 19, 22, 4, shade(l.c, 0.2)); for (let k = 0; k < 4; k++) px(x - 8 + v, y - 13 + k * 5, 16, 1, shade(l.c, -0.3)); px(x + 12, y - 4, 3, 3, "#5cc98a"); } },
    { k: "astronauta", cat: "Ropa", slot: "hat", name: "Casco de astronauta", lv: 10, price: 1000000, vars: [], g: "m",
      draw(cx, ht, _, now) { disc(cx, ht + 5, 12, OUT); disc(cx, ht + 5, 11, "#e9e4d8"); g.save(); g.globalAlpha = 0.35; disc(cx, ht + 6, 8, "#6fb4e6"); g.restore(); px(cx - 5, ht - 1, 3, 2, "rgba(255,255,255,0.8)"); px(cx + 9, ht + 2, 2, 2, Math.floor(now * 2) % 2 ? "#ef6b5b" : "#5cc98a"); } },
    { k: "laureles", cat: "Ropa", slot: "hat", name: "Corona de laureles", lv: 7, price: 220000, vars: ["metal"], g: "f",
      draw(cx, ht, [m]) { for (let i = 0; i < 6; i++) { px(cx - 9 + i, ht - 2 - Math.floor(i / 2), 2, 1, m.c); px(cx + 7 - i, ht - 2 - Math.floor(i / 2), 2, 1, m.c); } px(cx - 9, ht - 1, 2, 2, shade(m.c, -0.2)); px(cx + 7, ht - 1, 2, 2, shade(m.c, -0.2)); } },
    { k: "visor", cat: "Ropa", slot: "face", name: "Visor futurista", lv: 8, price: 350000, vars: ["neonColor"], g: "m",
      draw(hx, ht, [c], now) { px(hx, ht + 4, 16, 4, OUT); px(hx + 1, ht + 5, 14, 2, c.c); px(hx + 1 + (Math.floor(now * 8) % 12), ht + 5, 2, 2, "#ffffff"); } },
    { k: "diamantes", cat: "Ropa", slot: "neck", name: "Collar de diamantes", lv: 9, price: 650000, vars: [], g: "m",
      draw(cx, ty, _, now) { for (let i = 0; i < 7; i++) { const dy = (i > 0 && i < 6 ? 1 : 0) + (i > 1 && i < 5 ? 1 : 0); px(cx - 6 + i * 2, ty + 1 + dy, 1, 1, (Math.floor(now * 4) + i) % 5 ? "#c8f0ff" : "#ffffff"); } px(cx - 1, ty + 4, 2, 2, "#9ad3ef"); } },
  );
  KINDS.push({ k: "top_gala", cat: "Ropa", slot: "top", name: "Traje de gala", g: "m", lv: 7, price: 240000, vars: ["color"], top: "gala" });
  KINDS.push({ k: "top_armor", cat: "Ropa", slot: "top", name: "Armadura", g: "f", lv: 10, price: 1100000, vars: ["metal"], top: "armor" });
  KINDS.push({ k: "top_astro", cat: "Ropa", slot: "top", name: "Traje espacial", g: "m", lv: 9, price: 500000, vars: ["color"], top: "astro" });

  // Nombres que no salen bien solos.
  KINDS.find(k => k.k === "tulipanes").label = ([f, p]) => `Tulipanes ${f.m} ${p.n}`;
  KINDS.find(k => k.k === "orquidea").label = ([f, p]) => `Orquídea de flores ${f.n} ${p.n}`;
  KINDS.find(k => k.k === "flor").label = ([f]) => `Flor ${f.s} en el pelo`;
  KINDS.find(k => k.k === "collar_flores").label = ([f]) => `Collar de flores ${f.n}`;
  KINDS.find(k => k.k === "camaperro").label = ([c, f]) => `Cama ${c.n[1]} con perro ${f.n}`;
  KINDS.find(k => k.k === "bigote").label = ([f]) => `Bigote ${f.b}`;
  KINDS.find(k => k.k === "lentes_sol").label = ([c]) => `Anteojos de sol con marco ${c.n[0]}`;
  KINDS.find(k => k.k === "lentes_corazon").label = ([c]) => `Anteojos de corazón (${c.n[0]})`;
  VARIANTS.flower.forEach((f, i) => Object.assign(f, { m: ["rojos", "amarillos", "rosas", "violetas", "blancos", "naranjas"][i], s: ["roja", "amarilla", "rosa", "violeta", "blanca", "naranja"][i] }));
  VARIANTS.fur.forEach((f, i) => { f.b = ["pelirrojo", "canoso", "negro", "rubio", "castaño", "bicolor"][i]; });
  VARIANTS.paper.forEach(p => { p.n = "con " + p.n; });

  const KIND = Object.fromEntries(KINDS.map(k => [k.k, k]));
  const WEAR = ["top", "hat", "face", "neck"];
  const ROOM_ONE = ["desk", "chair", "floor", "paint"];
  // Un artículo es un tipo más un índice por variante: "planta.3" es la planta en maceta azul.
  const itemCache = {};
  function itemOf(id) {
    if (id in itemCache) return itemCache[id];
    const [k, ...idx] = String(id).split(".");
    const kind = KIND[k];
    if (!kind || idx.length !== kind.vars.length) return itemCache[id] = null;
    const v = kind.vars.map((d, i) => VARIANTS[d][Number(idx[i])]);
    if (v.some(x => !x)) return itemCache[id] = null;
    let price = kind.price, lv = kind.lv;
    v.forEach(x => { price *= x.p || 1; lv += x.lv || 0; });
    const name = kind.label ? kind.label(v) : [kind.name, ...v.map(x => colorName(x, kind.g))].join(" ");
    return itemCache[id] = { id, kind, v, name, price: Math.max(1000, Math.round(price / 500) * 500), lv: Math.min(10, lv) };
  }
  const CATALOG_SIZE = KINDS.reduce((n, k) => n + k.vars.reduce((m, d) => m * VARIANTS[d].length, 1), 0);
  const CATS = ["Escritorios", "Sillas", "Pisos", "Paredes", "Cuadros", "Plantas", "Muebles", "Adornos", "Equipamiento", "Ropa"];

  // La vitrina de una partida: unos artículos por nivel, al azar pero siempre los mismos
  // para la misma partida. Así cada sesión trae un catálogo distinto.
  function buildShop(key) {
    const R = rng(hashStr("vitrina:" + key)), out = [], seen = new Set();
    const span = KINDS.map(k => ({ k, lo: k.lv, hi: Math.min(10, k.lv + k.vars.reduce((s, d) => s + Math.max(0, ...VARIANTS[d].map(x => x.lv || 0)), 0)) }));
    for (let lv = 1; lv <= 10; lv++) {
      const want = lv === 1 ? 14 : 9, cats = CATS.slice().sort(() => R() - 0.5);
      for (let got = 0, guard = 0; got < want && guard < 400; guard++) {
        const cat = cats[guard % cats.length];
        const pool = span.filter(s => s.k.cat === cat && s.lo <= lv && s.hi >= lv && !out.some(o => o.kind === s.k));
        if (!pool.length) continue;
        const kind = pool[Math.floor(R() * pool.length)].k;
        for (let t = 0; t < 16; t++) {
          const it = itemOf(kind.k + kind.vars.map(d => "." + Math.floor(R() * VARIANTS[d].length)).join(""));
          if (it && it.lv === lv && !seen.has(it.id)) { seen.add(it.id); out.push(it); got++; break; }
        }
      }
    }
    return out;
  }

  // Lugares de cada oficina, relativos a su esquina. wall: x de cada cuadro (34 de ancho,
  // arriba de todo); small y big: [x, y] del centro de la base. El pasillo, en absoluto.
  const TOP_WALL = [10, 50], BOT_WALL = [4, 40, 118, 154];
  const DEPT_FLOOR = { small: [[10, 106], [183, 112]], big: [[148, 172]] };
  const SLOTS = {
    meet: { wall: [8], small: [[10, 172], [183, 172]], big: [[48, 172], [144, 172]] },
    design: { wall: TOP_WALL, small: [[10, 104], [183, 106], [10, 172], [183, 172]], big: [] },
    back: { wall: TOP_WALL, ...DEPT_FLOOR }, front: { wall: TOP_WALL, ...DEPT_FLOOR },
    db: { wall: BOT_WALL, ...DEPT_FLOOR }, scrap: { wall: BOT_WALL, ...DEPT_FLOOR }, ops: { wall: BOT_WALL, ...DEPT_FLOOR },
    qa: { wall: BOT_WALL, small: [[10, 174], [183, 174]], big: [[42, 74], [150, 74]] },
    hall: { wall: [], small: [[46, 216], [262, 216], [314, 216], [382, 216], [480, 216], [578, 216], [676, 216], [752, 262]], big: [] },
  };
  // La pared que ocupa el equipamiento de cada departamento (lo que dibuja drawDeco).
  const KIT_RANGES = { meet: [[12, 66]], design: [[12, 98]], back: [[12, 86]], front: [[12, 76]], db: [[10, 74]], scrap: [[14, 36], [124, 160]], ops: [[10, 76], [130, 144]], qa: [[12, 36], [124, 164]] };
  const kitBlocks = (roomId, x) => (KIT_RANGES[roomId] || []).some(([a, b]) => x < b && x + 34 > a);
  const placeName = id => id === "hall" ? "el pasillo" : (room(id) || {}).name || id;

