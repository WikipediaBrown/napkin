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
2. **DocC is nearly invisible to AI crawlers.** DocC renders as a client-side JS SPA;
   GPTBot / ClaudeBot / PerplexityBot fetch but do **not** execute JavaScript
   (Vercel/MERJ, 500M+ fetches). Only Gemini (via Googlebot) and AppleBot render it.
   DocC ships **no sitemap generator** (swift-docc#779, open since 2023). Confirmed
   locally: DocC emits ~102 per-page `index.html` files that are byte-identical 4,205-byte
   SPA shells titled "Documentation" with no canonical, description, or OG tags.
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

### 1a. DocC static-HTML enrichment — centerpiece
New script `Tools/site/docc_seo.py`, invoked in `Documentation.yml` after **each** DocC
build (the latest build into `docs/`, and each versioned build into `docs/<ref>/`).

For every `documentation/napkin/**/index.html` and `tutorials/**/index.html`:
- Locate the sibling route JSON under `data/…/<route>.json`.
- Read `metadata.title` and flatten `abstract` inline runs to plain text.
- Inject into `<head>` (replacing DocC's generic `<title>Documentation</title>`):
  - `<title>{Title} | napkin</title>`
  - `<meta name="description" content="{abstract}">`
  - `<link rel="canonical" href="{canonicalURL}">`
  - OG + Twitter tags (`og:title`, `og:description`, `og:type=article`, `og:url`, image)
  - `Person` author + `BreadcrumbList` JSON-LD (breadcrumb from DocC `hierarchy`)
  - a `<noscript>` block with `<h1>{Title}</h1><p>{abstract}</p>` + a link, so JS-less
    crawlers read real, unique content.
- **Canonical rule:**
  - Latest build (`docs/documentation/napkin/<route>/`) → canonical = its own
    `https://getnapkin.to/documentation/napkin/<route>/`.
  - Versioned build (`docs/<ref>/documentation/napkin/<route>/`) → canonical = the
    **unversioned latest** URL `https://getnapkin.to/documentation/napkin/<route>/`
    (dedupes `/2.0.8/…`, `/main/…` against the canonical copy).
- Idempotent and resilient: if a route JSON is missing, leave that page's shell untouched
  and log it (never fail the build over one page).

### 1b. Sitemap generator
New script `Tools/site/gen_sitemap.py` replacing the static `Tools/site/sitemap.xml` copy.
Emits `<url>` entries for: landing `/`, `/about/`, `/faq/`, `/recipes/`, `/changelog/`,
`/blog/` + each `/blog/<slug>/`, the Stage-2 compare pages, and **every** latest DocC page
(`documentation/napkin/**`). Versioned copies are **excluded** (canonicalized away).
`lastmod` from git commit date where practical, else file mtime. Wired into the workflow's
"Copy homepage" step in place of `cp Tools/site/sitemap.xml`.

### 1c. robots.txt
Keep `User-agent: * / Allow: /` and the `Sitemap:` line. Add explicit allow blocks (intent
signal) for: `GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, `Claude-SearchBot`,
`PerplexityBot`, `Google-Extended`, `AppleBot-Extended`.

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
  JSON-LD on the landing page, every blog post, and (via 1a) DocC pages.
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
- A sampled DocC page's static HTML (curl, no JS) shows a unique `<title>`, description,
  canonical, and `<noscript>` content.
- `sitemap.xml` contains the landing/blog/faq/recipes/changelog/about pages **and** the
  DocC routes; contains no `/<version>/…` URLs.
- Versioned DocC pages carry a canonical to the unversioned latest URL.
- `robots.txt` names the AI crawlers; `.spi.yml` present; landing page has no rating-less
  `SoftwareApplication`; `/about/` renders.
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

## Risks / open items
- **DocC output shape may shift under Xcode 27 / Swift 6.4** (see the WWDC-2026 transition
  work). `docc_seo.py` must be defensive (skip-and-log on unexpected JSON) so a DocC-Render
  change degrades gracefully rather than breaking the deploy.
- **`awesome-swift` inclusion is star-gated (≥15)** — cannot be completed now; the PR is
  drafted and parked.
- **Absolute measurement will undercount** (privacy-conscious audience blocks trackers); the
  referrer *signal* still comes through.
- Sitemap `lastmod` accuracy depends on git dates being available in the shallow CI checkout;
  fall back to file mtime.
