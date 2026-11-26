// Run with: node web/tests/core.test.mjs   (ports of key cases from GuitarAppFinalTests)
import assert from "node:assert/strict";
import * as C from "../core.js";
let n = 0;
const t = (name, fn) => { try { fn(); n++; } catch (e) { console.error("FAIL", name, e.message); process.exitCode = 1; } };
const tab = (s) => s.frets.map((f) => (f === null ? "x" : f < 10 ? String(f) : `(${f})`)).join("");

t("merge by column", () => assert.equal(C.mergeChordLine("G" + " ".repeat(10) + "C", "Sparks are rising up"), "[G]Sparks are [C]rising up"));
t("merge pads", () => assert.equal(C.mergeChordLine("G      D", "Hey"), "[G]Hey    [D]"));
t("merge devanagari", () => { const m = C.mergeChordLine("Am   F", "साँझ परेपछि"); assert.ok(m.startsWith("[Am]")); assert.equal(m.replace("[Am]", "").replace("[F]", ""), "साँझ परेपछि"); });
t("convert sheet", () => assert.equal(C.convertIfNeeded(`{title: Campfire Night}
Em7   0-2-2-0-3-3
G     320003
[Intro]
Em7  G  Dsus4 | x2
[Verse 1]
G                 C
Sparks are rising up
e|---0---3---|`), `{title: Campfire Night}
{comment: Intro}
[Em7] [G] [Dsus4]
{comment: Verse 1}
[G]Sparks are rising [C]up`));
t("inline untouched", () => { const s = "{title: X}\n[Verse]\n[G]Hello [C]world"; assert.equal(C.convertIfNeeded(s), s); });
t("plain untouched", () => { const s = "{title: X}\nJust words here\nAnd more words"; assert.equal(C.convertIfNeeded(s), s); });
for (const c of ["G", "Am", "F#m7", "Bb", "Cadd9", "Dsus4", "A7sus4", "G/F#", "Bm7b5", "Cmaj7", "E7(#9)", "Gdim"]) t("chord " + c, () => assert.ok(C.isChord(c)));
for (const c of ["Hello", "I", "Am I", "Go", "Chorus", "x2"]) t("not chord " + c, () => assert.ok(!C.isChord(c)));
t("chord lines", () => { assert.ok(!C.isChordLine("A man walks down")); assert.ok(C.isChordLine("  G   C  (x2)")); });
t("labels", () => { assert.equal(C.sectionLabel("[Verse 1]"), "Verse 1"); assert.equal(C.sectionLabel("[G]"), null); });
t("converted parses", () => {
  const s = C.parse(C.convertIfNeeded("{title: X}\n{duration: 1:00}\n[Chorus]\nC        G\nSing it loud"));
  assert.deepEqual(s.lines, [{ type: "section", text: "Chorus" }, { type: "lyrics", segments: [{ chord: "C", text: "Sing it l" }, { chord: "G", text: "oud" }] }]);
});
for (const [name, tb] of [["C", "x32010"], ["G", "320003"], ["Am", "x02210"], ["Em7", "022030"], ["Dsus4", "xx0233"], ["G/B", "x20003"], ["F", "133211"], ["Bm", "x24432"], ["Bb", "x13331"], ["C#m", "x46654"], ["F#m7", "242222"], ["Ab", "466544"], ["Fm", "133111"], ["Ebmaj7", "x68786"], ["C9", "x32333"], ["Bdim", "x2343x"]])
  t("shape " + name, () => assert.equal(tab(C.chordShape(name)), tb));
t("barre", () => { assert.equal(C.chordShape("Bb").barre, 1); assert.equal(C.chordShape("C#m").barre, 4); assert.equal(C.chordShape("C").barre, null); });
t("slash fallback", () => assert.equal(tab(C.chordShape("F#m/E")), tab(C.chordShape("F#m"))));
for (const x of ["N.C.", "H", "", "Intro"]) t("no shape " + x, () => assert.equal(C.chordShape(x), null));
t("chord name", () => assert.deepEqual(C.parseChordName("F#m7/E"), { root: 6, quality: "m7", bass: 4 }));

