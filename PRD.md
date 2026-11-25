# Moodchords — Product Requirements Document (v2)

**Status:** Draft · **Updated:** 24 Nov 2026 (v1: 22 Nov 2026) · **Platform:** iPhone (SwiftUI)

> **What changed in v2:** a crowd ("Who's listening?") filter, a song cue card, ready-to-play marks and Surprise me, better auto-scroll (count-in, tap-to-pause, speed nudge), YouTube reference links, in-app song editing, a Festival mood, a business-model section and a content-licensing stance. Every addition traces to the research in Appendix A.
>
> **Added 24 Nov 2026:** a built-in guitar tuner (§5.9).

---

## 1. Problem

Guitar players learn songs, then blank when someone says *"oe, baja ta"*. They forget the chords, the lyrics, or even which song to play. Three things make it worse:

1. **The crowd.** Elders want timeless songs, friends want their own taste, strangers need evergreen sing-alongs.
2. **The moment.** A campfire, a celebration, a romantic evening and a dance party each need different songs.
3. **The phone.** Reading chords from a phone means stopping mid-song to scroll.

## 2. Solution

A personal songbook of lyrics and chords, browsed by **mood** and **crowd**. Pick the moment, pick who's listening, pick a song you're ready to play, glance at its cue card, press **Play**. The sheet scrolls hands-free.

**USP:** no chord app organises songs by mood or audience, and none is built for playing to a group. In the Nepali/Hindi space, the existing apps are small, ad-funded and have stale catalogues (Appendix A).

## 3. Goals & audience

| | |
|---|---|
| **v1 audience** | Me (the builder), then friends. Personal tool first. |
| **Later** | Public App Store release. v1 is designed so nothing blocks that (user-owned content, no licensing dependency). |
| **v1 success** | I walk into a jam with 20+ of my songs loaded, find one that suits the mood and the crowd in under 10 seconds, and play it start to finish without the scroll falling out of step. |

## 4. Core user flow

1. Open app → **mood grid** (Romantic, Dance, Jolly, Campfire, Festival, …)
2. *(Optional)* **Who's listening?** → Elders · Friends · Mixed · Kids
3. Song list for that mood and crowd. **Ready-to-play** songs first, each row showing key, capo and first line. Or tap **Surprise me**.
4. Song screen → **cue card** (key, capo, strumming pattern, intro, first line, YouTube link) + sheet preview
5. **Play** → 3-2-1 count-in → full-screen sheet auto-scrolls. Tap anywhere to pause or resume.
6. Song ends → stop (or, in a setlist, the next song)

## 5. Features (v1)

### 5.1 Song import & editing
- Import songs from **files** (Files app; several at once) or **paste text**, in the Moodchords format (§6). *(Built in M1.)*
- Clear errors and warnings with line numbers. *(Built in M1.)*
- **Edit a song's text** from the song screen. This is the quick way to fix a wrong chord, since every chord source online gets chords wrong (A5).
- Delete songs. *(Built in M1.)*

### 5.2 Moods
- Default moods: **Romantic, Dance, Jolly, Campfire, Sad, Devotional, Nostalgic, Party, Festival** (Dashain/Tihar, Deusi-Bhailo).
- Add, rename and delete custom moods. A song can have several.

### 5.3 Crowd — "Who's listening?"
- Fixed crowd tags: **Elders, Friends, Mixed, Kids**. A song can have several.
- An optional filter that narrows the mood's song list. Skipping it shows every song in the mood.
- Set via `{crowd: Elders, Mixed}` in the file, or when editing a song.

### 5.4 Recall helpers
- **Ready to play:** mark the songs you can actually play right now. They're listed first, and Surprise me picks only from these.
- **Surprise me:** picks a random ready song within the chosen mood and crowd.
- **Favourites:** star your go-to songs.
- **Setlist / jam session:** queue songs. When one finishes, the next starts after ~5 s with a "Next: …" card.

### 5.5 Song cue card
Shown on the song screen before Play, with a compact version on each song-list row:
- key, **capo**, **strumming pattern**, **intro** note, **first lyric line**
- **YouTube reference link** for a quick listen, since players trust video over text sheets (A6)

### 5.6 Auto-scroll play mode
- Base pace: **song duration**. The sheet scrolls linearly over that time.
- **3-2-1 count-in** before scrolling starts, so your hands are ready.
- **Tap anywhere to pause or resume.** No buttons on screen.
- **Speed nudge:** a light gesture (e.g. a swipe up or down) to go faster or slower. The adjustment is **saved per song**, so it plays right the next time.
- The screen stays awake. A small ✕ or swipe down exits.

### 5.7 Play screen display
- Chords above lyrics, aligned to the right word or syllable, including Devanagari. *(Built in M1.)*
- Chord diagrams for every chord in the song.
- Transpose (±semitones) and capo. Chords and diagrams update.
- Adjustable text size, saved per song.
- Dark / stage mode.

