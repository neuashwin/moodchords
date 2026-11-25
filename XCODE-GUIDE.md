# Building Moodchords in Xcode: step-by-step guide

Everything Xcode's Claude Agent needs is already in the `Guitar App` folder:
- `CLAUDE.md`: the brief the agent reads first
- `PRD.md`: the product spec
- `Design/`: your design, unzipped so the agent can read it
- the tested parser and import code, already inside your new project

Follow these steps in order. Steps 1–4 take about 10 minutes and are done by you in Xcode. From step 5 on, the agent does the coding.

---

## Steps 1–2: iPhone only, name and bundle ID ✅ done by Claude (24 Nov)
Already set in the project:
- Supported Destinations: **iPhone only** (Mac, Vision Pro and iPad removed)
- Display Name: **Moodchords**
- Bundle Identifier: **`com.ashwin.Moodchords`**

What's left for you:
1. If Xcode shows a "file changed on disk" prompt, choose **Read From Disk** / **Revert** to load the new settings.
2. In the top bar, click **My Mac** and choose **iPhone 17** under **iOS 27.2**. The app needs iOS 27.2; the 26.5 simulators won't appear as options.
3. Optional check: blue project icon → **GuitarAppFinal** target → **General**. You should see only iPhone under Supported Destinations, and Moodchords as the Display Name.

## Step 3: Check the copied code builds (1 min)
1. In the sidebar, open **GuitarAppFinal → Core**. You should see `Parsing`, `Models`, `Import` and `Views`. This is the tested code from M1: the song parser, the chord-sheet converter, the importer and the chord renderer.
2. Press **⌘B** (Build). It should say **Build Succeeded**. I've already checked this builds for iPhone.

## Step 4: Tests ✅ done by Claude (24 Nov)
- Added the **GuitarAppFinalTests** target (Swift Testing, iPhone only), with the M1 tests inside.
- Added a shared **GuitarAppFinal** scheme with a test step, so **⌘U** runs the tests. All 80 test cases pass.

## Step 5: Version control ✅ done by Claude (24 Nov)
Git is on for the whole `Guitar App` folder, with a first commit "Set up Moodchords project for Xcode".
- `Songs Collection/` is **deliberately left out** (`.gitignore`): your song files contain copyrighted lyrics, and this keeps them off GitHub if you ever push the repo.
- After each step that works, commit: **Integrate → Commit…** (⌥⌘C), with a short message like "M2: mood grid".
- To undo the agent's uncommitted changes to a file: right-click it → **Integrate → Discard Changes**.

## Step 6: Start the agent ✅ prepared by Claude (24 Nov)
I've already read the brief, PRD and design and written `M2-PLAN.md`. It contains the summary, the exact design tokens (colours, mood colours, icons, fonts, sizes) and M2 split into 10 small steps (2.1–2.10). In the Claude Agent panel (with the **Guitar App** folder attached), paste:

> Read `CLAUDE.md`, then `M2-PLAN.md`. Answer the two questions at the end of M2-PLAN by using the defaults (SF Pro for now; keep the tab bar). Then do **step 2.1 only**, build, and show me the ThemeGallery preview.

Then for each next step, say **"Looks good, do step 2.2"** (and so on). If something looks off, describe it or attach a screenshot before moving on.

## Step 7: Build it one milestone at a time
Paste these prompts **one at a time**. After each one:
1. Press **⌘R** to run it in the simulator.
2. Compare it with the design. Open `Design/Moodchords design/Moodchords iOS.dc.html` in your browser and put them side by side.
3. Tell the agent what's off ("the mood tiles are too small", "use the orange from the design for Play").
4. When it looks right, commit (Step 5).

**7a. Design system**
> Build the design system from the design file: a `Theme` with the stage (dark) and paper (light) colours, chord colours, mood colours and icons (SF Symbols instead of Material Symbols), the type scale, and reusable components (glass card, white-pill segmented control, orange Play pill, mood tile, chip). Add a preview screen that shows them all in light and dark. Don't build app screens yet.

**7b. M2: Home and browsing**
> M2, part 1: build screen 01 Home (mood grid with song counts, Surprise me, first-launch empty state), 02 Who's listening? (sheet after tapping a mood), and 03 Song list (ready songs first, rows show key, capo and first line, crowd chips at the top, long-press quick actions). Use the SwiftData `Song` model in `Core/Models`. Make moods editable records, migrating the `moodNames` strings. Match the design file closely.

> M2, part 2: build 07 Add song (paste and import, reusing `SongImporter`, with a friendly import summary showing warnings), 08 Edit song, 10 Manage moods, plus favourites and ready-to-play.

**7c. Load your songs.** Once Add song works, put your 30 songs into the simulator:
- Drag the `Songs Collection/English`, `Nepali` and `Hindi` folders onto the running simulator window. They go into the Files app.
- In Moodchords, tap **Import**, then **Select All** in each folder.
- On your real iPhone, AirDrop the folders to yourself and import from Files.

**7d. M3: Play mode**
> M3: build 04 Song screen (cue card, chord sheet preview using `Core/Views/ChordSheetView`, Play button) and 05 Play mode exactly as in the design: count-in, auto-scroll over the song's duration, tap anywhere to pause, swipe up/down speed nudge saved per song, swipe down from the top to exit, current-line band, screen stays awake. Default 3:30 if a song has no duration.

**7e. M4: Music tools and tuner**
> M4: add transpose and capo, chord diagrams for the chords in each song, the full cue card (`strum`, `intro`, `youtube` directives: add them to `ChordProParser` with tests), and screen 06 Guitar tuner (microphone pitch detection, auto string detection, in-tune state, microphone permission screen).

**7f. M5: Setlists**
> M5: build 09 Setlists (create, reorder, total time, Start jam) and the "Next: …" card with auto-advance in play mode.

## Tips
- **One conversation per milestone.** Start a **New Conversation** for each milestone, and begin with "Read CLAUDE.md". Long conversations drift.
- **Ask for previews:** "Add #Previews for each state of this screen", so you can see screens without running the app.
- **Show it screenshots** when something looks wrong. Attach a simulator screenshot (⌘S in the Simulator) to your message.
- **Keep `CLAUDE.md` current:** after each milestone, ask "Update CLAUDE.md with what's now built and any new decisions."
- **Fonts (optional):** the design uses Barlow and Noto Sans Devanagari, both free from fonts.google.com. Download the `.ttf` files, drag them into the project, and ask the agent to register and use them. Until then it falls back to SF Pro.
- **Your song files:** the agent is told never to copy their lyrics into code. Songs only come into the app through Import.
