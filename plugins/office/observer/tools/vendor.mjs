// Arma src/vendor/ para la vista 3D del observer:
//   three-office.js  three.js y los agregados que usa, en un solo script (window.THREE_OFFICE);
//   kaykit.js        los muebles KayKit Furniture Bits (CC0, Kay Lousberg), con todo adentro.
// Uso (desde plugins/office/observer/tools): npm install && npm run vendor
// Después: bash ../build.sh para volver a armar index.html.
import { build } from "esbuild";
import fs from "fs";
import path from "path";

const here = path.dirname(new URL(import.meta.url).pathname);
const out = path.join(here, "..", "src", "vendor");
fs.mkdirSync(out, { recursive: true });
const safe = s => s.replace(/<\/script/gi, "<\\/script");

const r = await build({ entryPoints: [path.join(here, "three-entry.js")], bundle: true, format: "iife", minify: true, write: false, legalComments: "none" });
fs.writeFileSync(path.join(out, "three-office.js"), "/* three.js 0.170.0 (MIT) — https://threejs.org */\n" + safe(r.outputFiles[0].text));

// KayKit Furniture Bits, en la versión fija de su repositorio.
const KAYKIT = "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0/96d5930a8dbdb363409bbc2d3341718b00e17c9c";
const MODELS = ["armchair_pillows", "couch_pillows", "book_set", "cactus_medium_A", "cactus_small_A", "lamp_standing", "lamp_table",
  "rug_oval_A", "rug_rectangle_A", "rug_rectangle_B", "rug_rectangle_stripes_A", "shelf_B_large_decorated", "table_low", "table_medium_long"];
const get = async (p, bin) => { const res = await fetch(KAYKIT + "/addons/kaykit_furniture_bits/Assets/gltf/" + p); if (!res.ok) throw new Error(p + ": " + res.status); return bin ? Buffer.from(await res.arrayBuffer()) : res.text(); };
const png = (await get("furniturebits_texture.png", true)).toString("base64");
const assets = {};
for (const m of MODELS) {
  const j = JSON.parse(await get(m + ".gltf"));
  for (const b of j.buffers) b.uri = "data:application/octet-stream;base64," + (await get(b.uri, true)).toString("base64");
  for (const i of j.images || []) i.uri = "data:image/png;base64," + png;
  assets[m] = JSON.stringify(j);
}
const license = await (await fetch(KAYKIT + "/LICENSE.txt")).text();
fs.writeFileSync(path.join(out, "kaykit.js"), "/* KayKit Furniture Bits 1.0 — Kay Lousberg, www.kaylousberg.com — CC0 1.0 */\nwindow.KAYKIT = " + safe(JSON.stringify(assets)) + ";\n");
fs.writeFileSync(path.join(out, "KAYKIT-LICENSE.txt"), license);
console.log("Listo:", out);
