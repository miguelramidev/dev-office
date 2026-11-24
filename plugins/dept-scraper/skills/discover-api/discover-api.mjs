#!/usr/bin/env node
// discover-api-version: 1
// Descubre la API interna de un sitio: los pedidos JSON que hace la página para traer sus datos.
// Devuelve un resumen corto de cada endpoint (método, ruta, parámetros, si pide autenticación y
// la forma de la respuesta) y guarda las respuestas, sin cookies ni tokens, para usarlas de
// fixtures. Nunca muestra valores de cookies, tokens ni encabezados de autenticación.
//
// Dos formas:
//   node discover-api.mjs <url> [--wait 8] [--scroll 3] [--headed] [--out <carpeta>]
//     Abre la página con Playwright (sin ventana, salvo --headed), espera, baja la página
//     --scroll veces para disparar la carga diferida y graba lo que pide.
//   node discover-api.mjs --har <archivo.har> [--out <carpeta>]
//     Resume un HAR grabado a mano (Chrome: DevTools → Network → Export HAR). Sirve para los
//     sitios que bloquean al navegador automático o donde los datos aparecen después de un clic.
//
// Por defecto guarda en .office/scraper/<sitio>/ (summary.md y una respuesta por endpoint).
// Necesita Node 18 o más. Para la primera forma, además, Playwright: el del proyecto, uno global
// o uno en ~/.cache/dev-office/playwright (el script dice cómo instalarlo si falta).

import { createRequire } from "node:module";
import { readFileSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { homedir } from "node:os";

const USAGE = "Uso: node discover-api.mjs <url> [--wait 8] [--scroll 3] [--headed] [--out <carpeta>]\n     node discover-api.mjs --har <archivo.har> [--out <carpeta>]";

// --- Opciones -------------------------------------------------------------------------

const args = process.argv.slice(2);
const opts = { wait: 8, scroll: 3, headed: false, out: "", har: "", url: "" };
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--wait") opts.wait = Number(args[++i]);
  else if (a === "--scroll") opts.scroll = Number(args[++i]);
  else if (a === "--headed") opts.headed = true;
  else if (a === "--out") opts.out = args[++i];
  else if (a === "--har") opts.har = args[++i];
  else if (a === "-h" || a === "--help") { console.log(USAGE); process.exit(0); }
  else if (a.startsWith("--")) { console.error(`Opción desconocida: ${a}\n${USAGE}`); process.exit(2); }
  else opts.url = a;
}
if (!opts.url && !opts.har) { console.error(USAGE); process.exit(2); }
if (opts.url && !/^https?:\/\//i.test(opts.url)) { console.error("La dirección tiene que empezar con http:// o https://"); process.exit(2); }
if (!Number.isFinite(opts.wait) || opts.wait < 0 || !Number.isFinite(opts.scroll) || opts.scroll < 0) {
  console.error("--wait y --scroll van con un número."); process.exit(2);
}

// --- Qué se oculta ----------------------------------------------------------------------

// Nombres (de encabezados, parámetros o campos) cuyo valor nunca se muestra ni se guarda.
const SECRET = /(token|secret|passw|pwd|session|sess_id|sid$|csrf|xsrf|auth|api[-_]?key|apikey|signature|^sig$|cookie|bearer|credential|private)/i;
// Dominios de analítica, publicidad y monitoreo: no son la API del sitio.
const NOISE = /(google-analytics|googletagmanager|analytics\.google|doubleclick|googlesyndication|googleadservices|facebook\.(com|net)|fbcdn|connect\.facebook|hotjar|segment\.(io|com)|sentry|clarity\.ms|newrelic|nr-data|datadoghq|mixpanel|amplitude|fullstory|tiktok|snapchat|linkedin|twitter|bing\.com|criteo|taboola|outbrain|onesignal|intercom|zendesk|cloudflareinsights|recaptcha|hcaptcha|gstatic)/i;
const REDACTED = "<oculto>";

function redactValue(key, value) {
  return SECRET.test(key) ? REDACTED : value;
}

// Copia de un JSON con los valores de campos sensibles ocultos.
function redactJson(v, depth = 0) {
  if (depth > 40) return v;
  if (Array.isArray(v)) return v.map((x) => redactJson(x, depth + 1));
  if (v && typeof v === "object") {
    const o = {};
    for (const [k, x] of Object.entries(v)) o[k] = SECRET.test(k) && (typeof x !== "object" || x === null) ? REDACTED : redactJson(x, depth + 1);
    return o;
  }
  return v;
}

// --- Forma de una respuesta ---------------------------------------------------------------

function typeOf(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v;
}

// Las claves de un objeto con su tipo, hasta 12.
function keysOf(o) {
  const ks = Object.keys(o);
  const shown = ks.slice(0, 12).map((k) => `${k}: ${typeOf(o[k])}`);
  return shown.join(", ") + (ks.length > 12 ? `, … (${ks.length} claves)` : "");
}

// La lista de objetos más larga dentro de la respuesta: casi siempre son los datos.
function mainList(v, path = "$", depth = 0, best = null) {
  if (depth > 6 || v === null || typeof v !== "object") return best;
  if (Array.isArray(v)) {
    const objs = v.filter((x) => x && typeof x === "object" && !Array.isArray(x));
    if (objs.length >= 2 && (!best || objs.length > best.length)) best = { path, length: v.length, item: objs[0] };
    v.slice(0, 3).forEach((x, i) => { best = mainList(x, `${path}[${i}]`, depth + 1, best); });
    return best;
  }
  for (const [k, x] of Object.entries(v)) best = mainList(x, `${path}.${k}`, depth + 1, best);
  return best;
}

function shapeOf(json) {
  const lines = [];
  if (Array.isArray(json)) lines.push(`lista de ${json.length}`);
  else if (json && typeof json === "object") lines.push(`objeto: ${keysOf(json)}`);
  else lines.push(typeOf(json));
  const list = mainList(json);
  if (list) lines.push(`lista principal en \`${list.path.replace(/\[\d+\]/g, "[]")}\` (${list.length} elementos): ${keysOf(list.item)}`);
  return { lines, listLength: list ? list.length : 0 };
}

// --- Agrupar en endpoints -------------------------------------------------------------------

// /productos/123 y /productos/456 son el mismo endpoint: /productos/{id}.
function templatePath(path) {
  return path
    .split("/")
    .map((s) => (/^\d+$/.test(s) ? "{id}" : /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s) ? "{uuid}" : /^[0-9a-f]{24,}$/i.test(s) ? "{hash}" : s))
    .join("/");
}

