# Moodchords — project brief for Claude

Read this before doing anything. It carries the decisions made in earlier sessions.

## What we're building
**Moodchords** is an iPhone app for singer-guitarists. Songs (lyrics + chords) are organised by **mood** (Romantic, Campfire, Dance…) and **crowd** ("Who's listening?": Elders, Friends, Mixed, Kids). You pick a song you're ready to play, glance at its **cue card** (key, capo, strum, intro, first line), press **Play**, and the sheet **auto-scrolls hands-free**. Songs are in English, Nepali and Hindi (Devanagari). There's also a built-in **guitar tuner**.

The owner is building it for personal use first, with a public App Store release later. They're new to Swift, so explain what you change in plain words, work in small steps, and build and run after each step.

## Source of truth (read these)
| File | What it is |
|---|---|
| `M2-PLAN.md` | **Start here for M2.** Design tokens extracted from the design (exact colours, mood hues → hex, SF Symbol mapping, type, shapes) and M2 as steps 2.1–2.10. |
| `PRD.md` | **The product spec.** Features, decisions, milestones, risks. Follow it. Don't add out-of-scope features without asking. |
| `Design/Moodchords design/Moodchords iOS.dc.html` | **The approved UI design.** All 10 screens in light and stage (dark) mode, the user flow, a style guide, and a "Design decisions" section. Read its text and CSS for exact colours, sizes and layout. |
| `Design/Moodchords design/Moodchords Screen.dc.html` | The interactive prototype: every screen's structure, states and copy. |
| `Design/Moodchords design/uploads/*.jpg`, `Design References/` | The owner's style reference images. |
| `design-prompt.md` | The brief the design was made from (screens, states, principles). |
| `song-list.md` | The 30 test songs with mood and crowd tags. `song-list-backlog.md` has 71 more for later. |
| `Songs Collection/{English,Nepali,Hindi}/*.txt` | The owner's 30 song files. **Personal use only.** At the owner's request, copies (with a `{language:}` line added) are built into the app as `GuitarAppFinal/GuitarAppFinal/BundledSongs/BundledSong-<Language>-<Title>.txt`, loaded only in **Debug** builds (`BundledSongs.swift`). **Before any App Store / TestFlight release, delete the `BundledSongs` folder** (the files are in every build; only the loading is Debug-only). Never copy their lyrics into code, tests or previews. |
| `tools/extract_saved_pages.py` | Turns chord pages saved from Chrome (`Songs Collection/Saved pages/`) into song files. |

## Current state
- **M1 and M2 are done.** At the owner's request, parts of M3 and M4 are also built: Play mode, chord diagrams, the song page with cue card, and the tuner. A language filter (not in the PRD) was added at the owner's request too. Still to do: transpose, strum/intro/YouTube on the cue card (M4), and setlists (M5).
- **Core** (`GuitarAppFinal/GuitarAppFinal/Core/`, logic, no SwiftUI):
  - `Parsing/ChordProParser.swift`: the song format, including Devanagari.
    - Directives: `title, artist, key, capo, duration, mood, crowd, language, comment, start_of_chorus/verse/bridge/solo`.
    - Not yet parsed: `strum`, `intro`, `youtube` (M4 / v1.1).
    - `[Verse 1]`-style lines become sections. `markNotes` turns chord-website clutter into `.note` lines: chord-free lines before the song starts (= the last heading before the first chord), fingering tables, links and repeat marks. Dividers are dropped, and bar-notation lines (`| G D | Em |`) become chord rows.
  - `Music/ChordShapes.swift`: chord name → fingering. A hand-checked open-chord table, else E- or A-shape barres moved up the neck.
  - `Music/PitchDetector.swift`: YIN pitch detection (Accelerate) plus `Tuning` (standard strings, cents, nearest string).
  - `Models/Language.swift`: `SongLanguage`, `LanguageFilter` (All/English/Nepali/Hindi), `Song.matches(_:)`.
  - `Import/BundledSongs.swift`: Debug-only loader for the bundled song files. Each file loads once (tracked in UserDefaults), so deleted songs stay deleted.
  - `Parsing/ChordSheetConverter.swift`: chords-above-lyrics → inline `[C]`.
  - `Parsing/SourceEditing.swift`: reads/rewrites single `{name: value}` lines. The edit screen's fields and chips use it, so the song text stays the only source of truth.
  - `Models/Song.swift`: SwiftData `@Model`. Stores the raw `source` and re-parses it for display. `isFavorite`, `isReady`, `language`, `scrollSpeed` (Play-mode speed saved per song). `update(parsed:source:)` after editing.
  - `Models/Mood.swift`: `@Model` (name, SF Symbol, OKLCH hue, subtitle, sortOrder, isDefault). The 9 defaults are seeded on first launch (`MyApp`).
  - `Models/MoodLibrary.swift`: seeding, matching, rename (rewrites song tags), add, update, delete (custom only), reorder.
  - `Models/Crowd.swift`: `Crowd` enum over `crowdNames`, and `CrowdFilter` (one crowd or Anyone).
  - `Models/SongSummary.swift`: the row's meta line ("G · CAPO 2 · 2:45", "~3:30" when no length) and cue line (first lyric line).
  - `Import/SongImporter.swift`: paste/text import, and `importFiles` for several files or whole folders.
    - A song in a folder named English/Nepali/Hindi gets that `{language:}`.
    - Duplicates (same text, ignoring the language line) are skipped, but a missing language is filled in.
    - It returns an `ImportReport` of things to check.
  - `Views/ChordSheetView.swift`: chords above lyrics, using `ChordLineLayout`.
    - Runs of spaces collapse, and chords never run past the right edge.
    - Rows without chords or without words don't reserve that space, and lines never wrap mid-word.
    - Chords use the **tint**, so callers set `.tint(Theme.chord)`. `ChordLineView` is reused by Play mode.
