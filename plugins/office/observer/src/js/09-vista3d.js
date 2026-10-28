  // --- Vista 3D: la oficina en pixel art 3D ------------------------------------------
  // three.js con cámara isométrica, dibujado a baja resolución y con contornos
  // (RenderPixelatedPass). Muebles KayKit (CC0, Kay Lousberg) y personajes hechos acá.
  // No tiene guion propio: copia lo que pasa en el estado de la oficina (el mismo que mueve
  // la vista clásica), así que va sincronizada con la consola y con la demo.
  const view3d = (() => {
    const LIB = typeof THREE_OFFICE !== "undefined" ? THREE_OFFICE : null;
    const off = { ok: false, on: false, frame() {}, resize() {}, setOn() {}, nameOf: () => null };
    if (!LIB || typeof document === "undefined") return off;
    const { THREE, EffectComposer, RenderPixelatedPass, OutputPass, GLTFLoader, RoundedBoxGeometry, mergeGeometries } = LIB;
    const host = $("view3d"), ui = $("view3d-ui");
    let renderer = null;
    try { renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: "high-performance" }); } catch (e) { return off; }
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFShadowMap;
    host.insertBefore(renderer.domElement, ui);
    const u = ui.getContext("2d");

    // --- Utilidades ---
    const hash = s => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; };
    const rand = seed => { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; };
    const pickR = (R, list) => list[Math.floor(R() * list.length)];
    const tint = (hex, f) => { const n = parseInt(hex.slice(1), 16), t = f < 0 ? 0 : 255, p = Math.abs(f), ch = v => Math.round((t - v) * p + v); return "#" + ((1 << 24) + (ch(n >> 16) << 16) + (ch((n >> 8) & 255) << 8) + ch(n & 255)).toString(16).slice(1); };
    const gradient = (() => { const t = new THREE.DataTexture(new Uint8Array([110, 170, 220, 255]), 4, 1, THREE.RedFormat); t.minFilter = t.magFilter = THREE.NearestFilter; t.needsUpdate = true; return t; })();
    const mats = {};
    const toon = (color, o = {}) => { const k = color + JSON.stringify(o); if (!o.map && mats[k]) return mats[k]; const m = new THREE.MeshToonMaterial({ color, gradientMap: gradient, ...o }); if (!o.map) mats[k] = m; return m; };
    const basic = o => new THREE.MeshBasicMaterial(o);
    function canvasTex(w, h, draw, repeat) {
      const c = document.createElement("canvas"); c.width = w; c.height = h;
      const x = c.getContext("2d"); draw(x, w, h);
      const t = new THREE.CanvasTexture(c); t.magFilter = t.minFilter = THREE.NearestFilter; t.generateMipmaps = false; t.colorSpace = THREE.SRGBColorSpace;
      if (repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repeat[0], repeat[1]); }
      t.userData.canvas = c; t.userData.ctx = x;
      return t;
    }
    const P = (x, c, X, Y, Wd, Ht) => { x.fillStyle = c; x.fillRect(X, Y, Wd, Ht); };

    // --- Escena ---
    const scene = new THREE.Scene(); scene.background = new THREE.Color("#10141f");
    let statics = new THREE.Group(); scene.add(statics);
    const live = new THREE.Group(); scene.add(live);
    function mesh(geo, mat, parent, x = 0, y = 0, z = 0) { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = m.receiveShadow = true; (parent || statics).add(m); return m; }
    const asMat = c => typeof c === "string" ? toon(c) : c;
    const box = (x, z, y, w, d, h, c, parent) => mesh(new THREE.BoxGeometry(w, h, d), asMat(c), parent, x + w / 2, y + h / 2, z + d / 2);
    const rbox = (x, z, y, w, d, h, r, c, parent) => mesh(new RoundedBoxGeometry(w, h, d, 2, Math.min(r, w / 2, h / 2, d / 2)), asMat(c), parent, x + w / 2, y + h / 2, z + d / 2);
    const cyl = (x, z, y, r, h, c, parent, seg = 12) => mesh(new THREE.CylinderGeometry(r, r, h, seg), asMat(c), parent, x, y + h / 2, z);
    const planeZ = (x, z, y, w, h, m, parent) => { const o = mesh(new THREE.PlaneGeometry(w, h), m, parent, x + w / 2, y + h / 2, z); o.castShadow = false; return o; };
    const planeX = (x, z, y, d, h, m, parent) => { const o = mesh(new THREE.PlaneGeometry(d, h), m, parent, x, y + h / 2, z + d / 2); o.rotation.y = Math.PI / 2; o.castShadow = false; return o; };
    const planeY = (x, z, y, w, d, m, parent) => { const o = mesh(new THREE.PlaneGeometry(w, d), m, parent, x + w / 2, y, z + d / 2); o.rotation.x = -Math.PI / 2; o.castShadow = false; return o; };

    // Muebles KayKit.
    const KK = {};
    function loadKayKit() {
      const loader = new GLTFLoader(), src = window.KAYKIT || {};
      return Promise.all(Object.entries(src).map(([name, json]) => new Promise(res => loader.parse(json, "", g => {
        g.scene.traverse(o => { if (o.isMesh) { const map = o.material.map; if (map) { map.magFilter = THREE.NearestFilter; map.colorSpace = THREE.SRGBColorSpace; } o.material = toon("#ffffff", { map }); o.castShadow = o.receiveShadow = true; } });
        KK[name] = g.scene; res();
      }, () => res()))));
    }
    function kay(name, x, z, rotY = 0, s = 0.62, y = 0, parent) {
      if (!KK[name]) return null;
      const o = KK[name].clone(); o.scale.setScalar(s); o.rotation.y = rotY; o.position.set(x, y, z); (parent || statics).add(o); return o;
    }

    // --- Oficinas: 7 x 7 baldosas, en dos filas con el pasillo al medio ---
    const GX = 28, GY = 17, WALL_H = 2.6, DESK_H = 0.62, PART_H = 0.55, DOOR_H = 1.85;
    const R3 = [
      { id: "meet", x: 0, y: 0, top: true, floor: "wood", c: "#b5814f", wall: "#ecdcc0", corr: 6.3 },
      { id: "design", x: 7, y: 0, top: true, floor: "carpet", c: "#b9aedb", wall: "#e0d6f0" },
      { id: "back", x: 14, y: 0, top: true, floor: "carpet", c: "#5b79a3", wall: "#d6e2ef" },
      { id: "front", x: 21, y: 0, top: true, floor: "tiles", c: "#ede4d3", c2: "#d9cbb3", wall: "#d6ecdd" },
      { id: "db", x: 0, y: 10, floor: "carpet", c: "#4b8c85", wall: "#d2e7e3" },
      { id: "scrap", x: 7, y: 10, floor: "carpet", c: "#7c9a5a" },
      { id: "ops", x: 14, y: 10, floor: "concrete", c: "#8a909b" },
      { id: "qa", x: 21, y: 10, floor: "tiles", c: "#e6ecf0", c2: "#cbd6de" },
    ];
    R3.forEach(r => { r.corr = r.corr || 2.6; });
    const r3 = id => R3.find(r => r.id === id);
    const roomAt3 = p => R3.find(r => p.x >= r.x && p.x < r.x + 7 && p.y >= r.y && p.y < r.y + 7) || null;
    const nameOfRoom = id => (room(id) || {}).name || id;

    // Puestos: [oficina, x, y, hacia dónde mira]. "-y": escritorio con monitor (se ve la
    // pantalla); "+x": notebook (se ve la cara); "+y": silla de la mesa de reuniones.
    const SEAT_DEF = {
      ceo: ["meet", 3.0, 1.55, "+y"], adv: ["meet", 4.4, 1.55, "+y"], pm: ["meet", 1.1, 5.9, "-y"],
      barch: ["design", 1.4, 1.6, "-y"], farch: ["design", 5.8, 1.6, "-y"], oarch: ["design", 1.65, 4.4, "+x"], dsgn: ["design", 5.05, 4.4, "+x"],
      bdev: ["back", 1.4, 1.6, "-y"], btest: ["back", 5.8, 1.6, "-y"], blead: ["back", 5.05, 4.4, "+x"],
      fdev: ["front", 1.4, 1.6, "-y"], ftest: ["front", 5.8, 1.6, "-y"], flead: ["front", 5.05, 4.4, "+x"],
      ddev: ["db", 1.4, 1.6, "-y"], dtest: ["db", 5.8, 1.6, "-y"], dlead: ["db", 5.05, 4.4, "+x"],
      sdev: ["scrap", 1.4, 1.6, "-y"], stest: ["scrap", 5.8, 1.6, "-y"], slead: ["scrap", 5.05, 4.4, "+x"],
      odev: ["ops", 1.4, 1.6, "-y"], otest: ["ops", 5.8, 1.6, "-y"], olead: ["ops", 5.05, 4.4, "+x"],
      qa1: ["qa", 1.4, 1.6, "-y"], qa2: ["qa", 5.8, 1.6, "-y"],
    };
    const SEAT = {};
    Object.entries(SEAT_DEF).forEach(([id, [rid, x, y, f]]) => { const r = r3(rid); SEAT[id] = { x: r.x + x, y: r.y + y, facing: f, room: rid }; });
    // Lugares de la vida en la oficina.
    const SPOT = {
      coffee: { x: 26.9, y: 8.05, f: "-y" }, coffee2: { x: 26.4, y: 8.1, f: "-y" }, cooler: { x: 1.2, y: 8.05, f: "-y" }, cooler2: { x: 1.95, y: 8.2, f: "-x" },
      vending: { x: 6.35, y: 8.0, f: "-y" }, plants: { x: 9.3, y: 8.1, f: "-y" }, bench: { x: 6.2, y: 9.15, f: "+y" }, board: { x: 20.7, y: 8.95, f: "+y" },
      debate0: { x: 21.9, y: 16.4, f: "-y" }, debate1: { x: 22.8, y: 16.4, f: "-y" }, exit: { x: 0.4, y: 8.45, f: "+x" }, ceo: { x: 2.3, y: 3.0, f: "+x" },
      stall0: { x: 29.5, y: 8.65, f: "-y" }, stall1: { x: 30.5, y: 8.65, f: "-y" }, sink: { x: 28.45, y: 7.85, f: "-y" }, bathq: { x: 28.55, y: 9.35, f: "-y" },
    };
    const roomSpot = (rid, kind) => { const r = r3(rid); if (!r || !r.top || rid === "meet") return SPOT.plants; return kind === "printer" ? { x: r.x + 4.05, y: 1.0, f: "-y" } : { x: r.x + 3.2, y: 1.0, f: "-y" }; };

    // --- Pisos, paredes y tabiques ---
    function floorTex(kind, c, c2, rep) {
      return canvasTex(16, 16, x => {
        const R = rand(hash(kind + c));
        if (kind === "wood" || kind === "hall") {
          for (let k = 0; k < 4; k++) { P(x, tint(c, (R() - 0.5) * 0.14), 0, k * 4, 16, 4); P(x, tint(c, -0.25), 0, k * 4, 16, 1); P(x, tint(c, -0.25), Math.floor(R() * 16), k * 4, 1, 4); P(x, tint(c, 0.08), Math.floor(R() * 12), k * 4 + 2, 3, 1); }
          if (kind === "hall") { const d = x.getImageData(0, 0, 16, 16), o = x.createImageData(16, 16); for (let yy = 0; yy < 16; yy++) for (let xx = 0; xx < 16; xx++) for (let q = 0; q < 4; q++) o.data[(yy * 16 + xx) * 4 + q] = d.data[(xx * 16 + yy) * 4 + q]; x.putImageData(o, 0, 0); }
        } else if (kind === "tiles") {
          [[0, 0, c], [8, 0, c2], [0, 8, c2], [8, 8, c]].forEach(([a, b, col]) => { P(x, col, a, b, 8, 8); P(x, tint(col, 0.25), a + 1, b + 1, 3, 1); P(x, tint(c2, -0.15), a, b, 8, 1); P(x, tint(c2, -0.15), a, b, 1, 8); });
        } else if (kind === "concrete") {
          P(x, c, 0, 0, 16, 16); for (let i = 0; i < 14; i++) P(x, tint(c, (R() - 0.5) * 0.2), Math.floor(R() * 16), Math.floor(R() * 16), 1 + Math.floor(R() * 2), 1); P(x, tint(c, -0.2), 0, 0, 16, 1); P(x, tint(c, -0.2), 0, 0, 1, 16);
        } else {
          P(x, c, 0, 0, 16, 16); for (let i = 0; i < 16; i++) P(x, tint(c, (R() - 0.5) * 0.16), Math.floor(R() * 16), Math.floor(R() * 16), 1, 1); P(x, tint(c, -0.08), 0, 0, 16, 1); P(x, tint(c, -0.08), 0, 0, 1, 16);
        }
      }, rep);
    }
    function wallTex(color, len) {
      return canvasTex(16, 40, x => {
        P(x, color, 0, 0, 16, 40);
        for (let i = 2; i < 16; i += 6) for (let j = 4; j < 22; j += 5) P(x, tint(color, -0.06), i + (j % 2) * 3, j, 1, 1);
        P(x, tint(color, 0.18), 0, 0, 16, 2); P(x, tint(color, -0.2), 0, 2, 16, 1);
        P(x, tint(color, -0.12), 0, 24, 16, 13); P(x, tint(color, 0.2), 0, 23, 16, 1); P(x, tint(color, -0.25), 0, 24, 16, 1);
        P(x, tint(color, -0.22), 2, 26, 12, 1); P(x, tint(color, -0.22), 2, 26, 1, 9); P(x, tint(color, 0.05), 2, 35, 12, 1); P(x, tint(color, 0.05), 13, 26, 1, 10);
        P(x, "#8d7a66", 0, 37, 16, 3); P(x, "#b3a08a", 0, 37, 16, 1);
      }, [len, 1]);
    }
    const skies = [];
    function skyTex() { const t = canvasTex(48, 32, () => {}); drawSky(t); skies.push(t); return t; }
    function drawSky(t) {
      const x = t.userData.ctx, h = new Date().getHours(), day = h >= 7 && h < 18, dusk = h >= 18 && h < 20;
      const top = day ? "#6fb6ee" : dusk ? "#e07a58" : "#121a36", low = day ? "#c2e6f8" : dusk ? "#f6c97a" : "#2c376a", city = day ? "#8aa2bf" : dusk ? "#6b5a7a" : "#1f2644", lit = day ? "#c9d8ea" : "#ffd27a";
      {
        const R = rand(7);
        for (let y = 0; y < 32; y++) P(x, y < 16 ? top : low, 0, y, 48, 1);
        if (day) { P(x, "#ffffff", 8, 5, 9, 2); P(x, "#ffffff", 10, 4, 5, 1); P(x, "#ffffff", 30, 9, 8, 2); }
        else for (let i = 0; i < 10; i++) P(x, "#ffffff", Math.floor(R() * 48), Math.floor(R() * 14), 1, 1);
        let q = 0; while (q < 48) { const w = 3 + Math.floor(R() * 6), hh = 8 + Math.floor(R() * 14); P(x, city, q, 32 - hh, w, hh); for (let k = 0; k < 3; k++) P(x, lit, q + 1 + Math.floor(R() * Math.max(1, w - 2)), 32 - hh + 2 + Math.floor(R() * (hh - 4)), 1, 1); q += w; }
        for (let y = 0; y < 9; y += 2) P(x, "#efe9dc", 0, y, 48, 1);
      }
      t.needsUpdate = true;
    }
    const winLights = [];
    function windowOn(onX, a, b, y0 = 0.95, y1 = 2.05) {
      const g = new THREE.Group(); statics.add(g);
      const w = b - a, h = y1 - y0, sky = basic({ map: skyTex() }), F = "#f6f1e8";
      if (!onX) {
        planeZ(a, 0.02, y0, w, h, sky, g);
        box(a - 0.07, 0, y0 - 0.07, w + 0.14, 0.05, 0.07, F, g); box(a - 0.07, 0, y1, w + 0.14, 0.05, 0.07, F, g); box(a - 0.07, 0, y0, 0.07, 0.05, h, F, g); box(b, 0, y0, 0.07, 0.05, h, F, g);
        box(a + w / 2 - 0.03, 0, y0, 0.06, 0.04, h, F, g); box(a, 0, y0 + h * 0.45, w, 0.04, 0.04, F, g); box(a - 0.12, 0, y0 - 0.13, w + 0.24, 0.16, 0.06, F, g);
      } else {
        planeX(0.02, a, y0, w, h, sky, g);
        box(0, a - 0.07, y0 - 0.07, 0.05, w + 0.14, 0.07, F, g); box(0, a - 0.07, y1, 0.05, w + 0.14, 0.07, F, g); box(0, a - 0.07, y0, 0.05, 0.07, h, F, g); box(0, b, y0, 0.05, 0.07, h, F, g);
        box(0, a + w / 2 - 0.03, y0, 0.04, 0.06, h, F, g); box(0, a, y0 + h * 0.45, 0.04, w, 0.04, F, g); box(0, a - 0.12, y0 - 0.13, 0.16, w + 0.24, 0.06, F, g);
      }
      winLights.push({ onX, a, b });
    }
    function poster(onX, a, b, y0, y1, draw) {
      const m = toon("#ffffff", { map: canvasTex(24, 32, draw) });
      if (!onX) { box(a - 0.04, 0, y0 - 0.04, b - a + 0.08, 0.04, y1 - y0 + 0.08, "#2a2233"); planeZ(a, 0.045, y0, b - a, y1 - y0, m); }
      else { box(0, a - 0.04, y0 - 0.04, 0.04, b - a + 0.08, y1 - y0 + 0.08, "#2a2233"); planeX(0.045, a, y0, b - a, y1 - y0, m); }
    }
    function sconce(onX, q, y) {
      const lamp = toon("#fff1cf", { emissive: "#ffe2a0", emissiveIntensity: 0.9 });
      if (!onX) { box(q - 0.04, 0, y - 0.1, 0.08, 0.05, 0.08, "#c9a777"); rbox(q - 0.12, 0.02, y - 0.04, 0.24, 0.14, 0.2, 0.04, lamp); }
      else { box(0, q - 0.04, y - 0.1, 0.05, 0.08, 0.08, "#c9a777"); rbox(0.02, q - 0.12, y - 0.04, 0.14, 0.24, 0.2, 0.04, lamp); }
    }
    const clocks = [];
    function clockOn(onX, q, y) {
      const t = canvasTex(24, 24, () => {});
      const m = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.05, 20), [toon("#6e4a2f"), toon("#ffffff", { map: t }), toon("#6e4a2f")]);
      if (!onX) { m.position.set(q, y, 0.03); m.rotation.set(Math.PI / 2, 0, 0); } else { m.position.set(0.03, y, q); m.rotation.set(0, 0, -Math.PI / 2); }
      live.add(m); clocks.push(t);
    }
    function drawClock(t) {
      const x = t.userData.ctx, d = new Date(); P(x, "#fbf8f0", 0, 0, 24, 24);
      for (let i = 0; i < 12; i++) P(x, i % 3 ? "#9aa1ad" : "#3a3f4a", 12 + Math.round(Math.sin(i / 6 * Math.PI) * 9), 12 - Math.round(Math.cos(i / 6 * Math.PI) * 9), 1, 1);
      const hand = (a, l, c) => { for (let k = 0; k <= l; k++) P(x, c, Math.round(12 + Math.sin(a) * k), Math.round(12 - Math.cos(a) * k), 1, 1); };
      hand((d.getHours() % 12 + d.getMinutes() / 60) / 6 * Math.PI, 5, "#2b2d36"); hand(d.getMinutes() / 30 * Math.PI, 8, "#2b2d36"); hand(d.getSeconds() / 30 * Math.PI, 8, "#cf4b47");
      t.needsUpdate = true;
    }
    function buildRoomShell() {
      R3.forEach(r => planeY(r.x, r.y, 0.004, 7, 7, toon("#ffffff", { map: floorTex(r.floor, r.c, r.c2, [7, 7]) })));
      planeY(0, 7, 0.004, 28, 3, toon("#ffffff", { map: floorTex("hall", "#8a6440", null, [28, 3]) }));
      const runner = canvasTex(64, 8, x => { P(x, "#d4a24c", 0, 0, 64, 8); P(x, "#a63a4d", 0, 1, 64, 6); for (let i = 2; i < 64; i += 8) { P(x, "#d4a24c", i + 2, 3, 3, 2); P(x, "#c4505f", i + 3, 2, 1, 4); } }, [27 / 4, 1]);
      planeY(0.6, 8.1, 0.012, 26.8, 0.8, toon("#ffffff", { map: runner }));
      box(-0.2, -0.2, -0.35, GX + 0.2, GY + 0.2, 0.345, "#4a4058");
      const seg = (onX, a, b, color) => {
        const len = b - a, faces = Array(6).fill(toon("#f4ede2"));
        if (!onX) { faces[4] = toon("#ffffff", { map: wallTex(color, len) }); box(a, -0.2, 0, len, 0.2, WALL_H, faces); }
        else { faces[0] = toon("#ffffff", { map: wallTex(tint(color, 0.04), len) }); box(-0.2, a, 0, 0.2, len, WALL_H, faces); }
      };
      R3.filter(r => r.top).forEach(r => seg(false, r.x, r.x + 7, r.wall));
      seg(true, 0, 7, r3("meet").wall); seg(true, 7, 10, "#e9d7b9"); seg(true, 10, 17, r3("db").wall);
      box(-0.2, -0.2, 0, 0.2, 0.2, WALL_H, "#f4ede2");
      [7, 14, 21].forEach(q => box(q - 0.09, 0, 0, 0.18, 0.08, WALL_H, "#f1e9db")); [7, 10].forEach(q => box(0, q - 0.09, 0, 0.08, 0.18, WALL_H, "#f1e9db"));
      windowOn(false, 4.7, 6.5); windowOn(false, 9.1, 11.9); windowOn(false, 16.1, 18.9); windowOn(false, 23.1, 25.9); windowOn(true, 3.6, 5.9); windowOn(true, 12.0, 14.6);
      poster(false, 1.3, 3.7, 1.15, 2.05, x => { P(x, "#1f2f4a", 0, 0, 24, 32); for (let i = 0; i < 6; i++) P(x, ["#5cc98a", "#f2c14e", "#6fb4e6"][i % 3], 3 + i * 3, 26 - i * 3 - (i % 2) * 2, 2, 4 + i * 3 + (i % 2) * 2); P(x, "#e9e4d8", 3, 4, 10, 1); });
      poster(false, 12.15, 12.95, 1.15, 1.9, x => { P(x, "#ff7eb6", 0, 0, 24, 32); P(x, "#ffd166", 3, 3, 18, 10); P(x, "#06d6a0", 3, 16, 8, 12); P(x, "#118ab2", 13, 16, 8, 12); });
      poster(false, 19.6, 20.6, 1.15, 2.0, x => { P(x, "#1d2433", 0, 0, 24, 32); P(x, "#7fd1ff", 2, 3, 20, 2); for (let i = 0; i < 8; i++) P(x, ["#f2c14e", "#c792ea", "#9be37a"][i % 3], 3 + (i % 3) * 2, 8 + i * 3, 6 + (i * 5) % 10, 1); });
      poster(false, 26.2, 27.2, 1.15, 2.0, x => { P(x, "#f4f1ea", 0, 0, 24, 32); P(x, "#4a78d6", 2, 2, 20, 6); P(x, "#e17aa8", 2, 11, 9, 18); P(x, "#f2c14e", 13, 11, 9, 18); });
      poster(true, 15.4, 16.4, 1.15, 2.0, x => { P(x, "#22344a", 0, 0, 24, 32); P(x, "#79e0d0", 2, 3, 20, 3); for (let i = 0; i < 5; i++) P(x, "#4fb0a8", 2, 10 + i * 4, 20, 1); P(x, "#4fb0a8", 11, 10, 1, 17); });
      [4.25, 8.1, 15.1, 22.1].forEach(q => sconce(false, q, 1.75)); [6.4, 11.1].forEach(q => sconce(true, q, 1.75));
      clockOn(false, 26.7, 2.3); clockOn(true, 1.8, 2.3);
      box(0, 7.7, 0, 0.06, 1.6, 1.75, "#6e4a2f"); box(0.02, 7.78, 0.05, 0.06, 0.68, 1.62, "#9a6a43"); box(0.02, 8.52, 0.05, 0.06, 0.68, 1.62, "#9a6a43");
      const glass = toon("#bfe0f2", { emissive: "#7fb0d0", emissiveIntensity: 0.3 }); box(0.05, 8.0, 0.75, 0.04, 0.3, 0.6, glass); box(0.05, 8.7, 0.75, 0.04, 0.3, 0.6, glass);
      const exit = canvasTex(32, 10, x => { P(x, "#2fae66", 0, 0, 32, 10); x.fillStyle = "#fff"; x.font = "bold 8px monospace"; x.fillText("SALIDA", 3, 8); });
      box(0, 7.95, 1.9, 0.06, 1.1, 0.3, [basic({ map: exit }), toon("#1f8a4f"), toon("#1f8a4f"), toon("#1f8a4f"), toon("#1f8a4f"), toon("#1f8a4f")]);
      // Tabiques bajos con baranda, y marcos de puerta.
      const fab = toon("#ddd3c3"), rail = toon("#8a5d3b");
      const along = (Z, x0, x1) => { box(x0, Z - 0.07, 0, x1 - x0, 0.14, PART_H - 0.06, fab); box(x0, Z - 0.09, PART_H - 0.06, x1 - x0, 0.18, 0.06, rail); box(x0, Z - 0.08, 0, x1 - x0, 0.16, 0.06, "#6b6157"); };
      const across = (X, z0, z1) => { box(X - 0.07, z0, 0, 0.14, z1 - z0, PART_H - 0.06, fab); box(X - 0.09, z0, PART_H - 0.06, 0.18, z1 - z0, 0.06, rail); box(X - 0.08, z0, 0, 0.16, z1 - z0, 0.06, "#6b6157"); };
      R3.forEach(r => {
        const Z = r.top ? 7 : 10;
        along(Z, r.x, r.x + 3); along(Z, r.x + 5, r.x + 7);
        box(r.x + 2.95, Z - 0.1, 0, 0.1, 0.2, DOOR_H, "#6e4a2f"); box(r.x + 4.95, Z - 0.1, 0, 0.1, 0.2, DOOR_H, "#6e4a2f"); box(r.x + 2.8, Z - 0.12, DOOR_H, 2.4, 0.24, 0.16, "#6e4a2f");
      });
      [7, 14, 21].forEach(X => { across(X, 0, 7); across(X, 10, 17); });
    }

    // --- El baño, al final del pasillo: dos cubículos con puerta y un lavamanos con espejo ---
    const stallDoors = [];
    function buildBathroom() {
      planeY(28, 7, 0.004, 3, 3, toon("#ffffff", { map: floorTex("tiles", "#e4f0f6", "#bfd9e6", [6, 6]) }));
      box(28, 7, -0.35, 3.2, 3.2, 0.345, "#4a4058");
      const tiles = canvasTex(16, 16, x => { P(x, "#e6f2f7", 0, 0, 16, 16); P(x, "#c3dbe6", 0, 0, 16, 1); P(x, "#c3dbe6", 0, 0, 1, 16); P(x, "#c3dbe6", 8, 0, 1, 16); P(x, "#c3dbe6", 0, 8, 16, 1); P(x, "#7fb3d5", 0, 13, 16, 3); }, [6, 3]);
      const faces = Array(6).fill(toon("#f4ede2")); faces[4] = toon("#ffffff", { map: tiles });
      box(28, 6.8, 0, 3.2, 0.2, 1.5, faces); box(28, 6.76, 1.5, 3.2, 0.28, 0.06, "#8a5d3b");
      // Tabique hacia el pasillo, con la puerta, y el cartel.
      const fab = toon("#ddd3c3"), rail = toon("#8a5d3b");
      [[7, 7.95], [8.95, 10]].forEach(([z0, z1]) => { box(27.93, z0, 0, 0.14, z1 - z0, PART_H - 0.06, fab); box(27.91, z0, PART_H - 0.06, 0.18, z1 - z0, 0.06, rail); box(27.92, z0, 0, 0.16, z1 - z0, 0.06, "#6b6157"); });
      box(27.9, 7.9, 0, 0.2, 0.1, DOOR_H, "#6e4a2f"); box(27.9, 8.95, 0, 0.2, 0.1, DOOR_H, "#6e4a2f"); box(27.88, 7.8, DOOR_H, 0.24, 1.3, 0.16, "#6e4a2f");
      // Cubículos.
      const panel = "#7fb3d5";
      [29.0, 30.0, 31.0].forEach(x => box(x - 0.03, 7.0, 0.12, 0.06, 1.2, 1.2, panel));
      [29.0, 30.0].forEach((x0, n) => {
        box(x0, 8.17, 0.12, 0.1, 0.06, 1.2, panel); box(x0 + 0.9, 8.17, 0.12, 0.1, 0.06, 1.2, panel); box(x0, 8.15, 1.3, 1.0, 0.08, 0.05, "#5f8fb0");
        // Inodoro: tanque contra la pared, taza y tapa.
        box(x0 + 0.32, 7.02, 0.3, 0.36, 0.18, 0.35, "#f4f6f8"); cyl(x0 + 0.5, 7.42, 0, 0.13, 0.28, "#f4f6f8"); cyl(x0 + 0.5, 7.45, 0.28, 0.17, 0.06, "#ffffff"); box(x0 + 0.34, 7.2, 0.34, 0.32, 0.04, 0.3, "#e9eef2");
        box(x0 + 0.75, 7.05, 0.7, 0.12, 0.08, 0.12, "#e9eef2"); // papel
        // Puerta, con bisagra a la izquierda, y el cartelito de libre u ocupado.
        const hinge = new THREE.Group(); hinge.position.set(x0 + 0.1, 0.15, 8.2); live.add(hinge);
        const door = mesh(new THREE.BoxGeometry(0.8, 1.1, 0.04), toon("#6fa6cb"), hinge, 0.4, 0.55, 0);
        const sign = mesh(new THREE.PlaneGeometry(0.1, 0.06), basic({ color: "#5cc98a" }), hinge, 0.68, 0.75, 0.025); sign.castShadow = false;
        mesh(new THREE.BoxGeometry(0.04, 0.03, 0.06), toon("#c9ced8"), hinge, 0.7, 0.55, 0.04);
        stallDoors.push({ hinge, door, sign, open: 1 });
      });
      // Lavamanos con espejo y secador.
      box(28.12, 7.02, 0, 0.72, 0.5, 0.78, "#8a6440"); box(28.1, 7.0, 0.78, 0.76, 0.54, 0.05, "#f4f1ea"); cyl(28.48, 7.3, 0.8, 0.17, 0.04, "#cfd8de"); box(28.45, 7.05, 0.83, 0.06, 0.12, 0.1, "#c9ced8");
      box(28.16, 7.0, 0.95, 0.56, 0.03, 0.5, "#c9ced8"); planeZ(28.19, 7.031, 0.98, 0.5, 0.44, toon("#cfe8f2", { emissive: "#9fc4d8", emissiveIntensity: 0.4 }));
      box(28.76, 7.0, 1.05, 0.2, 0.14, 0.24, "#e9eef2"); box(28.8, 7.12, 1.07, 0.12, 0.03, 0.04, "#3a3f4a");
      cyl(29.6, 9.72, 0, 0.13, 0.36, "#9aa3b0"); cyl(29.6, 9.72, 0.36, 0.14, 0.03, "#6c727d");
      plant(30.62, 9.62, true, "tall", "#e9e4d8");

      const sign = canvasTex(24, 12, x => { P(x, "#2f5f8a", 0, 0, 24, 12); x.fillStyle = "#fff"; x.fillRect(4, 3, 3, 3); x.fillRect(3, 6, 5, 4); x.fillRect(16, 3, 3, 3); x.fillRect(15, 6, 5, 4); x.fillRect(11, 2, 1, 8); });
      box(28.05, 8.2, 1.35, 0.03, 0.5, 0.25, [basic({ map: sign }), toon("#2f5f8a"), toon("#2f5f8a"), toon("#2f5f8a"), toon("#2f5f8a"), toon("#2f5f8a")]);
    }

    // --- Muebles hechos acá ---
    function desk(x, z, w, d, g) {
      const wood = "#b07a4a", metal = "#5b6070";
      [[x + 0.04, z + 0.04], [x + 0.04, z + d - 0.1], [x + w - 0.1, z + 0.04], [x + w - 0.1, z + d - 0.1]].forEach(([a, b]) => box(a, b, 0, 0.06, 0.06, DESK_H - 0.05, metal, g));
      if (w >= d) { box(x + w - 0.5, z + 0.05, 0, 0.45, d - 0.1, DESK_H - 0.05, tint(wood, -0.08), g); for (let k = 0; k < 3; k++) box(x + w - 0.42, z + d - 0.06, 0.06 + k * 0.17, 0.3, 0.02, 0.012, "#d8c6a6", g); box(x + 0.05, z + 0.04, 0.15, w - 0.6, 0.03, 0.4, tint(wood, -0.35), g); }
      else { box(x + 0.05, z + d - 0.5, 0, w - 0.1, 0.45, DESK_H - 0.05, tint(wood, -0.08), g); box(x + w - 0.07, z + 0.05, 0.15, 0.03, d - 0.6, 0.4, tint(wood, -0.35), g); }
      rbox(x, z, DESK_H - 0.05, w, d, 0.05, 0.015, wood, g);
    }
    const SCREENS = {}, screenMeshes = {};
    const addScreen = (owner, m) => { live.add(m); (screenMeshes[owner] = screenMeshes[owner] || []).push(m); };
    const PAL = { code: ["#7fd1ff", "#f2c14e", "#c792ea", "#9be37a", "#ff8a80"], term: ["#7dff9a", "#4fd17a", "#b7ffcc"], ui: ["#4a78d6", "#e17aa8", "#f2c14e"], data: ["#79e0d0", "#e9e4d8", "#4fb0a8"], test: ["#5cc98a", "#5cc98a", "#ef6b5b", "#5cc98a"], design: ["#ff7eb6", "#ffd166", "#06d6a0", "#118ab2"], web: ["#9fd36b", "#6fb4e6", "#e9e4d8"], off: ["#1a2232"] };
    // Cada pantalla tiene su textura: se mueve solo si su dueño está trabajando.
    function screenTex(kind, v, owner) { const t = canvasTex(32, 20, () => {}); Object.assign(t.userData, { kind, v, owner }); SCREENS[owner + ":" + v] = t; drawScreen(t, 0, false); return t; }
    function drawScreen(t, now, busy) {
      const x = t.userData.ctx, kind = t.userData.kind, pal = PAL[kind] || PAL.code, step = (busy ? Math.floor(now * 2.5) : 0) + t.userData.v * 7;
      if (!busy) { P(x, "#0e1420", 0, 0, 32, 20); const k = Math.floor(now / 2) % 4; P(x, "#24324a", 10 + k * 3, 8, 6, 4); P(x, "#3b4a66", 11 + k * 3, 9, 4, 2); t.needsUpdate = true; return; }
      if (kind === "ui" || kind === "design") {
        P(x, "#f4f1ea", 0, 0, 32, 20); P(x, "#d9dde5", 0, 0, 32, 3); P(x, "#ef6b5b", 1, 1, 1, 1); P(x, "#f2c14e", 3, 1, 1, 1); P(x, "#5cc98a", 5, 1, 1, 1);
        const R = rand(hash(kind + t.userData.v) + Math.floor(now / 3)); P(x, pal[0], 2, 5, 28, 3);
        for (let i = 0; i < 4; i++) P(x, pal[1 + Math.floor(R() * (pal.length - 1))], 2 + Math.floor(R() * 20), 10 + Math.floor(R() * 6), 4 + Math.floor(R() * 6), 2 + Math.floor(R() * 3));
      } else {
        const term = kind === "term";
        P(x, term ? "#0c1710" : "#131a28", 0, 0, 32, 20); P(x, term ? "#1b2a20" : "#232d42", 0, 0, 32, 2); P(x, term ? "#2a4030" : "#33405c", 1, 0, 8, 2);
        if (!term) P(x, "#1a2232", 0, 2, 3, 18);
        for (let i = 0; i < 6; i++) {
          const R = rand(hash(kind + ":" + (i + step))), ind = Math.floor(R() * 3) * 2, len = 4 + Math.floor(R() * 14), y = 3 + i * 3;
          if (!term) P(x, "#4a5878", 1, y, 1, 1);
          if (i === 2 && !term) P(x, "#1d2840", 3, y - 1, 29, 3);
          P(x, pal[Math.floor(R() * pal.length)], (term ? 1 : 4) + ind, y, len, 1);
          if (R() < 0.5) P(x, pal[Math.floor(R() * pal.length)], (term ? 1 : 4) + ind + len + 1, y, 3 + Math.floor(R() * 4), 1);
        }
        if (Math.floor(now * 2) % 2) P(x, "#e9e4d8", term ? 2 : 5, 18, 2, 1);
      }
      t.needsUpdate = true;
    }
    function monitor(x, z, kind, dual, owner, g) {
      (dual ? [x - 0.36, x + 0.36] : [x]).forEach((mx, m) => {
        box(mx - 0.13, z - 0.08, DESK_H, 0.26, 0.16, 0.02, "#3a3f4a", g); box(mx - 0.03, z - 0.04, DESK_H, 0.06, 0.05, 0.14, "#4a5060", g);
        rbox(mx - 0.33, z - 0.03, DESK_H + 0.1, 0.66, 0.05, 0.4, 0.015, "#22262f", g);
        const s = new THREE.Mesh(new THREE.PlaneGeometry(0.6, 0.34), basic({ map: screenTex(kind, m, owner) })); s.position.set(mx, DESK_H + 0.31, z + 0.026); addScreen(owner, s);
        box(mx + 0.2, z + 0.02, DESK_H + 0.42, 0.09, 0.01, 0.09, "#f2e27a", g);
      });
      box(x - 0.26, z + 0.22, DESK_H, 0.52, 0.16, 0.025, "#d7dbe3", g); box(x + 0.34, z + 0.25, DESK_H, 0.07, 0.11, 0.025, "#d7dbe3", g);
      cyl(x + 0.55, z + 0.3, DESK_H, 0.05, 0.1, pickR(rand(hash("taza" + owner)), ["#cf4b47", "#4a78d6", "#f2c14e", "#47a865"]), g); cyl(x + 0.55, z + 0.3, DESK_H + 0.095, 0.04, 0.01, "#4a3222", g);
    }
    function laptop(x, z, owner, g) {
      box(x - 0.18, z - 0.22, DESK_H, 0.34, 0.44, 0.02, "#b9c0cc", g); box(x + 0.14, z - 0.22, DESK_H, 0.025, 0.44, 0.3, "#aeb6c3", g);
      box(x + 0.165, z - 0.04, DESK_H + 0.12, 0.005, 0.08, 0.08, toon("#e9eef5", { emissive: "#ffffff", emissiveIntensity: 0.5 }), g);
      const s = new THREE.Mesh(new THREE.PlaneGeometry(0.4, 0.26), basic({ map: screenTex("code", 0, owner) })); s.position.set(x + 0.135, DESK_H + 0.16, z); s.rotation.set(0, -Math.PI / 2, 0); addScreen(owner, s);
    }
    const FACE = { "+y": 0, "-y": Math.PI, "+x": Math.PI / 2, "-x": -Math.PI / 2 };
    function chair(x, z, facing, color, exec, parent) {
      const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = FACE[facing]; (parent || statics).add(g);
      const base = toon("#2b2f3a");
      for (let i = 0; i < 5; i++) { const leg = mesh(new THREE.BoxGeometry(0.04, 0.03, 0.24), base, g, 0, 0.06, 0); leg.rotation.y = i / 5 * Math.PI * 2; leg.translateZ(0.12); const w = mesh(new THREE.SphereGeometry(0.03, 6, 4), toon("#1d1f26"), g, 0, 0.03, 0); w.rotation.y = leg.rotation.y; w.translateZ(0.22); }
      mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.28, 8), toon("#6b7180"), g, 0, 0.2, 0);
      mesh(new RoundedBoxGeometry(0.44, 0.07, 0.42, 2, 0.03), toon(color), g, 0, 0.37, 0);
      mesh(new RoundedBoxGeometry(0.42, exec ? 0.55 : 0.4, 0.06, 2, 0.03), toon(color), g, 0, exec ? 0.72 : 0.64, -0.22);
      [-0.23, 0.23].forEach(s => { mesh(new THREE.BoxGeometry(0.04, 0.12, 0.04), base, g, s, 0.45, 0); mesh(new RoundedBoxGeometry(0.06, 0.03, 0.26, 1, 0.01), toon("#3a3f4a"), g, s, 0.52, 0.02); });
    }
    function plant(x, z, big, kind, potColor = "#b8673e", parent) {
      const g = new THREE.Group(); g.position.set(x, 0, z); (parent || statics).add(g);
      const R = rand(hash("planta" + x + z)), k = kind || pickR(R, ["bush", "tall", "round"]), h = big ? 0.32 : 0.2;
      mesh(new THREE.CylinderGeometry(big ? 0.17 : 0.12, big ? 0.13 : 0.09, h, 10), toon(potColor), g, 0, h / 2, 0);
      mesh(new THREE.CylinderGeometry(big ? 0.18 : 0.13, big ? 0.18 : 0.13, 0.04, 10), toon(tint(potColor, 0.15)), g, 0, h, 0);
      const leaf = toon("#4f9d58"), leaf2 = toon("#3f8a4a"), leaf3 = toon("#6cbf6f");
      if (k === "tall") for (let i = 0; i < 6; i++) { const m = mesh(new THREE.ConeGeometry(0.05, big ? 0.7 : 0.4, 4), i % 2 ? leaf : leaf2, g, Math.sin(i * 1.7) * 0.07, h + (big ? 0.33 : 0.2), Math.cos(i * 1.7) * 0.07); m.rotation.z = Math.sin(i * 2.3) * 0.25; m.rotation.x = Math.cos(i * 2.3) * 0.25; }
      else if (k === "round") { mesh(new THREE.IcosahedronGeometry(big ? 0.3 : 0.18, 1), leaf, g, 0, h + (big ? 0.32 : 0.18), 0); mesh(new THREE.IcosahedronGeometry(big ? 0.18 : 0.1, 1), leaf3, g, -0.06, h + (big ? 0.48 : 0.28), 0.05); }
      else for (let i = 0; i < 5; i++) mesh(new THREE.IcosahedronGeometry((big ? 0.2 : 0.12) * (0.8 + R() * 0.4), 0), [leaf, leaf2, leaf3][i % 3], g, (R() - 0.5) * (big ? 0.3 : 0.18), h + (big ? 0.2 : 0.12) + R() * (big ? 0.4 : 0.2), (R() - 0.5) * (big ? 0.3 : 0.18));
      return g;
    }
    function easel(x, z, w, draw) {
      box(x + 0.06, z, 0, 0.05, 0.05, 1.4, "#5b6070"); box(x + w - 0.11, z, 0, 0.05, 0.05, 1.4, "#5b6070");
      box(x, z - 0.02, 0.45, w, 0.04, 0.9, "#c3c9d4");
      planeZ(x + 0.04, z + 0.021, 0.49, w - 0.08, 0.82, toon("#ffffff", { map: canvasTex(32, 20, draw) }));
      box(x + 0.1, z, 0.42, w - 0.2, 0.12, 0.03, "#9aa2b1");
    }
    const racks = [];
    function rack(x, z) {
      box(x, z, 0, 0.7, 0.8, 1.9, "#2c3140");
      const t = canvasTex(14, 36, () => {}); t.userData.id = racks.length; racks.push(t);
      const m = planeZ(x + 0.05, z + 0.801, 0.05, 0.6, 1.78, toon("#ffffff", { map: t, emissive: "#ffffff", emissiveMap: t, emissiveIntensity: 0.6 }));
      statics.remove(m); live.add(m);
      box(x + 0.05, z + 0.05, 1.9, 0.6, 0.7, 0.04, "#3c4356");
    }
    function drawRack(t, now) {
      const x = t.userData.ctx; P(x, "#232835", 0, 0, 14, 36);
      for (let q = 0; q < 9; q++) { P(x, q % 3 === 2 ? "#3c4356" : "#1a1f2a", 0, q * 4, 14, 3); P(x, "#141820", 1, q * 4 + 1, 6, 1); for (let k = 0; k < 3; k++) { const on = (Math.floor(now * (3 + k)) + q * 7 + k * 3 + t.userData.id) % 5 !== 0; P(x, on ? ["#5cc98a", "#f2c14e", "#4fb0ff"][k] : "#10141c", 9 + k * 2, q * 4 + 1, 1, 1); } }
      t.needsUpdate = true;
    }
    function dbStack(x, z) { [0, 0.3, 0.6].forEach((y, i) => { cyl(x, z, y, 0.32, 0.24, ["#3f6fc6", "#4f80d6", "#6092e6"][i], null, 20); cyl(x, z, y + 0.08, 0.325, 0.03, "#9fc4ff", null, 20); }); }
    function cabinet(x, z, top) {
      box(x, z, 0, 0.6, 0.5, 0.95, "#8a909c");
      for (let k = 0; k < 3; k++) { box(x + 0.04, z + 0.5, 0.05 + k * 0.3, 0.52, 0.01, 0.27, "#9aa1ad"); box(x + 0.22, z + 0.51, 0.2 + k * 0.3, 0.16, 0.02, 0.03, "#c9ced8"); }
      if (top === "binders") ["#cf4b47", "#4a78d6", "#f2c14e"].forEach((c, i) => box(x + 0.08 + i * 0.1, z + 0.12, 0.95, 0.08, 0.28, 0.28, c));
      if (top === "plant") plant(x + 0.3, z + 0.25, false, "round", "#e9e4d8").position.y = 0.95;
      if (top === "jar") { cyl(x + 0.3, z + 0.25, 0.95, 0.12, 0.26, toon("#cfe8f2", { transparent: true, opacity: 0.7 })); cyl(x + 0.3, z + 0.25, 1.21, 0.13, 0.04, "#8a909c"); [[0.25, 1.02], [0.33, 1.1], [0.28, 1.15]].forEach(([a, y]) => mesh(new THREE.SphereGeometry(0.025, 6, 4), toon("#2b2d36"), null, x + a, y, z + 0.25)); }
    }
    function printer(x, z) {
      box(x, z, 0, 0.9, 0.5, 0.55, "#6e4a2f"); box(x + 0.1, z + 0.06, 0.55, 0.7, 0.4, 0.28, "#e9eef5"); box(x + 0.15, z + 0.44, 0.62, 0.5, 0.04, 0.06, "#3a3f4a"); box(x + 0.2, z + 0.28, 0.83, 0.4, 0.14, 0.01, "#ffffff");
      box(x + 0.68, z + 0.46, 0.75, 0.04, 0.01, 0.04, toon("#5cc98a", { emissive: "#5cc98a" }));
    }
    function vending(x, z) {
      box(x, z, 0, 0.9, 0.6, 1.7, "#cf4b47");
      const t = canvasTex(24, 44, c => { P(c, "#cf4b47", 0, 0, 24, 44); P(c, "#1d2433", 2, 4, 15, 34); for (let r = 0; r < 6; r++) { for (let k = 0; k < 4; k++) P(c, ["#f2c14e", "#47a865", "#6fb4e6", "#e17aa8", "#e08a3a"][(r + k) % 5], 3 + k * 4, 6 + r * 5, 2, 3); P(c, "#5b6070", 2, 9 + r * 5, 15, 1); } P(c, "#3a3f4a", 19, 14, 3, 10); P(c, "#5cc98a", 20, 16, 1, 1); P(c, "#16131f", 3, 39, 13, 3); P(c, "#f4f1ea", 2, 0, 20, 3); });
      planeZ(x, z + 0.601, 0, 0.9, 1.7, toon("#ffffff", { map: t }));
    }
    function lockers(x, z, n) {
      box(x, z, 0, n * 0.5, 0.45, 1.6, "#5f86a8");
      const t = canvasTex(12 * n, 40, c => { for (let k = 0; k < n; k++) { P(c, k % 2 ? "#6a92b5" : "#6189ab", k * 12, 0, 12, 40); P(c, "#3f5f7a", k * 12 + 11, 0, 1, 40); for (let v = 0; v < 4; v++) P(c, "#3f5f7a", k * 12 + 3, 3 + v * 2, 6, 1); P(c, "#c9ced8", k * 12 + 9, 18, 1, 4); P(c, "#f4f1ea", k * 12 + 3, 12, 4, 2); } });
      planeZ(x, z + 0.451, 0, n * 0.5, 1.6, toon("#ffffff", { map: t }));
    }
    let boardTex = null;
    function buildFurniture() {
      // Reuniones: mesa del CEO, biblioteca, credenza, sillón y lámpara.
      kay("table_medium_long", 3.75, 3.0, 0, 0.62); chair(3.0, 4.45, "-y", "#5a3e2b", true); chair(4.4, 4.45, "-y", "#5a3e2b", true);
      kay("rug_rectangle_B", 3.75, 3.0, 0, 1.2);
      kay("shelf_B_large_decorated", 0.35, 1.8, Math.PI / 2, 0.75); kay("shelf_B_large_decorated", 0.35, 1.8, Math.PI / 2, 0.75, 0.55);
      box(1.4, 0.1, 0, 2.2, 0.45, 0.65, "#6e4a2f"); for (let k = 0; k < 3; k++) box(1.45 + k * 0.7, 0.55, 0.06, 0.66, 0.01, 0.52, "#7d5432");
      box(3.28, 0.22, 0.65, 0.12, 0.12, 0.3, "#e3b341"); mesh(new THREE.SphereGeometry(0.09, 10, 8), toon("#f2c14e"), null, 3.34, 1.0, 0.28); kay("book_set", 1.8, 0.32, 0, 0.5, 0.65);
      kay("couch_pillows", 6.35, 5.9, -Math.PI / 2, 0.62); kay("table_low", 5.05, 5.9, Math.PI / 2, 0.45); kay("lamp_standing", 6.45, 4.6, 0, 0.62);
      plant(0.45, 6.55, true, "tall"); kay("cactus_medium_A", 6.5, 0.5, 0, 0.6);
      // Diseño, Backend y Frontend.
      easel(7.4, 6.0, 1.6, x => { P(x, "#f6f8fa", 0, 0, 32, 20); [["#ff7eb6", 2], ["#ffd166", 9], ["#06d6a0", 16], ["#118ab2", 23]].forEach(([c, o]) => P(x, c, o, 2, 6, 6)); P(x, "#8a909c", 3, 12, 24, 1); P(x, "#8a909c", 3, 15, 18, 1); });
      kay("armchair_pillows", 9.9, 6.1, Math.PI, 0.5); cabinet(9.65, 0.12, "plant"); printer(10.6, 0.12); kay("rug_rectangle_stripes_A", 10.9, 4.4, 0, 0.9);
      easel(14.4, 5.6, 1.6, x => { P(x, "#f6f8fa", 0, 0, 32, 20); [[2, 3], [20, 3], [11, 12]].forEach(([a, b]) => { P(x, "#dfe9f7", a, b, 9, 5); P(x, "#4a78d6", a + 1, b + 2, 7, 1); }); P(x, "#cf4b47", 11, 5, 9, 1); P(x, "#cf4b47", 15, 6, 1, 6); });
      cabinet(16.65, 0.12, "binders"); printer(17.6, 0.12); kay("rug_rectangle_B", 19.5, 4.4, 0, 0.6);
      easel(21.4, 5.6, 1.6, x => { P(x, "#f6f8fa", 0, 0, 32, 20); P(x, "#4a78d6", 2, 2, 28, 3); P(x, "#e9e4d8", 2, 7, 8, 11); P(x, "#f2c14e", 12, 7, 18, 4); P(x, "#e17aa8", 12, 13, 18, 5); });
      cabinet(23.65, 0.12, "plant"); printer(24.6, 0.12); kay("rug_rectangle_stripes_A", 26.5, 4.4, 0, 0.6);
      // Base de datos, Scraping, DevOps y QA.
      dbStack(0.8, 14.0); dbStack(0.8, 15.4); dbStack(2.0, 15.4); cabinet(4.0, 16.35, "binders"); kay("rug_rectangle_stripes_A", 3.6, 14.6, 0, 0.7);
      cyl(8.0, 14.6, 0, 0.12, 0.45, "#5b6070"); mesh(new THREE.IcosahedronGeometry(0.28, 2), toon("#3f86d0"), null, 8.0, 0.75, 14.6); mesh(new THREE.IcosahedronGeometry(0.285, 1), toon("#5cc98a", { transparent: true, opacity: 0.85 }), null, 8.0, 0.75, 14.6).scale.set(1, 0.6, 0.8);
      cabinet(11.0, 16.35, "plant"); kay("rug_oval_A", 10.6, 14.6, 0, 0.7);
      rack(14.3, 13.4); rack(14.3, 14.4); rack(14.3, 15.4); cabinet(18.0, 16.35, "binders");
      easel(21.4, 15.6, 1.6, x => { P(x, "#f6f8fa", 0, 0, 32, 20); for (let i = 0; i < 4; i++) { P(x, i === 2 ? "#ef6b5b" : "#5cc98a", 2, 2 + i * 4, 3, 3); P(x, "#8a909c", 7, 3 + i * 4, 20 - i * 3, 1); } });
      cabinet(27.2, 13.2, "jar"); kay("rug_rectangle_B", 25.4, 14.6, 0, 0.7);
      R3.forEach(r => { if (r.id !== "meet") plant(r.x + 6.45, r.y + 6.45, true); if (!r.top) plant(r.x + 0.45, r.y + 6.45, false, null, "#e9e4d8"); });
      // Pasillo: café, agua, máquina expendedora, casilleros, plantas, banco y tachos.
      box(26.2, 7.12, 0, 1.6, 0.6, 0.62, "#6e4a2f"); box(26.2, 7.12, 0.62, 1.6, 0.6, 0.04, "#e9e4d8");
      box(26.4, 7.18, 0.66, 0.45, 0.42, 0.55, "#3a3f4a"); box(26.46, 7.6, 0.85, 0.33, 0.01, 0.25, "#1d2028"); box(26.7, 7.6, 1.12, 0.04, 0.01, 0.04, toon("#ef6b5b", { emissive: "#ef6b5b" }));
      ["#e9e4d8", "#cf4b47", "#4a78d6"].forEach((c, i) => cyl(27.1 + i * 0.2, 7.4, 0.66, 0.05, 0.12, c));
      box(1.0, 7.3, 0, 0.4, 0.4, 0.75, "#e9eef5"); cyl(1.2, 7.5, 0.75, 0.16, 0.5, toon("#8fc8f0", { transparent: true, opacity: 0.85 })); cyl(0.32, 7.27, 0, 0.08, 0.42, "#cf4b47");
      vending(5.9, 7.12); lockers(12.6, 9.42, 4);
      [[9.3, 7.5], [16.3, 7.5], [22.3, 7.5], [2.0, 9.5], [9.0, 9.5], [23.0, 9.5]].forEach(([x, z]) => plant(x, z, true, null, "#e9e4d8"));
      box(5.7, 9.4, 0, 0.06, 0.35, 0.25, "#3a3f4a"); box(7.04, 9.4, 0, 0.06, 0.35, 0.25, "#3a3f4a"); box(5.6, 9.3, 0.25, 1.6, 0.5, 0.06, "#b07a4a"); box(5.6, 9.72, 0.31, 1.6, 0.08, 0.35, "#b07a4a");
      [["#4a78d6", 0], ["#47a865", 0.34], ["#e3c14a", 0.68]].forEach(([c, o]) => { box(26.4 + o, 9.38, 0, 0.3, 0.38, 0.55, c); box(26.39 + o, 9.37, 0.55, 0.32, 0.4, 0.05, tint(c, -0.15)); });
      // Tablero del ticket.
      box(19.75, 9.42, 0, 0.06, 0.06, 1.6, "#5b6070"); box(21.55, 9.42, 0, 0.06, 0.06, 1.6, "#5b6070"); box(19.6, 9.4, 0.62, 2.2, 0.06, 0.95, "#6e4a2f");
      boardTex = canvasTex(64, 28, () => {});
      planeZ(19.65, 9.461, 0.66, 2.1, 0.87, toon("#ffffff", { map: boardTex }));
    }
    let boardKey = "";
    function drawBoard3() {
      const b = boardInfo(), key = JSON.stringify([b.ticket, b.branch, b.lights.map(l => l.color), b.prText]);
      if (key === boardKey) return;
      boardKey = key;
      const x = boardTex.userData.ctx;
      P(x, "#f6f1e8", 0, 0, 64, 28); P(x, "#3a3f4a", 0, 0, 64, 8);
      x.fillStyle = "#f2e6c9"; x.font = "bold 7px monospace"; x.fillText(String(b.ticket || "Sin ticket").slice(0, 14), 3, 7);
      x.fillStyle = "#3a3f4a"; x.font = "6px monospace"; x.fillText(String(b.branch || "").slice(0, 20), 3, 16);
      b.lights.forEach((l, i) => { P(x, "#3a3f4a", 2 + i * 20, 20, 7, 7); P(x, l.color, 3 + i * 20, 21, 5, 5); x.font = "5px monospace"; x.fillText(l.label === "PR" ? String(b.prText).slice(0, 6) : l.label, 11 + i * 20, 26); });
      boardTex.needsUpdate = true;
    }

    // Lo de cada puesto va en su grupo: si el puesto no se usa (líder sin modo equipos,
    // departamento sin instalar), no se ve. La pizza y la torta aparecen sobre el escritorio.
    const seatGroups = {};
    const SCREEN_BY_ROOM = { back: "code", front: "ui", db: "data", scrap: "web", ops: "term", qa: "test", design: "design", meet: "code" };
    function buildSeats() {
      Object.entries(SEAT).forEach(([id, s]) => {
        const g = new THREE.Group(); scene.add(g); seatGroups[id] = { g, pizza: null, cake: null };
        const a = id === "pm" ? null : agent(id), role = a ? a.role || "" : "";
        const color = id === "ceo" ? "#7a1f2b" : s.room === "meet" && id !== "pm" ? "#5a3e2b" : pickR(rand(hash(id)), ["#3b4252", "#2f4a6b", "#4a3b5a", "#2f5a4a"]);
        chair(s.x, s.y, s.facing, color, s.room === "meet" && id !== "pm", g);
        let top = null;
        if (s.facing === "-y") {
          desk(s.x - 1, s.y - 1.3, 2, 0.8, g);
          const dual = s.room === "front" || s.room === "design";
          monitor(s.x - 0.15, s.y - 1.1, /tester$|^qa$/.test(role) ? "test" : SCREEN_BY_ROOM[s.room], dual, id, g);
          box(s.x - 0.9, s.y - 0.82, DESK_H, 0.28, 0.2, 0.02, "#f4f1ea", g);
          if (/developer$/.test(role)) { mesh(new THREE.SphereGeometry(0.06, 8, 6), toon("#f2d024"), g, s.x - 0.55, DESK_H + 0.06, s.y - 0.7); mesh(new THREE.SphereGeometry(0.045, 8, 6), toon("#f2d024"), g, s.x - 0.52, DESK_H + 0.13, s.y - 0.68); }
          if (!dual) { if (rand(hash("cosas" + id))() < 0.6) kay("lamp_table", s.x + 0.72, s.y - 1.1, 0, 0.3, DESK_H, g); else plant(s.x + 0.72, s.y - 1.05, false, "round", "#e9e4d8", g).position.y = DESK_H; }
          top = { x: s.x + 0.35, z: s.y - 0.8 };
        } else if (s.facing === "+x") {
          desk(s.x + 0.35, s.y - 0.8, 0.8, 1.6, g); laptop(s.x + 0.72, s.y, id, g); box(s.x + 0.45, s.y + 0.35, DESK_H, 0.28, 0.2, 0.02, "#f4f1ea", g);
          top = { x: s.x + 0.75, z: s.y + 0.5 };
        } else top = { x: s.x + 0.3, z: s.y + 0.95, y: 0.62 };
        const pz = new THREE.Group(); box(-0.18, -0.18, 0, 0.36, 0.36, 0.06, "#e9d29a", pz); box(-0.11, 0.181, 0.015, 0.22, 0.005, 0.03, "#cf4b47", pz); pz.position.set(top.x, top.y || DESK_H, top.z); pz.visible = false; scene.add(pz); seatGroups[id].pizza = pz;
        const ck = new THREE.Group(); cyl(0, 0, 0, 0.16, 0.1, "#f4e1c8", ck); cyl(0, 0, 0.1, 0.12, 0.08, "#e17aa8", ck); cyl(0, 0, 0.18, 0.012, 0.08, "#f2c14e", ck); mesh(new THREE.SphereGeometry(0.02, 6, 4), toon("#ffb347", { emissive: "#ff9a3c" }), ck, 0, 0.28, 0);
        ck.position.set(top.x - 0.25, top.y || DESK_H, top.z); ck.visible = false; scene.add(ck); seatGroups[id].cake = ck;
      });
    }
    // Oscurece las oficinas cuyo departamento no está instalado.
    const shades = {};
    function buildShades() { R3.forEach(r => { const m = new THREE.Mesh(new THREE.BoxGeometry(7, 2.2, 7), new THREE.MeshBasicMaterial({ color: "#0b0e14", transparent: true, opacity: 0.6, depthWrite: false })); m.position.set(r.x + 3.5, 1.1, r.y + 3.5); m.visible = false; scene.add(m); shades[r.id] = m; }); }

    // Junta lo fijo en pocos dibujos (mismo material, una sola geometría).
    function bake(group) {
      group.updateMatrixWorld(true);
      const byMat = new Map(), keep = [];
      group.traverse(o => {
        if (!o.isMesh) return;
        const m = Array.isArray(o.material) ? null : o.material;
        if (!m || m.transparent) { keep.push(o); return; }
        const src = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
        src.applyMatrix4(o.matrixWorld);
        const n = src.attributes.position.count, geo = new THREE.BufferGeometry();
        [["position", 3], ["normal", 3], ["uv", 2]].forEach(([a, k]) => {
          const at = src.attributes[a], arr = new Float32Array(n * k);
          if (at) for (let i = 0; i < n; i++) { arr[i * k] = at.getX(i); arr[i * k + 1] = at.getY(i); if (k === 3) arr[i * k + 2] = at.getZ(i); }
          geo.setAttribute(a, new THREE.BufferAttribute(arr, k));
        });
        if (!byMat.has(m)) byMat.set(m, []);
        byMat.get(m).push(geo);
      });
      const out = new THREE.Group();
      byMat.forEach((geos, m) => { const g = mergeGeometries(geos, false); if (!g) return; const o = new THREE.Mesh(g, m); o.castShadow = o.receiveShadow = true; out.add(o); });
      keep.forEach(o => { const c = o.clone(); c.matrixAutoUpdate = false; c.matrix.copy(o.matrixWorld); out.add(c); });
      return out;
    }

    // --- Personajes chibi ---
    const SKINS = ["#f6d5b8", "#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#5c3a21"];
    const HAIRS = ["#2b1d14", "#5a3825", "#a0522d", "#d9b26b", "#1d1a26", "#8a8f99", "#b8452f", "#3b2b4f"];
    const STYLES = ["short", "long", "bun", "curly", "spiky", "ponytail", "bob", "short", "long", "slick"];
    const EYES = ["#3a2a22", "#3a5f9f", "#2f6f45", "#5a3825"];
    const OUTFIT = {
      developer: { outfit: "hoodie", phones: "#ef6b5b", shoes: "#e9e4d8" }, tester: { outfit: "tee", print: "#f2c14e", badge: "#2f7a47" },
      lead: { outfit: "shirt", badge: "#1f6f63" }, architect: { outfit: "shirt", glasses: true }, designer: { outfit: "tee", print: "#06d6a0", shoes: "#f2c14e" },
      qa: { outfit: "coat", badge: "#6a4fb0" }, ceo: { outfit: "suit", tie: "#7a1f2b" }, adv: { outfit: "shirt", glasses: true }, pm: { outfit: "suit", tie: "#f2c14e" }, courier: { outfit: "tee", print: "#f2c14e" },
    };
    const SHIRT = { blue: "#4a78d6", green: "#47a865", teal: "#2f9e8f", cyan: "#3fb6c9", pink: "#e17aa8", red: "#8b6cd6", gold: "#c99a2e", purple: "#7a5cc0", yellow: "#d9b443", orange: "#e08a3a" };
    const kindOf = p => p.id === "pm" ? "pm" : p.id === "ceo" ? "ceo" : p.id === "adv" ? "adv" : p.id === "courier" ? "courier" : p.role === "qa" ? "qa" : (p.role || "").split(".")[1] || "developer";
    function lookOf(p) {
      const R = rand(hash(p.id + "look")), k = kindOf(p), o = OUTFIT[k] || OUTFIT.developer;
      const L = Object.assign({ skin: pickR(R, SKINS), hair: pickR(R, HAIRS), style: pickR(R, STYLES), eyes: pickR(R, EYES), beard: R() < 0.2,
        pants: pickR(R, ["#2f3a55", "#3a3f4a", "#5a4632", "#27303f", "#4a5a7a"]), shoes: pickR(R, ["#2b2d36", "#5a3825", "#3a3f4a"]),
        shirt: k === "pm" ? "#5b3fa0" : k === "courier" ? "#cf4b47" : SHIRT[p.color] || "#4a78d6" }, o);
      if (k === "pm") Object.assign(L, { style: "slick", hair: "#2b1d14", skin: "#f1c27d", pants: "#3a2a5a", beard: false, shoes: "#2b2d36" });
      if (k === "ceo") Object.assign(L, { style: "bald", hair: "#8a8f99", pants: "#2b2d36", beard: true, shoes: "#2b2d36" });
      if (k === "courier") Object.assign(L, { style: "short", pants: "#2b2d36", beard: false, cap: "#cf4b47" });
      return L;
    }
    function faceTex(L, st) {
      return canvasTex(16, 16, x => {
        if (st === "blink") { P(x, "#3a2632", 4, 8, 3, 1); P(x, "#3a2632", 9, 8, 3, 1); }
        else [4, 9].forEach(ex => { P(x, "#2b1d26", ex, 6, 3, 1); P(x, "#ffffff", ex, 7, 3, 3); P(x, L.eyes, ex + 1, 7, 2, 3); P(x, "#141018", ex + 1, 8, 1, 1); P(x, "#ffffff", ex + 1, 7, 1, 1); });
        P(x, tint(L.hair, -0.3), 4, 4, 3, 1); P(x, tint(L.hair, -0.3), 9, 4, 3, 1); P(x, "#f08f8f", 2, 11, 2, 1); P(x, "#f08f8f", 12, 11, 2, 1);
        if (st === "talk") { P(x, "#5a1f2a", 7, 11, 3, 3); P(x, "#ffffff", 7, 11, 3, 1); P(x, "#e07a86", 8, 13, 1, 1); }
        else { P(x, "#9a3f3f", 7, 12, 3, 1); P(x, "#9a3f3f", 6, 11, 1, 1); P(x, "#9a3f3f", 10, 11, 1, 1); }
        if (L.beard) { P(x, L.hair, 2, 12, 2, 3); P(x, L.hair, 12, 12, 2, 3); P(x, L.hair, 3, 14, 10, 2); P(x, L.hair, 6, 10, 5, 1); P(x, st === "talk" ? "#5a1f2a" : "#9a3f3f", 7, 12, 3, 1); }
        if (L.glasses) [3, 8].forEach(gx => { P(x, "#2b2238", gx, 6, 5, 1); P(x, "#2b2238", gx, 10, 5, 1); P(x, "#2b2238", gx, 6, 1, 5); P(x, "#2b2238", gx + 4, 6, 1, 5); });
      });
    }
    function shirtTex(L) {
      return canvasTex(16, 16, x => {
        const o = L.outfit, s = L.shirt;
        if (o === "tee") { P(x, tint(s, -0.2), 5, 0, 6, 1); P(x, tint(s, 0.2), 5, 5, 6, 5); P(x, L.print, 6, 6, 4, 3); }
        if (o === "hoodie") { P(x, "#efe9dc", 6, 1, 1, 5); P(x, "#efe9dc", 9, 1, 1, 4); P(x, tint(s, -0.2), 3, 10, 10, 5); P(x, tint(s, -0.35), 3, 10, 10, 1); }
        if (o === "shirt") { P(x, tint(s, 0.25), 4, 0, 3, 2); P(x, tint(s, 0.25), 9, 0, 3, 2); P(x, tint(s, -0.2), 8, 2, 1, 14); [4, 7, 10, 13].forEach(y => P(x, "#f4f1ea", 8, y, 1, 1)); P(x, tint(s, -0.18), 2, 4, 3, 3); }
        if (o === "suit") { for (let i = 0; i < 7; i++) P(x, "#f4f1ea", 5 + Math.floor(i / 2), i, 6 - 2 * Math.floor(i / 2), 1); P(x, L.tie, 7, 0, 2, 2); P(x, L.tie, 7, 2, 2, 8); P(x, tint(L.tie, -0.3), 8, 2, 1, 8); P(x, tint(s, -0.3), 4, 0, 1, 8); P(x, tint(s, -0.3), 11, 0, 1, 8); P(x, "#f4f1ea", 11, 4, 2, 1); }
        if (o === "coat") { for (let i = 0; i < 6; i++) P(x, s, 5 + Math.floor(i / 2), i, 6 - 2 * Math.floor(i / 2), 1); P(x, "#cfd4da", 4, 0, 1, 14); P(x, "#cfd4da", 11, 0, 1, 14); P(x, "#dfe3e8", 11, 8, 3, 3); P(x, "#4a78d6", 12, 6, 1, 3); P(x, "#cf4b47", 13, 6, 1, 3); }
        if (L.badge && o !== "hoodie") { P(x, L.badge, 4, 1, 1, 5); P(x, "#f4f1ea", 3, 6, 4, 5); P(x, L.badge, 3, 6, 4, 2); }
      });
    }
    function hairMeshes(L, head, mat) {
      const s = L.style, add = (geo, x, y, z) => mesh(geo, mat, head, x, y, z), RB = (w, h, d, r) => new RoundedBoxGeometry(w, h, d, 2, r);
      if (s === "bald") { add(RB(0.08, 0.14, 0.26, 0.03), -0.24, 0.2, -0.04); add(RB(0.08, 0.14, 0.26, 0.03), 0.24, 0.2, -0.04); add(RB(0.44, 0.1, 0.08, 0.03), 0, 0.17, -0.21); return; }
      if (s === "curly") { const R = rand(hash(L.hair + "rulos")); for (let i = 0; i < 16; i++) { const a = R() * Math.PI * 2, b = R() * 0.9; add(new THREE.IcosahedronGeometry(0.1, 0), Math.cos(a) * 0.2 * (1 - b * 0.3), 0.34 + b * 0.12, Math.sin(a) * 0.2 - 0.03 - (Math.sin(a) > 0.4 ? 0.06 : 0)); } add(RB(0.5, 0.26, 0.2, 0.08), 0, 0.22, -0.16); return; }
      add(RB(0.5, 0.17, 0.47, 0.08), 0, 0.4, -0.01); add(RB(0.49, 0.3, 0.14, 0.06), 0, 0.27, -0.17);
      if (s === "slick") { add(RB(0.46, 0.05, 0.08, 0.02), 0, 0.33, 0.2); return; }
      add(RB(0.46, 0.08, 0.08, 0.03), 0.03, 0.34, 0.2); add(RB(0.07, 0.16, 0.2, 0.03), -0.23, 0.29, 0.06); add(RB(0.07, 0.16, 0.2, 0.03), 0.23, 0.29, 0.06);
      if (s === "spiky") for (let i = 0; i < 5; i++) { const c = add(new THREE.ConeGeometry(0.07, 0.16, 5), -0.16 + i * 0.08, 0.53, -0.04 + (i % 2) * 0.06); c.rotation.z = (i - 2) * 0.2; }
      if (s === "bun") add(new THREE.SphereGeometry(0.12, 10, 8), 0, 0.52, -0.14);
      if (s === "ponytail") { const t = add(new THREE.CapsuleGeometry(0.065, 0.22, 4, 8), 0, 0.2, -0.27); t.rotation.x = 0.35; }
      if (s === "long") { add(RB(0.48, 0.42, 0.1, 0.04), 0, 0.08, -0.2); add(RB(0.07, 0.36, 0.14, 0.03), -0.235, 0.12, 0.02); add(RB(0.07, 0.36, 0.14, 0.03), 0.235, 0.12, 0.02); }
      if (s === "bob") { add(RB(0.07, 0.3, 0.3, 0.03), -0.24, 0.16, 0); add(RB(0.07, 0.3, 0.3, 0.03), 0.24, 0.16, 0); add(RB(0.48, 0.3, 0.1, 0.04), 0, 0.14, -0.2); }
    }
    function makePerson(p) {
      const L = lookOf(p), root = new THREE.Group(); live.add(root);
      const body = new THREE.Group(); root.add(body);
      const skin = toon(L.skin), top = toon(L.outfit === "coat" ? "#eef0f2" : L.shirt), pants = toon(L.pants), shoes = toon(L.shoes), hair = toon(L.hair);
      const legs = [-0.085, 0.085].map(sx => {
        const hip = new THREE.Group(); hip.position.set(sx, 0.45, 0); body.add(hip);
        mesh(new THREE.CapsuleGeometry(0.075, 0.1, 4, 8), pants, hip, 0, -0.1, 0);
        const knee = new THREE.Group(); knee.position.y = -0.21; hip.add(knee);
        mesh(new THREE.CapsuleGeometry(0.07, 0.08, 4, 8), pants, knee, 0, -0.08, 0); mesh(new RoundedBoxGeometry(0.15, 0.08, 0.22, 2, 0.035), shoes, knee, 0, -0.2, 0.035);
        return { hip, knee };
      });
      const torso = new THREE.Group(); torso.position.y = 0.42; body.add(torso);
      mesh(new RoundedBoxGeometry(0.38, 0.4, 0.25, 2, 0.08), top, torso, 0, 0.2, 0);
      mesh(new THREE.PlaneGeometry(0.3, 0.32), toon("#ffffff", { map: shirtTex(L), transparent: true, alphaTest: 0.5 }), torso, 0, 0.2, 0.1255).castShadow = false;
      if (L.outfit === "coat") mesh(new RoundedBoxGeometry(0.39, 0.2, 0.26, 2, 0.05), top, torso, 0, -0.04, 0);
      if (L.outfit === "hoodie") mesh(new RoundedBoxGeometry(0.3, 0.08, 0.14, 2, 0.04), toon(tint(L.shirt, -0.15)), torso, 0, 0.4, -0.08);
      const sleeve = L.outfit === "tee" ? skin : top;
      const arms = [-1, 1].map(s => {
        const sh = new THREE.Group(); sh.position.set(s * 0.235, 0.34, 0); torso.add(sh);
        mesh(new THREE.CapsuleGeometry(0.06, 0.18, 4, 8), sleeve, sh, 0, -0.13, 0);
        if (L.outfit === "tee") mesh(new THREE.CapsuleGeometry(0.068, 0.04, 4, 8), top, sh, 0, -0.03, 0);
        mesh(new THREE.SphereGeometry(0.062, 8, 6), skin, sh, 0, -0.29, 0);
        return sh;
      });
      const head = new THREE.Group(); head.position.y = 0.84; body.add(head);
      mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.06, 8), skin, head, 0, 0, 0); mesh(new RoundedBoxGeometry(0.46, 0.42, 0.42, 3, 0.14), skin, head, 0, 0.22, 0);
      [-1, 1].forEach(s => mesh(new THREE.SphereGeometry(0.05, 8, 6), skin, head, s * 0.235, 0.2, 0));
      const faces = { open: faceTex(L, "open"), blink: faceTex(L, "blink"), talk: faceTex(L, "talk") };
      const faceMat = toon("#ffffff", { map: faces.open, transparent: true, alphaTest: 0.5 });
      mesh(new THREE.PlaneGeometry(0.38, 0.38), faceMat, head, 0, 0.2, 0.2115).castShadow = false;
      hairMeshes(L, head, hair);
      if (L.phones) { const band = mesh(new THREE.TorusGeometry(0.255, 0.025, 6, 16, Math.PI), toon("#2b2d36"), head, 0, 0.28, 0); band.rotation.y = Math.PI / 2; [-1, 1].forEach(s => { mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.06, 12), toon(L.phones), head, s * 0.25, 0.22, 0).rotation.z = Math.PI / 2; }); }
      if (L.cap) { mesh(new RoundedBoxGeometry(0.5, 0.12, 0.48, 2, 0.05), toon(L.cap), head, 0, 0.47, 0); mesh(new THREE.BoxGeometry(0.3, 0.03, 0.18), toon(L.cap), head, 0, 0.42, 0.28); }
      const cup = new THREE.Group(); cyl(0, 0, 0, 0.05, 0.1, "#f4f1ea", cup); cyl(0, 0, 0.09, 0.042, 0.012, "#6e4a2f", cup); cup.position.set(0.02, -0.34, 0.05); arms[1].add(cup);
      const clip = new THREE.Group(); box(-0.11, -0.01, 0, 0.22, 0.02, 0.28, "#b8875a", clip); box(-0.09, 0.006, 0.02, 0.18, 0.01, 0.22, "#f6f2e7", clip); clip.position.set(-0.04, -0.42, 0.1); clip.rotation.x = -0.5; arms[0].add(clip);
      const pizza = new THREE.Group(); box(-0.2, -0.2, 0, 0.4, 0.4, 0.06, "#e9d29a", pizza); box(-0.12, 0.201, 0.02, 0.24, 0.005, 0.03, "#cf4b47", pizza); pizza.position.set(0, 0.18, 0.32); torso.add(pizza);
      const ring = new THREE.Mesh(new THREE.RingGeometry(0.3, 0.38, 24), basic({ color: "#f2c14e", transparent: true, opacity: 0.85, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.02; root.add(ring);
      return { root, body, legs, arms, head, faces, faceMat, cup, clip, pizza, ring, look: L };
    }

    // --- Nombres: al azar por sesión; el CEO es el dueño del ticket ---
    const NAMES = ["Lucía", "Mateo", "Valentina", "Martín", "Camila", "Julián", "Sofía", "Tomás", "Martina", "Nicolás", "Agustina", "Lucas", "Paula", "Diego", "Florencia", "Gabriel",
      "Renata", "Bruno", "Carla", "Ignacio", "Elena", "Facundo", "Abril", "Simón", "Julia", "Andrés", "Mía", "Joaquín", "Rocío", "Emilio", "Clara", "Santiago", "Olivia", "Franco", "Inés", "Ramiro"];
    let namesKey = "", names = {};
    function nameOf(id) {
      const key = mode === "live" ? String(state.liveSession || "") : "demo:" + state.demoRun;
      if (key !== namesKey) {
        namesKey = key; names = {};
        const R = rand(hash(key)), list = NAMES.slice().sort(() => R() - 0.5);
        ["pm", ...AGENTS.map(a => a.id)].forEach((k, i) => { names[k] = list[i % list.length]; });
      }
      if (id === "ceo") { const user = mode === "live" && state.live && state.live.sess && state.live.sess.user; if (user) return String(user).split(/\s+/)[0]; }
      return names[id] || null;
    }

    // --- Movimiento: cada persona en 3D sigue a su par del estado ---
    const people3 = {};
    const SPEED3 = 2.8;
    function route3(a, b) {
      const ra = roomAt3(a), rb = roomAt3(b), pts = [];
      if (ra && ra === rb) { pts.push({ x: a.x, y: ra.y + ra.corr }, { x: b.x, y: ra.y + ra.corr }, b); return pts; }
      if (ra) pts.push({ x: a.x, y: ra.y + ra.corr }, { x: ra.x + 4, y: ra.y + ra.corr }, { x: ra.x + 4, y: 8.45 }); else pts.push({ x: a.x, y: 8.45 });
      if (rb) pts.push({ x: rb.x + 4, y: 8.45 }, { x: rb.x + 4, y: rb.y + rb.corr }, { x: b.x, y: rb.y + rb.corr }, b); else pts.push({ x: b.x, y: 8.45 }, b);
      return pts;
    }
    const posOf3 = id => people3[id] ? { x: people3[id].x, y: people3[id].y } : SEAT[id] || SPOT.exit;
    // Dónde se para alguien que viene a hablarle a otro: al lado si está parado, detrás si mira
    // su pantalla, enfrente si usa notebook; al CEO se le habla desde la cabecera de la mesa.
    function spotNear(id, fromId) {
      if (id === "ceo") return SPOT.ceo;
      const q = people3[id];
      if (q && !q.seated && q.visible) { const side = posOf3(fromId).x < q.x ? -0.7 : 0.7; return { x: q.x + side, y: q.y, f: side < 0 ? "+x" : "-x" }; }
      const s = SEAT[id];
      if (!s) return SPOT.exit;
      if (s.facing === "+x") return { x: s.x + 1.45, y: s.y, f: "-x" };
      if (s.facing === "+y") return SPOT.ceo;
      return { x: s.x, y: r3(s.room).y + r3(s.room).corr, f: "-y" };
    }
    // Lo que el estado dice que está haciendo cada uno, traducido a un lugar de la oficina 3D.
    function targetOf(p, k) {
      if (k === "pm") {
        const d = state.pm.dest, t = d && d.target;
        if (!t || t === "ceo" || t === "door") return { key: "seat", pt: SEAT.pm, sit: true };
        return { key: "visit:" + t, pt: spotNear(t, "pm"), face: t };
      }
      if (k === "courier") {
        const c = state.courier, act = c && c.acts[0];
        if (act && act.k === "go" && act.to.visit) return { key: "visit:" + act.to.visit, pt: spotNear(act.to.visit, "courier"), face: act.to.visit };
        if (act && act.k === "go") return { key: "exit", pt: SPOT.exit };
        return null;
      }
      const act = p.acts && p.acts[0];
      if (!p.pos && !(act && (act.k === "go" || act.k === "home"))) return { key: "seat", pt: SEAT[k], sit: true };
      if (act && act.k === "home") return { key: "seat", pt: SEAT[k], sit: true };
      if (act && act.k === "go") {
        const to = act.to;
        if (to.visit) return { key: "visit:" + to.visit, pt: spotNear(to.visit, k), face: to.visit };
        if (to.coffee) return { key: "coffee", pt: posOf3(k).x < 14 ? SPOT.cooler : SPOT.coffee };
        if (to.debate !== undefined) return { key: "debate" + to.debate, pt: SPOT["debate" + to.debate] };
        if (to.spot) { const pt = to.spot === "window" || to.spot === "printer" ? roomSpot(p.room, to.spot) : SPOT[to.spot]; if (pt) return { key: "spot:" + to.spot, pt }; }
        if (to.x !== undefined) { const pt = from2d(to); return { key: "xy:" + Math.round(pt.x * 4) + ":" + Math.round(pt.y * 4), pt }; }
      }
      return null; // charla, espera o pose: se queda donde está
    }
    // Un punto de la vista clásica (en píxeles) llevado a la 3D: las puertas y el pasillo coinciden.
    function from2d(p) {
      const col = Math.max(0, Math.min(3, Math.floor(p.x / 192))), lx = p.x - col * 192, x = col * 7 + (lx < 96 ? lx / 96 * 4 : 4 + (lx - 96) / 96 * 3);
      const y = p.y < 184 ? Math.max(0.3, (p.y - 4) / 180 * 7) : p.y < 264 ? 7 + (p.y - 184) / 80 * 3 : 10 + Math.min(6.7, (p.y - 264) / 180 * 7);
      return { x: Math.max(0.3, Math.min(27.7, x)), y: Math.min(16.7, y), f: p.y >= 184 && p.y < 264 ? "-y" : undefined };
    }
    const facingTo = (from, to) => { const dx = to.x - from.x, dy = to.y - from.y; return Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "+x" : "-x") : (dy > 0 ? "+y" : "-y"); };
    function syncPerson(k, p, dt) {
      let q = people3[k];
      if (!q) { const s = SEAT[k] || SPOT.exit; q = people3[k] = { id: k, x: s.x, y: s.y, facing: s.facing || s.f || "+y", path: [], key: null, seated: !!SEAT[k], visible: true, m: makePerson(p) }; }
      const present = k === "courier" ? !!state.courier : k === "pm" ? true : p.present !== false;
      if (!present) { q.visible = false; if (k === "courier") { Object.assign(q, { x: SPOT.exit.x, y: SPOT.exit.y, path: [], key: null }); } return q; }
      if (!q.visible && k !== "courier") { const s = SEAT[k]; Object.assign(q, { x: s.x, y: s.y, facing: s.facing, seated: true, key: "seat", path: [] }); }
      q.visible = true;
      const t = targetOf(p, k);
      if (t && t.key !== q.key) {
        q.key = t.key; q.goal = t; q.seated = false;
        q.path = route3({ x: q.x, y: q.y }, t.pt);
      }
      if (q.path.length && reduced) { const end = q.path[q.path.length - 1]; q.x = end.x; q.y = end.y; q.path = [end]; }
      if (q.path.length) {
        const pt = q.path[0], dx = pt.x - q.x, dy = pt.y - q.y, dist = Math.hypot(dx, dy), done = !(p.path && p.path.length) && !(p.acts && p.acts[0] && p.acts[0].k === "go");
        const step = SPEED3 * (done ? 1.8 : 1) * dt;
        if (dist > 0.01) q.facing = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "+x" : "-x") : (dy > 0 ? "+y" : "-y");
        if (dist <= step) { q.x = pt.x; q.y = pt.y; q.path.shift(); } else { q.x += dx / dist * step; q.y += dy / dist * step; }
        if (!q.path.length && q.goal) {
          if (q.goal.sit) { q.seated = true; q.facing = q.goal.pt.facing; }
          else if (q.goal.face) q.facing = facingTo(q, posOf3(q.goal.face));
          else if (q.goal.pt.f) q.facing = q.goal.pt.f;
        }
      }
      // Cuando le hablan o habla en una charla, mira al otro.
      const act = p.acts && p.acts[0];
      if (!q.path.length && !q.seated && act && act.k === "talk" && people3[act.with]) q.facing = facingTo(q, people3[act.with]);
      return q;
    }
    function animate(q, p, now) {
      const m = q.m, walking = q.path.length > 0, sit = !walking && q.seated, working = p.status === "working";
      const inStall = /^stall/.test(p.doing || "");
      m.root.visible = q.visible && !inStall; if (!m.root.visible) return;
      m.root.position.set(q.x, 0, q.y);
      let d = FACE[q.facing] - m.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); m.root.rotation.y += d * 0.3;
      if (reduced) now = Math.floor(now / 5) * 5;
      const ph = now * 9 + q.x * 3, s = reduced ? 0 : Math.sin(ph), pose = p.pose && p.pose.kind;
      if (walking) {
        m.legs[0].hip.rotation.x = s * 0.55; m.legs[1].hip.rotation.x = -s * 0.55; m.legs[0].knee.rotation.x = Math.max(0, -s) * 0.6; m.legs[1].knee.rotation.x = Math.max(0, s) * 0.6;
        m.arms[0].rotation.x = -s * 0.5; m.arms[1].rotation.x = s * 0.5; m.arms[0].rotation.z = -0.08; m.arms[1].rotation.z = 0.08; m.body.position.y = Math.abs(Math.cos(ph)) * 0.035;
      } else if (sit) {
        m.legs.forEach(l => { l.hip.rotation.x = -Math.PI / 2; l.knee.rotation.x = Math.PI / 2; }); m.body.position.y = 0;
        if (pose === "celebrate") { m.arms[0].rotation.x = m.arms[1].rotation.x = -2.9 + Math.sin(now * 10) * 0.2; }
        else if (pose === "stretch") { m.arms[0].rotation.x = m.arms[1].rotation.x = -3.0; }
        else if (pose === "scratch") { m.arms[0].rotation.x = -0.3; m.arms[1].rotation.x = -2.6 + Math.sin(now * 12) * 0.15; }
        else if (working) { const t = Math.sin(now * 14 + q.x * 5) * 0.08; m.arms[0].rotation.x = -1.15 + t; m.arms[1].rotation.x = -1.15 - t; }
        else { m.arms[0].rotation.x = m.arms[1].rotation.x = -0.7; }
        m.arms[0].rotation.z = m.arms[1].rotation.z = 0;
      } else {
        m.legs.forEach(l => { l.hip.rotation.x = 0; l.knee.rotation.x = 0; });
        m.arms[0].rotation.x = p.prop === "clip" || q.id === "pm" ? -0.5 : 0; m.arms[1].rotation.x = p.prop === "cup" ? -0.7 : 0; m.arms[0].rotation.z = -0.06; m.arms[1].rotation.z = 0.06;
        if (pose === "celebrate") { m.arms[0].rotation.x = m.arms[1].rotation.x = -2.9 + Math.sin(now * 10) * 0.2; m.body.position.y = Math.abs(Math.sin(now * 8)) * 0.08; }
        else if (p.doing === "wash") { const t = Math.sin(now * 12) * 0.12; m.arms[0].rotation.x = -1.0 + t; m.arms[1].rotation.x = -1.0 - t; }
        else m.body.position.y = Math.sin(now * 2 + q.x) * 0.006;
      }
      if (p.prop === "pizza") m.arms[0].rotation.x = m.arms[1].rotation.x = -1.3;
      const say = p.say;
      if (say && say.text !== q.sayText) { q.sayText = say.text; q.sayAt = now; }
      if (!say) q.sayText = null;
      m.head.rotation.z = say && !walking ? Math.sin(now * 3) * 0.04 : 0;
      const talk = say && now - q.sayAt < 1.4 && Math.floor(now * 7) % 2, blink = (now + q.x * 1.7) % 4.2 < 0.13;
      const tex = talk ? m.faces.talk : blink ? m.faces.blink : m.faces.open;
      if (m.faceMat.map !== tex) { m.faceMat.map = tex; m.faceMat.needsUpdate = true; }
      m.cup.visible = p.prop === "cup"; m.clip.visible = q.id === "pm" && !sit; m.pizza.visible = p.prop === "pizza";
      m.ring.visible = state.selected === q.id;
    }

    // --- Mascotas: la que sale a pasear en la vista clásica también pasea acá ---
    const pets = {};
    function petMesh(it) {
      const k = it.kind.k, key = it.id;
      if (pets[key]) return pets[key];
      const g = new THREE.Group(), body = new THREE.Group(); g.add(body); live.add(g);
      if (k === "robot") {
        const c = it.v[0].c;
        mesh(new RoundedBoxGeometry(0.24, 0.2, 0.2, 2, 0.04), toon(c), body, 0, 0.18, 0); mesh(new RoundedBoxGeometry(0.18, 0.14, 0.16, 2, 0.04), toon("#c9ced8"), body, 0, 0.35, 0);
        [-0.04, 0.04].forEach(x => mesh(new THREE.SphereGeometry(0.02, 6, 4), toon("#4ff0ff", { emissive: "#4ff0ff" }), body, x, 0.36, 0.08));
        mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.08, 4), toon("#3a3f4a"), body, 0, 0.46, 0); mesh(new THREE.SphereGeometry(0.02, 6, 4), toon("#ef6b5b", { emissive: "#ef6b5b" }), body, 0, 0.5, 0);
        [-0.1, 0.1].forEach(x => mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.04, 10), toon("#3a3f4a"), body, x, 0.05, 0).rotation.z = Math.PI / 2);
      } else {
        const [a, b] = it.v[0].c, dog = k === "perro", fur = toon(a), spot = toon(b);
        const len = dog ? 0.36 : 0.28, hgt = dog ? 0.2 : 0.15;
        mesh(new THREE.CapsuleGeometry(dog ? 0.09 : 0.07, len - 0.1, 4, 8), fur, body, 0, hgt + 0.02, 0).rotation.x = Math.PI / 2;
        [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sz]) => mesh(new THREE.CylinderGeometry(0.025, 0.025, hgt, 6), fur, body, sx * 0.05, hgt / 2, sz * len * 0.32));
        const head = new THREE.Group(); head.position.set(0, hgt + 0.1, len * 0.5); body.add(head);
        mesh(new RoundedBoxGeometry(dog ? 0.16 : 0.13, dog ? 0.14 : 0.12, dog ? 0.16 : 0.12, 2, 0.04), fur, head, 0, 0, 0);
        if (dog) { mesh(new RoundedBoxGeometry(0.08, 0.06, 0.08, 1, 0.02), spot, head, 0, -0.03, 0.09); [-1, 1].forEach(s => mesh(new RoundedBoxGeometry(0.04, 0.1, 0.06, 1, 0.015), spot, head, s * 0.09, -0.02, -0.01)); }
        else [-1, 1].forEach(s => mesh(new THREE.ConeGeometry(0.03, 0.06, 4), spot, head, s * 0.045, 0.08, 0));
        [-0.035, 0.035].forEach(x => mesh(new THREE.SphereGeometry(0.012, 5, 4), toon("#1d1a26"), head, x, 0.015, (dog ? 0.08 : 0.06)));
        const tail = mesh(new THREE.CylinderGeometry(0.015, 0.02, dog ? 0.12 : 0.16, 5), spot, body, 0, hgt + (dog ? 0.08 : 0.1), -len * 0.5); tail.rotation.x = dog ? -0.7 : -0.3;
      }
      return pets[key] = { g, body };
    }
    function petsFrame(now) {
      const w = state.petWalk;
      Object.values(pets).forEach(p => { p.g.visible = false; });
      if (!w || !w.it) return;
      const p = petMesh(w.it), at = from2d(w.pos);
      p.g.visible = true;
      if (p.last) { const dx = at.x - p.last.x, dy = at.y - p.last.y; if (Math.abs(dx) + Math.abs(dy) > 0.002) p.g.rotation.y = Math.atan2(dx, dy); }
      p.last = at; p.g.position.set(at.x, 0, at.y);
      p.body.position.y = reduced ? 0 : Math.abs(Math.sin(now * 12)) * 0.03;
    }

    // --- Cámara, luces y textos ---
    const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 200);
    const home = new THREE.Vector3(15, 0, 8.5), target = home.clone();
    let zoom = 1, vw = 1, vh = 1;
    const composer = new EffectComposer(renderer);
    const pixelPass = new RenderPixelatedPass(2, scene, camera, { normalEdgeStrength: 0.25, depthEdgeStrength: 0.5 });
    composer.addPass(pixelPass); composer.addPass(new OutputPass());
    function placeCamera() {
      const dir = new THREE.Vector3(1, Math.tan(Math.PI / 6) * Math.SQRT2, 1).normalize();
      camera.position.copy(target).addScaledVector(dir, 60); camera.lookAt(target);
      const viewH = Math.max(21, 35 * vh / vw) / zoom;
      camera.left = -viewH * vw / vh / 2; camera.right = viewH * vw / vh / 2; camera.top = viewH / 2; camera.bottom = -viewH / 2; camera.updateProjectionMatrix();
    }
    function resize(x, y, w, h) {
      host.style.left = x + "px"; host.style.top = y + "px"; host.style.width = w + "px"; host.style.height = h + "px";
      vw = Math.max(1, w); vh = Math.max(1, h);
      renderer.setPixelRatio(1); renderer.setSize(vw, vh); composer.setSize(vw, vh);
      const dpr = window.devicePixelRatio || 1; ui.width = vw * dpr; ui.height = vh * dpr; ui.style.width = vw + "px"; ui.style.height = vh + "px";
      placeCamera();
    }
    const sun = new THREE.DirectionalLight("#fff1dc", 2.4); sun.position.set(home.x - 14, 22, home.z - 10); sun.target.position.copy(home); sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, { left: -22, right: 22, top: 22, bottom: -22, near: 1, far: 80 }); sun.shadow.bias = -0.0008; sun.shadow.normalBias = 0.02;
    const sky = new THREE.HemisphereLight("#dfe9ff", "#6b5a4a", 1.4), amb = new THREE.AmbientLight("#ffffff", 0.35);
    scene.add(sun, sun.target, sky, amb);
    // Mover y acercar: arrastrar y rueda; doble click vuelve a la vista general.
    let drag = null, mouse = null, moved = false;
    const cv = renderer.domElement;
    cv.addEventListener("pointerdown", e => { drag = { x: e.clientX, y: e.clientY, t: target.clone() }; moved = false; });
    addEventListener("pointerup", () => { drag = null; });
    cv.addEventListener("pointerleave", () => { mouse = null; });
    cv.addEventListener("pointermove", e => {
      const r = cv.getBoundingClientRect(); mouse = { x: e.clientX - r.left, y: e.clientY - r.top };
      if (!drag) return;
      if (Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 4) moved = true;
      const k = (camera.top - camera.bottom) / vh, dx = (e.clientX - drag.x) * k, dy = (e.clientY - drag.y) * k;
      target.copy(drag.t).addScaledVector(new THREE.Vector3(1, 0, -1).normalize(), -dx).addScaledVector(new THREE.Vector3(-1, 0, -1).normalize(), dy * 2);
      placeCamera();
    });
    // La rueda acerca hacia donde está el mouse: ese punto del piso queda quieto.
    const ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), ray = new THREE.Raycaster();
    const floorAt = (mx, my) => { ray.setFromCamera(new THREE.Vector2(mx / vw * 2 - 1, 1 - my / vh * 2), camera); const p = new THREE.Vector3(); return ray.ray.intersectPlane(ground, p) ? p : null; };
    cv.addEventListener("wheel", e => {
      e.preventDefault();
      const r = cv.getBoundingClientRect(), mx = e.clientX - r.left, my = e.clientY - r.top, before = floorAt(mx, my);
      zoom = Math.min(4, Math.max(0.8, zoom * (e.deltaY < 0 ? 1.12 : 1 / 1.12))); placeCamera();
      const after = floorAt(mx, my);
      if (before && after) { target.add(before.sub(after)); placeCamera(); }
    }, { passive: false });
    cv.addEventListener("dblclick", () => { zoom = 1; target.copy(home); placeCamera(); });
    const v3 = new THREE.Vector3();
    const toScreen = (x, y, z) => { v3.set(x, y, z).project(camera); return [(v3.x + 1) / 2 * vw, (1 - v3.y) / 2 * vh]; };
    let heads = [];
    // Click: en una persona abre su ficha (o, con la tienda abierta, la elige); en el tablero lo abre.
    cv.addEventListener("click", e => {
      if (moved) return;
      const r = cv.getBoundingClientRect(), mx = e.clientX - r.left, my = e.clientY - r.top;
      const [bx, by] = toScreen(20.7, 1.1, 9.46), [bx2, by2] = toScreen(21.8, 0.6, 9.46);
      if (Math.abs(mx - bx) < Math.abs(bx2 - bx) + 10 && Math.abs(my - by) < Math.abs(by2 - by) + 20) { openBoard(); return; }
      const h = pickHead(mx, my);
      if (!h || h.id === "courier") return;
      state.selected = h.id;
      if (drawerTab === "tienda") { const a = agent(h.id); shopSel.who = h.id; shopSel.room = a && room(a.room) && !room(a.room).off ? a.room : ""; renderPanel(true); }
      else { shopSel.room = shopSel.who = ""; openDrawer("empleado"); }
    });
    const pickHead = (mx, my) => heads.filter(h => Math.abs(h.at[0] - mx) < 22 && my > h.at[1] - 10 && my < h.at[1] + 70).sort((a, b) => b.at[1] - a.at[1])[0];

    const FONT = '"Pixelify Sans", monospace';
    const INK = { blue: "#2f5fb8", green: "#2f7a47", teal: "#1f6f63", cyan: "#2a8a9a", pink: "#c2457f", red: "#6a4fb0", gold: "#a8781c", purple: "#6a4fb0", yellow: "#9a7a1c", orange: "#b8621c" };
    function pixRect(x, y, w, h, fill, border) {
      u.fillStyle = border; u.fillRect(x + 2, y, w - 4, h); u.fillRect(x, y + 2, w, h - 4); u.fillRect(x + 1, y + 1, w - 2, h - 2);
      u.fillStyle = fill; u.fillRect(x + 3, y + 2, w - 6, h - 4); u.fillRect(x + 2, y + 3, w - 4, h - 6);
    }
    function wrap(text, maxW) { const words = String(text).split(" "), lines = []; let cur = ""; for (const w of words) { const t = cur ? cur + " " + w : w; if (u.measureText(t).width > maxW && cur) { lines.push(cur); cur = w; } else cur = t; } if (cur) lines.push(cur); return lines.slice(0, 3); }
    function headIcon(q, x, y, s) {
      const L = q.m.look;
      u.fillStyle = "#eef1f7"; u.fillRect(x, y, s, s); u.fillStyle = L.skin; u.fillRect(x + 3, y + 5, s - 6, s - 7);
      u.fillStyle = L.cap || L.hair; if (L.style !== "bald" || L.cap) u.fillRect(x + 2, y + 2, s - 4, 6); else { u.fillRect(x + 2, y + 9, 3, 6); u.fillRect(x + s - 5, y + 9, 3, 6); }
      u.drawImage(q.m.faces.open.userData.canvas, 0, 3, 16, 13, x + 3, y + 7, s - 6, s - 9);
    }
    const shortOf = (k, p) => k === "pm" ? "PM" : k === "courier" ? "Repartidor" : p.short || p.label || k;
    const fullOf = (k, p) => k === "pm" ? "Project manager · Claude" : k === "courier" ? "Repartidor de pizza" : (p.label || k) + (p.provider ? " · " + PROVIDERS[p.provider].name : "");
    function drawUI(now) {
      const dpr = window.devicePixelRatio || 1;
      u.setTransform(dpr, 0, 0, dpr, 0, 0); u.clearRect(0, 0, vw, vh); u.imageSmoothingEnabled = false;
      const fs = 14;
      // Carteles de las puertas.
      u.globalAlpha = 0.92; u.font = "600 12px " + FONT; u.textBaseline = "middle"; u.textAlign = "center";
      const plate = (name, at) => { const [x, y] = at, w = Math.ceil(u.measureText(name).width) + 14; pixRect(Math.round(x - w / 2), Math.round(y - 10), w, 20, "#4a3222", "#21160f"); u.fillStyle = "#f6dfa6"; u.fillText(name, Math.round(x), Math.round(y) + 1); };
      R3.forEach(r => plate(nameOfRoom(r.id), toScreen(r.x + 4, DOOR_H + 0.3, r.top ? 7 : 10)));
      plate("Baños", toScreen(28, DOOR_H + 0.3, 8.45));
      u.globalAlpha = 1;
      heads = [];
      everyone((k, p, q) => { if (q && q.visible && !/^stall/.test(p.doing || "")) heads.push({ id: k, p, q, at: toScreen(q.x, q.seated ? 1.45 : 1.62, q.y) }); });
      // Qué está haciendo cada uno y cómo le fue (sin pisarse).
      const chips = [];
      heads.slice().sort((a, b) => b.at[1] - a.at[1]).forEach(({ p, at }) => {
        if (p.say) return;
        const res = p.bubble && (p.status === "pass" || p.status === "fail" || p.status === "waiting") ? p.bubble : null;
        const busy = p.status === "working" && p.tool, stuck = p.status === "working" && p.stuck;
        if (!res && !busy && !stuck) return;
        const t = res || (stuck ? "¿trabado? " + p.stuck + " min sin novedades" : p.tool.length > 30 ? p.tool.slice(0, 29) + "…" : p.tool);
        u.font = (res ? "600 12px " : "11px ") + FONT; u.textAlign = "center";
        const w = Math.ceil(u.measureText(t).width) + (res ? 14 : 24), x = Math.round(at[0] - w / 2);
        let y = Math.round(at[1] - 26);
        for (let n = 0; n < 8; n++) { const hit = chips.find(o => x < o.x + o.w + 2 && o.x < x + w + 2 && y < o.y + 20 && o.y < y + 20); if (!hit) break; y = hit.y - 21; }
        chips.push({ x, y, w });
        pixRect(x, y, w, 18, res ? { pass: "#2f8a52", fail: "#c23b3b", waiting: "#c98a1c" }[p.status] : stuck ? "#b86a2c" : "rgba(29,26,38,0.88)", "#241d2e");
        if (!res) { const k = Math.floor(now * 3) % 3; for (let i = 0; i < 3; i++) { u.fillStyle = i === k ? "#f2c14e" : "#6c727d"; u.fillRect(x + 6 + i * 4, y + 8, 2, 2); } }
        u.fillStyle = "#ffffff"; u.fillText(t, x + w / 2 + (res ? 0 : 5), y + 9.5);
      });
      u.textAlign = "left";
      // Globos de diálogo, con la carita de quien habla, sin pisarse.
      const placed = [];
      heads.filter(h => h.p.say).sort((a, b) => b.at[1] - a.at[1]).forEach(({ id, p, q, at }) => {
        const who = (nameOf(id) ? nameOf(id) + " · " : "") + shortOf(id, p);
        u.font = "600 " + (fs - 2) + "px " + FONT; const nw = u.measureText(who).width;
        u.font = fs + "px " + FONT; const lines = wrap(p.say.text, 210), mw = Math.max(nw, ...lines.map(l => u.measureText(l).width));
        const icon = 28, w = Math.ceil(mw) + icon + 22, h = Math.max(icon + 10, 12 + (fs - 1) + lines.length * (fs + 3) + 4);
        let x = Math.max(4, Math.min(vw - w - 4, Math.round(at[0] - w / 2))), y = Math.round(at[1] - h - 14);
        for (let n = 0; n < 12; n++) { const hit = placed.find(o => x < o.x + o.w + 4 && o.x < x + w + 4 && y < o.y + o.h + 4 && o.y < y + h + 4); if (!hit) break; y = hit.y - h - 6; }
        placed.push({ x, y, w, h });
        const tx = Math.round(at[0]);
        u.fillStyle = "#241d2e"; u.fillRect(tx - 6, y + h - 2, 12, 3); u.fillRect(tx - 4, y + h + 1, 8, 3); u.fillRect(tx - 2, y + h + 4, 4, 3);
        pixRect(x, y, w, h, "#ffffff", "#241d2e");
        u.fillStyle = "#ffffff"; u.fillRect(tx - 4, y + h - 3, 8, 3); u.fillRect(tx - 2, y + h, 4, 3); u.fillRect(tx - 1, y + h + 3, 2, 2);
        u.fillStyle = "#e6e9f0"; u.fillRect(x + 3, y + h - 4, w - 6, 2);
        headIcon(q, x + 6, y + 5, icon);
        u.textBaseline = "top";
        u.font = "600 " + (fs - 2) + "px " + FONT; u.fillStyle = INK[p.color] || (id === "pm" ? "#5b3fa0" : "#3a3f4a"); u.fillText(who, x + icon + 13, y + 6);
        u.font = fs + "px " + FONT; u.fillStyle = "#1d1a26"; lines.forEach((l, i) => u.fillText(l, x + icon + 13, y + 7 + (fs - 1) + i * (fs + 3)));
      });
      // Nombre y rol de quien está bajo el mouse.
      const h = mouse && !drag && pickHead(mouse.x, mouse.y);
      if (h && !h.p.say) {
        const t1 = (nameOf(h.id) || shortOf(h.id, h.p)), t2 = fullOf(h.id, h.p);
        u.font = "600 " + fs + "px " + FONT; const a = u.measureText(t1).width; u.font = (fs - 3) + "px " + FONT; const b = u.measureText(t2).width;
        const w = Math.ceil(Math.max(a, b)) + 18, hh = fs * 2 + 8, x = Math.round(h.at[0] - w / 2), y = Math.round(h.at[1] - hh - 12);
        pixRect(x, y, w, hh, "#1d1a26", "#f6dfa6"); u.textBaseline = "top"; u.textAlign = "center";
        u.font = "600 " + fs + "px " + FONT; u.fillStyle = "#ffffff"; u.fillText(t1, x + w / 2, y + 4);
        u.font = (fs - 3) + "px " + FONT; u.fillStyle = "#c9d0de"; u.fillText(t2, x + w / 2, y + 6 + fs); u.textAlign = "left";
      }
    }
    function everyone(fn) {
      fn("pm", state.pm, people3.pm);
      state.agents.forEach(a => fn(a.id, a, people3[a.id]));
      fn("courier", state.courier || { id: "courier", status: "idle" }, people3.courier);
    }

    // --- Arranque y cada cuadro ---
    let ready = false, lastT = 0, lastScreens = 0, lastClock = 0, lastSky = 0;
    loadKayKit().then(() => {
      buildRoomShell(); buildFurniture(); buildBathroom();
      const merged = bake(statics); scene.remove(statics); scene.add(merged); statics = merged;
      buildSeats(); Object.values(seatGroups).forEach(sg => { const b = bake(sg.g); scene.remove(sg.g); scene.add(b); sg.g = b; });
      buildShades();
      const patch = basic({ color: "#fff4d2", transparent: true, opacity: 0.12, depthWrite: false });
      winLights.forEach(w => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w.b - w.a, 1.8), patch); m.rotation.x = -Math.PI / 2; if (!w.onX) m.position.set((w.a + w.b) / 2 + 0.6, 0.012, 1.1); else { m.rotation.z = Math.PI / 2; m.position.set(1.1, 0.012, (w.a + w.b) / 2 + 0.6); } scene.add(m); });
      ready = true;
    });
    function frame(ts, pace = 1) {
      if (!ready) return;
      const now = ts / 1000, dt = Math.min(0.1, now - lastT || 0) * pace; lastT = now;
      everyone((k, p) => { const q = syncPerson(k, p, dt); animate(q, p, now); });
      petsFrame(now);
      // Puestos que no se usan, oficinas apagadas, pizza y torta sobre el escritorio.
      Object.entries(seatGroups).forEach(([id, sg]) => {
        const a = id === "pm" ? null : agent(id), used = id === "pm" || (a && a.present !== false && !(/\.lead$/.test(a.role || "") && !a.present));
        sg.g.visible = !!used; (screenMeshes[id] || []).forEach(m => { m.visible = !!used; });
        sg.pizza.visible = !!(state.pizza && state.pizza[id] > state.t);
        sg.cake.visible = !!(state.cake && state.cake.id === id);
      });
      R3.forEach(r => { shades[r.id].visible = !!(room(r.id) && room(r.id).off); });
      stallDoors.forEach((d, n) => {
        const busy = state.agents.some(a => a.doing === "stall" + n);
        d.open += ((busy ? 0 : 1) - d.open) * Math.min(1, dt * 6 + 0.02);
        d.hinge.rotation.y = d.open * 1.35; d.sign.material.color.set(busy ? "#ef6b5b" : "#5cc98a");
      });
      if (now - lastScreens > 0.4) {
        lastScreens = now;
        Object.values(SCREENS).forEach(t => { const o = t.userData.owner, p = o === "pm" ? state.pm : agent(o); drawScreen(t, reduced ? 0 : now, !!(p && p.status === "working") || o === "pm"); });
        racks.forEach(t => drawRack(t, now)); drawBoard3();
      }
      if (now - lastClock > 1) { lastClock = now; clocks.forEach(drawClock); }
      if (now - lastSky > 600) { lastSky = now; skies.forEach(drawSky); }
      // Corte de luz: casi todo a oscuras.
      const dark = (state.blackout || 0) > state.t;
      sun.intensity = dark ? 0.15 : 2.4; sky.intensity = dark ? 0.12 : 1.4; amb.intensity = dark ? 0.05 : 0.35;
      composer.render();
      drawUI(now);
    }
    function setOn(v) {
      api.on = !!v;
      host.hidden = !api.on;
      $("office").hidden = api.on;
    }
    function snapshot() {
      composer.render(); drawUI(performance.now() / 1000);
      const c = document.createElement("canvas"); c.width = vw; c.height = vh;
      const x = c.getContext("2d"); x.drawImage(renderer.domElement, 0, 0, vw, vh); x.drawImage(ui, 0, 0, vw, vh);
      return c.toDataURL("image/png");
    }
    const api = { ok: true, on: false, frame, resize, setOn, nameOf, snapshot };
    return api;
  })();

  // Vista 3D (si el navegador tiene WebGL) o la clásica; se recuerda la elección.
  function renderViewBtn() { $("btn-view").textContent = view3d.on ? "Vista: 3D" : "Vista: clásica"; $("btn-view").setAttribute("aria-pressed", String(view3d.on)); }
  if (view3d.ok) {
    resize3d = view3d.resize;
    $("btn-view").hidden = false;
    view3d.setOn(prefs.view !== "2d");
    $("btn-view").addEventListener("click", () => { view3d.setOn(!view3d.on); prefs.view = view3d.on ? "3d" : "2d"; savePrefs(); renderViewBtn(); resize(); });
    renderViewBtn(); resize();
  }
