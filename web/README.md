# Moodchords for the web (PWA)

The same songbook as the iPhone app, rebuilt as a web app so anyone can use it on
**iPhone, Android or a computer**, for free, without an app store.

**Open it:** https://neuashwin.github.io/moodchords/

## Install it like an app

- **iPhone / iPad (Safari):** open the link, tap **Share** → **Add to Home Screen**.
- **Android (Chrome):** open the link, tap **Install app** (or ⋮ → **Add to Home screen**).
- **Computer (Chrome / Edge):** click the install icon in the address bar.

After the first visit it works offline. Songs are saved on that device only (in the browser).
Use **Moods → Back up all songs** to save a backup file, and **Restore from a backup** on a new phone.

## What's in it

Everything the iPhone app has today: the mood grid (with custom moods), "Who's listening?",
the language filter, song list with ready-to-play and favourites, Surprise me, the song page
with cue card and chord diagrams, Play mode (count-in, auto-scroll, tap to pause, swipe for
speed, text size, screen stays awake), the guitar tuner, and adding songs by pasting,
importing `.txt` / `.cho` files or a folder, with chords-above-lyrics sheets converted automatically.

No songs are included (lyrics are copyrighted). Two original sample songs are one tap away.

## How it's built

Plain HTML, CSS and JavaScript. No build step, no framework, no server.

| File | What it is |
|---|---|
| `index.html`, `styles.css` | The page and the design tokens from `Design/` |
| `app.js` | Screens, navigation, storage (`localStorage`) |
| `core.js` | Ports of the Swift `Core/`: ChordPro parser, chord-sheet converter, chord shapes, YIN pitch detection, source editing |
| `icons.js` | Material Symbols Rounded icons as SVG paths |
| `sw.js`, `manifest.webmanifest` | Offline caching and install info |
| `fonts/` | Barlow, Barlow Condensed, DM Mono, Noto Sans Devanagari (SIL Open Font License) |
| `tests/core.test.mjs` | Tests ported from the Swift test suite |

Run it locally: `python3 -m http.server --directory web 8000`, then open http://localhost:8000.
Run the tests: `node --experimental-default-type=module web/tests/core.test.mjs`.

It deploys to GitHub Pages automatically on every push to `main` (`.github/workflows/pages.yml`).
After changing any file, bump `VERSION` in `sw.js` so installed copies pick up the update.