function isJsonType(ct) {
  return /json|javascript\+json|graphql/i.test(ct || "");
}

const endpoints = new Map();
let seen = 0;
let skippedNoise = 0;

// Agrega un pedido: { method, url, status, reqHeaders: {nombre: valor}, postData, contentType, body (texto), resourceType }
function addExchange(x) {
  seen++;
  let u;
  try { u = new URL(x.url); } catch { return; }
  if (!/^https?:$/.test(u.protocol)) return;
  if (NOISE.test(u.hostname)) { skippedNoise++; return; }
  const isApiType = x.resourceType ? /^(xhr|fetch)$/i.test(x.resourceType) : false;
  if (!isJsonType(x.contentType) && !isApiType) return;
  let json;
  if (x.body) { try { json = JSON.parse(x.body); } catch { json = undefined; } }
  if (json === undefined && !isJsonType(x.contentType)) return;
  const key = `${x.method} ${u.host}${templatePath(u.pathname)}`;
  let e = endpoints.get(key);
  if (!e) {
    e = { key, method: x.method, host: u.host, path: templatePath(u.pathname), count: 0, statuses: new Set(), params: new Map(), auth: new Set(), cookies: false, custom: new Set(), bodyKeys: new Set(), graphql: new Set(), size: 0, json: undefined, example: "" };
    endpoints.set(key, e);
  }
  e.count++;
  e.statuses.add(x.status);
  for (const [k, v] of u.searchParams) if (!e.params.has(k)) e.params.set(k, redactValue(k, v));
  for (const [rawName, v] of Object.entries(x.reqHeaders || {})) {
    const name = rawName.toLowerCase();
    if (name === "cookie") { if (v) e.cookies = true; continue; }
    if (name === "authorization" || name === "proxy-authorization") { e.auth.add(`${name}: ${String(v).split(" ")[0]} …`); continue; }
    if (SECRET.test(name)) { e.auth.add(name); continue; }
    if (name.startsWith("x-") || name === "apollographql-client-name") e.custom.add(name);
  }
  if (x.postData) {
    try {
      const pd = JSON.parse(x.postData);
      if (pd && typeof pd === "object" && !Array.isArray(pd)) {
        Object.keys(pd).forEach((k) => e.bodyKeys.add(k));
        if (typeof pd.operationName === "string") e.graphql.add(pd.operationName);
      }
    } catch {
      for (const part of String(x.postData).split("&")) { const k = decodeURIComponent(part.split("=")[0] || ""); if (k) e.bodyKeys.add(k); }
    }
  }
  const size = x.body ? Buffer.byteLength(x.body) : 0;
  // Se queda con la respuesta más grande de cada endpoint: suele ser la más completa.
  if (json !== undefined && size >= e.size) {
    e.size = size;
    e.json = json;
    const ex = new URL(u.href);
    for (const k of [...ex.searchParams.keys()]) if (SECRET.test(k)) ex.searchParams.set(k, REDACTED);
    e.example = ex.href;
  }
}

