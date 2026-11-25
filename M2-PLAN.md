# M2 plan: Browse (for Xcode's Claude Agent)

This is the "Step 6" briefing: what the app is, what exists, the design system pulled out of the design file, and M2 broken into small steps. Read `CLAUDE.md` first, then this file. **Do one step at a time.** After each step: build, run on the iPhone 17 (iOS 27.2) simulator, show the owner, and wait for "next".

## 1. Summary
- **App:** Moodchords, an iPhone songbook. Pick a mood, then optionally who's listening, then a song you're ready to play. The cue card shows how it starts, then hands-free auto-scroll. Songs are in English, Nepali and Hindi (Devanagari). Full spec in `PRD.md`.
- **Already built** (`GuitarAppFinal/Core/`, tested, 80 cases):
  - parser and chord-sheet converter
  - the SwiftData `Song` model (stores the raw `source`; `moodNames`/`crowdNames` are strings)
  - `SongImporter` (file and paste)
  - `ChordSheetView` (chords above lyrics, Devanagari-safe)
- **Not built:** every screen. `ContentView` is still "Hello, world!".
- **M2 covers design screens** 01 Home, 02 Who's listening, 03 Song list, 07 Add song, 08 Edit song, 09A Favourites, 10 Manage moods, plus the tab bar.
- **Not in M2:** 04 Song screen and 05 Play (M3), 06 Tuner (M4), 09B Setlist builder (M5). Give those tabs a simple placeholder.

## 2. Design system (extracted from `Design/Moodchords design/Moodchords Screen.dc.html`)
Two modes. Follow the system appearance; Play mode (M3) defaults to dark "stage".

| Token | Light | Dark (stage) |
|---|---|---|
| bg (screen background) | `#EFE9E0` | `#15110E` |
| stage (play / deepest) | `#F7F2EA` | `#0C0907` |
| sheet (sheets, editors) | `#FAF6F0` | `#241D18` |
| fg (primary text) | `#1C1713` | `#F7F0E8` |
| fg2 (secondary text) | `#5C534A` | `#B9AEA3` |
| fg3 (tertiary, borders) | `#A99F94` | `#62584F` |
| card | white 60% | white 5.5% |
| card2 | `#FFFFFF` | white 8% |
| line (hairlines) | `#1C1713` 10% | white 9% |
| chip | `#1C1713` 6.5% | white 8.5% |
| **chord** | `#B4430A` | `#FFA552` |
| glass (floating buttons, tab bar) | white 62% + blur | `#302720` 62% + blur |
| ok / ok background | `#1C7443` | `#6EE29C` |
| danger | `#B42318` | `#FF8B7B` |
| **Accent** (Surprise me, Play) | gradient `#EE6A1F` → `#C2440A` | same |

**Mood colours:** OKLCH(L 0.8, C 0.11, hue), converted to hex. Store the hue on the mood, so custom moods can use any hue.

| Mood | Hue | Hex | Design icon → SF Symbol suggestion |
|---|---|---|---|
| Romantic | 10 | `#FBA0AD` | favorite → `heart.fill` |
| Dance | 290 | `#BCB2FF` | nightlife → `figure.dance` |
| Jolly | 95 | `#D4BD67` | sentiment_very_satisfied → `face.smiling.inverse` |
| Campfire | 50 | `#F7A97C` | local_fire_department → `flame.fill` |
| Sad | 245 | `#7FC5FF` | rainy → `cloud.rain.fill` |
| Devotional | 80 | `#E3B667` | temple_hindu → `hands.and.sparkles.fill` |
| Nostalgic | 200 | `#56D3DA` | radio → `radio.fill` |
| Party | 330 | `#E6A4E0` | celebration → `party.popper.fill` |
| Festival *(sub: "Dashain · Tihar")* | 150 | `#89D298` | festival → `fireworks` |

Each mood tints the screen with a soft radial **glow** at the top: the mood colour at 45% (light) or 22% (dark) fading to transparent, over bg.

**Crowds** (fixed, not editable):

| Crowd | Sub | SF Symbol suggestion |
|---|---|---|
| Elders | Parents, relatives | `figure.2` |
| Friends | Your own crowd | `person.3.fill` |
| Mixed | Family gathering | `person.3.sequence.fill` |
| Kids | Simple sing-alongs | `figure.and.child.holdinghands` |

Plus an "Anyone" option (`infinity`) that skips the filter.

**Tab bar** (floating glass capsule, 4 tabs; the active tab gets a chip background and a chord-coloured icon):

| Tab | Icon |
|---|---|
| Moods | `square.grid.2x2.fill` |
| Favourites | `star.fill` |
| Setlists | `music.note.list` |
| Tuner | `tuningfork` |

**Typography:**
- Barlow, weight 800 for big titles. "Moodchords" is 42 pt with −2% tracking; "Who's listening?" is 32 pt. Body is 500–600.
- **DM Mono** 12 pt with +4% tracking for spec labels and counts ("12 SONGS", "KEY", "CAPO").
- Noto Sans Devanagari is the fallback for Devanagari.
- The font files are **not** in the project yet. Use SF Pro (rounded weights to match), SF Mono for the DM Mono labels, and the system Devanagari, all behind a `Theme.font(...)` helper so swapping in real fonts later is a one-line change. Tell the owner.

**Shapes** (all values in points):