### 5.8 Languages
- Lyrics in Nepali, Hindi (Devanagari) and English, mixed freely. Chord names are always Latin.

### 5.9 Guitar tuner
A built-in chromatic tuner, so you can tune up before playing without leaving the app or opening a second one.
- **Microphone-based:** listens to the guitar through the phone's mic. No clip-on hardware needed.
- **Shows** the nearest note, its string (E A D G B E in standard tuning), and how far sharp or flat it is in cents, with a clear "in tune" state (within ±5 cents).
- **Auto string detection:** pluck any string and the tuner works out which one it is.
- **Big, glanceable display:** readable at arm's length, works in dark/stage mode.
- **Capo-aware hint:** when a song uses a capo, the song screen links to the tuner with a reminder to tune *before* putting the capo on.
- **Reachable from anywhere:** a tuner button on the home screen and on every song screen.
- **Works offline,** like the rest of the app.
- **Later:** alternate tunings (Drop D, half-step down), a reference-tone mode (play the note so you can tune by ear), and an adjustable A4 reference (default 440 Hz).

*Why:* competitors treat a tuner as standard. SongbookPro includes one, and Ultimate Guitar puts its tuner behind the Pro subscription (Appendix A, A7). Tuning at a campfire shouldn't need a second app.

## 6. Song file format

ChordPro-style plain text (`.txt` / `.cho`) with inline `[chords]`:

```
{title: Timi Bina}
{artist: Example Artist}
{key: G}
{capo: 2}
{duration: 4:30}
{mood: Romantic, Campfire}
{crowd: Friends, Mixed}
{strum: D DU UDU}
{intro: G C D x2}
{youtube: https://youtu.be/…}

[G]Timi bina [C]kehi pani [D]chaina
[Em]तिमी बिना [C]केही पनि [D]छैन
```

| Directive | Status |
|---|---|
| `title`, `artist`, `key`, `duration`, `mood`, `comment`, `start_of_chorus` / `verse` / `bridge` | Parsed (M1) |
| `capo`, `crowd`, `strum`, `intro`, `youtube` | To add (M2/M4) |
| `start_of_solo` / `sos` | v1.1, for section-aware scrolling |

Inline chords instead of "chords on the line above": Devanagari letters combine, so space-based alignment breaks. Brackets attach each chord to an exact position.

## 7. Technical decisions

| Area | Decision |
|---|---|
| Platform | iPhone only, native **SwiftUI** (`~/Documents/Apps/GuitarApp`) |
| Storage | **On-device only** (SwiftData). No account, no server, fully offline. Backup is deferred (see §9). |
| Content | **User-added only** for the personal app. See §10. |
| Network | None required. The YouTube link opens outside the app. |
| Tuner | On-device pitch detection from the microphone (AVAudioEngine + a pitch algorithm such as YIN). Needs the microphone permission, asked the first time the tuner opens. No audio is recorded or stored. |

## 8. Business model (for the public release)

