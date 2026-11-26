// Moodchords core logic, ported from the Swift app (GuitarAppFinal/Core).
// No DOM here: parsing, chord sheets, chord shapes, tuning, summaries and source editing.

// ---------------------------------------------------------------- helpers

const trimH = (s) => s.replace(/^[ \t 　]+|[ \t 　]+$/g, "");
const lower = (s) => s.toLowerCase();
export const normalizedName = (name) => lower(trimH(name));

// ---------------------------------------------------------------- chord sheet converter

const CHORD_RE = /^[A-G](?:#|b)?(?:maj|min|m|M|dim|aug|sus|add|\+|°|ø|[0-9]|#|b|\(|\))*(?:\/[A-G](?:#|b)?)?$/;
const INLINE_CHORD_RE = /\[[A-G](?:#|b)?[^\]\s]*\]/;
const FILLER = new Set(["|", "||", "/", "-", "–", "N.C.", "NC", "(", ")"]);

export function isChord(token) {
  return CHORD_RE.test(token);
}

const tokens = (line) => line.split(/\s+/).filter(Boolean);

function isRepeatMarker(token) {
  const l = token.toLowerCase().replace(/^[()]+|[()]+$/g, "");
  return /^x?\d+x?$/.test(l);
}

function isDirectiveLine(line) {
  const t = trimH(line);
  return t.startsWith("{") && t.endsWith("}");
}

export function isChordLine(line) {
  const toks = tokens(line);
  if (!toks.length) return false;
  let count = 0;
  for (const t of toks) {
    if (isChord(t)) { count++; continue; }
    if (FILLER.has(t) || isRepeatMarker(t)) continue;
    return false;
  }
  return count > 0;
}

/** `[Verse 1]` → "Verse 1". A bracketed chord like `[G]` is not a label. */
export function sectionLabel(line) {
  const t = trimH(line);
  if (!t.startsWith("[") || !t.endsWith("]") || [...t].length <= 2) return null;
  const inner = trimH(t.slice(1, -1));
  if (inner.includes("[") || isChord(inner)) return null;
  return inner;
}

function isFingeringLine(line) {
  const toks = tokens(line);
  if (toks.length !== 2 || !isChord(toks[0])) return false;
  return /^[0-9xX]([-\s]?[0-9xX]){5}$/.test(toks[1]);
}

function isTabLine(line) {
  return /^[eBGDAEbgda]\s?\|[-0-9hpbr/\\|~x\s]*$/.test(trimH(line));
}

function isLyricLine(line) {
  return trimH(line) !== "" && !isChordLine(line) && !isDirectiveLine(line)
    && sectionLabel(line) === null && !isFingeringLine(line) && !isTabLine(line);
}

export function needsConversion(lines) {
  const body = lines.filter((l) => !isDirectiveLine(l));
  const hasInline = body.some((l) => l.includes("[") && !isChordLine(l) && sectionLabel(l) === null && INLINE_CHORD_RE.test(l));
  const chordLines = body.filter(isChordLine).length;
  return !hasInline && chordLines > 0;
}

function chordPositions(line) {
  const chars = [...line, " "];
  const result = [];
  let token = "", start = 0;
  chars.forEach((c, i) => {
    if (/\s/.test(c)) {
      if (token && isChord(token)) result.push([start, token]);
      token = "";
    } else {
      if (!token) start = i;
      token += c;
    }
  });
  return result;
}

const graphemes = (s) => (typeof Intl !== "undefined" && Intl.Segmenter
  ? Array.from(new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(s), (x) => x.segment)
  : [...s]);

export function mergeChordLine(chordLine, lyricLine) {
  const lyric = graphemes(lyricLine);
  const chords = chordPositions(chordLine);
  const last = chords.length ? chords[chords.length - 1][0] : 0;
  while (lyric.length < last) lyric.push(" ");
  for (const [col, chord] of [...chords].reverse()) {
    lyric.splice(Math.min(col, lyric.length), 0, `[${chord}]`);
  }
  return lyric.join("");
}

function chordOnlyLine(line) {
  return chordPositions(line).map(([, c]) => `[${c}]`).join(" ");
}

function convertLines(lines) {
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (isDirectiveLine(line)) out.push(line);
    else if (isFingeringLine(line) || isTabLine(line)) { /* dropped */ }
    else if (sectionLabel(line) !== null) out.push(`{comment: ${sectionLabel(line)}}`);
    else if (isChordLine(line)) {
      const next = lines[i + 1];
      if (next !== undefined && isLyricLine(next)) { out.push(mergeChordLine(line, next)); i++; }
      else out.push(chordOnlyLine(line));
    } else out.push(line);
  }
  return out;
}

/** Chords-above-lyrics → inline [chords], if the text looks like that layout. */
export function convertIfNeeded(text) {
  const lines = text.split(/\r\n|\r|\n/);
  return needsConversion(lines) ? convertLines(lines).join("\n") : text;
}

// ---------------------------------------------------------------- parser

export const DEFAULT_DURATION = 210;

export class ParseError extends Error {}

export function looksLikeDirective(line) {
  return /^\{\s*[A-Za-z_]+\s*(:|\}|$)/.test(line);
}

function appendTags(value, tags) {
  for (const raw of value.split(",")) {
    const t = trimH(raw);
    if (!t || tags.some((x) => x.toLowerCase() === t.toLowerCase())) continue;
    tags.push(t);
  }
}

export function parseCapo(value) {
  const l = trimH(value.toLowerCase());
  if (l === "none" || l === "no capo" || l === "no") return 0;
  const m = l.match(/^\d+/);
  if (!m) return null;
  const fret = parseInt(m[0], 10);
  return fret <= 12 ? fret : null;
}

export function parseDuration(value) {
  const parts = trimH(value).split(":");
  if (parts.length < 1 || parts.length > 3) return null;
  if (!parts.every((p) => /^\d+$/.test(p))) return null;
  const nums = parts.map(Number);
  if (parts.length > 1 && nums.slice(1).some((n) => n >= 60)) return null;
  const s = nums.reduce((a, n) => a * 60 + n, 0);
  return s > 0 ? s : null;
}

const isCombining = (cp) => /\p{M}/u.test(cp) || cp === "‍" || cp === "‌";

/** Splits `[G]Timi [C]bina` into segments. Works on code points so Devanagari marks survive. */
export function parseLyricLine(line, lineNumber = 0, warnings = []) {
  const cps = Array.from(line);
  const segs = [];
  let chord = null, text = "";
  const flush = () => {
    if (chord !== null || text) segs.push({ chord, text });
    text = "";
  };
  for (let i = 0; i < cps.length; i++) {
    const c = cps[i];
    if (c === "[") {
      const close = cps.indexOf("]", i + 1);
      if (close !== -1) {
        flush();
        const name = trimH(cps.slice(i + 1, close).join(""));
        chord = name || null;
        i = close;
        continue;
      }
      warnings.push({ line: lineNumber, message: "A [ has no matching ], so it's shown as lyrics." });
    }
    text += c;
  }
  flush();
  // Repair chords placed inside a letter: move leading combining marks back.
  for (let i = 1; i < segs.length; i++) {
    const cp = Array.from(segs[i].text);
    let n = 0;
    while (n < cp.length && isCombining(cp[n])) n++;
    if (n > 0) {
      segs[i - 1].text += cp.slice(0, n).join("");
      segs[i].text = cp.slice(n).join("");
      if (segs[i].chord) warnings.push({ line: lineNumber, message: `Chord [${segs[i].chord}] was inside a letter, so it was moved to the next letter.` });
    }
  }
  return segs;
}

const isLink = (t) => /https?:\/\/|www\./i.test(t);
const isFingering = (t) => /(^|\s)[0-9xX]([-–][0-9xX(][0-9)]?){4,}/.test(t)
  || /^[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]-[EADGBe]$/.test(t);
const isDivider = (t) => {
  const marks = t.replace(/\s/g, "");
  return [...marks].length >= 3 && [...marks].every((c) => "-=_*~–—".includes(c));
};
const isRepeatMark = (t) => /^\(?(?:[xX×]\d*|\d+[xX×])\)?$/.test(t);

export function barChords(text) {
  if (!text.includes("|")) return null;
  const chords = [];
  for (const tok of tokens(text)) {
    const cleaned = tok.replace(/^[|()[\]]+|[|()[\]]+$/g, "");
    if (!cleaned || cleaned === "%" || /^x?\d+x?$/.test(cleaned.toLowerCase())) continue;
    if (!isChord(cleaned)) return null;
    chords.push(cleaned);
  }
  return chords.length ? chords : null;
}

const hasChord = (line) => line.type === "lyrics" && line.segments.some((s) => s.chord);

function markNotes(lines) {
  const firstChord = lines.findIndex(hasChord);
  let songStart = null;
  if (firstChord !== -1) {
    for (let i = firstChord - 1; i >= 0; i--) if (lines[i].type === "section") { songStart = i; break; }
  }
  const out = [];
  lines.forEach((line, index) => {
    const pre = songStart !== null && index < songStart;
    if (line.type === "section" && pre) { out.push({ type: "note", text: line.text }); return; }
    if (line.type === "lyrics" && line.segments.every((s) => !s.chord)) {
      const text = line.segments.map((s) => s.text).join("").trim();
      if (isDivider(text)) return;
      const bars = barChords(text);
      if (bars) { out.push({ type: "lyrics", segments: bars.map((c) => ({ chord: c, text: "" })) }); return; }
      if (pre || isLink(text) || isFingering(text) || isRepeatMark(text)) { out.push({ type: "note", text }); return; }
    }
    out.push(line);
  });
  return out;
}

function tidyBlankLines(lines) {
  const out = [];
  for (const l of lines) {
    if (l.type === "blank" && (!out.length || out[out.length - 1].type === "blank")) continue;
    out.push(l);
  }
  while (out.length && out[out.length - 1].type === "blank") out.pop();
  return out;
}

/**
 * Parses a song. Lines are {type: "lyrics", segments}, {type: "section", text},
 * {type: "note", text} or {type: "blank"}.
 */
export function parse(source) {
  let text = source.replace(/^﻿/, "");
  if (!text.trim()) throw new ParseError("The song is empty.");
  let title = null, artist = null, key = null, duration = null, capo = null, language = null;
  const moods = [], crowds = [], warnings = [];
  let lines = [];

  text.split(/\r\n|\r|\n|\u2028|\u2029/).forEach((raw, idx) => {
    const n = idx + 1;
    const line = trimH(raw);
    if (!line) { lines.push({ type: "blank" }); return; }
    if (line.startsWith("#")) return;
    if (line.startsWith("{") && looksLikeDirective(line)) {
      if (!line.endsWith("}")) {
        warnings.push({ line: n, message: "Directive is missing a closing }, so it was skipped." });
        return;
      }
      const inner = line.slice(1, -1);
      const colon = inner.indexOf(":");
      const name = lower(trimH(colon === -1 ? inner : inner.slice(0, colon)));
      const value = colon === -1 ? "" : trimH(inner.slice(colon + 1));
      switch (name) {
        case "title": case "t": title = value || null; break;
        case "artist": case "subtitle": case "st": artist = value || null; break;
        case "key": key = value || null; break;
        case "duration": {
          const s = parseDuration(value);
          if (s) duration = s;
          else warnings.push({ line: n, message: `Couldn't read duration "${value}". Use minutes:seconds, e.g. {duration: 4:30}.` });
          break;
        }
        case "mood": case "moods": appendTags(value, moods); break;
        case "crowd": case "crowds": appendTags(value, crowds); break;
        case "capo": {
          const f = parseCapo(value);
          if (f === null) warnings.push({ line: n, message: `Couldn't read capo "${value}". Use a fret number, e.g. {capo: 2}.` });
          else capo = f > 0 ? f : null;
          break;
        }
        case "language": case "lang": language = value || null; break;
        case "comment": case "c": case "comment_italic": case "ci":
          if (value) lines.push({ type: "section", text: value });
          break;
        case "start_of_solo": case "sos": lines.push({ type: "section", text: value || "Solo" }); break;
        case "start_of_chorus": case "soc": lines.push({ type: "section", text: value || "Chorus" }); break;
        case "start_of_verse": case "sov": lines.push({ type: "section", text: value || "Verse" }); break;
        case "start_of_bridge": case "sob": lines.push({ type: "section", text: value || "Bridge" }); break;
        case "end_of_solo": case "eos": case "end_of_chorus": case "eoc":
        case "end_of_verse": case "eov": case "end_of_bridge": case "eob": break;
        default: warnings.push({ line: n, message: `Unknown directive {${name}} was ignored.` });
      }
      return;
    }
    const label = sectionLabel(line);
    if (label !== null) { lines.push({ type: "section", text: label }); return; }
    lines.push({ type: "lyrics", segments: parseLyricLine(line, n, warnings) });
  });

  if (!title) throw new ParseError("The song needs a title. Add a line like {title: My Song}.");
  lines = markNotes(lines);
  if (duration === null) warnings.push({ line: 1, message: "No {duration:} found. Auto-scroll will assume 3:30." });

  const song = { title, artist, key, duration, moods, crowds, capo, language, lines: tidyBlankLines(lines), warnings };
  song.effectiveDuration = duration ?? DEFAULT_DURATION;
  const seen = new Set();
  song.chords = [];
  for (const l of song.lines) if (l.type === "lyrics") for (const s of l.segments) {
    if (s.chord && !seen.has(s.chord)) { seen.add(s.chord); song.chords.push(s.chord); }
  }
  return song;
}

export function tryParse(source) {
  try { return parse(source); } catch { return null; }
}

/** Splits segments into word pieces so lines wrap between words. Runs of spaces collapse. */
export function pieces(segments) {
  const result = [];
  for (const seg of segments) {
    const collapsed = seg.text.replace(/\s+/g, " ");
    const words = collapsed.match(/[^ ]+ ?| /g) || [];
    if (words[0] === " ") {
      words.shift();
      const last = result[result.length - 1];
      if (last && !last.text.endsWith(" ")) last.text += " ";
    }
    if (!words.length) {
      if (seg.chord) result.push({ chord: seg.chord, text: "" });
      continue;
    }
    words.forEach((w, i) => result.push({ chord: i === 0 ? seg.chord : null, text: w }));
  }
  return result;
}

// ---------------------------------------------------------------- summary

export function formatDuration(s) {
  s = Math.max(0, Math.round(s));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

export function summary(parsed) {
  if (!parsed) return { metaLine: "KEY ?", cueLine: "No cue yet. Add how it starts.", firstLine: null };
  let firstLine = null;
  for (const l of parsed.lines) {
    if (l.type !== "lyrics") continue;
    const t = l.segments.map((s) => s.text).join("").split(/\s+/).filter(Boolean).join(" ");
    if (t) { firstLine = t; break; }
  }
  const opening = parsed.chords.slice(0, 4);
  const parts = [parsed.key || "KEY ?"];
  if (parsed.capo) parts.push(`CAPO ${parsed.capo}`);
  parts.push(parsed.duration ? formatDuration(parsed.duration) : "~" + formatDuration(DEFAULT_DURATION));
  const cueLine = firstLine || (opening.length ? "Starts on " + opening.join(" · ") : "No cue yet. Add how it starts.");
  return { metaLine: parts.join(" · "), cueLine, firstLine, openingChords: opening };
}

// ---------------------------------------------------------------- source editing

const FIELD_ALIASES = {
  title: ["title", "t"], artist: ["artist", "subtitle", "st"], key: ["key"], capo: ["capo"],
  duration: ["duration"], mood: ["mood", "moods"], crowd: ["crowd", "crowds"], language: ["language", "lang"],
};
const HEADER_NAMES = new Set(Object.values(FIELD_ALIASES).flat());

function directiveIn(line) {
  const t = trimH(line);
  if (!looksLikeDirective(t) || !t.endsWith("}")) return null;
  const inner = t.slice(1, -1);
  const colon = inner.indexOf(":");
  if (colon === -1) return { name: lower(trimH(inner)), value: "" };
  return { name: lower(trimH(inner.slice(0, colon))), value: trimH(inner.slice(colon + 1)) };
}

export function fieldValue(field, source) {
  for (const line of source.split("\n")) {
    const d = directiveIn(line);
    if (d && FIELD_ALIASES[field].includes(d.name)) return d.value;
  }
  return null;
}

export function fieldList(field, source) {
  return (fieldValue(field, source) || "").split(",").map(trimH).filter(Boolean);
}

export function setField(field, newValue, source) {
  const lines = source.split("\n");
  const matches = lines.map((l, i) => [l, i]).filter(([l]) => {
    const d = directiveIn(l);
    return d && FIELD_ALIASES[field].includes(d.name);
  }).map(([, i]) => i);
  const value = trimH(newValue ?? "");
  const newLine = `{${field}: ${value}}`;
  if (!value) {
    for (const i of matches.reverse()) lines.splice(i, 1);
  } else if (matches.length) {
    for (const i of matches.slice(1).reverse()) lines.splice(i, 1);
    lines[matches[0]] = newLine;
  } else {
    let at = 0;
    for (let i = 0; i < lines.length; i++) {
      const d = directiveIn(lines[i]);
      if (d && HEADER_NAMES.has(d.name)) at = i + 1;
      else if (trimH(lines[i])) break;
    }
    lines.splice(at, 0, newLine);
  }
  return lines.join("\n");
}

export function setFieldList(field, values, source) {
  return setField(field, values.join(", "), source);
}

export function duplicateKey(source) {
  return setField("language", null, source).replace(/\r\n/g, "\n").trim();
}

// ---------------------------------------------------------------- chord shapes

const NOTE_VALUES = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const QUALITY = {
  "": "", M: "", maj: "", m: "m", min: "m", "-": "m", 7: "7", dom7: "7",
  maj7: "maj7", M7: "maj7", "Δ": "maj7", "Δ7": "maj7", ma7: "maj7",
  m7: "m7", min7: "m7", "-7": "m7", sus4: "sus4", sus: "sus4", sus2: "sus2", 2: "sus2",
  "7sus4": "7sus4", "7sus": "7sus4", add9: "add9", add2: "add9", 6: "6", m6: "m6",
  9: "9", m9: "m7", maj9: "maj7", 11: "7sus4", 13: "7",
  dim: "dim", "°": "dim", o: "dim", dim7: "dim7", "°7": "dim7", o7: "dim7",
  m7b5: "m7b5", "ø": "m7b5", "ø7": "m7b5", aug: "aug", "+": "aug", 5: "5",
  mmaj7: "m", madd9: "m", "7b9": "7", "7#9": "7",
};

function normaliseQuality(text) {
  const q = text.replace(/[()]/g, "");
  if (q in QUALITY) return QUALITY[q];
  return q.startsWith("m") && !q.startsWith("maj") ? "m" : "";
}

export function parseChordName(name) {
  let rest = trimH(name);
  if (!(rest[0] in NOTE_VALUES)) return null;
  let root = NOTE_VALUES[rest[0]];
  rest = rest.slice(1);
  if (rest[0] === "#") { root++; rest = rest.slice(1); } else if (rest[0] === "b") { root--; rest = rest.slice(1); }
  let bass = null;
  const slash = rest.indexOf("/");
  if (slash !== -1) {
    const b = rest.slice(slash + 1);
    rest = rest.slice(0, slash);
    if (b[0] in NOTE_VALUES) {
      bass = NOTE_VALUES[b[0]] + (b[1] === "#" ? 1 : b[1] === "b" ? -1 : 0);
      bass = (bass + 12) % 12;
    }
  }
  return { root: (root + 12) % 12, quality: normaliseQuality(rest), bass };
}

const shape = (tab, barre = null) => ({ frets: [...tab].map((c) => (c === "x" ? null : Number(c))), barre });
const OPEN = {
  C: shape("x32010"), D: shape("xx0232"), E: shape("022100"), G: shape("320003"),
  A: shape("x02220"), F: shape("133211", 1), B: shape("x24442", 2),
  Am: shape("x02210"), Dm: shape("xx0231"), Em: shape("022000"), Bm: shape("x24432", 2), "F#m": shape("244222", 2),
  A7: shape("x02020"), B7: shape("x21202"), C7: shape("x32310"), D7: shape("xx0212"), E7: shape("020100"), G7: shape("320001"),
  Cmaj7: shape("x32000"), Dmaj7: shape("xx0222"), Emaj7: shape("021100"), Fmaj7: shape("xx3210"), Gmaj7: shape("320002"), Amaj7: shape("x02120"),
  Am7: shape("x02010"), Dm7: shape("xx0211"), Em7: shape("022030"), Bm7: shape("x20202"),
  Asus4: shape("x02230"), Dsus4: shape("xx0233"), Esus4: shape("022200"), Asus2: shape("x02200"), Dsus2: shape("xx0230"),
  A7sus4: shape("x02030"), Cadd9: shape("x32033"), Gsus4: shape("330013"),
  A6: shape("x02222"), C6: shape("x32210"), D6: shape("xx0202"), E6: shape("022120"),
  "G/B": shape("x20003"), "C/G": shape("332010"), "C/E": shape("032010"), "D/F#": shape("200232"), "Am/G": shape("302210"), "Em/D": shape("xx0000"),
};
const N = null;
const E_SHAPE = {
  "": [0, 2, 2, 1, 0, 0], m: [0, 2, 2, 0, 0, 0], 7: [0, 2, 0, 1, 0, 0], m7: [0, 2, 0, 0, 0, 0],
  maj7: [0, N, 1, 1, 0, N], sus4: [0, 2, 2, 2, 0, 0], "7sus4": [0, 2, 0, 2, 0, 0], 5: [0, 2, 2, N, N, N],
  6: [0, N, -1, 1, 0, N], m6: [0, N, -1, 0, 0, N],
};
const A_SHAPE = {
  "": [N, 0, 2, 2, 2, 0], m: [N, 0, 2, 2, 1, 0], 7: [N, 0, 2, 0, 2, 0], m7: [N, 0, 2, 0, 1, 0],
  maj7: [N, 0, 2, 1, 2, 0], sus4: [N, 0, 2, 2, 3, 0], sus2: [N, 0, 2, 2, 0, 0], "7sus4": [N, 0, 2, 0, 3, 0],
  dim: [N, 0, 1, 2, 1, N], m7b5: [N, 0, 1, 0, 1, N], dim7: [N, 0, 1, 2, 1, 2], aug: [N, 0, 3, 2, 2, 1],
  6: [N, 0, 2, 2, 2, 2], m6: [N, 0, 2, 2, 1, 2], 9: [N, 0, -1, 0, 0, 0], add9: [N, 0, 2, 4, 0, 0], 5: [N, 0, 2, 2, N, N],
};
const NOTE_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

function place(offsets, fret) {
  const frets = offsets.map((o) => (o === null ? null : fret + o));
  const barred = frets.filter((f) => f === fret).length >= 2;
  return { frets, barre: fret > 0 && barred ? fret : null };
}

export function chordShape(name) {
  const cleaned = trimH(name);
  if (OPEN[cleaned]) return OPEN[cleaned];
  const c = parseChordName(cleaned);
  if (!c) return null;
  const key = NOTE_NAMES[c.root] + c.quality;
  if (OPEN[key]) return OPEN[key];
  const options = [];
  if (E_SHAPE[c.quality]) options.push(place(E_SHAPE[c.quality], (c.root - 4 + 12) % 12));
  if (A_SHAPE[c.quality]) options.push(place(A_SHAPE[c.quality], (c.root - 9 + 12) % 12));
  const playable = options.filter((s) => s.frets.every((f) => (f ?? 0) >= 0));
  if (!playable.length) return null;
  const high = (s) => Math.max(0, ...s.frets.filter((f) => f !== null));
  return playable.reduce((a, b) => (high(b) < high(a) ? b : a));
}

// ---------------------------------------------------------------- tuning

export const STRINGS = [
  { number: 6, note: "E", frequency: 82.41 },
  { number: 5, note: "A", frequency: 110.0 },
  { number: 4, note: "D", frequency: 146.83 },
  { number: 3, note: "G", frequency: 196.0 },
  { number: 2, note: "B", frequency: 246.94 },
  { number: 1, note: "E", frequency: 329.63 },
];
export const IN_TUNE_CENTS = 5;
export const cents = (f, target) => 1200 * Math.log2(f / target);
export const nearestString = (f) => STRINGS.reduce((a, b) => (Math.abs(cents(f, b.frequency)) < Math.abs(cents(f, a.frequency)) ? b : a));
export const ordinal = (n) => (n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`);
const SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
export function noteNameFor(f) {
  const midi = Math.round(69 + 12 * Math.log2(f / 440));
  return SHARP_NAMES[((midi % 12) + 12) % 12];
}

/** YIN pitch detection. Returns Hz, or null for silence/noise. */
export function detectPitch(samples, sampleRate, { minF = 60, maxF = 1000, threshold = 0.15, silence = 0.006 } = {}) {
  const maxLag = Math.floor(sampleRate / minF);
  const minLag = Math.max(Math.floor(sampleRate / maxF), 2);
  const window = samples.length - maxLag;
  if (window <= maxLag / 2 || minLag >= maxLag) return null;
  let sum = 0;
  for (let i = 0; i < samples.length; i++) sum += samples[i] * samples[i];
  if (Math.sqrt(sum / samples.length) <= silence) return null;

  const diff = new Float32Array(maxLag + 1);
  for (let lag = 1; lag <= maxLag; lag++) {
    let d = 0;
    for (let i = 0; i < window; i++) { const x = samples[i] - samples[i + lag]; d += x * x; }
    diff[lag] = d;
  }
  const norm = new Float32Array(maxLag + 1).fill(1);
  let running = 0;
  for (let lag = 1; lag <= maxLag; lag++) {
    running += diff[lag];
    norm[lag] = running > 0 ? (diff[lag] * lag) / running : 1;
  }
  let found = -1;
  for (let lag = minLag; lag < maxLag; lag++) {
    if (norm[lag] < threshold) {
      while (lag + 1 < maxLag && norm[lag + 1] < norm[lag]) lag++;
      found = lag;
      break;
    }
  }
  if (found < 0) return null;
  let refined = found;
  if (found > 1 && found < maxLag) {
    const a = norm[found - 1], b = norm[found], c = norm[found + 1];
    const den = a - 2 * b + c;
    if (den !== 0) refined = found + (0.5 * (a - c)) / den;
  }
  return sampleRate / refined;
}

// ---------------------------------------------------------------- moods, crowds, languages

export const DEFAULT_MOODS = [
  { name: "Romantic", icon: "favorite", hue: 10 },
  { name: "Dance", icon: "nightlife", hue: 290 },
  { name: "Jolly", icon: "sentiment_very_satisfied", hue: 95 },
  { name: "Campfire", icon: "local_fire_department", hue: 50 },
  { name: "Sad", icon: "rainy", hue: 245 },
  { name: "Devotional", icon: "temple_hindu", hue: 80 },
  { name: "Nostalgic", icon: "radio", hue: 200 },
  { name: "Party", icon: "celebration", hue: 330 },
  { name: "Festival", icon: "festival", hue: 150, subtitle: "Dashain · Tihar" },
];

export const MOOD_ICON_CHOICES = [
  "favorite", "nightlife", "sentiment_very_satisfied", "local_fire_department", "rainy", "temple_hindu",
  "radio", "celebration", "festival", "bedtime", "beach_access", "cake", "flight", "hiking", "home",
  "local_cafe", "park", "piano", "headphones", "music_note", "wb_sunny", "auto_awesome", "spa", "pets",
  "school", "sports_esports",
];
export const MOOD_HUES = [10, 30, 50, 80, 95, 120, 150, 175, 200, 225, 245, 270, 290, 310, 330, 350];

export const CROWDS = [
  { id: "elders", title: "Elders", subtitle: "Parents, relatives", icon: "elderly" },
  { id: "friends", title: "Friends", subtitle: "Your own crowd", icon: "group" },
  { id: "mixed", title: "Mixed", subtitle: "Family gathering", icon: "diversity_3" },
  { id: "kids", title: "Kids", subtitle: "Simple sing-alongs", icon: "child_care" },
];
export const crowdFromName = (name) => CROWDS.find((c) => c.id === normalizedName(name)) || null;

export const LANGUAGES = ["English", "Nepali", "Hindi"];
export const languageFromName = (name) => (name ? LANGUAGES.find((l) => l.toLowerCase() === normalizedName(name)) || null : null);

export function renamedTags(tags, from, to) {
  const out = [];
  for (const t of tags) {
    const r = normalizedName(t) === normalizedName(from) ? to : t;
    if (!out.some((x) => normalizedName(x) === normalizedName(r))) out.push(r);
  }
  return out;
}

export const SONG_EXTENSIONS = ["txt", "text", "cho", "chordpro", "chopro", "crd", "pro"];

export const TEMPLATE = `{title: Song Title}
{artist: Artist}
{key: G}
{duration: 3:30}
{mood: Campfire, Jolly}

{comment: Verse 1}
[G]Put each chord in [C]brackets right be[D]fore the word
[Em]नेपाली वा हिन्दी [C]पनि लेख्न [D]सकिन्छ

{start_of_chorus}
[C]This is the [G]chorus
{end_of_chorus}`;

export const SAMPLE_SONGS = [
  `{title: Campfire Night}
{artist: Moodchords Sample}
{key: G}
{duration: 2:45}
{mood: Campfire, Jolly}
{crowd: Friends, Mixed}
{language: English}

{comment: Verse 1}
[G]Sparks are rising [C]up into the [G]sky
[Em]Friends around the [C]fire and the [D]night rolls by

{start_of_chorus}
[C]Sing it loud, [G]sing it slow
[D]Every song we [G]used to know
{end_of_chorus}

{comment: Verse 2}
[G]Someone's got a [C]story, someone's [G]got a tune
[Em]Strumming till the [C]morning chases [D]off the moon`,
  `{title: साँझको गीत}
{artist: Moodchords Sample}
{key: Am}
{duration: 3:10}
{mood: Romantic, Nostalgic}
{crowd: Elders, Mixed}
{language: Nepali}

{comment: Verse}
[Am]साँझ परेपछि [F]पहाड हेर्छु
[C]तिम्रो याद [G]मनमा बोक्छु
[Am]Saanjh parepachhi [F]pahad herchhu

{start_of_chorus}
[F]बिस्तारै [G]बिस्तारै
[Am]गीत यो [G]गाउँछु [Am]म
{end_of_chorus}`,
];
