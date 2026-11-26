// Moodchords web app (PWA). The Swift app's screens, rebuilt with plain JS.
import * as C from "./core.js";
import { ICONS } from "./icons.js";

// ================================================================ utilities

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));
const icon = (name, filled = false, cls = "") => {
  const d = ICONS[name] || ICONS.music_note;
  return `<svg class="ico ${cls}" viewBox="0 0 960 960" aria-hidden="true"><path d="${d[filled ? 1 : 0]}"/></svg>`;
};
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;
const app = $("#app");
const layer = $("#layer");

let toastTimer;
function toast(msg) {
  const el = $("#toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2200);
}

// ================================================================ storage

const KEY = "moodchords.v1";
function freshDb() {
  return {
    songs: [],
    moods: C.DEFAULT_MOODS.map((m) => ({ id: uid(), ...m, isDefault: true })),
    prefs: { language: "all", playFontSize: 26, installDismissed: false },
  };
}
function load() {
  try {
    const d = JSON.parse(localStorage.getItem(KEY));
    if (d && Array.isArray(d.songs) && Array.isArray(d.moods)) {
      d.prefs = { ...freshDb().prefs, ...(d.prefs || {}) };
      return d;
    }
  } catch { /* fall through */ }
  return freshDb();
}
let db = load();
function save() {
  try { localStorage.setItem(KEY, JSON.stringify(db)); }
  catch { toast("Couldn't save. Your browser's storage is full."); }
}
if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});

const parseCache = new Map();
function parsed(song) {
  let p = parseCache.get(song.source);
  if (p === undefined) {
    p = C.tryParse(song.source);
    parseCache.set(song.source, p);
  }
  return p || { title: "(Untitled)", artist: null, key: null, duration: null, moods: [], crowds: [], capo: null, language: null, lines: [], warnings: [], chords: [], effectiveDuration: C.DEFAULT_DURATION };
}
const songById = (id) => db.songs.find((s) => s.id === id);
const moodById = (id) => db.moods.find((m) => m.id === id);
const hasMood = (song, name) => parsed(song).moods.some((m) => C.normalizedName(m) === C.normalizedName(name));
const songCrowds = (song) => parsed(song).crowds.map(C.crowdFromName).filter(Boolean).map((c) => c.id);
const langOk = (song) => db.prefs.language === "all" || C.languageFromName(parsed(song).language) === db.prefs.language;
const crowdOk = (song, crowd) => !crowd || crowd === "anyone" || songCrowds(song).includes(crowd);
const byTitle = (a, b) => parsed(a).title.localeCompare(parsed(b).title);
const moodFor = (song) => {
  const names = parsed(song).moods.map(C.normalizedName);
  return db.moods.find((m) => names.includes(C.normalizedName(m.name))) || null;
};
const songsForMood = (mood, crowd) => db.songs.filter((s) => hasMood(s, mood.name) && langOk(s) && crowdOk(s, crowd));

function addSong(source) {
  const p = C.parse(source);
  const song = { id: uid(), source, isFavorite: false, isReady: false, scrollSpeed: 1, createdAt: Date.now() };
  db.songs.push(song);
  return { song, parsed: p };
}

// ================================================================ router

const routes = [];
const route = (pattern, fn, opts = {}) => routes.push({ re: new RegExp("^" + pattern + "$"), fn, opts });
let cleanup = null;
let depth = Number(sessionStorage.getItem("mc.depth") || 0);

function go(hash) {
  depth++;
  sessionStorage.setItem("mc.depth", depth);
  location.hash = hash;
}
function back(fallback = "#/") {
  if (depth > 0) {
    depth--;
    sessionStorage.setItem("mc.depth", depth);
    history.back();
  } else {
    location.replace(fallback);
  }
}
function replace(hash) { location.replace(hash); }

function render() {
  closeSheet();
  if (cleanup) { cleanup(); cleanup = null; }
  const path = decodeURIComponent((location.hash || "#/").slice(1)) || "/";
  for (const r of routes) {
    const m = path.match(r.re);
    if (m) {
      const tab = r.opts.tab;
      renderTabs(tab);
      app.innerHTML = "";
      cleanup = r.fn(...m.slice(1)) || null;
      if (!r.opts.keepScroll) window.scrollTo(0, 0);
      return;
    }
  }
  replace("#/");
}
window.addEventListener("hashchange", render);

function renderTabs(active) {
  const bar = $("#tabbar");
  if (!active) { bar.classList.add("hidden"); return; }
  bar.classList.remove("hidden");
  const tabs = [["moods", "#/", "grid_view", "Moods"], ["favourites", "#/favourites", "star", "Favourites"], ["tuner", "#/tuner", "graphic_eq", "Tuner"]];
  bar.innerHTML = tabs.map(([id, href, ic, label]) => `<a href="${href}" class="${id === active ? "on" : ""}" ${id === active ? 'aria-current="page"' : ""}>${icon(ic, id === active)}<span>${label}</span></a>`).join("");
}

// ================================================================ sheets

function openSheet(html, { onOpen } = {}) {
  layer.innerHTML = `<div class="backdrop"></div><div class="bottom-sheet" role="dialog" aria-modal="true"><div class="grabber"></div>${html}</div>`;
  $(".backdrop", layer).addEventListener("click", closeSheet);
  const sheet = $(".bottom-sheet", layer);
  let startY = null;
  sheet.addEventListener("touchstart", (e) => { if (sheet.scrollTop <= 0) startY = e.touches[0].clientY; }, { passive: true });
  sheet.addEventListener("touchend", (e) => { if (startY !== null && e.changedTouches[0].clientY - startY > 90) closeSheet(); startY = null; });
  onOpen && onOpen(sheet);
  return sheet;
}
function closeSheet() { layer.innerHTML = ""; }
document.addEventListener("keydown", (e) => { if (e.key === "Escape" && layer.innerHTML) closeSheet(); });

// ================================================================ shared pieces

function chordSheetHTML(lines) {
  let out = '<div class="cs">';
  lines.forEach((line, i) => {
    if (line.type === "blank") out += `<div class="blank" data-i="${i}"></div>`;
    else if (line.type === "section") out += `<div class="sec" data-i="${i}">${esc(line.text)}</div>`;
    else if (line.type === "note") out += `<div class="note" data-i="${i}">${esc(line.text)}</div>`;
    else {
      const ps = C.pieces(line.segments);
      const anyChord = ps.some((p) => p.chord);
      const anyText = ps.some((p) => p.text.trim());
      const cls = !anyChord ? "nochords" : !anyText ? "chordsonly" : "";
      out += `<div class="ln ${cls}" data-i="${i}">` + ps.map((p) => `<span class="pc"><span class="ch">${esc(p.chord || "")}</span><span class="tx">${esc(p.text) || (p.chord ? " " : "")}</span></span>`).join("") + "</div>";
    }
  });
  return out + "</div>";
}

/** After layout: a wrapped row of a line that has no chords of its own doesn't keep an empty chord row. */
function fixWrappedRows(root) {
  $$(".cs .ln:not(.nochords):not(.chordsonly)", root).forEach((ln) => {
    const pcs = $$(".pc", ln);
    pcs.forEach((pc) => pc.classList.remove("nc"));
    const rows = new Map();
    pcs.forEach((pc) => { const k = pc.offsetTop; if (!rows.has(k)) rows.set(k, []); rows.get(k).push(pc); });
    if (rows.size < 2) return;
    for (const row of rows.values()) {
      if (row.every((pc) => !pc.firstElementChild.textContent)) row.forEach((pc) => pc.classList.add("nc"));
    }
  });
}
let wrapTimer;
window.addEventListener("resize", () => { clearTimeout(wrapTimer); wrapTimer = setTimeout(() => fixWrappedRows(app), 100); });
document.fonts?.ready.then(() => fixWrappedRows(app));