// --- Fuente: HAR ----------------------------------------------------------------------------

function fromHar(file) {
  let har;
  try { har = JSON.parse(readFileSync(file, "utf8")); } catch (err) { console.error(`No pude leer el HAR ${file}: ${err.message}`); process.exit(1); }
  const entries = har?.log?.entries;
  if (!Array.isArray(entries)) { console.error(`${file} no parece un HAR (falta log.entries).`); process.exit(1); }
  for (const en of entries) {
    const req = en.request || {}, res = en.response || {};
    const headers = Object.fromEntries((req.headers || []).map((h) => [h.name, h.value]));
    let body = res.content?.text || "";
    if (body && res.content?.encoding === "base64") { try { body = Buffer.from(body, "base64").toString("utf8"); } catch { body = ""; } }
    addExchange({
      method: req.method || "GET", url: req.url || "", status: res.status, reqHeaders: headers,
      postData: req.postData?.text || "", contentType: res.content?.mimeType || "", body,
      resourceType: en._resourceType || "",
    });
  }
  return entries.length && entries[0]?.request?.url ? new URL(entries[0].request.url).host : "har";
}

// --- Fuente: navegador ------------------------------------------------------------------------

function loadPlaywright() {
  const places = [join(process.cwd(), "package.json"), import.meta.url, join(homedir(), ".cache", "dev-office", "playwright", "package.json")];
  for (const p of places) {
    let req;
    try { req = createRequire(p); } catch { continue; }
    for (const name of ["playwright", "playwright-core", "@playwright/test"]) {
      try { const m = req(name); if (m?.chromium) return m; } catch { /* sigue */ }
    }
  }
  return null;
}

async function fromBrowser(url) {
  const pw = loadPlaywright();
  if (!pw) {
    const dir = join(homedir(), ".cache", "dev-office", "playwright");
    console.error(
      "Falta Playwright. Instalalo una vez, fuera del proyecto (pedile aprobación al CEO):\n" +
      `  npm install --prefix "${dir}" playwright\n` +
      `  npx --prefix "${dir}" playwright install chromium\n` +
      "O grabá el tráfico a mano en Chrome (DevTools → Network → Export HAR) y corré: node discover-api.mjs --har <archivo.har>",
    );
    process.exit(3);
  }
  let browser, lastErr;
  // Chromium de Playwright; si no está descargado, el Chrome o el Edge instalados.
  for (const channel of [undefined, "chrome", "msedge"]) {
    try { browser = await pw.chromium.launch({ headless: !opts.headed, ...(channel ? { channel } : {}) }); break; } catch (err) { lastErr = err; }
  }
  if (!browser) {
    console.error(`No pude abrir un navegador: ${String(lastErr?.message || lastErr).split("\n")[0]}\nInstalá Chromium: npx playwright install chromium (o usá --har).`);
    process.exit(3);
  }
  const pending = [];
  const page = await browser.newPage();
  page.on("response", (res) => {
    const req = res.request();
    pending.push((async () => {
      const ct = res.headers()["content-type"] || "";
      const rt = req.resourceType();
      if (!/^(xhr|fetch)$/.test(rt) && !isJsonType(ct)) return;
      let body = "";
      try { body = await res.text(); } catch { body = ""; }
      let reqHeaders = {};
      try { reqHeaders = await req.allHeaders(); } catch { reqHeaders = req.headers(); }
      addExchange({ method: req.method(), url: req.url(), status: res.status(), reqHeaders, postData: req.postData() || "", contentType: ct, body, resourceType: rt });
    })());
  });
  let status = 0, title = "";
  try {
    const r = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
    status = r ? r.status() : 0;
    for (let i = 0; i < opts.scroll; i++) {
      await page.waitForTimeout(1200);
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight)).catch(() => {});
    }
    await page.waitForTimeout(opts.wait * 1000);
    title = await page.title().catch(() => "");
  } catch (err) {
    console.error(`La página no terminó de cargar: ${String(err.message).split("\n")[0]}. Sigo con lo que llegó.`);
  }
  await Promise.allSettled(pending);
  await browser.close();
  return { host: new URL(url).host, status, title };
}

