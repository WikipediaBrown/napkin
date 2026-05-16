#!/usr/bin/env python3
"""Render CHANGELOG.md into a styled /changelog/ page matching the site.

Zero dependencies. Handles the constrained Keep-a-Changelog subset the
napkin CHANGELOG actually uses: ##/### headings, `-` bullets (with
wrapped continuation lines), blank-line paragraphs, `code spans`,
**bold**, and [text](url) links. Everything is HTML-escaped before
inline markdown is applied, so `Component<X>` etc. render literally.

Usage:  python3 changelog.py CHANGELOG.md > changelog/index.html
"""
import html
import re
import sys

_CODE = re.compile(r"`([^`]+)`")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def inline(text: str) -> str:
    """Escape, then apply code/bold/link markdown. Order matters: escape
    first so generated tags survive; code spans before bold/links so
    backticked content isn't reinterpreted."""
    text = html.escape(text, quote=False)

    code_slots: list[str] = []

    def _stash_code(m: re.Match) -> str:
        code_slots.append(m.group(1))
        return f"\x00CODE{len(code_slots) - 1}\x00"

    text = _CODE.sub(_stash_code, text)
    text = _BOLD.sub(r"<strong>\1</strong>", text)
    text = _LINK.sub(
        lambda m: f'<a href="{html.escape(m.group(2), quote=True)}">{m.group(1)}</a>',
        text,
    )
    for i, c in enumerate(code_slots):
        text = text.replace(f"\x00CODE{i}\x00", f"<code>{c}</code>")
    return text


def render_body(md: str) -> str:
    out: list[str] = []
    in_list = False
    para: list[str] = []
    pending_li: list[str] | None = None

    def flush_para() -> None:
        nonlocal para
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>")
            para = []

    def flush_li() -> None:
        nonlocal pending_li
        if pending_li is not None:
            out.append(f"<li>{inline(' '.join(pending_li))}</li>")
            pending_li = None

    def close_list() -> None:
        nonlocal in_list
        flush_li()
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in md.splitlines():
        line = raw.rstrip()

        if line.startswith("# "):  # document title — skip, page has its own h1
            continue
        if line.startswith("## "):
            flush_para()
            close_list()
            out.append(f'<h2 class="cl__ver">{inline(line[3:].strip())}</h2>')
            continue
        if line.startswith("### "):
            flush_para()
            close_list()
            out.append(f'<h3 class="cl__cat">{inline(line[4:].strip())}</h3>')
            continue
        if line.startswith("- "):
            flush_para()
            flush_li()
            if not in_list:
                out.append("<ul>")
                in_list = True
            pending_li = [line[2:].strip()]
            continue
        if in_list and line.startswith("  ") and line.strip():
            # wrapped continuation of the current bullet
            if pending_li is not None:
                pending_li.append(line.strip())
            continue
        if not line.strip():
            flush_para()
            close_list()
            continue
        # plain paragraph text (e.g. the 2.0.0 prose)
        close_list()
        para.append(line.strip())

    flush_para()
    close_list()
    return "\n".join(out)


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Changelog — napkin</title>
    <meta name="description" content="Release notes for napkin, the Swift 6 framework for Clean Architecture iOS / macOS apps. Mirrors the GitHub CHANGELOG; Keep a Changelog format, Semantic Versioning.">
    <meta name="theme-color" content="#f6f1e3" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#0e1410" media="(prefers-color-scheme: dark)">
    <meta property="og:title" content="Changelog — napkin">
    <meta property="og:description" content="Release notes for napkin. Keep a Changelog format, Semantic Versioning.">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://getnapkin.to/changelog/">
    <meta property="og:image" content="https://getnapkin.to/social-preview.png">
    <meta name="twitter:card" content="summary_large_image">
    <link rel="canonical" href="https://getnapkin.to/changelog/">
    <link rel="icon" type="image/png" sizes="48x48" href="/napkin-icon.png">
    <link rel="icon" type="image/png" sizes="96x96" href="/napkin-icon@2x.png">
    <link rel="apple-touch-icon" href="/napkin-icon@2x.png">
    <link rel="alternate" type="application/atom+xml" title="napkin releases" href="https://github.com/WikipediaBrown/napkin/releases.atom">
    <link rel="stylesheet" href="/styles.css">
</head>
<body>

<a class="skip-link" href="#main">Skip to content</a>

<header class="masthead" role="banner">
    <div class="masthead__inner">
        <a class="masthead__brand" href="/" aria-label="napkin — home">
            <span class="masthead__mark" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M4 4 H20 V20 L4 20 L4 4 Z" />
                    <path d="M4 14 L14 14 L14 20" />
                </svg>
            </span>
            <span class="masthead__wordmark">napkin</span>
        </a>
        <nav class="masthead__nav" aria-label="Primary">
            <ul>
                <li><a href="/documentation/napkin/">Docs</a></li>
                <li><a href="/#example">Example</a></li>
                <li><a href="/blog/">Blog</a></li>
                <li><a href="/changelog/" aria-current="page">Changelog</a></li>
                <li><a href="https://github.com/WikipediaBrown/napkin">GitHub</a></li>
            </ul>
        </nav>
    </div>
</header>

<main id="main">
<section class="post changelog" aria-labelledby="cl-title">
    <p class="post__kicker"><span>§</span> <span class="sep">·</span> <span>Release notes</span></p>
    <h1 class="post__title" id="cl-title">Changelog.</h1>
    <p class="post__lede">Mirrors the <a class="link" href="https://github.com/WikipediaBrown/napkin/blob/main/CHANGELOG.md">GitHub CHANGELOG</a>. <a class="link" href="https://keepachangelog.com/en/1.1.0/">Keep a Changelog</a> format; <a class="link" href="https://semver.org/spec/v2.0.0.html">Semantic Versioning</a>.</p>

    <div class="post__body cl__body">
__BODY__
    </div>

    <footer class="post__footer">
        <p><a href="/blog/">← Blog</a> &nbsp;·&nbsp; <a href="/faq/">FAQ</a></p>
        <p><a href="https://github.com/WikipediaBrown/napkin/releases">GitHub releases</a> · <a href="https://github.com/WikipediaBrown/napkin/releases.atom">RSS</a></p>
    </footer>
</section>
</main>

<footer class="colophon" role="contentinfo">
    <div class="colophon__inner">
        <p class="colophon__line">
            <a class="link link--mono" href="https://github.com/WikipediaBrown/napkin">napkin</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="https://github.com/WikipediaBrown/napkin/blob/main/LICENSE.md">Apache&#8209;2.0</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/changelog/">CHANGELOG</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/blog/">Blog</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/faq/">FAQ</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/recipes/">Recipes</a>
        </p>
        <p class="colophon__line colophon__line--right">
            Made with 🌲🌲🌲 in Cascadia
        </p>
    </div>
</footer>

</body>
</html>
"""


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "CHANGELOG.md"
    with open(src, encoding="utf-8") as fh:
        md = fh.read()
    sys.stdout.write(PAGE.replace("__BODY__", render_body(md)))


if __name__ == "__main__":
    main()
