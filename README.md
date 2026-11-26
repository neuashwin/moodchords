# Moodchords

An iPhone songbook for singer-guitarists. Songs (lyrics with chords) are organised by
**mood** (Romantic, Campfire, Dance…) and **who's listening** (Elders, Friends, Mixed, Kids).
Pick a song you're ready to play, glance at its cue card, press **Play** and the sheet
scrolls by itself, hands-free. Songs can be in English, Nepali or Hindi (Devanagari).

Built with SwiftUI and SwiftData. Everything stays on the phone: no accounts, no network.

## Use it now, on any phone (free)

There's also a **web app version** that works on iPhone, Android and computers, with no app store:

**👉 https://neuashwin.github.io/moodchords/**

On iPhone: open it in Safari → Share → **Add to Home Screen**. On Android: open it in Chrome → **Install app**.
It works offline once installed. The code is in [`web/`](web/).

## Features

- **Mood grid** with custom moods (add, rename, recolour, reorder), and a
  **"Who's listening?"** crowd filter.
- **Language filter:** All · English · Nepali · Hindi.
- **Song list** with ready-to-play songs first, key/capo/length and the first line,
  favourites, and **Surprise me** (a random song you're ready to play).
- **Song page** with a cue card (key, capo, length, how it starts) and a **chord chart**
  with a finger diagram for every chord in the song.
- **Play mode:** a 3-2-1 count-in, then auto-scroll over the song's length. Tap to pause,
  swipe up/down to change speed (saved per song), text size control, and the screen stays awake.
- **Guitar tuner:** listens with the microphone, auto-detects the string, needle and
  "Tune up / Tune down / In tune". The microphone is only on while the tuner is open.
- **Add songs** by pasting, from `.txt` / ChordPro (`.cho`) files, or whole folders.
  Sheets copied from chord websites ("chords above the lyrics") are converted automatically.
- **Edit songs** in a chord-highlighting editor with live preview.

## Requirements

- Xcode with the **iOS 27** SDK
- An iPhone (or simulator) on **iOS 27.0** or later (iPhone only)

## Build and run

1. Clone the repo and open `GuitarAppFinal/GuitarAppFinal.xcodeproj`.
2. Select the **GuitarAppFinal** target → **Signing & Capabilities**:
   - choose your own **Team**
   - change the **Bundle Identifier** (e.g. `com.yourname.Moodchords`)
3. Pick a simulator or your iPhone and press **⌘R**. Run the tests with **⌘U**.

## Songs

No songs are included: song lyrics are copyrighted. The app starts empty. Add your own
songs with **+ → Paste song** or **Import file**. Two original sample songs you can try are in
[`sample-songs/`](sample-songs/).

### Song format

A small ChordPro subset: directives in braces, chords in square brackets right before the
syllable they land on.

```
{title: Campfire Night}
{artist: Moodchords Sample}
{key: G}
{capo: 2}
{duration: 2:45}
{mood: Campfire, Jolly}
{crowd: Friends, Mixed}
{language: English}

{start_of_verse}
[G]Sparks are rising [C]up into the [G]sky
{end_of_verse}
```

- `duration` sets how long Play mode takes to scroll the song (3:30 if missing).
- `mood`, `crowd` and `language` decide where the song shows up.
- `[Verse 1]`-style lines become section headings.

### Built-in personal songs (optional)

For your own copy, files named `BundledSong-<Language>-<Title>.txt` placed in
`GuitarAppFinal/GuitarAppFinal/BundledSongs/` are loaded into the library on first launch
of **Debug** builds. That folder is git-ignored. Don't publish or ship songs you don't
have the rights to.

## Project layout

| Path | What's there |
|---|---|
| `GuitarAppFinal/GuitarAppFinal/Core/` | Logic: song parser, chord-sheet converter, models, import, chord shapes, pitch detection |
| `GuitarAppFinal/GuitarAppFinal/Theme/` | Colours, type, shared components |
| `GuitarAppFinal/GuitarAppFinal/Screens/` | The app's screens |
| `GuitarAppFinal/GuitarAppFinalTests/` | Unit tests (Swift Testing) |
| `PRD.md`, `M2-PLAN.md`, `Design/` | Product spec, build plan and the UI design |
| `web/` | The web app (PWA) version, published to GitHub Pages |

## Licence

[MIT](LICENSE). The song lyrics you add are not covered by this licence.