// --- Bloqueos ---------------------------------------------------------------------------------

function blockHint(status, title) {
  if ([401, 403, 429, 503].includes(status) || /just a moment|attention required|access denied|captcha|are you a robot|verify you are human|pardon our interruption/i.test(title)) {
    return `\n> **La página parece bloqueada** (código ${status}${title ? `, título "${title}"` : ""}). Probá con --headed, o grabá el tráfico a mano en tu navegador y usá --har. Si el proyecto activó el anti-bloqueo, seguí la skill anti-blocking.\n`;
  }
  return "";
}

// --- Resumen ------------------------------------------------------------------------------------

function slug(s) {
  return s.replace(/[{}]/g, "").replace(/[^A-Za-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 60) || "raiz";
}

async function main() {
  let host, hint = "";
  if (opts.har) host = fromHar(opts.har);
  else { const r = await fromBrowser(opts.url); host = r.host; hint = blockHint(r.status, r.title); }

  const out = resolve(opts.out || join(".office", "scraper", slug(host)));
  mkdirSync(out, { recursive: true });

  const list = [...endpoints.values()]
    .map((e) => ({ ...e, shape: e.json !== undefined ? shapeOf(e.json) : { lines: ["(sin cuerpo JSON)"], listLength: 0 } }))
    .sort((a, b) => b.shape.listLength - a.shape.listLength || b.size - a.size);

  const md = [];
  md.push(`# API interna de ${host}`);
  md.push("");
  md.push(`Fuente: ${opts.har ? `HAR ${opts.har}` : opts.url} · ${new Date().toISOString().slice(0, 10)}`);
  md.push(`${seen} pedidos vistos, ${list.length} endpoints con JSON${skippedNoise ? `, ${skippedNoise} de analítica o publicidad descartados` : ""}. Los valores de cookies, tokens y autenticación no se muestran.`);
  if (hint) md.push(hint);
  if (!list.length) {
    md.push("");
    md.push("No encontré pedidos JSON. Puede que los datos vengan en el HTML (buscá un `<script type=\"application/json\">` o `__NEXT_DATA__`), que aparezcan después de un clic (grabá un HAR a mano) o que la página esté bloqueada.");
  }
  list.forEach((e, i) => {
    const n = String(i + 1).padStart(2, "0");
    const file = `${n}-${e.method.toLowerCase()}-${slug(e.path)}.json`;
    if (e.json !== undefined) writeFileSync(join(out, file), JSON.stringify(redactJson(e.json), null, 2) + "\n");
    md.push("");
    md.push(`## ${n}. ${e.method} ${e.host}${e.path}`);
    md.push("");
    md.push(`- Visto ${e.count} ${e.count === 1 ? "vez" : "veces"}, código ${[...e.statuses].join(", ")}, ${(e.size / 1024).toFixed(1)} KB.`);
    if (e.example) md.push(`- Ejemplo: \`${e.example}\``);
    if (e.params.size) md.push(`- Parámetros: ${[...e.params].map(([k, v]) => `\`${k}\`=${String(v).slice(0, 40)}`).join(", ")}`);
    if (e.bodyKeys.size) md.push(`- Cuerpo del pedido: ${[...e.bodyKeys].slice(0, 15).join(", ")}${e.graphql.size ? ` (GraphQL: ${[...e.graphql].join(", ")})` : ""}`);
    const auth = [...e.auth, ...(e.cookies ? ["cookies"] : [])];
    md.push(`- Autenticación: ${auth.length ? `manda ${auth.join(", ")}` : "ninguna a la vista"}`);
    if (e.custom.size) md.push(`- Encabezados propios: ${[...e.custom].join(", ")}`);
    e.shape.lines.forEach((l) => md.push(`- Respuesta: ${l}`));
    if (e.json !== undefined) md.push(`- Guardada en \`${file}\` (sin valores sensibles).`);
  });
  md.push("");
  md.push("Antes de usar un endpoint: revisá los términos del sitio y `robots.txt` (skill responsible-scraping), y que los datos se vean sin iniciar sesión.");
  const text = md.join("\n") + "\n";
  writeFileSync(join(out, "summary.md"), text);
  process.stdout.write(text);
  console.error(`\nGuardado en ${out}`);
}

main().catch((err) => { console.error(err?.stack || String(err)); process.exit(1); });