function diagramSVG(name) {
  const s = C.chordShape(name);
  if (!s) return "";
  const fretted = s.frets.filter((f) => f !== null && f > 0);
  const high = Math.max(0, ...fretted);
  const low = fretted.length ? Math.min(...fretted) : 0;
  const start = high <= 4 ? 1 : low;
  const W = 62, H = 78, x0 = 10, y0 = 16, gw = 44, gh = 56, sx = gw / 5, fy = gh / 4;
  let g = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(name)} chord">`;
  g += `<g stroke="currentColor" stroke-width="1" opacity="0.55">`;
  for (let i = 0; i < 6; i++) g += `<line x1="${x0 + i * sx}" y1="${y0}" x2="${x0 + i * sx}" y2="${y0 + gh}"/>`;
  for (let j = 0; j <= 4; j++) g += `<line x1="${x0}" y1="${y0 + j * fy}" x2="${x0 + gw}" y2="${y0 + j * fy}"/>`;
  g += "</g>";
  if (start === 1) g += `<rect x="${x0 - 0.5}" y="${y0 - 3}" width="${gw + 1}" height="3.5" rx="1" fill="currentColor"/>`;
  else g += `<text x="${x0 - 3}" y="${y0 + fy * 0.68}" font-size="8" text-anchor="end" fill="currentColor" font-family="DM Mono, monospace">${start}</text>`;
  if (s.barre && s.barre >= start) {
    const idx = s.frets.map((f, i) => (f === s.barre ? i : -1)).filter((i) => i >= 0);
    const a = Math.min(...idx), b = Math.max(...idx);
    const y = y0 + (s.barre - start + 0.5) * fy;
    g += `<rect x="${x0 + a * sx - 4}" y="${y - 4}" width="${(b - a) * sx + 8}" height="8" rx="4" fill="currentColor"/>`;
  }
  s.frets.forEach((f, i) => {
    const x = x0 + i * sx;
    if (f === null) g += `<text x="${x}" y="${y0 - 6}" font-size="8" text-anchor="middle" fill="currentColor" opacity="0.7">×</text>`;
    else if (f === 0) g += `<circle cx="${x}" cy="${y0 - 8.5}" r="2.6" fill="none" stroke="currentColor" stroke-width="1.1" opacity="0.8"/>`;
    else if (!(s.barre && f === s.barre)) g += `<circle cx="${x}" cy="${y0 + (f - start + 0.5) * fy}" r="4.2" fill="currentColor"/>`;
  });
  return g + "</svg>";
}

function songRowHTML(song, { swatch = false } = {}) {
  const p = parsed(song);
  const sm = C.summary(p);
  const mood = moodFor(song);
  const lead = swatch
    ? `<span class="sw" style="--hue:${mood ? mood.hue : 50}">${icon(mood ? mood.icon : "music_note", true)}</span>`
    : `<span class="mark ${song.isReady ? "ready" : ""}" aria-label="${song.isReady ? "Ready to play" : "Still learning"}">${icon(song.isReady ? "check_circle" : "radio_button_unchecked", song.isReady)}</span>`;
  return `<div class="row" data-song="${song.id}" role="button" tabindex="0">
    ${lead}
    <span class="body"><span class="t">${esc(p.title)}</span>${p.artist ? `<div class="a">${esc(p.artist)}</div>` : ""}
      <div class="meta mono">${esc(sm.metaLine)}</div><div class="cue">${esc(sm.cueLine)}</div></span>
    <button class="star ${song.isFavorite ? "on" : ""}" data-star="${song.id}" aria-label="${song.isFavorite ? "Remove from favourites" : "Add to favourites"}">${icon("star", song.isFavorite)}</button>
  </div>`;
}

/** Tap opens the song, the star toggles favourite, long-press (or right-click) opens quick actions. */
function bindRows(root, rerender) {
  $$(".row[data-song]", root).forEach((row) => {
    const id = row.dataset.song;
    let timer = null, long = false, sx = 0, sy = 0;
    row.addEventListener("pointerdown", (e) => {
      long = false; sx = e.clientX; sy = e.clientY;
      timer = setTimeout(() => { long = true; navigator.vibrate && navigator.vibrate(10); quickActions(id, rerender); }, 520);
    });
    const cancel = () => clearTimeout(timer);
    row.addEventListener("pointermove", (e) => { if (Math.abs(e.clientX - sx) + Math.abs(e.clientY - sy) > 10) cancel(); });
    row.addEventListener("pointerup", cancel);
    row.addEventListener("pointercancel", cancel);
    row.addEventListener("contextmenu", (e) => { e.preventDefault(); cancel(); if (!long) quickActions(id, rerender); long = true; });
    row.addEventListener("click", (e) => {
      if (long) { long = false; return; }
      if (e.target.closest("[data-star]")) {
        const s = songById(id); s.isFavorite = !s.isFavorite; save(); rerender(); return;
      }
      go(`#/song/${id}`);
    });
    row.addEventListener("keydown", (e) => { if (e.key === "Enter") go(`#/song/${id}`); });
  });
}

function quickActions(id, rerender) {
  const s = songById(id);
  if (!s) return;
  const p = parsed(s);
  openSheet(`<div class="menu-title"><b>${esc(p.title)}</b>${p.artist ? `<div class="muted">${esc(p.artist)}</div>` : ""}</div>
    <div class="menu">
      <button data-a="fav">${s.isFavorite ? "Unfavourite" : "Favourite"}${icon("star", s.isFavorite)}</button>
      <button data-a="ready">${s.isReady ? "Mark not ready" : "Mark ready to play"}${icon(s.isReady ? "radio_button_unchecked" : "check_circle")}</button>
      <button data-a="play">Play${icon("play_arrow")}</button>
      <button data-a="edit">Edit song${icon("edit")}</button>
    </div>`, {
    onOpen: (sh) => $$("[data-a]", sh).forEach((b) => b.addEventListener("click", () => {
      const a = b.dataset.a;
      closeSheet();
      if (a === "fav") { s.isFavorite = !s.isFavorite; save(); rerender(); }
      if (a === "ready") { s.isReady = !s.isReady; save(); rerender(); }
      if (a === "play") go(`#/play/${id}`);
      if (a === "edit") go(`#/edit/${id}`);
    })),
  });
}

function languageChips(onChange) {
  const opts = [["all", "All"], ...C.LANGUAGES.map((l) => [l, l])];
  return `<div class="chips" role="radiogroup" aria-label="Language">${opts.map(([v, t]) => `<button class="chip ${db.prefs.language === v ? "on" : ""}" data-lang="${v}" role="radio" aria-checked="${db.prefs.language === v}">${t}</button>`).join("")}</div>`;
}
function bindLanguageChips(root, rerender) {
  $$("[data-lang]", root).forEach((b) => b.addEventListener("click", () => { db.prefs.language = b.dataset.lang; save(); rerender(); }));
}

// ================================================================ install prompt

let deferredInstall = null;
window.addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); deferredInstall = e; if (location.hash === "#/" || !location.hash) render(); });
const isStandalone = () => window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
const isIOS = () => /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

function installBanner() {
  if (isStandalone() || db.prefs.installDismissed) return "";
  if (deferredInstall) return `<div class="install">${icon("download")}<p><b>Install Moodchords</b><br>Use it like an app, even offline.</p><button class="text-btn primary" id="do-install">Install</button><button id="x-install" aria-label="Dismiss">${icon("close")}</button></div>`;
  if (isIOS()) return `<div class="install">${icon("ios_share")}<p><b>Install on your iPhone:</b> tap Share ${icon("ios_share")} in Safari, then <b>Add to Home Screen</b>.</p><button id="x-install" aria-label="Dismiss">${icon("close")}</button></div>`;
  return "";
}
function bindInstall(root, rerender) {
  $("#do-install", root)?.addEventListener("click", async () => {
    if (!deferredInstall) return;
    deferredInstall.prompt();
    await deferredInstall.userChoice.catch(() => {});
    deferredInstall = null; rerender();
  });
  $("#x-install", root)?.addEventListener("click", () => { db.prefs.installDismissed = true; save(); rerender(); });
}

// ================================================================ Home

