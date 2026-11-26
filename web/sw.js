// Moodchords service worker: caches the whole app so it works offline.
// Bump VERSION whenever any app file changes, so phones pick up the new version.
const VERSION = "moodchords-v1";
const FILES = [
  "./", "index.html", "styles.css", "app.js", "core.js", "icons.js", "manifest.webmanifest",
  "icons/icon-192.png", "icons/icon-512.png", "icons/maskable-512.png", "icons/apple-touch-icon.png",
  "fonts/barlow-latin-500-normal.woff2", "fonts/barlow-latin-500-italic.woff2", "fonts/barlow-latin-600-normal.woff2",
  "fonts/barlow-latin-700-normal.woff2", "fonts/barlow-latin-800-normal.woff2", "fonts/barlow-condensed-latin-800-normal.woff2",
  "fonts/dm-mono-latin-500-normal.woff2",
  "fonts/noto-sans-devanagari-devanagari-500-normal.woff2", "fonts/noto-sans-devanagari-devanagari-600-normal.woff2",
  "fonts/noto-sans-devanagari-devanagari-700-normal.woff2", "fonts/noto-sans-devanagari-devanagari-800-normal.woff2",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Stale-while-revalidate: answer from the cache straight away (works offline), and refresh
// the cached copy from the network in the background so the next launch gets any update.
self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== location.origin) return;
  e.respondWith(
    caches.open(VERSION).then(async (cache) => {
      const key = req.mode === "navigate" ? "index.html" : req;
      const hit = await cache.match(key, { ignoreSearch: true });
      const fresh = fetch(req, { cache: "no-cache" }).then((res) => {
        if (res.ok && res.type === "basic") cache.put(key, res.clone());
        return res;
      }).catch(() => null);
      if (hit) { e.waitUntil(fresh); return hit; }
      return (await fresh) || Response.error();
    })
  );
});