// Parser
t("samples parse", () => C.SAMPLE_SONGS.forEach((s) => C.parse(s)));
t("devanagari split letter", () => {
  const w = []; const segs = C.parseLyricLine("[Am]साँ[F]झ", 1, w); assert.equal(segs.map((s) => s.text).join(""), "साँझ");
  const segs2 = C.parseLyricLine("[Am]स[F]ाँझ", 1, w); assert.equal(segs2[0].text, "साँ"); assert.equal(segs2[1].chord, "F"); assert.equal(w.length, 1);
});
t("directives", () => {
  const s = C.parse("{title: A}\n{key: G}\n{capo: 2nd fret}\n{duration: 4:05}\n{mood: Romantic, romantic, Sad}\n{crowd: Friends}\n{language: Nepali}\n[G]Hi");
  assert.equal(s.capo, 2); assert.equal(s.duration, 245); assert.deepEqual(s.moods, ["Romantic", "Sad"]); assert.equal(s.language, "Nepali"); assert.deepEqual(s.chords, ["G"]);
});
t("missing title", () => assert.throws(() => C.parse("[G]Hi"), C.ParseError));
t("brace lyric", () => { const s = C.parse("{title: A}\n{Pyaar ka, sapna}"); assert.equal(s.lines[0].type, "lyrics"); });
t("notes", () => {
  const s = C.parse("{title: A}\nCapo: 1st fret\nVideo https://x.y\n[Verse]\n[G]Hi there\n------\n| G D | Em |\nx2");
  assert.deepEqual(s.lines.map((l) => l.type), ["note", "note", "section", "lyrics", "lyrics", "note"]);
});
t("duration", () => { assert.equal(C.parseDuration("1:02:03"), 3723); assert.equal(C.parseDuration("4:75"), null); assert.equal(C.parseDuration("270"), 270); });
t("summary", () => { const s = C.summary(C.parse(C.SAMPLE_SONGS[0])); assert.equal(s.metaLine, "G · 2:45"); assert.equal(s.cueLine, "Sparks are rising up into the sky"); });
t("summary default", () => assert.equal(C.summary(C.parse("{title: A}\n{capo: 3}\n[G] [C]")).metaLine, "KEY ? · CAPO 3 · ~3:30"));
t("pieces", () => assert.deepEqual(C.pieces([{ chord: "G", text: "Hello   big " }, { chord: "C", text: " world" }]).map((p) => [p.chord, p.text]), [["G", "Hello "], [null, "big "], ["C", "world"]]));
t("setField", () => {
  let s = "{title: A}\n{key: G}\n\n[G]Hi";
  s = C.setField("capo", "2", s); assert.equal(s, "{title: A}\n{key: G}\n{capo: 2}\n\n[G]Hi");
  s = C.setField("key", "", s); assert.equal(C.fieldValue("key", s), null);
  s = C.setFieldList("mood", ["Sad", "Jolly"], s); assert.deepEqual(C.fieldList("mood", s), ["Sad", "Jolly"]);
});
t("renamed tags", () => assert.deepEqual(C.renamedTags(["sad", "Jolly"], "Sad", "Jolly"), ["Jolly"]));

// Pitch
const tone = (f, sr = 48000, count = 4096) => Float32Array.from({ length: count }, (_, i) => { const x = i / sr; return 0.3 * (Math.sin(2 * Math.PI * f * x) + 0.5 * Math.sin(4 * Math.PI * f * x) + 0.25 * Math.sin(6 * Math.PI * f * x)); });
for (const s of C.STRINGS) t("pitch " + s.frequency, () => assert.ok(Math.abs(C.cents(C.detectPitch(tone(s.frequency), 48000), s.frequency)) < 3));
t("silence", () => assert.equal(C.detectPitch(new Float32Array(4096), 48000), null));
t("nearest", () => { assert.equal(C.nearestString(108).number, 5); assert.equal(C.noteNameFor(440), "A"); });
console.log(`${n} passed`);