route("/", () => {
  const draw = () => {
    if (!db.songs.length) return drawFirstLaunch();
    const ready = db.songs.filter((s) => s.isReady && langOk(s));
    app.innerHTML = `<div class="screen">
      <div class="topbar"><span class="spacer"></span>
        <button class="circle-btn glass" id="add" aria-label="Add a song">${icon("add")}</button></div>
      <h1 class="big">Moodchords</h1>
      <p class="subtitle">What's the vibe tonight?</p>
      ${installBanner()}
      <div style="margin-top:16px">${languageChips()}</div>
      <button class="surprise" id="surprise" ${ready.length ? "" : "disabled"}>
        ${icon("shuffle")}<span><b>Surprise me</b><span>${ready.length ? `From ${plural(ready.length, "song")} you're ready to play` : "Mark songs ready to play to use this"}</span></span>
        <span class="go">${icon("play_arrow", true)}</span></button>
      <div class="grid">${db.moods.map((m) => {
        const n = songsForMood(m).length;
        return `<button class="tile" data-mood="${m.id}" style="--hue:${m.hue}">
          <span class="sym">${icon(m.icon, true)}</span><span class="bgsym">${icon(m.icon, true)}</span>
          <span class="name">${esc(m.name)}</span><span class="count">${n ? plural(n, "song") : "No songs yet"}${m.subtitle ? " · " + esc(m.subtitle) : ""}</span></button>`;
      }).join("")}</div>
      <div style="text-align:center;margin-top:18px"><a class="link-btn" href="#/moods" onclick="event.preventDefault();">${icon("edit")} Edit moods</a></div>
    </div>`;
    $("#add").addEventListener("click", addSheet);
    $(".link-btn", app).addEventListener("click", () => go("#/moods"));
    $("#surprise").addEventListener("click", () => {
      if (!ready.length) return;
      const s = ready[Math.floor(Math.random() * ready.length)];
      go(`#/song/${s.id}`);
    });
    $$("[data-mood]").forEach((b) => b.addEventListener("click", () => crowdSheet(moodById(b.dataset.mood))));
    bindLanguageChips(app, draw);
    bindInstall(app, draw);
  };
  const drawFirstLaunch = () => {
    app.innerHTML = `<div class="screen">
      <div class="topbar"><span class="spacer"></span>
        <button class="circle-btn glass" id="add" aria-label="Add a song">${icon("add")}</button></div>
      <h1 class="big">Moodchords</h1>
      ${installBanner()}
      <div class="empty-hero"><div class="backdrop">BAJA TA</div>
        <div class="kicker">"Oe, baja ta!"</div>
        <h2>Add your first song</h2>
        <p>Paste a chord sheet or import a file. Next time someone asks you to play, it's already sorted by mood.</p>
        <div class="stack">
          <button class="cap-btn accent" id="paste">${icon("content_paste")} Paste song</button>
          <button class="cap-btn glass" id="import">${icon("upload_file")} Import file <small>.TXT · .CHO</small></button>
          <button class="cap-btn glass" id="samples">${icon("library_music")} Try 2 sample songs</button>
        </div>
        <p class="mono" style="margin:26px 0 10px">Your songs will sort into</p>
        <div class="wrap-chips">${db.moods.map((m) => `<span class="chip small mood" style="--hue:${m.hue}">${icon(m.icon, true)} ${esc(m.name)}</span>`).join("")}</div>
        <p class="help" style="margin-top:26px">Everything stays on this device. No account, nothing uploaded.</p>
      </div></div>`;
    $("#add").addEventListener("click", addSheet);
    $("#paste").addEventListener("click", () => go("#/paste"));
    $("#import").addEventListener("click", () => pickFiles(false));
    $("#samples").addEventListener("click", loadSamples);
    bindInstall(app, draw);
  };
  draw();
}, { tab: "moods" });

function loadSamples() {
  const existing = new Set(db.songs.map((s) => C.duplicateKey(s.source)));
  let added = 0;
  for (const src of C.SAMPLE_SONGS) {
    if (existing.has(C.duplicateKey(src))) continue;
    const { song } = addSong(src);
    song.isReady = true;
    added++;
  }
  save();
  toast(added ? `Added ${plural(added, "sample song")}` : "The samples are already in your library");
  render();
}

function crowdSheet(mood) {
  if (!mood) return;
  const all = songsForMood(mood);
  const count = (c) => all.filter((s) => crowdOk(s, c)).length;
  openSheet(`<span class="chip small mood" style="--hue:${mood.hue}">${icon(mood.icon, true)} ${esc(mood.name)}</span>
    <span class="mono" style="margin-left:8px">${plural(all.length, "song")}</span>
    <h3>Who's listening?</h3><p class="lead">One tap. You can change it on the song list.</p>
    <div class="crowd-grid">${C.CROWDS.map((c) => `<button class="crowd-card" data-crowd="${c.id}">
      <span class="top">${icon(c.icon, true)}<span class="mono" style="font-size:10px">${plural(count(c.id), "song")}</span></span>
      <b>${c.title}</b><span class="s">${c.subtitle}</span></button>`).join("")}</div>
    <button class="anyone" data-crowd="anyone">${icon("all_inclusive")} Anyone · all ${plural(all.length, "song")}</button>`, {
    onOpen: (sh) => $$("[data-crowd]", sh).forEach((b) => b.addEventListener("click", () => { closeSheet(); go(`#/mood/${mood.id}/${b.dataset.crowd}`); })),
  });
}

// ================================================================ Song list

route("/mood/([^/]+)/([a-z]+)", (moodId, crowd) => {
  const mood = moodById(moodId);
  if (!mood) return replace("#/");
  const draw = () => {
    const songs = songsForMood(mood, crowd).sort(byTitle);
    const ready = songs.filter((s) => s.isReady), learning = songs.filter((s) => !s.isReady);
    const crowdTitle = crowd === "anyone" ? null : C.CROWDS.find((c) => c.id === crowd)?.title;
    app.innerHTML = `<div class="glow" style="--hue:${mood.hue}"></div><div class="screen">
      <div class="topbar"><button class="circle-btn glass" id="back" aria-label="Back">${icon("chevron_left")}</button><span class="spacer"></span>
        <button class="circle-btn glass" id="add" aria-label="Add a song">${icon("add")}</button></div>
      <div class="mood-head"><span class="mood-badge" style="--hue:${mood.hue}">${icon(mood.icon, true)}</span><h2 class="title">${esc(mood.name)}</h2></div>
      <div class="chips">${[["anyone", "Anyone"], ...C.CROWDS.map((c) => [c.id, c.title])].map(([id, t]) => `<button class="chip ${crowd === id ? "on" : ""}" data-c="${id}">${crowd === id ? icon("check") : ""}${t}</button>`).join("")}</div>
      ${db.prefs.language !== "all" ? `<p class="help">${icon("info")} Showing ${db.prefs.language} songs only. <a href="#" id="all-lang">Show all languages</a></p>` : ""}
      ${songs.length ? `
        ${ready.length ? `<div class="section-label"><span class="mono">Ready to play</span><span class="mono">${ready.length}</span></div><div class="list">${ready.map((s) => songRowHTML(s)).join("")}</div>` : ""}
        ${learning.length ? `<div class="section-label"><span class="mono">Still learning</span><span class="mono">${learning.length}</span></div><div class="list">${learning.map((s) => songRowHTML(s)).join("")}</div>` : ""}
        <p class="help" style="text-align:center;margin-top:18px">Long-press a song for quick actions.</p>`
      : `<div class="empty" style="--hue:${mood.hue}"><div class="badge">${icon(mood.icon, true)}</div>
          <h3>No ${esc(mood.name)} songs${crowdTitle ? ` for ${crowdTitle}` : ""} yet</h3>
          <p>${crowdTitle ? `${esc(mood.name)} has ${plural(songsForMood(mood).length, "song")}, just not tagged for this crowd.` : `Tag a song with {mood: ${esc(mood.name)}} to see it here.`}</p>
          ${crowdTitle && songsForMood(mood).length ? `<button class="text-btn primary" data-c="anyone">Show for Anyone</button><br>` : ""}
          <button class="link-btn" id="add2">${icon("add")} Add a song</button></div>`}
    </div>`;
    $("#back").addEventListener("click", () => back());
    $("#add").addEventListener("click", addSheet);
    $("#add2")?.addEventListener("click", addSheet);
    $("#all-lang")?.addEventListener("click", (e) => { e.preventDefault(); db.prefs.language = "all"; save(); draw(); });
    $$("[data-c]").forEach((b) => b.addEventListener("click", () => replace(`#/mood/${mood.id}/${b.dataset.c}`)));
    bindRows(app, draw);
  };
  draw();
});

// ================================================================ Favourites

route("/favourites", () => {
  const draw = () => {
    const favs = db.songs.filter((s) => s.isFavorite).sort(byTitle);
    app.innerHTML = `<div class="screen"><div class="topbar"></div>
      <h1 class="big">Favourites</h1><p class="mono" style="margin-top:6px">${plural(favs.length, "song")}</p>
      ${favs.length ? `<div class="list" style="margin-top:16px">${favs.map((s) => songRowHTML(s, { swatch: true })).join("")}</div>`
        : `<div class="empty"><div class="badge" style="--hue:50">${icon("star", true)}</div><h3>No favourites yet</h3><p>Tap the star on any song to keep it here.</p></div>`}
    </div>`;
    bindRows(app, draw);
  };
  draw();
}, { tab: "favourites" });

// ================================================================ Song page

