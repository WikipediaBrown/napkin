# SEO Stage 1 — Technical Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make napkin's site and docs readable by search engines and AI crawlers: turn on DocC's official per-page content flag, generate a complete sitemap and crawler policy at deploy time, add Swift Package Index and author-identity metadata, and ping Bing on every deploy.

**Architecture:** The public site is assembled from scratch on every deploy by `.github/workflows/Documentation.yml` (DocC build + files copied from `Tools/site/`). All changes are to `Tools/site/`, the DocC catalog (`Sources/napkin/napkin.docc/`), or that workflow — never to the generated `docs/` folder. Two new stdlib-only Python scripts generate `sitemap.xml` and `robots.txt` at deploy time, replacing static copies that go stale.

**Tech Stack:** GitHub Actions (macOS runner), Swift DocC (`swift package generate-documentation`), Python 3 stdlib (no pip installs), hand-rolled HTML.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-11-seo-discoverability-design.md` (Stage 1 section).
- Never edit anything under `docs/` except `docs/superpowers/` — the rest is build output, regenerated on every deploy.
- Canonical host is exactly `https://getnapkin.to` (no `www`, no trailing host slash in generated URLs except path roots).
- Python scripts must use only the standard library (the CI runner has no pip step).
- The DocC flag is exactly `--experimental-transform-for-static-hosting-with-content` and MUST be passed conditionally (detect support first) — an older toolchain must still build green.
- Author identity strings, verbatim: name `WikipediaBrown`, url `https://wikipediabrown.dev`, sameAs `https://github.com/WikipediaBrown` (and `https://spookylabs.ai` on the landing page only).
- Work on branch `seo/discoverability`; commit after every task; PR targets `develop` (never push to `main`).
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: `.spi.yml` — point Swift Package Index at our docs

**Files:**
- Create: `.spi.yml` (repo root)

**Interfaces:**
- Produces: repo-root `.spi.yml` consumed by swiftpackageindex.com's build system. Nothing else in this plan depends on it.

- [ ] **Step 1: Create the file**

```yaml
version: 1
external_links:
  documentation: "https://getnapkin.to/documentation/napkin/"
```

Write exactly that (two spaces of indentation) to `.spi.yml`.

- [ ] **Step 2: Validate it parses as YAML**

Run: `ruby -ryaml -e 'p YAML.load_file(".spi.yml")' `
Expected: `{"version"=>1, "external_links"=>{"documentation"=>"https://getnapkin.to/documentation/napkin/"}}`

- [ ] **Step 3: Commit**

