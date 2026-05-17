#!/usr/bin/env python3
"""Generate a per-post Open Graph card (1280x640 PNG) for every blog post.

Zero Python deps; shells out to `rsvg-convert` (already used for the logo).
Each post's card lives at Tools/site/blog/<slug>/og.png, so the existing
`cp -R Tools/site/blog/.` deploy step ships it with no workflow change.

For each Tools/site/blog/<slug>/index.html it reads the <h1 class=
"post__title"> and <p class="post__kicker">, lays the title out in the
site's serif (Georgia — the real fallback in --font-serif, and what
fontconfig has installed) on the paper/moss palette, renders to PNG, and
rewrites that post's og:image + JSON-LD image to the per-post URL.

Usage:  python3 Tools/site/blog-og.py            # all posts
        python3 Tools/site/blog-og.py <slug> ... # specific posts
Idempotent: re-running regenerates the PNG and leaves the HTML unchanged
once it already points at og.png.
"""
import html
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
BLOG = ROOT / "blog"

# Palette — hex approximations of the styles.css light-mode tokens, kept
# identical to the values baked into napkin-mark.svg so the brand is
# consistent across the favicon, logo, and these cards.
PAPER = "#f6f1e3"
EDGE = "#e3d6ba"
MOSS = "#356847"
INK = "#1b2230"
INK3 = "#6f6a5c"

W, H = 1280, 640
MARGIN = 96
TEXT_W = W - 2 * MARGIN  # usable title width

_TITLE_RE = re.compile(r'<h1 class="post__title">(.*?)</h1>', re.S)
_KICKER_RE = re.compile(r'<p class="post__kicker">(.*?)</p>', re.S)
_TAGS = re.compile(r"<[^>]+>")


def _text(raw: str) -> str:
    """Strip tags, unescape entities, collapse whitespace."""
    return re.sub(r"\s+", " ", html.unescape(_TAGS.sub(" ", raw))).strip()


def wrap(title: str):
    """Pick the largest font size (px) at which `title` fits in <=4 lines,
    then greedily word-wrap. Georgia advance ~0.50*em for mixed case; 0.53
    is a deliberately conservative estimate so lines never overflow."""
    for size in (66, 60, 54, 48, 43):
        cpl = max(8, int(TEXT_W / (size * 0.53)))
        lines, cur = [], ""
        for word in title.split():
            cand = word if not cur else f"{cur} {word}"
            if len(cand) <= cpl:
                cur = cand
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
        if len(lines) <= 4 and all(len(ln) <= cpl for ln in lines):
            return size, lines
    return 43, lines  # smallest size; accept whatever wrapping we got


def svg_for(title: str, kicker: str) -> str:
    size, lines = wrap(title)
    lh = round(size * 1.18, 1)
    block_h = lh * len(lines)
    # Vertically center the title block in the area below the wordmark and
    # above the footer rule (roughly y in [188, 556]).
    top = 188 + ((556 - 188) - block_h) / 2 + size
    tspans = "".join(
        f'<tspan x="{MARGIN}" y="{round(top + i * lh, 1)}">'
        f"{html.escape(ln)}</tspan>"
        for i, ln in enumerate(lines)
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <rect width="{W}" height="{H}" fill="{PAPER}"/>
  <rect x="22" y="22" width="{W-44}" height="{H-44}" rx="26" fill="none"
        stroke="{EDGE}" stroke-width="3"/>
  <!-- brand: napkin mark + wordmark -->
  <g transform="translate({MARGIN} 84)">
    <g transform="scale(2.4)" fill="none" stroke="{MOSS}" stroke-width="1.4"
       stroke-linecap="round" stroke-linejoin="round">
      <path d="M4 4 H20 V20 L4 20 L4 4 Z"/>
      <path d="M4 14 L14 14 L14 20"/>
    </g>
    <text x="74" y="40" font-family="Georgia, serif" font-size="40"
          fill="{MOSS}">napkin</text>
  </g>
  <!-- kicker -->
  <text x="{MARGIN}" y="170" font-family="'Andale Mono', monospace"
        font-size="23" letter-spacing="3" fill="{INK3}">{html.escape(kicker.upper())}</text>
  <line x1="{MARGIN}" y1="556" x2="{W-MARGIN}" y2="556" stroke="{EDGE}" stroke-width="2"/>
  <!-- title -->
  <text font-family="Georgia, serif" font-size="{size}" font-weight="bold"
        fill="{INK}">{tspans}</text>
  <text x="{MARGIN}" y="596" font-family="'Andale Mono', monospace"
        font-size="22" letter-spacing="2" fill="{MOSS}">getnapkin.to/blog</text>
</svg>
"""


def render(slug: str) -> bool:
    idx = BLOG / slug / "index.html"
    if not idx.is_file():
        print(f"  skip {slug}: no index.html", file=sys.stderr)
        return False
    src = idx.read_text()
    tm, km = _TITLE_RE.search(src), _KICKER_RE.search(src)
    if not tm or not km:
        print(f"  skip {slug}: no title/kicker", file=sys.stderr)
        return False
    title, kicker = _text(tm.group(1)), _text(km.group(1))
    svg = svg_for(title, kicker)
    out = BLOG / slug / "og.png"
    proc = subprocess.run(
        ["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(out)],
        input=svg.encode(), capture_output=True,
    )
    if proc.returncode != 0:
        print(f"  FAIL {slug}: {proc.stderr.decode().strip()}", file=sys.stderr)
        return False

    # Point this post's og:image + JSON-LD image at its own card.
    url = f"https://getnapkin.to/blog/{slug}/og.png"
    new = re.sub(
        r'(<meta property="og:image" content=")[^"]*(">)',
        rf"\1{url}\2", src,
    )
    new = re.sub(
        r'("image":\s*")https://getnapkin\.to/social-preview\.png(")',
        rf"\1{url}\2", new,
    )
    if new != src:
        idx.write_text(new)
    print(f"  ok {slug}: {out.relative_to(ROOT.parent.parent)} "
          f"({out.stat().st_size} B) title={len(title)}c")
    return True


def main() -> None:
    slugs = sys.argv[1:] or sorted(
        p.parent.name for p in BLOG.glob("*/index.html")
    )
    ok = sum(render(s) for s in slugs)
    print(f"generated {ok}/{len(slugs)} cards")


if __name__ == "__main__":
    main()
