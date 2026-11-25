#!/usr/bin/env python3
"""Turn chord pages you saved from Chrome ("Save Page As… > Webpage, Complete")
into Moodchords song files (.txt) ready to import into the app.

Each output file has the song's directives (title, artist, key, capo, mood, crowd)
followed by the chord sheet exactly as the page shows it, with chords on the line
above the lyrics. The app converts that layout to inline [chords] on import.

Mood and crowd come from song-list.md, matched by song title.

Song files are written to "Songs Collection/<English|Nepali|Hindi>/", using the
language section the song sits under in song-list.md. Saved pages are read from
"Songs Collection/Saved pages" and any folders inside it.

Usage (from the Guitar App folder):
    python3 tools/extract_saved_pages.py
    python3 tools/extract_saved_pages.py <saved pages folder> <songs collection folder>
"""

import difflib
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SONG_LIST = ROOT / "song-list.md"


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


COLLECTION = ROOT / "Songs Collection"


def load_song_list() -> dict:
    """title key -> (title, artist, mood, crowd, language) from the markdown tables."""
    songs = {}
    language = "Unsorted"
    for line in SONG_LIST.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"##\s+(\w+)", line)
        if heading:
            language = heading.group(1)
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 5 and cells[0].isdigit():
            _, title, artist, mood, crowd = cells
            artist = artist.replace("⚠️", "").split(" — ")[0].strip()
            songs[norm(title)] = (title, artist, mood, crowd, language)
    return songs


def match_song(page_song: str, song_list: dict):
    """Find the song-list entry for a page title. Chord sites spell titles differently
    ("Phoolko Aakhama Acoustic", "Yo Samjhine Man", "Dui Rupaiyan - Kutu Ma Kutu"),
    so fall back to containment, then to the closest spelling."""
    key = norm(page_song)
    if key in song_list:
        return song_list[key]
    contained = [k for k in song_list if k in key or key in k]
    if len(contained) == 1:
        return song_list[contained[0]]
    close = difflib.get_close_matches(key, list(song_list), n=1, cutoff=0.7)
    return song_list[close[0]] if close else None


def page_text(markup: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", " ", markup))


def extract(page: Path, song_list: dict):
    markup = page.read_text(encoding="utf-8", errors="replace")

    pre = re.search(r"<pre[^>]*>(.*?)</pre>", markup, re.S)
    if not pre:
        return None, "no chord sheet found on the page"
    sheet = html.unescape(re.sub(r"<[^>]+>", "", pre.group(1)))
    sheet = sheet.replace("\r\n", "\n").replace(" ", " ").strip("\n")

    title_tag = re.search(r"<title>(.*?)</title>", markup, re.S)
    page_title = html.unescape(title_tag.group(1)) if title_tag else page.stem
    m = re.match(r"(.*?) CHORDS(?: \(ver \d+\))? by (.*?) @", page_title)
    song_name, artist = (m.group(1), m.group(2)) if m else (page.stem, None)

    info = match_song(song_name, song_list)
    title, mood, crowd, language = song_name.title(), None, None, "Unsorted"
    if info:
        title, artist, mood, crowd, language = info[0], info[1] or artist, info[2], info[3], info[4]

    text = page_text(markup)
    key = re.search(r"Key:\s*([A-G][#b]?m?)\b", text)
    capo = re.search(r"Capo:\s*(\d+)(?:st|nd|rd|th)?\s*fret", text, re.I)
    no_capo = re.search(r"Capo:\s*no capo", text, re.I)

    lines = [f"{{title: {title}}}"]
    if artist:
        lines.append(f"{{artist: {artist}}}")
    if key:
        lines.append(f"{{key: {key.group(1)}}}")
    if capo:
        lines.append(f"{{capo: {capo.group(1)}}}")
    elif no_capo:
        lines.append("{capo: none}")
    if mood:
        lines.append(f"{{mood: {mood}}}")
    if crowd:
        lines.append(f"{{crowd: {crowd}}}")
    lines += ["", sheet, ""]

    report = {
        "title": title,
        "language": language,
        "matched_list": bool(info),
        "key": key.group(1) if key else "-",
        "capo": capo.group(1) if capo else ("none" if no_capo else "-"),
        "sheet_lines": sheet.count("\n") + 1,
    }
    return "\n".join(lines), report


def main():
    if len(sys.argv) == 3:
        src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    elif len(sys.argv) == 1:
        src, dst = COLLECTION / "Saved pages", COLLECTION
    else:
        sys.exit(__doc__)
    song_list = load_song_list()

    for page in sorted(src.rglob("*.html")):
        content, report = extract(page, song_list)
        if content is None:
            print(f"SKIP  {page.name}: {report}")
            continue
        folder = dst / report["language"]
        folder.mkdir(parents=True, exist_ok=True)
        out = folder / (re.sub(r"[^\w\- ]", "", report["title"]).strip() + ".txt")
        out.write_text(content, encoding="utf-8")
        flag = "" if report["matched_list"] else "  (not in song-list.md: no mood/crowd)"
        print(f"OK    {report['title']:<30} key {report['key']:<4} capo {report['capo']:<5} "
              f"-> {report['language']}/{out.name}{flag}")


if __name__ == "__main__":
    main()