- **Theme** (`Theme/`): colour tokens (light/dark), `Theme.font(...)` helpers, `MoodColor` (OKLCH hue → sRGB), `moodGlow`, components (`MoodTile`, `Chip`, `AccentPill`, `GlassCircleButton`, `GlassTabBar`, `ReadyMark`, capsule buttons), `TabBarVisibility` (`.hidesTabBar()`, `.clearsTabBar()`), `ThemeGallery` preview.
- **Screens** (`Screens/`):
  - `RootView`: a system `TabView` with its own bar hidden and our glass bar overlaid. It hosts app-wide sheets via `SheetRouter`, and `router.requestedTab` switches tabs.
  - Browsing: `HomeScreen` (1A grid with `LanguageChips` / 1B first launch), `CrowdSheet`, `SongListScreen` + `SongRow` (long-press quick actions, plus a language menu), `FavouritesScreen`, `MoodsScreen` + `MoodEditorSheet`.
  - `Song/SongScreen`: design 04, with chips, a Ready switch, the cue card, the `ChordChart` of `ChordDiagramView`s, Play and the sheet.
  - `Song/PlayScreen`: design 05. A count-in, then auto-scroll over the song length × `scrollSpeed`.
    - Tap pauses; swipes nudge the speed (saved per song); dragging scrubs while paused; swipe down from the top or ✕ exits. There's a text size control and the screen stays awake.
    - `PlayClock` holds the position, so only the moving parts update each frame. The lyrics sit in an overlay so a long song can't push the header off-screen.
  - `Tuner/TunerScreen` + `TunerEngine`: design 06. The mic is only on while the screen is visible. `AudioCapture` runs AVAudioSession/AVAudioEngine on its own queue, because doing that on the main thread deadlocked and crashed the app.
  - `Editing/`: Add song entry, Paste, Import result, Edit song (with a Language row), and `SongTextEditor`.
