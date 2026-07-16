#!/usr/bin/env python3
"""Generate sitemap.xml for getnapkin.to from an assembled site directory.

Usage: python3 gen_sitemap.py <site_root>   # prints XML to stdout

Lists the landing page, the static pages, every blog post, and every
DocC-generated page under documentation/ and tutorials/. Versioned doc
copies (/<ref>/...) are deliberately absent: we only walk the unversioned
trees, and robots.txt (gen_robots.py) blocks the versioned ones.
"""
import os
import re
import sys

HOST = "https://getnapkin.to"
STATIC_PAGES = ["", "about/", "faq/", "recipes/", "changelog/", "blog/",
                "when-to-use-napkin/"]
PUBLISHED_RE = re.compile(
    r'property="article:published_time"\s+content="(\d{4}-\d{2}-\d{2})"')


def dated_pages(root, section):
    base = os.path.join(root, section)
    if not os.path.isdir(base):
        return
    for name in sorted(os.listdir(base)):
        page = os.path.join(base, name, "index.html")
        if os.path.isfile(page):
            with open(page, encoding="utf-8") as f:
                m = PUBLISHED_RE.search(f.read())
            yield f"{section}/{name}/", (m.group(1) if m else None)


def docc_pages(root):
    for tree in ("documentation", "tutorials"):
        base = os.path.join(root, tree)
        for dirpath, _, filenames in os.walk(base):
            if "index.html" in filenames:
                rel = os.path.relpath(dirpath, root)
                yield rel.rstrip("/") + "/", None


def main(root):
    entries = [(p, None) for p in STATIC_PAGES]
    entries += list(dated_pages(root, "blog"))
    entries += list(dated_pages(root, "compare"))
    entries += sorted(docc_pages(root))
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for path, lastmod in entries:
        lines.append("    <url>")
        lines.append(f"        <loc>{HOST}/{path}</loc>")
        if lastmod:
            lines.append(f"        <lastmod>{lastmod}</lastmod>")
        lines.append("    </url>")
    lines.append("</urlset>")
    print("\n".join(lines))


if __name__ == "__main__":
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(f"usage: {sys.argv[0]} <site_root>")
    main(sys.argv[1])