| Element | Spec |
|---|---|
| Mood tiles | 118 tall, radius 26, filled with the mood colour. Name in Barlow 700, 21 pt; count in mono, 78% opacity; a big faded icon (116 pt, 13% opacity) in the corner. |
| "New mood" tile | Same size, dashed/inset 1.5 pt `fg3` border |
| Surprise me pill | 68 tall, radius 34, accent gradient, a 48 pt round play button inside on white at 22% opacity. Subtitle: "From N songs you're ready to play". |
| Glass buttons | 44 × 44 circles (search, add) at the top right |

**Copy:**
- Home subtitle: "What's the vibe tonight?"
- First-launch kicker: "OE, BAJA TA!"

## 3. M2 steps (small, one at a time)

**2.1 Theme and components.** `Theme/` folder containing:
- colour tokens (light/dark via asset colours or `Color(light:dark:)`)
- mood colour from hue
- the glow background modifier
- the font helpers
- reusable views: `GlassCircleButton`, `AccentPill`, `MoodTile`, `Chip`, `SpecLabel` (mono caps), `GlassTabBar`

Add a `ThemeGallery` preview showing all of them in light and dark. *Done when* the preview matches the design's style guide.

**2.2 Data model.**
- Add a `Mood` `@Model`: `id`, `name`, `symbol`, `hue`, `subtitle?`, `sortOrder`, `isDefault`.
- Seed the 9 defaults on first launch.
- Add `isReady: Bool = false` to `Song`.
- Add a `Crowd` enum (Elders/Friends/Mixed/Kids) over `crowdNames`.
- Match a song's `moodNames` to `Mood` records by case-insensitive name. Keep `moodNames` as the stored link, so renaming a mood must update songs. Unit tests for seeding, matching and rename.
- *Don't* store lyrics anywhere new.

**2.3 App shell.** A root view with the glass tab bar: Moods (Home), Favourites, Setlists (placeholder: "Coming in M5"), Tuner (placeholder: "Coming in M4"). `.modelContainer(for: [Song.self, Mood.self])`.

**2.4 Home (screens 1A, 1B).**
- **1A (with songs):**
  - top-right glass search and add buttons
  - title and subtitle
  - the Surprise me pill, which picks a random ready song. In M2 it just opens that song in the list; the song screen comes in M3.
  - a 2-column mood grid with counts ("12 SONGS" / "NO SONGS YET") and a "New mood" tile
- **1B (first launch, no songs):**
  - "OE, BAJA TA!"
  - "Add your first song"
  - Paste song / Import file (.TXT · .CHO)
  - a "Your songs will sort into" row of mood chips

**2.5 Who's listening? sheet (2A).**
- Opens after tapping a mood.
- Header: mood chip and count, then "Who's listening?" and "One tap. You can change it on the song list."
- A 2×2 crowd grid, each with icon, name, sub and a count of songs in that mood for that crowd. Plus "Anyone".
- One tap dismisses straight into the song list.

**2.6 Song list (3A, 3B, 3C).**
- Mood header with a chevron to change mood.
- An inline crowd chip row.
- Sections: "READY TO PLAY" first, then the rest, each with a count.
- **Rows:**
  - ready icon: a check mark vs. an empty ring, not colour alone
  - title and artist
  - a mono meta line: key · capo · length
  - the first lyric line
  - a favourite star
- **3B:** an empty state with an "Add a song" button.
- **3C:** long-press quick actions: Favourite/Unfavourite, Mark ready/not ready, Add to setlist… (disabled until M5), Edit song.
- Tapping a song opens a simple placeholder detail using `ChordSheetView` until M3.
- Test with a Devanagari title plus romanized titles side by side.

**2.7 Add song (7A, 7B, 7C).**
- **7A:** an entry sheet with three rows:
  - Paste song ("Lyrics with [chords] from notes or a website")
  - Import file (".txt or ChordPro (.cho), one song or a whole folder")
  - Start from the template
- **7B:** a paste editor with inline errors.
- **7C:** an import result ("Added N songs" plus friendly warnings).
- **Reuse `SongImporter`** (it already converts chords-above-lyrics sheets) and `SongImporter.allowedTypes`.

**2.8 Edit song (8A, 8B).**
- A monospaced editor over `song.source`, with chords highlighted in the chord colour.
- A segmented Edit / Preview toggle; Preview uses `ChordSheetView`.
- On save, re-parse and update the title, artist, key, moods etc. Show parser warnings inline.

**2.9 Favourites (9A).** The Favourites tab lists starred songs in the same row style.

**2.10 Manage moods (10A, 10B).**
- **10A:** reorder (drag), rename, and delete custom moods only.
- **10B:** new mood: name, symbol picker (a small curated grid), hue picker showing the colours.
- Reached from the "New mood" tile and from Home.

**After 2.10:** update `CLAUDE.md` (what's built, new decisions), make sure ⌘U passes, and remind the owner to commit.

## 4. Questions for the owner before starting
1. **Fonts:** download Barlow, DM Mono and Noto Sans Devanagari (fonts.google.com) and add them now, or start with SF Pro and swap later? *(Default: SF Pro for now.)*
2. **Tab bar:** the design adds a 4-tab bar (Moods, Favourites, Setlists, Tuner) that the PRD didn't specify. Keep it? *(Default: yes, as designed.)*