- **Not built yet:** the Setlists tab (M5) is a placeholder. The search buttons do nothing (search isn't in the PRD; ask the owner). Transpose and strum/intro/YouTube aren't built.
- **Tests:** 190 Swift Testing cases in **GuitarAppFinalTests**, all passing. ⌘U runs them. Add tests for new logic there.
- **Testing with sample data:** launch with `-UseSampleData` (DEBUG only) to run on an in-memory library: the two sample songs, a romanized-title stub, and a "website layout" copy of Campfire Night for formatting tests. The real library is untouched. Previews use `#Preview(traits: .sampleLibrary)`.
- **Files app:** `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` make "On My iPhone → Moodchords" visible, so files can be dropped there and imported.
- **Simulator checks:** device-interaction sessions time out after about a minute idle. Keep calls frequent, and start the session right before handing it to a helper.
- The old prototype project at `~/Documents/Apps/GuitarApp` is reference only.

## Decisions made in M2
- **Fonts:** SF Pro, SF Mono and the system Devanagari font stand in for Barlow, DM Mono and Noto Sans Devanagari, all behind `Theme.font(...)`. Swapping in the real fonts is a one-place change; Dynamic Type can be added then.
- **Tab bar:** kept as designed (4 tabs). Pushed screens (song list, song page, moods) hide it.
- **Songs link to moods by name** (`moodNames`, case-insensitive, never accent-folded, so Devanagari stays exact). Renaming a mood rewrites the songs' tags. Deleting a custom mood leaves song tags in place.
- **Import:** unknown mood tags are *not* auto-created as moods; the import result lists them as things to check.
- **Surprise me** opens the song page of a random ready song (from the current language filter).
- **Language filter** (owner request): All / English / Nepali / Hindi on Home, saved in `@AppStorage("languageFilter")`. It applies to Home, the crowd sheet and the song list, but not to Favourites. Songs without a language only show under All.
- **Edit song** has a "Delete song" button (it's the only place to delete).
- Mood tiles and chips draw their content in light mode in both themes (dark ink on pastel), because some symbols change shape in dark mode.

## Milestones (from the PRD)
1. ~~M1: song model + parser + import~~ ✅
2. ~~M2: Browse~~ ✅
   - Design system first: colours, type, components from the design file.
   - Then the mood grid (incl. Festival) with custom moods, the "Who's listening?" crowd sheet, and the song list (ready songs first, rows show key/capo/first line).
   - Also favourites, ready-to-play with Surprise me, the add-song screens (paste/import) and edit song text.
3. **M3: Play mode** (built early at the owner's request; see Current state).
   - The sheet auto-scrolls over the song's duration, with a 3-2-1 count-in.
   - Tap anywhere to pause; swipe up/down nudges the speed, saved per song; swipe down from the top exits.
   - Keep the screen awake, stage (dark) mode, text size.
4. **M4: Music tools.** Chord diagrams, the cue card (key/capo/length/first line) and the tuner are built. Still to do: transpose, capo controls, and strum/intro/YouTube on the cue card.
5. **M5: Setlists.** Queue songs, with a "Next: …" card and auto-advance.

## Design system (from the design file; check the HTML for exact values)
**Colours:**
| Role | Value |
|---|---|
| Stage (dark) background | `#1C1713` |
| Stage surfaces | `#2B2521` / `#3A322C` |
| Paper (light) background | `#F3ECE4` |
| Muted text | `#B5A99E` |
| Chords on stage | amber `#FFA552` |
| Chords on light | burnt orange `#B4430A` |
| Primary/Play accent | orange `#F2742A` / `#EE6A1F` |

**Type:** Barlow, with Noto Sans Devanagari for Devanagari. If those font files aren't in the project yet, use SF Pro and the system Devanagari font, and tell the owner.

**Icons:** the mockups use Material Symbols as stand-ins. Use the matching **SF Symbols** in code.

**Key design decisions:**
- The crowd picker is a **sheet** after tapping a mood. The song list repeats it as an inline chip row.
- Play mode: the whole screen is the button. The only visible control is a 30 pt ✕ inside a 44 pt hit area. The current line gets a soft band, past lines fade, and upcoming lines stay at AAA contrast.
- Ready-to-play uses a check mark vs. an empty ring, not colour alone.

## GitHub
- **Public repo:** https://github.com/neuashwin/moodchords (MIT). `main` tracks `origin/main`.
- `main` started fresh from a clean snapshot. The older history, which includes the reference images, is on the local branch **`private-history`**. **Never push `private-history`.**
- `.gitignore` keeps these off GitHub: `Songs Collection/`, `GuitarAppFinal/GuitarAppFinal/BundledSongs/` (the copyrighted songs), `Design References/` and `Design/Moodchords design/uploads/` (other people's images). Before every push, check that nothing matching those got staged.

## Rules and gotchas
- **iPhone only** (PRD). The target is set to iPhone only (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator`, `TARGETED_DEVICE_FAMILY = 1`). Bundle ID `com.ashwin.Moodchords`, display name Moodchords. Don't re-add Mac/iPad/Vision; `ChordSpacing` uses `UIFont`.
- **Storage:** on-device SwiftData only. No accounts, no network, no iCloud for now; the owner decided this.
- **No real song lyrics in code, previews, tests or sample data** (the bundled song *files* are the one owner-approved exception; see above). Use only the two original sample songs:
  - `Campfire Night`: in `design-prompt.md`
  - `साँझको गीत`: in `../sample-songs/` and `design-prompt.md`
- The build settings have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `MemberImportVisibility`:
  - mark pure parsing types `nonisolated`
  - import modules explicitly (e.g. `import Foundation` in test files that use `replacingOccurrences`, `import SwiftData` where `.modelContainer` is used)
- **Devanagari:** the parser walks Unicode scalars, not Characters, because `]` followed by a vowel sign is one Character. Don't "simplify" that.
- **`.cho` import:** use `UTType(filenameExtension: "cho")` with the *default* conformance. Conforming to `.plainText` greys the files out in the picker.
- **Braces:** lyric lines can start with `{`. Only `{name}` or `{name: value}` counts as a directive (`ChordProParser.looksLikeDirective`).
- The deployment target is **iOS 27.0** (lowered from 27.2; nothing used needs newer than iOS 26). The owner's iPhone ("Ashwin iPhone", iOS 27.2.1) runs the app via ⌘R with automatic signing. Simulators: any iOS 27.2 iPhone (e.g. iPhone 18 Pro).
- **Disk space** on the owner's Mac is tight: Xcode builds, previews and simulators can fill it, and the error then shows as "Couldn't create workspace arena folder". Clear DerivedData and the Previews cache. Only the iOS 27.2 (24B8117) simulator runtime is installed now.
- **SwiftData deletes:** a screen showing a song must not read it after it's deleted (crash). `SongDetailPlaceholder` watches a `@Query` and closes itself.
- **Sheets:** open app-wide sheets through `SheetRouter` (`router.show(...)`). It waits for one sheet to close before opening the next, because swapping directly isn't reliable.
- **Tab bar inset:** use `.clearsTabBar()` *inside* each tab's NavigationStack. A safe-area inset set outside the stack doesn't reach its content.
- **Text editor:** smart quotes and dashes are off (curly quotes break `{title: …}`), and highlighting is skipped while the keyboard has marked (composing) text.
- After each change: build, run in the simulator, and check against the design file. Keep previews working with in-memory SwiftData.
