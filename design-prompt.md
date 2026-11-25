# Claude Design prompt — Moodchords UI

Copy everything below the line into Claude Design and attach your reference images with it.

---

## What I want

Design the complete iPhone UI for **Moodchords**, a songbook app for singer-guitarists. I want to see every screen before any code is written, as high-fidelity mockups on an **iPhone 17 Pro frame (402 × 874 pt)**. Show each screen in **light mode and dark "stage" mode**.

I've attached reference images I like. **Follow their visual style (colour, typography, shapes, mood) over any default choices below.** If a reference conflicts with a functional requirement here, keep the function and adapt the style.

## The app in one paragraph

You've learned dozens of songs, but when a friend says *"oe, baja ta"* ("come on, play something") you blank: no chords, no lyrics, no idea what to play. Moodchords fixes that. You pick the **mood** (Romantic, Campfire, Dance…), optionally **who's listening** (Elders, Friends, Mixed, Kids), and pick a song you're ready to play. A **cue card** reminds you of the key, capo, strumming pattern and how the song starts. You press **Play** and the lyrics and chords **scroll by themselves**, so your hands never leave the guitar. Songs are in **English, Nepali and Hindi**, so the design must handle **Devanagari script (नेपाली / हिन्दी)** as gracefully as English. A built-in **guitar tuner** gets you in tune first.

## Who uses it, and where

- Casual guitarists aged 18–35, mostly in Nepal and the Nepali/Indian diaspora.
- Places: campfires, picnics, hostel rooms, family gatherings, house parties. Often **dim or dark**, often **noisy**, and the phone is usually **propped up about an arm's length away** on a knee, a chair or a rock.
- They glance at the screen while playing and singing. Nothing on the play screen should need reading twice.

## Design principles (in priority order)

1. **Glanceable at arm's length.** Large lyrics, bold chords, high contrast. The play screen is the most important screen in the app.
2. **Hands-free while playing.** No small buttons on the play screen. Anything you might do mid-song is one tap anywhere, or one swipe.
3. **Mood is the identity.** Each mood has its own colour and icon, and the home screen should feel like picking a vibe, not browsing a database.
4. **Calm, not cluttered.** No ads, no badges, no upsell banners. Few elements per screen.
5. **Native iOS feel.** Follow current iOS conventions (navigation bars, sheets, SF Symbols, the translucent "Liquid Glass" controls of iOS 26) unless my references say otherwise.
6. **Bilingual by default.** Every list and card must look right with a long English title, a long Devanagari title and a mixed romanized Nepali title.

## Moods and crowds (use these exactly)

**Moods** (each gets its own colour and SF Symbol-style icon; suggest a palette that works in light and dark):
Romantic · Dance · Jolly · Campfire · Sad · Devotional · Nostalgic · Party · Festival *(Dashain/Tihar)* · plus a "+ New mood" tile.

**Crowd ("Who's listening?")**: Elders · Friends · Mixed · Kids.

## Sample content (use this real data, no lorem ipsum)

**Songs** (title — artist — key — capo — mood — crowd):
- Wonderwall — Oasis — F#m — capo 2 — Campfire — Friends, Mixed
- Perfect — Ed Sheeran — Ab — capo 1 — Romantic — Friends, Mixed
- Take Me Home, Country Roads — John Denver — A — capo 2 — Campfire — Elders, Mixed, Kids
- Three Little Birds — Bob Marley — A — no capo — Jolly — Elders, Mixed, Kids
- Parelima — 1974 AD — E — no capo — Romantic — Friends, Mixed
- Resham — Nepathya — no capo — Campfire — Elders, Friends, Mixed
- Timro Nyano — The Uglyz — Romantic — Friends, Mixed
- Phool Ko Aankha Ma — Ani Choying Drolma — Db — Devotional — Elders, Mixed
- Yo Samjhine Mann Chha — Narayan Gopal — capo 3 — Nostalgic — Elders
- Tum Hi Ho — Arijit Singh (Aashiqui 2) — Fm — capo 1 — Romantic — Friends, Mixed
- Kesariya — Arijit Singh (Brahmāstra) — C — Romantic — Friends, Mixed
- Yeh Dosti — Kishore Kumar & Manna Dey (Sholay) — Campfire — Elders, Mixed, Kids
- साँझको गीत — Moodchords Sample — Am — Romantic, Nostalgic (a Devanagari title, to test layout)

**Lyrics for any lyric or chord-sheet mockup:** use ONLY these original sample lyrics. Don't use real song lyrics anywhere; they're copyrighted.

*Campfire Night* (key G, 2:45, strum `D DU UDU`, intro `G C D ×2`):
```
VERSE 1
[G]Sparks are rising [C]up into the [G]sky
[Em]Friends around the [C]fire and the [D]night rolls by
CHORUS
[C]Sing it loud, [G]sing it slow
[D]Every song we [G]used to know
VERSE 2
[G]Someone's got a [C]story, someone's [G]got a tune
[Em]Strumming till the [C]morning chases [D]off the moon
```

*साँझको गीत* (key Am, 3:10):
```
VERSE
[Am]साँझ परेपछि [F]पहाड हेर्छु
[C]तिम्रो याद [G]मनमा बोक्छु
[Am]Saanjh parepachhi [F]pahad herchhu
CHORUS
[F]बिस्तारै [G]बिस्तारै
[Am]गीत यो [G]गाउँछु [Am]म
```

A `[chord]` marks where the chord sits. **Draw chords above the syllable they belong to**, in a bold accent colour, not inline in brackets. Long chord names (Em7, A7sus4, Cadd9) should hang over the following words rather than pushing them apart.

## Screens to design

For each screen: the main state, plus the extra states listed.