route("/song/([^/]+)", (id) => {
  const song = songById(id);
  if (!song) return replace("#/");
  const draw = () => {
    const p = parsed(song);
    const sm = C.summary(p);
    const mood = moodFor(song);
    const hue = mood ? mood.hue : 50;
    const firstLyric = p.lines.find((l) => l.type === "lyrics" && l.segments.some((s) => s.text.trim()));
    const diagramChords = p.chords.filter((c) => C.chordShape(c));
    app.innerHTML = `<div class="glow" style="--hue:${hue}"></div><div class="screen no-tabs" style="padding-bottom:calc(var(--safe-b) + 120px)">
      <div class="topbar"><button class="circle-btn glass" id="back" aria-label="Back">${icon("chevron_left")}</button><span class="spacer"></span>
        <button class="circle-btn glass" id="fav" aria-label="${song.isFavorite ? "Remove from favourites" : "Add to favourites"}" style="color:${song.isFavorite ? "#F2742A" : "inherit"}">${icon("favorite", song.isFavorite)}</button>
        <button class="text-btn glass" id="edit">Edit</button></div>
      <div class="wrap-chips" style="margin-top:8px">
        ${p.moods.map((m) => { const md = db.moods.find((x) => C.normalizedName(x.name) === C.normalizedName(m)); return `<span class="chip small ${md ? "mood" : ""}" style="--hue:${md ? md.hue : 0}">${md ? icon(md.icon, true) : ""}${esc(m)}</span>`; }).join("")}
        ${p.crowds.map((c) => `<span class="chip small">${esc(c)}</span>`).join("")}
        ${p.language ? `<span class="chip small">${esc(p.language)}</span>` : ""}
      </div>
      <div class="song-title-row"><div class="tt"><h2 class="title">${esc(p.title)}</h2>${p.artist ? `<div class="muted" style="margin-top:2px">${esc(p.artist)}</div>` : ""}</div>
        <button class="ready-toggle" id="ready" role="switch" aria-checked="${song.isReady}">Ready <span class="switch ${song.isReady ? "on" : ""}"></span></button></div>
      <div class="card">
        <div class="mono">Cue card</div>
        <div class="specs">
          <div><div class="mono" style="font-size:10px">Key</div><div class="v">${esc(p.key || "?")}</div></div>
          <div><div class="mono" style="font-size:10px">Capo</div><div class="v">${p.capo ? "Fret " + p.capo : "None"}</div></div>
          <div><div class="mono" style="font-size:10px">Length</div><div class="v">${p.duration ? C.formatDuration(p.duration) : "~" + C.formatDuration(C.DEFAULT_DURATION)}</div></div>
        </div>
        <div class="cue-start"><div class="mono" style="font-size:10px;margin-bottom:4px">How it starts</div>
          ${firstLyric ? chordSheetHTML([firstLyric]) : `<div class="muted" style="font-style:italic">${esc(sm.cueLine)}</div>`}</div>
      </div>
      ${p.capo ? `<div class="capo-note">${icon("info")} Tune before putting the capo on. <button id="tuner">Tuner</button></div>` : ""}
      ${diagramChords.length ? `<div class="diagrams">${diagramChords.map((c) => `<div class="diagram"><div class="n">${esc(c)}</div>${diagramSVG(c)}</div>`).join("")}</div>` : ""}
      <div class="sheet-view">${chordSheetHTML(p.lines)}</div>
    </div>
    <button class="cap-btn accent play-fab" id="play">Play <small>${C.formatDuration(song.scrollSpeed ? p.effectiveDuration / song.scrollSpeed : p.effectiveDuration)}</small> ${icon("play_arrow", true)}</button>`;
    $("#back").addEventListener("click", () => back());
    $("#edit").addEventListener("click", () => go(`#/edit/${id}`));
    $("#fav").addEventListener("click", () => { song.isFavorite = !song.isFavorite; save(); draw(); toast(song.isFavorite ? "Added to favourites" : "Removed from favourites"); });
    $("#ready").addEventListener("click", () => { song.isReady = !song.isReady; save(); draw(); });
    $("#tuner")?.addEventListener("click", () => go("#/tuner"));
    $("#play").addEventListener("click", () => go(`#/play/${id}`));
    fixWrappedRows(app);
  };
  draw();
});

// ================================================================ Play mode

let wakeLock = null;
async function keepAwake(on) {
  try {
    if (on && "wakeLock" in navigator && !wakeLock) {
      wakeLock = await navigator.wakeLock.request("screen");
      wakeLock.addEventListener("release", () => { wakeLock = null; });
    } else if (!on && wakeLock) { await wakeLock.release(); wakeLock = null; }
  } catch { /* not supported or not allowed */ }
}

