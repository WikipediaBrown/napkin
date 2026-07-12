# napkin discoverability (SEO + GEO) — design

**Date:** 2026-07-11
**Branch:** `seo/discoverability`
**Author/maintainer identity:** WikipediaBrown (github.com/WikipediaBrown, https://wikipediabrown.dev)

## Goal

Make napkin — the framework, its site, its docs, and its GitHub repo — as findable as
possible by **both** traditional search engines **and** AI systems (ChatGPT, Claude,
Perplexity, Google AI Overviews/AI Mode, and coding assistants). Do everything we
credibly can in-repo, do the external actions that don't require the maintainer's
personal accounts, and hand off a written checklist for the account-gated rest.

## What the research established (evidence base)

Two adversarially-verified deep-research passes (2026-07-11; 24 of 25 claims survived
3-vote verification). The findings that shape this design:

1. **Classic search ranking is the dominant AI-citation gate.** ChatGPT cites pages it
   retrieved via general web search **88.5%** of the time, vs Reddit 1.9%, YouTube 0.5%
   (Ahrefs, 1.4M prompts). Ranking on Google/Bing for queries like "RIBs alternative
   Swift" and "Clean Architecture iOS framework" *is* the AI-visibility strategy.
2. **DocC's default output is nearly invisible to AI crawlers, but there is now an official
   fix.** DocC renders as a client-side JS SPA; GPTBot / ClaudeBot / PerplexityBot fetch but
   do **not** execute JavaScript (Vercel/MERJ, 500M+ fetches). Only Gemini (via Googlebot)
   and AppleBot render it. By default DocC emits ~102 byte-identical 4,205-byte shells titled
   "Documentation". **However**, Swift 6.3+ ships an official flag,
   `--experimental-transform-for-static-hosting-with-content`, that makes DocC write a real
   `<title>` and the full page content (in `<noscript>`) into each `index.html` — verified
   locally on the Xcode 27 toolchain. This is the official replacement for hand-injected
   content and is the approach this design uses. DocC still ships **no sitemap generator**
   (swift-docc#779, open) and the flag does not emit description/canonical/Open Graph (those
   await the unshipped "absolute hosting URL" feature, #779/#964) — so the sitemap and
   versioned-docs deduplication remain this project's responsibility (§1a-bis, §1b).
3. **GEO content shape that measurably wins citations:** direct quotations, statistics,
   cited sources (+30–40% in the GEO/KDD-2024 paper); titles/URLs semantically matched to
   the user's question. Keyword-stuffing performs ~10% *worse* than baseline.
4. **Earned third-party mentions ≫ backlinks** (YouTube ~0.74, branded mentions ~0.7,
   backlinks ~0.2 — Ahrefs, 75k brands). `awesome-swift`'s "Patterns" list has **no**
   RIBs-style framework (open niche), but its gate is **≥15 GitHub stars** (napkin ~2).
5. **Structured data still consumed by Google in 2026**, but pick honest types
   (SoftwareSourceCode / TechArticle / BlogPosting / BreadcrumbList). Do **not** fake a
   `SoftwareApplication` aggregateRating/review to chase a rich result — it violates
   Google's self-serving-review policy. FAQ rich results were retired May 2026, but
   `FAQPage` JSON-LD still aids AI parsing.
6. **llms.txt: keep, don't over-invest** — 97% of llms.txt files get zero requests;
   no major AI system is confirmed to consume it. napkin already has one.
7. **Crawler policy:** for a project that *wants* AI visibility, robots.txt should
   explicitly allow the AI crawlers. GitHub Pages has no server headers/redirects, so
   robots.txt + injected `<meta>` are the only levers. Not behind Cloudflare, so
   Cloudflare's Sept 15 2026 default AI-block does not apply.
8. **Swift Package Index:** already listed; add `.spi.yml` to control the docs link.

## Non-goals / things that could backfire (explicitly avoided)

- **No fabricated `SoftwareApplication` rating/review** (policy violation).
- **No keyword stuffing** (measurably counterproductive).
- **No cloaking** — the `<noscript>`/injected metadata must faithfully describe the same
  content the JS renders (it's derived from DocC's own JSON, so it matches by construction).
- **No over-investment in llms.txt / llms-full.txt** beyond keeping them in sync cheaply.
- **No auto-hosting a second DocC copy on SPI** (cross-domain duplicate content).

## Architecture constraint (critical)

`.github/workflows/Documentation.yml` **regenerates the entire `docs/` tree on every
deploy** from `Tools/site/` + the DocC catalog + the workflow. Therefore:
- The source of truth is `Tools/site/` and the workflow — **never hand-edit `docs/`**.
- Any per-page DocC transformation must be a **build step** that runs after
  `generate-documentation`, operating on the freshly-built `docs/` output.

---

## Stage 1 — Technical foundation (PR #1)

High-evidence, low-risk. No prose judgment calls; safe to ship first.

### 1a. DocC crawler-readability — the OFFICIAL flag (revised 2026-07-12)

**Corrected after primary-source verification + an empirical test on the Xcode 27 / Swift
6.4 toolchain.** The original plan here was a hand-rolled Python post-processor. That is
superseded: DocC now ships a first-party flag that does the core job, matching the
"prefer the official mechanism" preference.

**Add `--experimental-transform-for-static-hosting-with-content`** to **both**
`swift package generate-documentation` invocations in `Documentation.yml` (the latest build
and the versioned-docs loop). Shipped in Swift 6.3 (swift-docc PRs #1383/#1402/#1409),
expanded on `main` for 6.4. With it, DocC itself writes into every per-page `index.html`:
- a **real `<title>`** (e.g. `Presenter`) in place of the generic `Documentation`, and
- the **full page content** (title, declaration, abstract, Overview, "Mentioned In") as
  semantic HTML inside the page's `<noscript>` — readable by JS-less crawlers
  (GPTBot/ClaudeBot/PerplexityBot).

Verified locally on napkin's `Presenter` page: the shell grows from a byte-identical
4,205 B "Documentation" placeholder to a 5,109 B page with a real title and real
`<noscript>` content. Not cloaking (the content is DocC's own render of the same page).

Toolchain gate: the flag is `--experimental-` and only exists in Swift 6.3+. napkin's docs
build currently `xcode-select`s the highest non-beta Xcode 26.x; confirm that runner's
`docc` accepts the flag (Swift 6.3 shipped in Xcode 26.4+), and **pass it conditionally** —
detect support (`docc convert --help | grep static-hosting-with-content`) and only append
the flag if present — so an older runner image degrades to today's behavior instead of
failing the build. (This dovetails with the separate Xcode-27 CI transition work.)

### 1a-bis. Residual DocC metadata — minimal, official-adjacent (NOT hand-injected content)

The official flag does **not** emit `<meta name=description>`, `<link rel=canonical>`, or
Open Graph (verified absent; upstream ties these to the unshipped "absolute hosting URL"
feature, swift-docc #779/#964). Handle the residue with the **smallest** step, no content
injection (so nothing can diverge from what DocC renders → no cloaking risk):

- **Versioned-docs duplication** (`/main/…`, `/2.0.8/…` vs the latest at
  `/documentation/napkin/…`): since we cannot set a canonical officially, use the
  Google-recommended *single-signal* alternative — **`robots.txt` `Disallow:` the versioned
  path prefixes** (`/main/`, `/<version>/`) and **exclude them from the sitemap**. This
  removes the duplicates from indexing without mixing contradictory canonical+noindex
  signals. The latest (unversioned) copy stays fully crawlable. Old versions remain
  reachable by humans via the version picker; they're just not indexed.
- **`<meta name=description>`**: deferred. The full page text now lives in `<noscript>`, so
  crawlers can derive a snippet; a separate description tag is a minor gain with no official
  emitter. Revisit if/when the absolute-hosting-URL feature lands (it would add description +
  canonical + OG natively — at which point drop this residue entirely).
- **Author/Organization JSON-LD** site-wide default: set officially via DocC's
  `theme-settings.json` `meta.title` (already-shipped catalog file) so rendered titles read
  `{Page} | napkin`; richer per-page JSON-LD is deferred to the native feature rather than
  hand-injected.

### 1b. Sitemap generator
New script `Tools/site/gen_sitemap.py` replacing the static `Tools/site/sitemap.xml` copy.
Emits `<url>` entries for: landing `/`, `/about/`, `/faq/`, `/recipes/`, `/changelog/`,
`/blog/` + each `/blog/<slug>/`, the Stage-2 compare pages, and **every** latest DocC page
(`documentation/napkin/**` and `tutorials/**`). Versioned copies (`/<ref>/…`) are
**excluded** (they're `Disallow`ed in robots.txt per §1a-bis). `lastmod` from git commit date
where practical, else file mtime. Wired into the workflow's "Copy homepage" step in place of
`cp Tools/site/sitemap.xml`.

### 1c. robots.txt
Keep `User-agent: * / Allow: /` and the `Sitemap:` line. Add explicit allow blocks (intent
signal) for: `GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, `Claude-SearchBot`,
`PerplexityBot`, `Google-Extended`, `AppleBot-Extended`. Also add `Disallow:` rules for the
versioned-docs path prefixes (`/main/`, and each built `/<version>/`) per §1a-bis so only the
latest DocC copy is indexed. The `Disallow` list is generated in the workflow from the same
ref list the versioned-docs loop uses, so it stays in sync automatically.

### 1d. `.spi.yml`
Add at repo root:
```yaml
version: 1
external_links:
  documentation: "https://getnapkin.to/documentation/napkin/"
```
(Points SPI's Documentation link at the existing site; avoids a duplicate DocC copy.)

### 1e. Author identity + schema cleanup
- Add a reusable `Person` author object — `{ name: "WikipediaBrown",
  url: "https://wikipediabrown.dev", sameAs: [github repo/owner, spookylabs.ai] }` — to the
  JSON-LD on the landing page and every blog post. (DocC pages get their metadata from the
  official flag in §1a, not injected JSON-LD; richer DocC JSON-LD waits for the native
  absolute-hosting-URL feature.)
- **Remove** the rating-less `SoftwareApplication` JSON-LD block from `Tools/site/index.html`;
  keep and enrich the `SoftwareSourceCode` block (add `author`, `sameAs`).
- New `Tools/site/about/index.html` → `/about/`: a short maintainer/E-E-A-T page
  (`Person` + `Organization` Spooky Labs, links to wikipediabrown.dev + GitHub), copied in
  the workflow and added to nav + sitemap + llms.txt.
- Add `BreadcrumbList` JSON-LD to blog posts.

### 1f. IndexNow
Generate a one-time IndexNow key (a UUID), store it as `Tools/site/<key>.txt` (file content =
the key), copy it to the site root in the workflow, and add a post-deploy workflow step that
POSTs the sitemap's URLs to the IndexNow endpoint (Bing/Yandex) with that key. Cheap,
static-host-compatible.

### Stage 1 acceptance
- A sampled DocC page's static HTML (curl, no JS) shows a **unique real `<title>`** and
  **real page content in `<noscript>`** — emitted by the official flag, not injected.
- The docs workflow passes `--experimental-transform-for-static-hosting-with-content`
  conditionally (present only when the runner's `docc` supports it) and builds green either
  way.
- `sitemap.xml` contains the landing/blog/faq/recipes/changelog/about pages **and** the
  latest DocC routes; contains no `/<version>/…` URLs.
- `robots.txt` names the AI crawlers, and `Disallow`s the versioned-docs prefixes so only the
  latest DocC copy is indexed.
- `.spi.yml` present; landing page has no rating-less `SoftwareApplication`; `/about/` renders.
- `Documentation.yml` builds green on a manual `workflow_dispatch`.

---

## Stage 2 — Content (PR #2)

Highest ceiling; maintainer voice matters, reviewed separately. New server-rendered pages
reuse the existing hand-rolled blog template (full OG/Twitter + `TechArticle` JSON-LD),
written in GEO-optimal shape (concrete quotations, stats, cited sources; titles matched to
real queries) and in napkin's established **honest** positioning (RIBs is alive and
maintained; the real differences are no RxSwift, no runtime leak detector).

- `/compare/napkin-vs-ribs/` — the unoccupied `awesome-swift` niche.
- `/compare/napkin-vs-tca/` — vs The Composable Architecture.
- `/compare/napkin-vs-viper/` — vs VIPER.
- `/when-to-use-napkin/` — a standalone decision guide (when napkin fits vs when it doesn't),
  cross-linked from the three compare pages.
- Expand `/faq/` with more Q&A-shaped, citable entries (keep `FAQPage` JSON-LD).
- README: add a concise "napkin vs alternatives" table + links to the compare pages
  (GitHub renders tables/links; strips OG/JS).
- Wire all new pages into sitemap, llms.txt (+ llms-full.txt bodies), and nav.

### Stage 2 acceptance
- Three compare pages + when-to-use render with valid TechArticle JSON-LD (Rich Results
  test passes) and appear in sitemap + llms.txt + nav.
- FAQ expanded; README comparison table links resolve.
- No keyword stuffing; positioning matches the project's honest stance.

---

## Stage 3 — External actions + playbook (PR #3)

A new `MARKETING.md` (repo root) plus the actions that don't need the maintainer's accounts.

- **Automated / agent-doable:** IndexNow submission (from 1f); a **drafted** `awesome-swift`
  PR held until napkin clears the 15-star gate; draft HN / Reddit (r/swift, r/iOSProgramming)
  / Stack Overflow / iOS Dev Weekly copy signed as WikipediaBrown.
- **Account-gated (documented step-by-step in MARKETING.md):** Google Search Console + Bing
  Webmaster verification (agent drops the HTML verification file once given the token) and
  sitemap submission; posting the community content; a short YouTube demo (highest-correlated
  signal, ~0.74).
- **Measurement:** MARKETING.md documents how to track AI referrers (`chatgpt.com` /
  `perplexity.ai` / `bing.com` referrers, Search Console). **No analytics is being added now**
  (maintainer's choice); MARKETING.md records Cloudflare Web Analytics and GoatCounter as
  cookieless options to add later if desired.
- **GitHub repo:** confirm description/topics/social-preview (already strong); optionally add
  topics (`viper`, `tca`, `ios-architecture`, `dependency-injection`).

### Stage 3 acceptance
- `MARKETING.md` committed with a clear checklist splitting agent-done vs maintainer-todo.
- IndexNow ping verified firing on deploy.
- Draft community/awesome-swift copy present in the repo (e.g. under `Tools/site/` or
  `MARKETING.md`) ready to post.

---

## Decisions locked
- Delivery: **Option A** — three staged, independently-shippable PRs.
- Content: **all three** compare pages + when-to-use guide.
- Analytics: **none now**; documented for later.
- Author identity: WikipediaBrown / wikipediabrown.dev.
- SPI: external-link the docs (no second DocC copy).
- DocC crawler-readability: the **official** `--experimental-transform-for-static-hosting-with-content`
  flag (verified on Xcode 27), not a hand-rolled content injector. Versioned-docs dedup via
  `robots.txt Disallow` + sitemap exclusion, since no official canonical emitter exists yet.

## Risks / open items
- **The DocC content flag is `--experimental-`.** Its spelling/behavior could change across
  toolchains, and it only exists in Swift 6.3+. Mitigation: pass it *conditionally* (detect
  via `docc convert --help`) so the build degrades to today's behavior rather than failing;
  re-verify after the Xcode-27 CI transition. If/when the native "absolute hosting URL"
  feature ships (adding description + canonical + Open Graph + native sitemap), revisit and
  drop the §1a-bis / §1b residue in favor of the native path.
- **No official canonical for versioned docs.** Using `robots.txt Disallow` (single-signal)
  instead of a canonical is deliberate — mixing canonical+noindex sends contradictory signals
  (per Google/Mueller). Trade-off: `Disallow`ed old-version pages won't be indexed at all
  (acceptable — we only want the latest indexed).
- **`awesome-swift` inclusion is star-gated (≥15)** — cannot be completed now; the PR is
  drafted and parked.
- **Absolute measurement will undercount** (privacy-conscious audience blocks trackers); the
  referrer *signal* still comes through.
- Sitemap `lastmod` accuracy depends on git dates being available in the shallow CI checkout;
  fall back to file mtime.