The research shows users hate paywalled core features (Ultimate Guitar locks auto-scroll and transpose behind Pro), ads (the Nepali apps' only revenue), and subscriptions (the OnSong backlash, billing complaints about UG and Chordify). So:

- **No ads, ever.**
- **The core is free:** auto-scroll, transpose, moods, crowd, **tuner**.
- **One-time unlock** for extras, e.g. unlimited songs past a generous free tier, setlists, and later the sharing features.

## 9. Out of scope for v1

| Feature | When |
|---|---|
| Section-aware scrolling (pause on solos/instrumentals) | v1.1 |
| Lyrics-only singalong view (big text, no chords) | v1.1 |
| Last-played date / "haven't played in a while" nudge | v1.1 |
| Devanagari ⇄ romanized lyrics toggle | v1.1 |
| Bluetooth page-turner pedal support | v1.1 |
| Live lyrics on friends' phones; audience request queue | Later |
| Sharing/exporting songs to friends | Later |
| Backup (iCloud sync / export all) | Later, chosen on-device only for v1 |
| Licensed starter library | Later (§10) |
| iPad, Android, accounts | Later |
| Tuner extras: alternate tunings, reference tones, adjustable A4 | v1.1 |
| Tap-a-chord editor, OCR, web import | Later |

## 10. Content & licensing

- **Personal app:** I add my own songs (starting from `song-list.md`). On my phone, the app "has the songs".
- **Public release:** ship only **public-domain folk songs** (folk songs are outside Nepal's Copyright Act) plus user-added songs, until licensing is sorted. Routes: **LyricFind/IPRS** for Hindi, **MRCSN** or direct artist deals for Nepali.
- Don't copy lyrics from chord blogs into a public build. MRCSN sent 34,000 demand letters in 2026, and existing Nepali apps rely on disclaimers alone.

## 11. Risks & open questions

1. **Losing every song.** Storage is on-device only and every song is typed by hand, so a lost or reset phone wipes the library. Song loss is a common complaint about competitors (A8). Revisit backup once the library passes ~30 songs.
2. **Scroll drift.** Duration-based scrolling drifts through long intros and solos. Count-in, tap-pause and the saved speed nudge mitigate it. Section-aware scrolling is planned for v1.1.
3. **Devanagari chord placement.** Handled at the parser level (M1). Keep testing with real lyrics.
4. **Creating songs is the bottleneck.** The library starts empty, so adding and editing songs has to stay painless.
5. **Copyright** for any public build (§10).
6. **Name check.** Confirm "Moodchords" is free on the App Store.
7. **Tuner accuracy in noisy places.** Campfires and parties are loud, and other people talking can confuse pitch detection. Test in a noisy room; consider a noise gate and only showing a reading when one clear note is detected.

## 12. Milestones

1. **M1: Song model + parser + import.** ✅ Done 22 Nov 2026.
2. **M2: Browse.** Mood grid (incl. Festival), custom moods, **crowd tags + filter**, favourites, **ready to play + Surprise me**, **edit song text**. Parser: `crowd`.
3. **M3: Play mode.** Rendered sheet, duration auto-scroll, **count-in, tap-to-pause, speed nudge saved per song**, keep awake, dark mode, text size.
4. **M4: Music tools.** Transpose, capo, chord diagrams, **cue card** (capo, strum, intro, first line, YouTube), **guitar tuner** (standard tuning, auto string detection). Parser: `strum`, `intro`, `youtube` (`capo` already done).
5. **M5: Setlists.** Queue + auto-advance.
6. **Dogfood:** load 20+ real songs, play a real jam, then revisit §11 and the v1.1 list.

---

## Appendix A — Research summary (24 Nov 2026)

Three research passes: forum pain points, competitor apps and their reviews, and the Nepali/Hindi chord scene. Reddit and Facebook groups were blocked, so evidence comes from guitar forums, app store reviews, Trustpilot and Nepali press.

| # | Finding | Drives |
|---|---|---|
| A1 | Going blank when asked to "play something" is very common. Players tape a go-to list (key and first line) to the guitar. | Ready to play, Surprise me, cue card |
| A2 | Choosing for the crowd: sing-along choruses work, sad songs flop at campfires, mixed ages need old and new. Nepali crowds expect specific songs (Timro Nyano, Rato Rani, Kale Dai, Parelima). | Crowd filter |
| A3 | Auto-scroll that doesn't keep pace is the #1 functional complaint against every competitor (UG, Set List Maker, SongbookPro, GuitarTapp). | Count-in, tap-pause, nudge |
| A4 | Forgetting how a song starts (intro, strum). Nepali chord blogs rarely give a strumming pattern, and capo positions conflict between sources. | Cue card, `strum`/`capo`/`intro` |
| A5 | Wrong chords everywhere. Sources disclaim accuracy, and players build their own sheets. | Edit song text |
| A6 | YouTube channels (Nepali E-Chords ~158K, Nepali Guitar Tutorial ~121K) are the trusted reference. | `youtube` link |
| A7 | Users hate paywalled core features, ads and subscriptions. | §8 Business model |
| A8 | Song loss from sync bugs and reset devices erodes trust. | §11 Risk 1 |
| A9 | No app offers group features (shared lyrics, request queue). | Later list |
| A10 | The Nepali/Hindi app field is small: one-developer apps with ads and stale catalogues (ChordPedia, Nepali Chords and Lyrics, iAndRobot, Chords Nepal). None has moods or crowd features. | USP |
| A11 | Lyrics copyright is actively enforced: MRCSN (34,000 letters in 2026), IPRS + LyricFind for India. Folk songs are excluded from Nepal's copyright law. | §10 |

**Selected sources**
- Forums: community.justinguitar.com (campfire songs, autoscroll issues, repertoire), forum.gibson.com (playing for guests, brain fade), umgf.com (song list on the side), chordie.com forum (chord accuracy)
- Competitors: App Store pages for Ultimate Guitar, OnSong, SongbookPro, SongBook ChordPro, Chordify, forScore; onsongapp.com/docs/features/autoscroll; Trustpilot for UG, OnSong and Chordify
- Nepal/India: english.onlinekhabar.com (guitar and picnic song lists), kathmandupost.com (Deusi-Bhailo changes), nepsongchords.blogspot.com, mrcsn.org, asiaiplaw.com (MRCSN letters), wipo.int (Nepal Copyright Act), mediainfoline.com (IPRS + LyricFind)