route("/play/([^/]+)", (id) => {
  const song = songById(id);
  if (!song) return replace("#/");
  const p = parsed(song);
  const duration = Math.max(p.effectiveDuration, 10);
  const lines = p.lines.filter((l) => l.type !== "note");
  document.documentElement.style.background = "#0C0907";
  app.innerHTML = `<div class="play stage-mode" id="play">
    <div class="lyrics" id="lyrics" style="--pfs:${db.prefs.playFontSize}px">${chordSheetHTML(lines)}</div>
    <div class="fade-b"></div>
    <div class="head"><div class="progress"><i id="prog"></i></div>
      <div class="hrow"><button class="x" id="exit" aria-label="Exit play mode"><span>${icon("close")}</span></button>
        <span class="status mono" id="status">${esc(p.title)}</span><span class="left mono" id="left">-${C.formatDuration(duration)}</span></div></div>
    <div id="ov"></div><div id="toastspot"></div>
  </div>`;
  const root = $("#play"), lyr = $("#lyrics"), ov = $("#ov"), prog = $("#prog"), left = $("#left"), status = $("#status");
  let phase = "count", count = 3, t = 0, last = 0, raf = 0, countTimer = 0, lineEls = [], tops = [], contentH = 0;
  const topInset = () => Math.max(140, 100 + (parseFloat(getComputedStyle(root).getPropertyValue("--safe-t")) || 0));
  const readingLine = () => root.clientHeight * 0.32;
  const travel = () => Math.max(contentH + topInset() - readingLine() - 60, 0);
  const measure = () => {
    fixWrappedRows(lyr);
    lineEls = $$("[data-i]", lyr);
    tops = lineEls.map((el) => el.offsetTop);
    contentH = lyr.scrollHeight;
  };
  const opening = p.chords.filter(C.isChord).slice(0, 4);

  function paint() {
    const frac = Math.min(t / duration, 1);
    const off = travel() * frac;
    lyr.style.transform = `translateY(${topInset() - off}px)`;
    prog.style.width = `${frac * 100}%`;
    left.textContent = "-" + C.formatDuration(Math.max(duration - t, 0));
    const reading = off + readingLine() - topInset();
    let cur = -1;
    tops.forEach((top, i) => { if (top <= reading + 4) cur = i; });
    lineEls.forEach((el, i) => {
      el.classList.toggle("cur", i === cur && el.classList.contains("ln"));
      el.classList.toggle("past", i < cur);
    });
  }
  function setStatus() {
    status.textContent = phase === "paused" ? "Paused" : phase === "done" ? "Finished" : song.scrollSpeed !== 1 && phase === "playing" ? `${song.scrollSpeed.toFixed(1)}×` : p.title;
  }
  function show() {
    setStatus();
    if (phase === "count") {
      ov.innerHTML = `<div class="ov count"><div class="mono">Get ready</div><div class="num">${count}</div>
        ${opening.length ? `<div class="starts"><span class="mono">Starts on</span>${opening.map((c) => `<b>${esc(c)}</b>`).join("")}</div>` : ""}
        <p class="muted" style="margin-top:34px">Tap to skip the count</p></div>`;
    } else if (phase === "paused") {
      ov.innerHTML = `<div class="ov paused"><div class="pbtn">${icon("play_arrow", true)}</div><h3>Paused</h3>
        <div class="muted" style="font-weight:600">Tap anywhere to resume · drag to scroll</div>
        <div class="mono" style="margin-top:12px" id="pt">${C.formatDuration(t)} of ${C.formatDuration(duration)}</div>
        <div class="tsize"><button data-fs="-2" aria-label="Smaller text">${icon("text_decrease")}</button>Text size<button data-fs="2" aria-label="Larger text">${icon("text_increase")}</button></div>
        <div class="hints"><span>${icon("swipe_vertical")} Swipe up or down to change speed</span><span>${icon("keyboard_double_arrow_down")} Swipe down from the top to exit</span></div></div>`;
      $$("[data-fs]", ov).forEach((b) => b.addEventListener("click", (e) => {
        e.stopPropagation();
        db.prefs.playFontSize = Math.min(Math.max(db.prefs.playFontSize + Number(b.dataset.fs), 18), 44);
        save();
        lyr.style.setProperty("--pfs", db.prefs.playFontSize + "px");
        measure(); paint();
      }));
    } else if (phase === "done") {
      ov.innerHTML = `<div class="ov paused" style="background:rgb(12 9 7 / 0.9)"><div class="mono">Song finished</div><h3 style="margin-top:8px">That was ${esc(p.title)}</h3>
        <div class="stack" style="width:min(320px,100%);margin-top:24px"><button class="cap-btn accent" id="again">${icon("replay")} Play again</button>
        <button class="cap-btn glass" id="done">${icon("check")} Done</button></div></div>`;
      $("#again").addEventListener("click", (e) => { e.stopPropagation(); t = 0; startCount(); });
      $("#done").addEventListener("click", (e) => { e.stopPropagation(); back(`#/song/${id}`); });
    } else ov.innerHTML = "";
  }
  function startCount() {
    phase = "count"; count = 3; show(); paint();
    clearInterval(countTimer);
    countTimer = setInterval(() => {
      count--;
      if (count <= 0) { clearInterval(countTimer); startPlay(); } else show();
    }, 1000);
  }
  function startPlay() {
    clearInterval(countTimer);
    phase = "playing"; show(); last = performance.now();
    cancelAnimationFrame(raf);
    const step = (now) => {
      if (phase !== "playing") return;
      t += ((now - last) / 1000) * song.scrollSpeed;
      last = now;
      if (t >= duration) { t = duration; paint(); phase = "done"; show(); return; }
      paint();
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  }
  function pause() { phase = "paused"; cancelAnimationFrame(raf); show(); }

  let toastT;
  function nudge(stepV) {
    song.scrollSpeed = Math.min(Math.max(Math.round((song.scrollSpeed + stepV) * 10) / 10, 0.5), 2);
    save(); setStatus();
    const up = stepV > 0;
    $("#toastspot").innerHTML = `<div class="speed-toast">${icon(up ? "keyboard_double_arrow_up" : "keyboard_double_arrow_down")}${up ? "Faster" : "Slower"} <em>· saved for this song</em><b>${song.scrollSpeed.toFixed(1)}×</b></div>`;
    clearTimeout(toastT);
    toastT = setTimeout(() => { const el = $("#toastspot"); if (el) el.innerHTML = ""; }, 1400);
  }

  // Gestures: tap = pause/resume, vertical swipe = speed (or scrub while paused), down from top = exit.
  let start = null;
  root.addEventListener("pointerdown", (e) => {
    if (e.target.closest("button")) return;
    start = { x: e.clientX, y: e.clientY, t0: t, moved: false };
  });
  root.addEventListener("pointermove", (e) => {
    if (!start) return;
    const dy = e.clientY - start.y;
    if (Math.abs(dy) > 24 || Math.abs(e.clientX - start.x) > 24) start.moved = true;
    if (phase === "paused" && start.moved && travel() > 0) {
      t = Math.min(Math.max(start.t0 - (dy / travel()) * duration, 0), duration);
      paint();
      const pt = $("#pt"); if (pt) pt.textContent = `${C.formatDuration(t)} of ${C.formatDuration(duration)}`;
    }
  });
  root.addEventListener("pointerup", (e) => {
    if (!start) return;
    const dy = e.clientY - start.y, dx = e.clientX - start.x;
    const s = start; start = null;
    if (s.y < 110 + 40 && dy > 80) { back(`#/song/${id}`); return; }
    if (!s.moved) {
      if (phase === "count") startPlay();
      else if (phase === "playing") pause();
      else if (phase === "paused") startPlay();
      return;
    }
    if (phase === "playing" && Math.abs(dy) > 40 && Math.abs(dy) > Math.abs(dx)) nudge(dy < 0 ? 0.1 : -0.1);
  });
  root.addEventListener("pointercancel", () => { start = null; });
  $("#exit").addEventListener("click", (e) => { e.stopPropagation(); back(`#/song/${id}`); });
  const onKey = (e) => {
    if (e.key === " ") { e.preventDefault(); phase === "playing" ? pause() : startPlay(); }
    else if (e.key === "ArrowUp" && phase === "playing") nudge(0.1);
    else if (e.key === "ArrowDown" && phase === "playing") nudge(-0.1);
    else if (e.key === "Escape") back(`#/song/${id}`);
  };
  document.addEventListener("keydown", onKey);
  const onVis = () => { if (document.visibilityState === "visible") keepAwake(true); else if (phase === "playing") pause(); };
  document.addEventListener("visibilitychange", onVis);
  const onResize = () => { measure(); paint(); };
  window.addEventListener("resize", onResize);

  measure();
  if (document.fonts) document.fonts.ready.then(() => { measure(); paint(); });
  keepAwake(true);
  startCount();

  return () => {
    cancelAnimationFrame(raf); clearInterval(countTimer); clearTimeout(toastT);
    document.removeEventListener("keydown", onKey);
    document.removeEventListener("visibilitychange", onVis);
    window.removeEventListener("resize", onResize);
    document.documentElement.style.background = "";
    keepAwake(false);
  };
});

// ================================================================ Tuner

route("/tuner", () => {
  let stream = null, ctx = null, analyser = null, timer = 0, locked = null, recent = [], lastHeard = 0, alive = true;
  const drawIntro = (denied = false) => {
    app.innerHTML = `<div class="screen"><div class="mic-hero">
      <div class="mic">${icon("mic", true)}</div>
      <h2>Let the tuner hear your guitar</h2>
      <p>Moodchords uses the microphone only while the tuner is open, to hear which note you're playing.</p>
      <div class="banner ok">${icon("lock")} <span>Sound stays on your phone. Nothing is recorded or sent.</span></div>
      ${denied ? `<div class="banner err">${icon("error")} <span><b>Microphone is blocked.</b>Allow it for this site in your browser's settings, then try again.</span></div>` : ""}
      <div style="margin-top:30px"><button class="cap-btn dark" id="allow">Allow microphone</button></div>
    </div></div>`;
    $("#allow").addEventListener("click", start);
  };
  const drawTuner = () => {
    app.innerHTML = `<div class="screen tuner">
      <div class="nav-head"><span></span><span class="ttl">Tuner</span><span class="mono" style="font-size:10px">A4 · 440</span></div>
      <div class="strip">STANDARD · E A D G B E</div>
      <div class="note idle" id="note">–</div>
      <div class="which" id="which">Listening…</div>
      <div class="hz mono" id="hz" style="text-transform:none">Pluck any open string</div>
      <div class="meter"><div class="zone"></div><div class="ticks">${Array.from({ length: 21 }, (_, i) => `<i class="${i === 10 ? "mid" : ""}"></i>`).join("")}</div><div class="needle idle" id="needle"></div></div>
      <div class="meter-labels mono" style="font-size:10px"><span>♭ Flat</span><span>Sharp ♯</span></div>
      <div class="tune-label" id="label">${icon("touch_app")} Pluck a string</div>
      <div class="strings">${C.STRINGS.map((s) => `<button data-s="${s.number}" aria-label="${C.ordinal(s.number)} string ${s.note}">${s.note}</button>`).join("")}</div>
      <p class="help" id="mode">Auto-detect · tap a string to lock it</p>
    </div>`;
    $$("[data-s]").forEach((b) => b.addEventListener("click", () => {
      const n = Number(b.dataset.s);
      locked = locked === n ? null : n;
      $$("[data-s]").forEach((x) => x.classList.toggle("locked", Number(x.dataset.s) === locked));
      $("#mode").textContent = locked ? `Locked to the ${C.ordinal(locked)} string · tap it again for auto-detect` : "Auto-detect · tap a string to lock it";
    }));
  };
  async function start() {
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false } });
    } catch (e) {
      if (alive) drawIntro(true);
      return;
    }
    if (!alive) { stream.getTracks().forEach((t) => t.stop()); return; }
    sessionStorage.setItem("mc.mic", "1");
    drawTuner();
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === "suspended") await ctx.resume().catch(() => {});
    const src = ctx.createMediaStreamSource(stream);
    analyser = ctx.createAnalyser();
    analyser.fftSize = 4096;
    src.connect(analyser);
    const buf = new Float32Array(analyser.fftSize);
    timer = setInterval(() => {
      analyser.getFloatTimeDomainData(buf);
      const f = C.detectPitch(buf, ctx.sampleRate);
      update(f);
    }, 70);
  }
  function update(f) {
    const now = performance.now();
    if (f) {
      recent.push(f); if (recent.length > 3) recent.shift();
      lastHeard = now;
    } else if (now - lastHeard > 1200) recent = [];
    const noteEl = $("#note"), needle = $("#needle"), label = $("#label"), which = $("#which"), hz = $("#hz");
    if (!noteEl) return;
    if (!recent.length) {
      noteEl.className = "note idle"; noteEl.textContent = "–";
      which.textContent = "Listening…"; hz.textContent = "Pluck any open string";
      needle.className = "needle idle"; needle.style.left = "50%";
      label.className = "tune-label"; label.innerHTML = `${icon("touch_app")} Pluck a string`;
      $$("[data-s]").forEach((x) => x.classList.remove("on"));
      return;
    }
    const freq = [...recent].sort((a, b) => a - b)[Math.floor(recent.length / 2)];
    const target = locked ? C.STRINGS.find((s) => s.number === locked) : C.nearestString(freq);
    const c = C.cents(freq, target.frequency);
    const ok = Math.abs(c) <= C.IN_TUNE_CENTS;
    noteEl.className = "note" + (ok ? " ok" : "");
    noteEl.textContent = target.note;
    which.textContent = `${C.ordinal(target.number)} string · ${target.note}`;
    hz.textContent = `${freq.toFixed(1)} Hz · target ${target.frequency.toFixed(1)}`;
    const clamped = Math.max(-50, Math.min(50, c));
    needle.style.left = `${50 + clamped}%`;
    needle.className = "needle" + (ok ? " ok" : "");
    if (ok) { label.className = "tune-label ok"; label.innerHTML = `${icon("check_circle", true)} In tune`; }
    else if (c < 0) { label.className = "tune-label up"; label.innerHTML = `${icon("arrow_upward")} Tune up <span class="mono" style="color:inherit;opacity:.8">${Math.round(c)}¢</span>`; }
    else { label.className = "tune-label down"; label.innerHTML = `${icon("arrow_downward")} Tune down <span class="mono" style="color:inherit;opacity:.8">+${Math.round(c)}¢</span>`; }
    $$("[data-s]").forEach((x) => x.classList.toggle("on", Number(x.dataset.s) === target.number));
  }
  // If permission was already granted, start straight away.
  if (navigator.permissions?.query) {
    navigator.permissions.query({ name: "microphone" }).then((st) => { if (!alive) return; if (st.state === "granted") start(); else if (st.state === "denied") drawIntro(true); }).catch(() => { if (sessionStorage.getItem("mc.mic")) start(); });
  } else if (sessionStorage.getItem("mc.mic")) start();
  drawIntro();
  return () => {
    alive = false;
    clearInterval(timer);
    stream?.getTracks().forEach((t) => t.stop());
    ctx?.close().catch(() => {});
  };
}, { tab: "tuner" });

// ================================================================ Add songs

function addSheet() {
  openSheet(`<h3 style="font-size:26px;margin-top:0">Add a song</h3><p class="lead">Bring in songs you already play.</p>
    <div class="stack">
      <button class="option" data-a="paste"><span class="oi accent">${icon("content_paste")}</span><span><b>Paste song</b><span>Lyrics with [chords], from notes or a website</span></span><span class="chev">${icon("chevron_right")}</span></button>
      <button class="option" data-a="file"><span class="oi">${icon("description")}</span><span><b>Import files</b><span>.txt or ChordPro (.cho), one song per file, or a backup</span></span><span class="chev">${icon("chevron_right")}</span></button>
      ${"webkitdirectory" in document.createElement("input") && !isIOS() ? `<button class="option" data-a="folder"><span class="oi">${icon("folder_open")}</span><span><b>Import a folder</b><span>Every song file inside, sorted by language folder</span></span><span class="chev">${icon("chevron_right")}</span></button>` : ""}
      <button class="option" data-a="samples"><span class="oi">${icon("library_music")}</span><span><b>Sample songs</b><span>Two original songs to try the app</span></span><span class="chev">${icon("chevron_right")}</span></button>
    </div>
    <div style="text-align:center"><button class="link-btn" data-a="template">${icon("description")} Start from the template</button></div>`, {
    onOpen: (sh) => $$("[data-a]", sh).forEach((b) => b.addEventListener("click", () => {
      const a = b.dataset.a;
      closeSheet();
      if (a === "paste") go("#/paste");
      if (a === "template") go("#/paste/template");
      if (a === "file") pickFiles(false);
      if (a === "folder") pickFiles(true);
      if (a === "samples") loadSamples();
    })),
  });
}

route("/paste(/template)?", (tpl) => {
  let text = tpl ? C.TEMPLATE : "";
  app.innerHTML = `<div class="screen no-tabs">
    <div class="nav-head"><button class="text-btn glass" id="cancel">Cancel</button><span class="ttl">Paste song</span><button class="text-btn primary" id="done" disabled>Add</button></div>
    <div class="wrap-chips" style="margin:8px 0"><button class="chip small" id="tpl">${icon("description")} Template</button><button class="chip small" id="clip">${icon("content_paste")} Paste</button></div>
    <div id="status"></div>
    <textarea class="editor" id="src" spellcheck="false" autocapitalize="off" autocomplete="off" autocorrect="off" placeholder="{title: Song Title}&#10;{key: G}&#10;{mood: Campfire}&#10;&#10;[G]Put each chord in [C]brackets…&#10;&#10;Or paste a sheet with chords above the lyrics."></textarea>
    <p class="help">Put each chord in [brackets] right before the word it lands on. Sheets copied from chord websites (chords on the line above) are converted for you.</p>
  </div>`;
  const ta = $("#src"), st = $("#status"), done = $("#done");
  ta.value = text;
  const check = () => {
    text = ta.value;
    if (!text.trim()) { st.innerHTML = ""; done.disabled = true; return null; }
    const converted = C.convertIfNeeded(text);
    try {
      const p = C.parse(converted);
      const warn = p.warnings.filter((w) => !w.message.startsWith("No {duration"));
      st.innerHTML = `<div class="banner ok">${icon("check_circle", true)}<span><b>${esc(p.title)}</b>${converted !== text ? "Chords above the lyrics will be moved inline. " : ""}${plural(p.chords.length, "chord")}${p.moods.length ? " · " + esc(p.moods.join(", ")) : " · no mood yet"}${p.duration ? "" : " · no length, 3:30 assumed"}</span></div>`
        + (warn.length ? `<div class="banner warn">${icon("info")}<span>${warn.slice(0, 3).map((w) => esc(`Line ${w.line}: ${w.message}`)).join("<br>")}</span></div>` : "");
      done.disabled = false;
      return converted;
    } catch (e) {
      st.innerHTML = `<div class="banner err">${icon("error", true)}<span><b>${esc(e.message.includes("title") ? "The song needs a title" : e.message)}</b>${e.message.includes("title") ? "Add a first line like <code>{title: Campfire Night}</code>" : ""}</span></div>`;
      done.disabled = true;
      return null;
    }
  };
  ta.addEventListener("input", check);
  $("#tpl").addEventListener("click", () => { if (!ta.value.trim() || confirm("Replace the text with the template?")) { ta.value = C.TEMPLATE; check(); } });
  $("#clip").addEventListener("click", async () => {
    try { const clip = await navigator.clipboard.readText(); if (clip) { ta.value = clip; check(); } }
    catch { ta.focus(); toast("Long-press in the box and choose Paste"); }
  });
  $("#cancel").addEventListener("click", () => back());
  done.addEventListener("click", () => {
    const src = check();
    if (!src) return;
    const dupe = db.songs.find((s) => C.duplicateKey(s.source) === C.duplicateKey(src));
    if (dupe) { toast("That song is already in your library"); return; }
    const { song } = addSong(src);
    save();
    toast("Song added");
    replace(`#/song/${song.id}`);
  });
  check();
  if (!tpl) ta.focus();
});