```bash
git add .spi.yml
git commit -m "feat: add .spi.yml pointing Swift Package Index docs link at getnapkin.to

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: DocC site title via `theme-settings.json`

**Files:**
- Modify: `Sources/napkin/napkin.docc/theme-settings.json`

**Interfaces:**
- Produces: rendered DocC page titles become `{Page} | napkin` (applied by the DocC web app at page load; the static `<title>` comes from Task 8's flag).

- [ ] **Step 1: Add the `meta.title` key**

The file currently starts:

```json
{
    "features": {
```

Change it to add a `meta` object first:

```json
{
    "meta": {
        "title": "napkin"
    },
    "features": {
```

(Everything else in the file is unchanged.)

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; d=json.load(open('Sources/napkin/napkin.docc/theme-settings.json')); print(d['meta'])"`
Expected: `{'title': 'napkin'}`

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/napkin.docc/theme-settings.json
git commit -m "feat: set DocC site title so doc pages read 'Page | napkin'

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Landing-page structured data — real author, drop the dead rating block

**Files:**
- Modify: `Tools/site/index.html` (two JSON-LD edits in `<head>`)

**Interfaces:**
- Produces: landing page has exactly ONE `application/ld+json` block (`SoftwareSourceCode`) whose `author` is the Person object below. Task 10's checks grep for this.

- [ ] **Step 1: Replace the Organization author with a Person**

In `Tools/site/index.html`, find (line ~47):

```json
        "author": { "@type": "Organization", "name": "napkin", "url": "https://getnapkin.to/" }
```

Replace with:

```json
        "author": {
            "@type": "Person",
            "name": "WikipediaBrown",
            "url": "https://wikipediabrown.dev",
            "sameAs": ["https://github.com/WikipediaBrown", "https://spookylabs.ai"]
        }
```

- [ ] **Step 2: Delete the entire `SoftwareApplication` script block**

Delete this whole block (it can never earn a Google rich result without a fabricated rating, which policy forbids):

```html
    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "napkin",
        "applicationCategory": "DeveloperApplication",
        "operatingSystem": "iOS 26, macOS 26",
        "url": "https://getnapkin.to/",
        "downloadUrl": "https://github.com/WikipediaBrown/napkin",
        "softwareVersion": "2.0",
        "license": "https://www.apache.org/licenses/LICENSE-2.0",
        "description": "A Swift 6.2 framework for Clean Architecture iOS / macOS apps — Router-Interactor-Builder pattern rebuilt around Swift Concurrency, without RxSwift.",
        "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" }
    }
    </script>
```

- [ ] **Step 3: Validate every remaining JSON-LD block parses**

Run:
```bash
python3 - <<'PY'
import json, re
html = open('Tools/site/index.html').read()
blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
assert len(blocks) == 1, f"expected 1 JSON-LD block, found {len(blocks)}"
d = json.loads(blocks[0])
assert d["@type"] == "SoftwareSourceCode" and d["author"]["@type"] == "Person"
print("OK:", d["author"]["name"])
PY
```
Expected: `OK: WikipediaBrown`

- [ ] **Step 4: Commit**

```bash
git add Tools/site/index.html
git commit -m "feat: landing page schema — Person author, drop rating-less SoftwareApplication

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Blog posts — Person author on all six

**Files:**
- Modify: all six `Tools/site/blog/*/index.html`

**Interfaces:**
- Produces: each blog post's `Article` JSON-LD has the same Person author object (checked by Task 10).

- [ ] **Step 1: Replace the author line in each post**

Each of the six files below contains, at line ~33, exactly:

```json
        "author": { "@type": "Organization", "name": "napkin" },
```

Replace it in every file with:

```json
        "author": { "@type": "Person", "name": "WikipediaBrown", "url": "https://wikipediabrown.dev", "sameAs": ["https://github.com/WikipediaBrown"] },
```

Files:
- `Tools/site/blog/modular-ios-apps-swift-concurrency/index.html`
- `Tools/site/blog/swift-6-actor-isolation-architecture/index.html`
- `Tools/site/blog/testing-swift-actors-guide/index.html`
- `Tools/site/blog/swiftui-dependency-injection-without-libraries/index.html`
- `Tools/site/blog/swift-6-ribs-replacement/index.html`
- `Tools/site/blog/swift-6-mainactor-protocol-conformance/index.html`

- [ ] **Step 2: Verify no Organization authors remain and all JSON-LD still parses**

Run:
```bash
grep -rn '"author": { "@type": "Organization"' Tools/site/blog/ && echo "FAIL: Organization author remains" || echo "OK: no Organization authors"
python3 - <<'PY'
import json, re, glob
for f in glob.glob('Tools/site/blog/*/index.html'):
    for b in re.findall(r'<script type="application/ld\+json">(.*?)</script>', open(f).read(), re.S):
        d = json.loads(b)
        assert d["author"]["name"] == "WikipediaBrown", f
print("OK: 6 posts parsed")
PY
```
Expected: `OK: no Organization authors` then `OK: 6 posts parsed`

- [ ] **Step 3: Commit**

```bash
git add Tools/site/blog
git commit -m "feat: credit blog posts to WikipediaBrown (Person) for author identity

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `/about/` page + links

**Files:**
- Create: `Tools/site/about/index.html`
- Modify: `Tools/site/index.html` (footer), `Tools/site/llms.txt` (Project section), `.github/workflows/Documentation.yml` (copy step)

**Interfaces:**
- Produces: `/about/` URL. Task 6's sitemap generator lists `about/` as a static page; Task 10 checks it renders.

- [ ] **Step 1: Create `Tools/site/about/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About — napkin</title>
    <meta name="description" content="Who maintains napkin, the Swift 6 framework for Clean Architecture iOS / macOS apps, and how to get in touch.">
    <meta name="theme-color" content="#f6f1e3" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#0e1410" media="(prefers-color-scheme: dark)">

    <meta property="og:title" content="About — napkin">
    <meta property="og:description" content="Who maintains napkin and how to get in touch.">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://getnapkin.to/about/">
    <meta property="og:image" content="https://getnapkin.to/social-preview.png">
    <meta name="twitter:card" content="summary_large_image">
    <link rel="canonical" href="https://getnapkin.to/about/">

    <link rel="icon" type="image/png" sizes="48x48" href="/napkin-icon.png">
    <link rel="icon" type="image/png" sizes="96x96" href="/napkin-icon@2x.png">
    <link rel="apple-touch-icon" href="/napkin-icon@2x.png">
    <link rel="stylesheet" href="/styles.css">

    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@type": "AboutPage",
        "url": "https://getnapkin.to/about/",
        "mainEntity": {
            "@type": "Person",
            "name": "WikipediaBrown",
            "url": "https://wikipediabrown.dev",
            "sameAs": ["https://github.com/WikipediaBrown", "https://spookylabs.ai"]
        }
    }
    </script>
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
    </div>
</header>

<main id="main" class="prose">
    <h1>About</h1>
    <p>napkin is built and maintained by
        <a href="https://wikipediabrown.dev">WikipediaBrown</a>
        (<a href="https://github.com/WikipediaBrown">GitHub</a>), under
        <a href="https://spookylabs.ai">Spooky Labs</a>.</p>
    <p>napkin is an open-source Swift 6 framework for building iOS and macOS apps as a
        tree of small, isolated, composable units — the Router-Interactor-Builder pattern,
        rebuilt around Swift Concurrency. It is modeled on Uber's
        <a href="https://github.com/uber/ribs-ios">RIBs</a> (which is alive and well);
        napkin's differences are native Swift Concurrency, no RxSwift dependency, and no
        runtime leak detector.</p>
    <p>Found a bug, or want to contribute? Open an issue or pull request on
        <a href="https://github.com/WikipediaBrown/napkin">GitHub</a>. Security reports:
        see <a href="/security.txt">security.txt</a>.</p>
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
        </p>
        <p class="colophon__line colophon__line--right">
            Made with 🌲🌲🌲 in Cascadia
        </p>
    </div>
</footer>

</body>
</html>
```

Note: the `masthead`/`colophon`/`prose` classes come from the shared `/styles.css`,
same as the FAQ page. If rendering looks off in Step 4, compare against
`Tools/site/faq/index.html` and match its wrapper markup.

- [ ] **Step 2: Link it from the landing-page footer**

In `Tools/site/index.html`, find:

```html
            <a class="link link--mono" href="/faq/">FAQ</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/recipes/">Recipes</a>
```

Replace with:

```html
            <a class="link link--mono" href="/faq/">FAQ</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/about/">About</a>
            <span aria-hidden="true" class="colophon__sep">·</span>
            <a class="link link--mono" href="/recipes/">Recipes</a>
```

- [ ] **Step 3: Add it to `Tools/site/llms.txt`**

Find:

```markdown
- [AGENTS.md (conventions for AI agents)](https://github.com/WikipediaBrown/napkin/blob/main/AGENTS.md)
```

Replace with:

```markdown
- [AGENTS.md (conventions for AI agents)](https://github.com/WikipediaBrown/napkin/blob/main/AGENTS.md)
- [About the maintainer](https://getnapkin.to/about/)
```

- [ ] **Step 4: Copy it in the workflow**

In `.github/workflows/Documentation.yml`, find:

```yaml
          mkdir -p docs/faq docs/recipes docs/changelog
          cp Tools/site/faq/index.html docs/faq/index.html
```

Replace with:

```yaml
          mkdir -p docs/faq docs/recipes docs/changelog docs/about
          cp Tools/site/faq/index.html docs/faq/index.html
          cp Tools/site/about/index.html docs/about/index.html
```

- [ ] **Step 5: Eyeball it locally**

Run: `open Tools/site/about/index.html` (styles won't load from `file://` with absolute paths — check structure, headings, and links resolve; full styling is verified in Task 10's assembled tree).

- [ ] **Step 6: Commit**

```bash
git add Tools/site/about Tools/site/index.html Tools/site/llms.txt .github/workflows/Documentation.yml
git commit -m "feat: add /about page (maintainer identity) and link it from footer + llms.txt

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Sitemap generator

**Files:**
- Create: `Tools/site/gen_sitemap.py`
- Create: `Tools/site/tests/test_gen_sitemap.py`
- Delete: `Tools/site/sitemap.xml`
- Modify: `.github/workflows/Documentation.yml`

**Interfaces:**
- Consumes: an assembled site root directory (the workflow's `docs/` after all pages are copied).
- Produces: CLI `python3 Tools/site/gen_sitemap.py <site_root>` printing sitemap XML to stdout. Task 9 (IndexNow) reads `<loc>` values from the generated `docs/sitemap.xml`; Task 10 asserts on its contents.

- [ ] **Step 1: Write the failing test**

Create `Tools/site/tests/test_gen_sitemap.py`:

```python
import os, subprocess, sys, tempfile, unittest

# Deliberately no XML parser here: Python's stdlib XML parsers are unsafe on
# untrusted input (XXE / entity expansion), defusedxml would add a dependency,
# and the sitemap under test is generated by our own script two lines up.
# A structural check is sufficient and dependency-free.

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "gen_sitemap.py")


def make_fixture(root):
    def page(rel, html="<html></html>"):
        d = os.path.join(root, rel)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "index.html"), "w") as f:
            f.write(html)

    page("")                    # landing
    page("about"); page("faq"); page("recipes"); page("changelog"); page("blog")
    page("blog/some-post",
         '<html><head><meta property="article:published_time" content="2026-05-15">'
         "</head></html>")
    page("documentation/napkin"); page("documentation/napkin/presenter")
    page("tutorials/napkin")
    page("main/documentation/napkin")      # versioned copy: must be excluded
    page("2.0.8/documentation/napkin")     # versioned copy: must be excluded
    page("css")                            # asset dir: must be excluded


class TestGenSitemap(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        make_fixture(self.tmp.name)
        out = subprocess.run([sys.executable, SCRIPT, self.tmp.name],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.xml = out.stdout

    def test_wellformed(self):
        self.assertTrue(self.xml.startswith('<?xml version="1.0"'))
        self.assertEqual(self.xml.count("<urlset"), 1)
        self.assertTrue(self.xml.rstrip().endswith("</urlset>"))
        self.assertEqual(self.xml.count("<url>"), self.xml.count("</url>"))
        self.assertEqual(self.xml.count("<loc>"), self.xml.count("</loc>"))
        self.assertEqual(self.xml.count("<url>"), self.xml.count("<loc>"))

    def test_static_and_docc_pages_present(self):
        for url in ["https://getnapkin.to/",
                    "https://getnapkin.to/about/",
                    "https://getnapkin.to/blog/some-post/",
                    "https://getnapkin.to/documentation/napkin/presenter/",
                    "https://getnapkin.to/tutorials/napkin/"]:
            self.assertIn(f"<loc>{url}</loc>", self.xml, url)

    def test_versioned_and_assets_excluded(self):
        self.assertNotIn("/main/", self.xml)
        self.assertNotIn("/2.0.8/", self.xml)
        self.assertNotIn("/css/", self.xml)

    def test_blog_lastmod_from_published_time(self):
        self.assertIn("<lastmod>2026-05-15</lastmod>", self.xml)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it — must fail**

Run: `python3 Tools/site/tests/test_gen_sitemap.py`
Expected: errors (script does not exist yet).

- [ ] **Step 3: Implement `Tools/site/gen_sitemap.py`**

```python
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
STATIC_PAGES = ["", "about/", "faq/", "recipes/", "changelog/", "blog/"]
PUBLISHED_RE = re.compile(
    r'property="article:published_time"\s+content="(\d{4}-\d{2}-\d{2})"')


def blog_posts(root):
    blog = os.path.join(root, "blog")
    if not os.path.isdir(blog):
        return
    for name in sorted(os.listdir(blog)):
        page = os.path.join(blog, name, "index.html")
        if os.path.isfile(page):
            with open(page, encoding="utf-8") as f:
                m = PUBLISHED_RE.search(f.read())
            yield f"blog/{name}/", (m.group(1) if m else None)


def docc_pages(root):
    for tree in ("documentation", "tutorials"):
        base = os.path.join(root, tree)
        for dirpath, _, filenames in os.walk(base):
            if "index.html" in filenames:
                rel = os.path.relpath(dirpath, root)
                yield rel.rstrip("/") + "/", None


def main(root):
    entries = [(p, None) for p in STATIC_PAGES]
    entries += list(blog_posts(root))
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
```

- [ ] **Step 4: Run the test — must pass**

Run: `python3 Tools/site/tests/test_gen_sitemap.py`
Expected: `OK` (4 tests).

- [ ] **Step 5: Wire into the workflow and delete the static file**

In `.github/workflows/Documentation.yml`, delete the line:

```yaml
          cp Tools/site/sitemap.xml docs/sitemap.xml
```

Then find the end of the "Copy homepage" step (the `sed` that writes `docs/index.html`):

```yaml
          sed \
            -e "s/__NAPKIN_VERSION__/${VERSION}/g" \
            -e "s#<!-- __VERSION_LINKS__ -->#${VERSION_LINKS}#g" \
            Tools/site/index.html > docs/index.html
```

Immediately after it, add:

```yaml

          # sitemap.xml — generated from the assembled site so it can never
          # go stale. Must run after every page above has been copied in.
          python3 Tools/site/gen_sitemap.py docs > docs/sitemap.xml
          echo "sitemap: $(grep -c '<loc>' docs/sitemap.xml) URLs"
```

Then delete the now-unused static file:

```bash
git rm Tools/site/sitemap.xml
```

- [ ] **Step 6: Commit**

```bash
git add Tools/site/gen_sitemap.py Tools/site/tests/test_gen_sitemap.py .github/workflows/Documentation.yml
git commit -m "feat: generate sitemap.xml at deploy time, covering all DocC pages

Replaces the hand-maintained 12-URL sitemap, which missed every
documentation page (DocC ships no sitemap generator; swift-docc#779).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: robots.txt generator — welcome AI crawlers, hide old doc versions

**Files:**
- Create: `Tools/site/gen_robots.py`
- Create: `Tools/site/tests/test_gen_robots.py`
- Delete: `Tools/site/robots.txt`
- Modify: `.github/workflows/Documentation.yml`

**Interfaces:**
- Consumes: the list of version refs that actually built (computed in the workflow, e.g. `main 2.0.8 2.0.7`).
- Produces: CLI `python3 Tools/site/gen_robots.py --disallow <ref>...` printing robots.txt to stdout. Task 10 asserts on its output.

robots.txt semantics note (why every group repeats the Disallow list): a crawler obeys
only the single most specific `User-agent` group that matches it. If we gave GPTBot its
own `Allow: /` group without the Disallows, GPTBot would ignore the `*` group entirely
and crawl the versioned copies. So the generator writes the same rule body for `*` and
for every named bot.

- [ ] **Step 1: Write the failing test**

Create `Tools/site/tests/test_gen_robots.py`:

```python
import os, subprocess, sys, unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "gen_robots.py")
BOTS = ["GPTBot", "OAI-SearchBot", "ChatGPT-User", "ClaudeBot",
        "Claude-SearchBot", "PerplexityBot", "Google-Extended",
        "Applebot-Extended"]


def run(*args):
    out = subprocess.run([sys.executable, SCRIPT, *args],
                         capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    return out.stdout


class TestGenRobots(unittest.TestCase):
    def test_named_groups_each_carry_disallows(self):
        txt = run("--disallow", "main", "2.0.8")
        for bot in ["*"] + BOTS:
            self.assertIn(f"User-agent: {bot}", txt, bot)
        # every group must repeat the disallows (most-specific-group rule)
        self.assertEqual(txt.count("Disallow: /main/"), len(BOTS) + 1)
        self.assertEqual(txt.count("Disallow: /2.0.8/"), len(BOTS) + 1)
        self.assertEqual(txt.count("Allow: /"), len(BOTS) + 1)

    def test_sitemap_line(self):
        self.assertIn("Sitemap: https://getnapkin.to/sitemap.xml",
                      run("--disallow", "main"))

    def test_no_refs_means_no_disallows(self):
        txt = run("--disallow")
        self.assertNotIn("Disallow:", txt)
        self.assertIn("User-agent: GPTBot", txt)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it — must fail**

Run: `python3 Tools/site/tests/test_gen_robots.py`
Expected: errors (script does not exist yet).

- [ ] **Step 3: Implement `Tools/site/gen_robots.py`**

```python
#!/usr/bin/env python3
"""Generate robots.txt for getnapkin.to.

Usage: python3 gen_robots.py --disallow [ref ...]   # prints to stdout

Welcomes the AI crawlers by name (we WANT AI assistants to read this site)
and blocks the versioned documentation copies (/main/, /2.0.8/, ...) so only
the latest docs get indexed. Each named group repeats the full rule body
because a crawler obeys only the most specific User-agent group that
matches it — a bare "Allow: /" group would override the * group's
Disallow rules for that bot.
"""
import argparse

# AI crawlers we explicitly welcome. robots.txt allows unlisted bots anyway;
# naming them is a deliberate "yes, index us" signal.
AI_BOTS = [
    "GPTBot",            # OpenAI: training
    "OAI-SearchBot",     # OpenAI: ChatGPT search citations
    "ChatGPT-User",      # OpenAI: on-demand fetches for a user
    "ClaudeBot",         # Anthropic: indexing
    "Claude-SearchBot",  # Anthropic: search citations
    "PerplexityBot",     # Perplexity
    "Google-Extended",   # Google: Gemini training opt-in
    "Applebot-Extended", # Apple: Apple Intelligence opt-in
]


def group(agent, disallows):
    lines = [f"User-agent: {agent}", "Allow: /"]
    lines += [f"Disallow: /{ref}/" for ref in disallows]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--disallow", nargs="*", default=[],
                        help="versioned-docs path prefixes to block")
    refs = parser.parse_args().disallow
    groups = [group("*", refs)] + [group(bot, refs) for bot in AI_BOTS]
    print("\n\n".join(groups))
    print("\nSitemap: https://getnapkin.to/sitemap.xml")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test — must pass**

Run: `python3 Tools/site/tests/test_gen_robots.py`
Expected: `OK` (3 tests).

- [ ] **Step 5: Wire into the workflow and delete the static file**

In `.github/workflows/Documentation.yml`, delete the line:

```yaml
          cp Tools/site/robots.txt docs/robots.txt
```

Then, immediately after the `gen_sitemap.py` lines added in Task 6, add:

```yaml
          # robots.txt — welcome AI crawlers, block the versioned doc copies
          # that actually built this run (same refs as the version dropdown).
          EXISTING_REFS=""
          for ref in $REFS; do
            if [ -d "docs/${ref}" ]; then EXISTING_REFS="${EXISTING_REFS} ${ref}"; fi
          done
          python3 Tools/site/gen_robots.py --disallow ${EXISTING_REFS} > docs/robots.txt
```

Then delete the now-unused static file:

```bash
git rm Tools/site/robots.txt
```

- [ ] **Step 6: Commit**

```bash
git add Tools/site/gen_robots.py Tools/site/tests/test_gen_robots.py .github/workflows/Documentation.yml
git commit -m "feat: generate robots.txt — welcome AI crawlers, block versioned doc copies

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: DocC content flag, passed conditionally

**Files:**
- Modify: `.github/workflows/Documentation.yml` (new detection step + both `generate-documentation` calls)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `DOCC_CONTENT_FLAG` environment variable (either the flag string or unset), consumed by both build steps in the same workflow.

- [ ] **Step 1: Add the detection step**

In `.github/workflows/Documentation.yml`, immediately after the "Select Xcode" step, add:

```yaml
      - name: Detect DocC content flag
        # Swift 6.3+ DocC can write each page's real title and full text into
        # its index.html (readable without JavaScript — which the crawlers
        # behind ChatGPT/Claude/Perplexity never run). The flag is marked
        # experimental, so detect support instead of assuming it: on an older
        # toolchain we simply build today's output.
        run: |
          if xcrun docc convert --help 2>/dev/null | grep -q -- '--experimental-transform-for-static-hosting-with-content'; then
            echo "DOCC_CONTENT_FLAG=--experimental-transform-for-static-hosting-with-content" >> "$GITHUB_ENV"
            echo "docc supports static-hosting-with-content: passing it"
          else
            echo "docc does not support static-hosting-with-content: building without it"
          fi
```

- [ ] **Step 2: Pass the flag in the latest-docs build**

In the "Build DocC (latest)" step, find:

```yaml
          swift package --allow-writing-to-directory ./docs \
            generate-documentation \
            --target napkin \
            --disable-indexing \
            --transform-for-static-hosting \
```

Replace with:

```yaml
          swift package --allow-writing-to-directory ./docs \
            generate-documentation \
            --target napkin \
            --disable-indexing \
            --transform-for-static-hosting \
            ${DOCC_CONTENT_FLAG} \
```

(`${DOCC_CONTENT_FLAG}` is deliberately unquoted: when unset it expands to
nothing and the line disappears; quoting it would pass an empty argument
and break the build.)

- [ ] **Step 3: Pass the flag in the versioned-docs build**

In the "Build versioned docs" step, find:

```yaml
            if swift package --allow-writing-to-directory "docs/${ref}" \
                generate-documentation \
                --target napkin \
                --disable-indexing \
                --transform-for-static-hosting \
```

Replace with:

```yaml
            if swift package --allow-writing-to-directory "docs/${ref}" \
                generate-documentation \
                --target napkin \
                --disable-indexing \
                --transform-for-static-hosting \
                ${DOCC_CONTENT_FLAG} \
```

- [ ] **Step 4: Verify the flag works against this repo's real docs locally**

Run:
```bash
OUT="$(mktemp -d)/docc"
swift package --allow-writing-to-directory "$OUT" \
  generate-documentation --target napkin \
  --disable-indexing --transform-for-static-hosting \
  --experimental-transform-for-static-hosting-with-content \
  --output-path "$OUT" 2>&1 | tail -2
grep -o '<title>[^<]*</title>' "$OUT/documentation/napkin/presenter/index.html"
```
Expected: build succeeds; final line is `<title>Presenter</title>` (NOT `<title>Documentation</title>`).

- [ ] **Step 5: Verify the workflow YAML still parses**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/Documentation.yml"); puts "YAML OK"'`
Expected: `YAML OK`

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/Documentation.yml
git commit -m "feat: enable DocC static-hosting-with-content flag (detected, not assumed)

Each doc page's real title and text land in its index.html, readable by
crawlers that don't run JavaScript. Experimental flag, so the workflow
detects support and falls back to today's output on older toolchains.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: IndexNow — tell Bing about new pages on every deploy

**Files:**
- Create: `Tools/site/indexnow-key.txt`
- Modify: `.github/workflows/Documentation.yml` (copy the key file; add post-deploy ping step)

**Interfaces:**
- Consumes: `docs/sitemap.xml` (Task 6) for the URL list; the key file must be live at `https://getnapkin.to/indexnow-key.txt` (IndexNow fetches it to verify we own the site).
- Produces: nothing downstream.

- [ ] **Step 1: Generate the key file**

Run:
```bash
uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' > Tools/site/indexnow-key.txt
cat Tools/site/indexnow-key.txt
```
Expected: one 32-character lowercase hex string. (The key is not a secret — it gets published at the site root; that's how the protocol proves site ownership.)

- [ ] **Step 2: Copy it into the site in the workflow**

In `.github/workflows/Documentation.yml`, find:

```yaml
          cp Tools/site/security.txt docs/security.txt
```

Replace with:

```yaml
          cp Tools/site/security.txt docs/security.txt
          # IndexNow key — must be publicly fetchable for the ping step below.
          cp Tools/site/indexnow-key.txt docs/indexnow-key.txt
```

- [ ] **Step 3: Add the ping step after deploy**

At the end of the workflow, after the "Deploy to GitHub Pages" step, add:

```yaml
      - name: Ping IndexNow
        # Tells Bing (and other IndexNow engines) which URLs exist, right
        # after deploy — indexing in days instead of weeks. Google doesn't
        # support IndexNow; it discovers us via sitemap.xml. Best-effort:
        # a failed ping must never fail the deploy.
        run: |
          python3 - <<'PY' > /tmp/indexnow.json
          import json, re
          urls = re.findall(r"<loc>([^<]+)</loc>", open("docs/sitemap.xml").read())
          key = open("Tools/site/indexnow-key.txt").read().strip()
          print(json.dumps({
              "host": "getnapkin.to",
              "key": key,
              "keyLocation": "https://getnapkin.to/indexnow-key.txt",
              "urlList": urls,
          }))
          PY
          curl -sS -X POST "https://api.indexnow.org/indexnow" \
            -H "Content-Type: application/json; charset=utf-8" \
            --data @/tmp/indexnow.json \
            -w "\nIndexNow HTTP %{http_code}\n" || echo "IndexNow ping failed (non-fatal)"
```

- [ ] **Step 4: Verify YAML parses**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/Documentation.yml"); puts "YAML OK"'`
Expected: `YAML OK`

- [ ] **Step 5: Commit**

```bash
git add Tools/site/indexnow-key.txt .github/workflows/Documentation.yml
git commit -m "feat: ping IndexNow (Bing) with all site URLs after each deploy

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Assemble the whole site locally and run acceptance checks

**Files:**
- No new files (uses a scratch directory; fixes go into the files from Tasks 1–9 if a check fails).

**Interfaces:**
- Consumes: everything above. This task simulates the workflow's "Copy homepage" step against a real DocC build, then asserts Stage 1's acceptance criteria from the spec.

- [ ] **Step 1: Build docs with the flag into a scratch site root**

```bash
SITE="$(mktemp -d)/site"
swift package --allow-writing-to-directory "$SITE" \
  generate-documentation --target napkin \
  --disable-indexing --transform-for-static-hosting \
  --experimental-transform-for-static-hosting-with-content \
  --output-path "$SITE" 2>&1 | tail -2
```
Expected: `Generated documentation archive at: .../site`

- [ ] **Step 2: Assemble the rest of the site exactly as the workflow does**

```bash
cd "$(git rev-parse --show-toplevel)"
cp Tools/site/styles.css "$SITE/styles.css"
cp Tools/site/llms.txt "$SITE/llms.txt"
mkdir -p "$SITE/faq" "$SITE/recipes" "$SITE/changelog" "$SITE/about" "$SITE/blog"
cp Tools/site/faq/index.html "$SITE/faq/index.html"
cp Tools/site/about/index.html "$SITE/about/index.html"
cp Tools/site/recipes/index.html "$SITE/recipes/index.html"
python3 Tools/site/changelog.py CHANGELOG.md > "$SITE/changelog/index.html"
cp -R Tools/site/blog/. "$SITE/blog/"
mkdir -p "$SITE/main"   # fake versioned build to prove exclusion works
sed -e "s/__NAPKIN_VERSION__/9.9.9/g" -e "s#<!-- __VERSION_LINKS__ -->##g" \
  Tools/site/index.html > "$SITE/index.html"
python3 Tools/site/gen_sitemap.py "$SITE" > "$SITE/sitemap.xml"
python3 Tools/site/gen_robots.py --disallow main > "$SITE/robots.txt"
```

- [ ] **Step 3: Run the acceptance checks**

```bash
set -e
# 1. DocC page has a real title and real noscript content, no JS needed
grep -q '<title>Presenter</title>' "$SITE/documentation/napkin/presenter/index.html"
grep -qi 'A base class for presenters' "$SITE/documentation/napkin/presenter/index.html"
# 2. sitemap covers static + docs pages, excludes versioned copies
grep -q '<loc>https://getnapkin.to/about/</loc>' "$SITE/sitemap.xml"
grep -q '<loc>https://getnapkin.to/documentation/napkin/presenter/</loc>' "$SITE/sitemap.xml"
! grep -q '/main/' "$SITE/sitemap.xml"
# 3. robots welcomes AI crawlers and blocks versioned docs
grep -q 'User-agent: GPTBot' "$SITE/robots.txt"
grep -q 'Disallow: /main/' "$SITE/robots.txt"
# 4. landing page: exactly one JSON-LD block, Person author, About link
[ "$(grep -c 'application/ld+json' "$SITE/index.html")" = "1" ]
grep -q '"WikipediaBrown"' "$SITE/index.html"
grep -q 'href="/about/"' "$SITE/index.html"
# 5. about page exists with Person schema
grep -q '"AboutPage"' "$SITE/about/index.html"
# 6. unit tests still green
python3 Tools/site/tests/test_gen_sitemap.py
python3 Tools/site/tests/test_gen_robots.py
echo "ALL STAGE-1 ACCEPTANCE CHECKS PASSED"
```
Expected: `ALL STAGE-1 ACCEPTANCE CHECKS PASSED` (plus two `OK` unittest lines). If any check fails, fix the responsible task's file and re-run this step before proceeding.

- [ ] **Step 4: Push the branch and open the PR (to `develop`, never `main`)**

```bash
git push -u origin seo/discoverability
gh pr create --base develop --title "SEO stage 1: DocC content flag, generated sitemap/robots, SPI + author metadata, IndexNow" --body "$(cat <<'EOF'
## Summary
- Turn on DocC's official `--experimental-transform-for-static-hosting-with-content` (detected at build time, falls back cleanly) so every docs page has its real title and text in static HTML — readable by the crawlers behind ChatGPT/Claude/Perplexity, which don't run JavaScript
- Generate `sitemap.xml` at deploy time covering all ~100 DocC pages (was: hand-maintained, 12 URLs)
- Generate `robots.txt`: explicitly welcome AI crawlers; block stale versioned doc copies from indexing
- Add `.spi.yml` so Swift Package Index's docs link points at getnapkin.to
- Author identity: Person schema (WikipediaBrown) on landing + blog, new `/about/` page; drop the rating-less SoftwareApplication block
- Ping IndexNow (Bing) with all URLs after each deploy

Spec: `docs/superpowers/specs/2026-07-11-seo-discoverability-design.md` (Stage 1)

## Test plan
- [x] `Tools/site/tests/test_gen_sitemap.py`, `test_gen_robots.py`
- [x] Local full-site assembly + acceptance checks (plan Task 10)
- [ ] After merge: `workflow_dispatch` the Documentation workflow, then spot-check https://getnapkin.to/sitemap.xml, /robots.txt, /about/, and a docs page title

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Deferred to later stages (so nobody "helpfully" adds them now)

- Comparison pages, FAQ expansion, README table → Stage 2 PR.
- MARKETING.md, community-post drafts, awesome-swift submission, Search Console/Bing verification instructions → Stage 3 PR.
- No analytics of any kind (explicit maintainer decision).