### 1. Home: mood grid
- Large title "Moodchords".
- A grid of mood tiles (2 columns), each with its icon, name, colour and song count ("12 songs").
- A prominent **"Surprise me"** button that picks a random song I'm ready to play.
- Quick access to the **tuner**, **favourites**, **setlists** and **add song (+)**.
- Optional search.
- *States:* first launch with no songs (inviting empty state: "Add your first song" with Import file / Paste song), and a normal state with songs.

### 2. "Who's listening?" crowd picker
- Appears after picking a mood (a sheet or an inline segmented row; recommend one).
- Four options (Elders, Friends, Mixed, Kids) plus "Anyone" to skip.
- Should feel like a quick one-tap choice, not a form.

### 3. Song list (for a mood + crowd)
- Header shows the mood (with its colour) and the chosen crowd, both changeable.
- "Ready to play" songs grouped at the top, the rest below.
- Each row works like a mini setlist note: title, artist, **key and capo**, and the **first lyric line** in small text. Also a favourite star and a ready-to-play indicator.
- Include at least one Devanagari title.
- *States:* a mood with no songs for that crowd.

### 4. Song screen (before playing)
- Title, artist, mood and crowd tags.
- The **cue card**, the most important part, which answers "how does this song start?":
  - key, capo, strumming pattern (show it visually, e.g. ↓ ↓↑ ↑↓↑), intro, first line
  - a YouTube reference link ("Listen first")
- A strip of **chord diagrams** (finger-position boxes) for every chord in the song.
- Controls for **transpose (− / +)**, **capo**, **text size**, a ready-to-play toggle, favourite, and edit.
- A scrollable preview of the chord sheet.
- A big, unmissable **Play** button.
- Show it for *Campfire Night* (English) and *साँझको गीत* (Devanagari).

### 5. Play mode (the most important screen)
- Full screen, dark by default, very large lyrics with bold chords above them.
- The current line is highlighted; past lines fade.
- No visible buttons except a tiny ✕ (or a swipe-down hint) to exit.
- A thin progress indicator showing how far through the song you are.
- *States to show:*
  1. **3-2-1 count-in** before scrolling starts
  2. **Scrolling** mid-song
  3. **Paused** after a tap anywhere (a subtle overlay, "Tap to resume")
  4. **Speed nudge** feedback after a swipe up/down ("Faster · saved for this song")
  5. **Song finished**, and in a setlist the **"Next: Perfect – Ed Sheeran"** card with a 5-second countdown
- Show light stage mode as well, and one Devanagari version.

### 6. Guitar tuner
- Big detected note (e.g. "A"), the string it belongs to, and a needle or meter showing cents flat/sharp.
- A clear **in-tune** state (colour change, check mark).
- The six strings E A D G B E, with the detected one highlighted.
- Must be readable at arm's length and in the dark.
- *States:* listening (no note yet), flat, sharp, in tune, and the first-time **microphone permission** explanation screen.
- Small note on the song screen for capo songs: "Tune before putting the capo on."

### 7. Add song
- An entry point offering **Import file** or **Paste song**.
- **Paste screen:** a text area with a "Template" button and clear inline error messages (e.g. "The song needs a title").
- **Import result:** "Added 10 songs", with a short, friendly list of any warnings (e.g. "No song length set; auto-scroll will assume 3:30").

### 8. Edit song
- A text editor for the song file (monospaced, with chords highlighted), plus simple fields for title, artist, key, capo, duration, moods and crowd.
- A live preview toggle.

### 9. Favourites and setlists
- **Favourites:** a simple list.
- **Setlist builder:** name the jam ("Friday campfire"), add songs, drag to reorder, and see the total time. Then "Start jam".

### 10. Manage moods
- The mood list with the 9 defaults, plus add, rename, delete and reorder custom moods, and a colour/icon picker for a new mood.

## Interactions and flow to illustrate

Show one **user-flow strip** with screens left to right: Home → pick *Campfire* → Who's listening: *Friends* → Song list → *Wonderwall* song screen → Play (count-in) → Play (scrolling).

Annotate key interactions with small callouts: tap anywhere to pause, swipe up/down for speed, swipe down to exit, long-press a song row for quick actions (favourite, ready to play, add to setlist).

## Visual direction (defaults, overridden by my reference images)

- **Mood:** warm, musical and a little nostalgic, like a campfire at dusk. Not a corporate dashboard.
- **Colour:** a dark, warm stage background (near-black with a hint of warmth) and a light mode with soft off-white. Each mood has its own accent colour. Chords use one consistent accent that stays readable on both.
- **Typography:** SF Pro (or the reference font). Lyrics are large, around 24–28 pt in play mode. Chords are bold and slightly smaller than the lyrics. Devanagari falls back to a matching Devanagari face (e.g. Kohinoor Devanagari / Noto Sans Devanagari) with enough line height that vowel signs aren't clipped.
- **Shapes:** rounded cards and tiles, soft depth, generous spacing.
- **Accessibility:** WCAG AA contrast at minimum (AAA for play-mode text), 44 pt minimum tap targets, and nothing that relies on colour alone.

## Deliverables

1. Every screen and state above in **light and dark**, at iPhone 17 Pro size.
2. The **user-flow strip** with interaction callouts.
3. A **mini style guide**:
   - the mood colour palette with icons
   - type scale (including the Devanagari pairing)
   - chord and lyric styling
   - buttons, chips, cards
   - the chord-diagram component
   - the tuner meter
4. A short note on any design decision where you chose between options (e.g. sheet vs inline crowd picker), so I can push back.

## Things to avoid

- Real song lyrics (use only the sample lyrics above).
- Ads, upgrade banners, paywalls, streaks or gamification.
- Tiny controls or dense text on the play screen.
- Making the Devanagari layout an afterthought.