let lastReport = null;
function pickFiles(folder) {
  const input = document.createElement("input");
  input.type = "file";
  input.multiple = true;
  if (folder) input.webkitdirectory = true;
  else input.accept = ".txt,.text,.cho,.chordpro,.chopro,.crd,.pro,.json,text/plain,application/json";
  input.addEventListener("change", async () => {
    const files = [...input.files];
    if (!files.length) return;
    if (files.length === 1 && files[0].name.toLowerCase().endsWith(".json")) return restoreBackup(files[0]);
    lastReport = await importFiles(files, folder);
    go("#/imported");
  });
  input.click();
}

async function importFiles(files, fromFolder) {
  const report = { added: [], languageUpdates: 0, fileCount: 0, folderName: null, checks: [] };
  const existing = new Map(db.songs.map((s) => [C.duplicateKey(s.source), s]));
  const moodKeys = new Set(db.moods.map((m) => C.normalizedName(m.name)));
  files.sort((a, b) => (a.webkitRelativePath || a.name).localeCompare(b.webkitRelativePath || b.name, undefined, { numeric: true }));
  for (const file of files) {
    const name = file.name;
    const rel = file.webkitRelativePath || "";
    if (rel && !report.folderName) report.folderName = rel.split("/")[0];
    if (name.startsWith(".")) continue;
    const ext = name.split(".").pop().toLowerCase();
    if (!C.SONG_EXTENSIONS.includes(ext)) {
      if (fromFolder) report.checks.push({ title: name, kind: "skipped", message: "Skipped. It isn't a song file." });
      continue;
    }
    report.fileCount++;
    let text;
    try { text = await file.text(); } catch { report.checks.push({ title: name, kind: "problem", message: "Couldn't read the file as text." }); continue; }
    let source = C.convertIfNeeded(text);
    const parts = rel.split("/");
    const folderLang = parts.length > 1 ? C.languageFromName(parts[parts.length - 2]) : null;
    if (folderLang && C.fieldValue("language", source) === null) source = C.setField("language", folderLang, source);
    const dupe = existing.get(C.duplicateKey(source));
    if (dupe) {
      const incoming = folderLang || C.languageFromName(C.fieldValue("language", source));
      if (incoming && !parsed(dupe).language) {
        const updated = C.setField("language", incoming, dupe.source);
        if (C.tryParse(updated)) { dupe.source = updated; report.languageUpdates++; continue; }
      }
      report.checks.push({ title: name, kind: "skipped", message: "Already in your library, so it was skipped." });
      continue;
    }
    try {
      const { song, parsed: p } = addSong(source);
      existing.set(C.duplicateKey(source), song);
      report.added.push(p.title);
      for (const w of p.warnings) report.checks.push({ title: p.title, kind: w.message.includes("duration") ? "length" : "problem", message: w.message });
      if (!p.key) report.checks.push({ title: p.title, kind: "key", message: "No key set. Add {key: G} so the cue card can show it." });
      if (!p.moods.length) report.checks.push({ title: p.title, kind: "mood", message: "No mood tags, so it won't show on the mood grid. Edit it to add one." });
      for (const m of p.moods) if (!moodKeys.has(C.normalizedName(m))) report.checks.push({ title: p.title, kind: "mood", message: `“${m}” isn't one of your moods yet. Add it in Moods to see this song there.` });
    } catch (e) {
      report.checks.push({ title: name, kind: "problem", message: e.message || "Couldn't read this song." });
    }
  }
  save();
  return report;
}

route("/imported", () => {
  const r = lastReport;
  if (!r) return replace("#/");
  const kindIcon = { length: "timer", key: "music_note", mood: "sentiment_very_satisfied", skipped: "block", problem: "warning" };
  app.innerHTML = `<div class="screen no-tabs">
    <div class="nav-head"><span></span><span></span><button class="text-btn primary" id="done">Done</button></div>
    ${r.added.length ? `<div class="done-badge">${icon("check", true)}</div>` : ""}
    <h2 class="title" style="margin-top:14px">${r.added.length ? `Added ${plural(r.added.length, "song")}` : "No new songs added"}</h2>
    <p class="muted">From ${plural(r.fileCount, "file")}${r.folderName ? ` in “${esc(r.folderName)}”` : ""}.${r.added.length ? " They're sorted into your moods already." : ""}${r.languageUpdates ? ` ${plural(r.languageUpdates, "song")} got a language from the folder name.` : ""}</p>
    ${r.added.length ? `<div class="wrap-chips">${r.added.slice(0, 8).map((t) => `<span class="chip small">${esc(t)}</span>`).join("")}${r.added.length > 8 ? `<span class="chip small">+${r.added.length - 8} more</span>` : ""}</div>` : ""}
    ${r.checks.length ? `<div class="section-label"><span class="mono">${plural(r.checks.length, "thing")} to check</span></div>
      <div class="list checks">${r.checks.map((c) => `<div class="check">${icon(kindIcon[c.kind] || "info")}<span><b>${esc(c.title)}</b><span>${esc(c.message)}</span></span></div>`).join("")}</div>` : ""}
    <div style="margin-top:26px"><button class="cap-btn accent" id="moods">Go to my moods</button></div>
  </div>`;
  const leave = () => replace("#/");
  $("#done").addEventListener("click", leave);
  $("#moods").addEventListener("click", leave);
});

// ================================================================ Edit song

route("/edit/([^/]+)", (id) => {
  const song = songById(id);
  if (!song) return replace("#/");
  let source = song.source, mode = "edit";
  const draw = () => {
    const p = C.tryParse(source);
    const moodsInSong = C.fieldList("mood", source);
    const extraMoods = moodsInSong.filter((m) => !db.moods.some((x) => C.normalizedName(x.name) === C.normalizedName(m)));
    const crowds = C.fieldList("crowd", source).map(C.normalizedName);
    const lang = C.languageFromName(C.fieldValue("language", source));
    app.innerHTML = `<div class="screen no-tabs">
      <div class="nav-head"><button class="text-btn glass" id="cancel">Cancel</button><span class="ttl">Edit song</span><button class="text-btn primary" id="done" ${p ? "" : "disabled"}>Done</button></div>
      <div class="seg"><button data-m="edit" class="${mode === "edit" ? "on" : ""}">${icon("code")} Edit</button><button data-m="preview" class="${mode === "preview" ? "on" : ""}">${icon("visibility")} Live preview</button></div>
      <div id="err">${p ? "" : `<div class="banner err">${icon("error", true)}<span><b>The song needs a title</b>Add a line like {title: My Song}.</span></div>`}</div>
      <label class="field"><span class="mono">Title</span><input data-f="title" value="${esc(C.fieldValue("title", source) ?? "")}"></label>
      <label class="field"><span class="mono">Artist</span><input data-f="artist" value="${esc(C.fieldValue("artist", source) ?? "")}"></label>
      <div class="field-row">
        <label class="field"><span class="mono">Key</span><input data-f="key" value="${esc(C.fieldValue("key", source) ?? "")}" placeholder="G" autocapitalize="characters"></label>
        <label class="field"><span class="mono">Capo</span><input data-f="capo" value="${esc(C.fieldValue("capo", source) ?? "")}" placeholder="None" inputmode="numeric"></label>
        <label class="field"><span class="mono">Length</span><input data-f="duration" value="${esc(C.fieldValue("duration", source) ?? "")}" placeholder="3:30" inputmode="numeric"></label>
      </div>
      <span class="mono group-label">Moods</span>
      <div class="wrap-chips">${db.moods.map((m) => { const on = moodsInSong.some((x) => C.normalizedName(x) === C.normalizedName(m.name)); return `<button class="chip small mood ${on ? "" : "off"}" style="--hue:${m.hue}" data-mood="${esc(m.name)}">${icon(on ? "check" : m.icon, true)} ${esc(m.name)}</button>`; }).join("")}
        ${extraMoods.map((m) => `<button class="chip small on" data-mood="${esc(m)}" title="Not one of your moods">${icon("check")} ${esc(m)}</button>`).join("")}</div>
      <span class="mono group-label">Who's listening</span>
      <div class="wrap-chips">${C.CROWDS.map((c) => `<button class="chip small ${crowds.includes(c.id) ? "on" : ""}" data-crowd="${c.id}">${icon(crowds.includes(c.id) ? "check" : c.icon, true)} ${c.title}</button>`).join("")}</div>
      <span class="mono group-label">Language</span>
      <div class="wrap-chips">${["", ...C.LANGUAGES].map((l) => `<button class="chip small ${(lang || "") === l ? "on" : ""}" data-lang="${l}">${l || "None"}</button>`).join("")}</div>
      <span class="mono group-label">Song</span>
      <div id="body"></div>
      <button class="danger-btn" id="delete">${icon("delete")} Delete song</button>
    </div>`;
    const body = $("#body");
    if (mode === "edit") {
      body.innerHTML = `<textarea class="editor" id="src" spellcheck="false" autocapitalize="off" autocomplete="off" autocorrect="off"></textarea>
        <p class="help">Chords go in [brackets] right before the syllable. Headings: {comment: Verse 1}.</p>`;
      const ta = $("#src");
      ta.value = source;
      ta.style.height = Math.max(320, ta.scrollHeight + 10) + "px";
      ta.addEventListener("input", () => {
        source = ta.value;
        const ok = C.tryParse(source);
        $("#done").disabled = !ok;
        $("#err").innerHTML = ok ? "" : `<div class="banner err">${icon("error", true)}<span><b>The song needs a title</b>Add a line like {title: My Song}.</span></div>`;
        $$("[data-f]").forEach((inp) => { if (document.activeElement !== inp) inp.value = C.fieldValue(inp.dataset.f, source) ?? ""; });
      });
      ta.addEventListener("change", () => { const y = scrollY; draw(); scrollTo(0, y); });
    } else {
      body.innerHTML = `<div class="card" style="margin-top:0">${p ? chordSheetHTML(p.lines) : '<span class="muted">Nothing to preview yet.</span>'}</div>`;
      fixWrappedRows(body);
    }
    $$("[data-f]").forEach((inp) => inp.addEventListener("input", () => {
      source = C.setField(inp.dataset.f, inp.value, source);
      const ta = $("#src"); if (ta) ta.value = source;
      const ok = C.tryParse(source);
      $("#done").disabled = !ok;
    }));
    $$("[data-mood]").forEach((b) => b.addEventListener("click", () => {
      const name = b.dataset.mood;
      let list = C.fieldList("mood", source);
      list = list.some((x) => C.normalizedName(x) === C.normalizedName(name)) ? list.filter((x) => C.normalizedName(x) !== C.normalizedName(name)) : [...list, name];
      source = C.setFieldList("mood", list, source); redraw();
    }));
    $$("[data-crowd]").forEach((b) => b.addEventListener("click", () => {
      const cr = C.CROWDS.find((c) => c.id === b.dataset.crowd);
      let list = C.fieldList("crowd", source);
      list = list.some((x) => C.normalizedName(x) === cr.id) ? list.filter((x) => C.normalizedName(x) !== cr.id) : [...list, cr.title];
      source = C.setFieldList("crowd", list, source); redraw();
    }));
    $$("[data-lang]").forEach((b) => b.addEventListener("click", () => { source = C.setField("language", b.dataset.lang, source); redraw(); }));
    $$("[data-m]").forEach((b) => b.addEventListener("click", () => { mode = b.dataset.m; redraw(); }));
    $("#cancel").addEventListener("click", () => back(`#/song/${id}`));
    $("#done").addEventListener("click", () => {
      if (!C.tryParse(source)) return;
      song.source = source; save(); toast("Saved"); back(`#/song/${id}`);
    });
    $("#delete").addEventListener("click", () => {
      if (!confirm(`Delete “${parsed(song).title}”? This can't be undone.`)) return;
      db.songs = db.songs.filter((s) => s.id !== id); save(); toast("Song deleted");
      replace("#/");
    });
  };
  const redraw = () => { const y = scrollY; draw(); scrollTo(0, y); };
  draw();
});

// ================================================================ Moods manager

route("/moods", () => {
  const draw = () => {
    app.innerHTML = `<div class="screen no-tabs">
      <div class="topbar"><button class="circle-btn glass" id="back" aria-label="Back">${icon("chevron_left")}</button><span class="spacer"></span></div>
      <h1 class="big">Moods</h1><p class="muted">Rename, recolour and reorder. The 9 starting moods can't be deleted.</p>
      <div class="list" style="margin-top:14px">${db.moods.map((m, i) => `<div class="mood-row" style="--hue:${m.hue}"><span class="dot">${icon(m.icon, true)}</span>
        <span class="nm">${esc(m.name)}<small class="mono" style="font-size:10px">${plural(db.songs.filter((s) => hasMood(s, m.name)).length, "song")}</small></span>
        <span class="acts"><button data-up="${i}" ${i === 0 ? "disabled" : ""} aria-label="Move up">${icon("arrow_upward")}</button><button data-down="${i}" ${i === db.moods.length - 1 ? "disabled" : ""} aria-label="Move down">${icon("arrow_downward")}</button><button data-edit="${m.id}" aria-label="Edit ${esc(m.name)}">${icon("edit")}</button></span></div>`).join("")}</div>
      <button class="link-btn" id="new" style="margin-left:6px">${icon("add_circle")} New mood</button>
      <span class="mono group-label" style="margin-top:30px">Your library</span>
      <div class="menu">
        <button id="backup">Back up all songs<span>${icon("download")}</span></button>
        <button id="restore">Restore from a backup<span>${icon("upload_file")}</span></button>
        <button id="theme">Appearance: ${({ "": "Match system", light: "Light", dark: "Stage (dark)" })[db.prefs.theme || ""]}<span>${icon("bedtime")}</span></button>
      </div>
      <p class="help">Songs are saved in this browser only. Back up before clearing browser data or switching phones.</p>
    </div>`;
    $("#back").addEventListener("click", () => back());
    $("#new").addEventListener("click", () => moodEditor(null, draw));
    $$("[data-edit]").forEach((b) => b.addEventListener("click", () => moodEditor(moodById(b.dataset.edit), draw)));
    $$("[data-up]").forEach((b) => b.addEventListener("click", () => { const i = +b.dataset.up; [db.moods[i - 1], db.moods[i]] = [db.moods[i], db.moods[i - 1]]; save(); draw(); }));
    $$("[data-down]").forEach((b) => b.addEventListener("click", () => { const i = +b.dataset.down; [db.moods[i + 1], db.moods[i]] = [db.moods[i], db.moods[i + 1]]; save(); draw(); }));
    $("#backup").addEventListener("click", downloadBackup);
    $("#restore").addEventListener("click", () => pickFiles(false));
    $("#theme").addEventListener("click", () => {
      const order = ["", "light", "dark"];
      db.prefs.theme = order[(order.indexOf(db.prefs.theme || "") + 1) % 3];
      save(); applyTheme(); draw();
    });
  };
  draw();
});

function moodEditor(mood, done) {
  let name = mood ? mood.name : "", hue = mood ? mood.hue : 245, ic = mood ? mood.icon : "bedtime";
  const drawSheet = (sh) => {
    sh.innerHTML = `<div class="grabber"></div>
      <div class="nav-head"><button class="text-btn glass" data-a="cancel">Cancel</button><span class="ttl">${mood ? "Edit mood" : "New mood"}</span><button class="text-btn primary" data-a="save">${mood ? "Save" : "Add"}</button></div>
      <div class="preview-tile"><div class="tile" style="--hue:${hue}"><span class="sym">${icon(ic, true)}</span><span class="bgsym">${icon(ic, true)}</span><span class="name">${esc(name || "New mood")}</span><span class="count">${plural(mood ? db.songs.filter((s) => hasMood(s, mood.name)).length : 0, "song")}</span></div></div>
      <label class="field"><span class="mono">Name</span><input id="mname" value="${esc(name)}" placeholder="e.g. Hostel nights" maxlength="24"></label>
      <span class="mono group-label">Colour</span>
      <div class="swatches">${C.MOOD_HUES.map((h) => `<button data-h="${h}" class="${h === hue ? "on" : ""}" style="--hue:${h}" aria-label="Colour ${h}">${h === hue ? icon("check") : ""}</button>`).join("")}</div>
      <span class="mono group-label">Icon</span>
      <div class="icon-grid">${C.MOOD_ICON_CHOICES.map((x) => `<button data-i="${x}" class="${x === ic ? "on" : ""}" aria-label="${x.replace(/_/g, " ")}">${icon(x, true)}</button>`).join("")}</div>
      ${mood && !mood.isDefault ? `<button class="danger-btn" data-a="delete">${icon("delete")} Delete mood</button><p class="help">Songs keep their tag, so adding the mood back brings them back.</p>` : ""}`;
    const nameInput = $("#mname", sh);
    nameInput.addEventListener("input", () => { name = nameInput.value; $(".name", sh).textContent = name || "New mood"; });
    $$("[data-h]", sh).forEach((b) => b.addEventListener("click", () => { hue = +b.dataset.h; drawSheet(sh); }));
    $$("[data-i]", sh).forEach((b) => b.addEventListener("click", () => { ic = b.dataset.i; drawSheet(sh); }));
    $$("[data-a]", sh).forEach((b) => b.addEventListener("click", () => {
      const a = b.dataset.a;
      if (a === "cancel") return closeSheet();
      if (a === "delete") {
        if (!confirm(`Delete the mood “${mood.name}”?`)) return;
        db.moods = db.moods.filter((m) => m.id !== mood.id); save(); closeSheet(); done(); return;
      }
      const trimmed = name.trim();
      if (!trimmed) return toast("Give the mood a name");
      if (db.moods.some((m) => m !== mood && C.normalizedName(m.name) === C.normalizedName(trimmed))) return toast("You already have a mood with that name");
      if (mood) {
        if (mood.name !== trimmed) {
          for (const s of db.songs) if (hasMood(s, mood.name)) s.source = C.setFieldList("mood", C.renamedTags(C.fieldList("mood", s.source), mood.name, trimmed), s.source);
          mood.name = trimmed;
        }
        mood.hue = hue; mood.icon = ic;
      } else db.moods.push({ id: uid(), name: trimmed, icon: ic, hue, isDefault: false });
      save(); closeSheet(); done();
    }));
  };
  openSheet("", { onOpen: drawSheet });
}

function downloadBackup() {
  const data = { app: "moodchords", version: 1, exportedAt: new Date().toISOString(), songs: db.songs, moods: db.moods };
  const blob = new Blob([JSON.stringify(data, null, 1)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `moodchords-backup-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  toast(`Backed up ${plural(db.songs.length, "song")}`);
}

async function restoreBackup(file) {
  try {
    const data = JSON.parse(await file.text());
    if (data.app !== "moodchords" || !Array.isArray(data.songs)) throw new Error();
    const existing = new Set(db.songs.map((s) => C.duplicateKey(s.source)));
    let added = 0;
    for (const s of data.songs) {
      if (typeof s.source !== "string" || !C.tryParse(s.source) || existing.has(C.duplicateKey(s.source))) continue;
      db.songs.push({ id: uid(), source: s.source, isFavorite: !!s.isFavorite, isReady: !!s.isReady, scrollSpeed: Number(s.scrollSpeed) || 1, createdAt: s.createdAt || Date.now() });
      existing.add(C.duplicateKey(s.source)); added++;
    }
    for (const m of data.moods || []) {
      if (!m.name || db.moods.some((x) => C.normalizedName(x.name) === C.normalizedName(m.name))) continue;
      db.moods.push({ id: uid(), name: m.name, icon: ICONS[m.icon] ? m.icon : "music_note", hue: Number(m.hue) || 200, isDefault: false });
    }
    save(); toast(`Restored ${plural(added, "song")}`); replace("#/"); render();
  } catch { toast("That file isn't a Moodchords backup"); }
}

// ================================================================ boot

function applyTheme() {
  const t = db.prefs.theme || "";
  if (t) document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme;
}
applyTheme();
render();

if ("serviceWorker" in navigator && location.protocol !== "file:") {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
