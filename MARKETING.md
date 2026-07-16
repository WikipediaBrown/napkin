# napkin discoverability playbook

The off-site half of the SEO/discoverability plan (spec:
`docs/superpowers/specs/2026-07-11-seo-discoverability-design.md`, Stage 3). The
research behind these priorities (two adversarially-verified passes, July 2026, in
that spec): ranking in ordinary web search is the main gate to being cited by AI
assistants; **earned mentions** (YouTube, community posts, lists) correlate with
AI-answer visibility far more than backlinks; comparison/decision content wins
citations. Everything below is either **done**, **drafted and waiting for you to
post it**, or **needs your accounts** with steps written out.

Facts and drafts written July 16, 2026 — re-check dates/versions before posting.

---

## Already automated (nothing to do)

- **IndexNow** — every site deploy pings Bing with all URLs (`Documentation.yml`,
  since Stage 1). *Verify once after the next release:* the "Ping IndexNow" step in
  the Documentation workflow log should end `IndexNow HTTP 200`.
- **Sitemap + robots** — generated at deploy; AI crawlers explicitly welcomed.
- **Swift Package Index** — `.spi.yml` points SPI's Documentation link at
  getnapkin.to.

## Needs your accounts (step-by-step)

### 1. Google Search Console  *(highest value, ~15 minutes)*
1. Go to https://search.google.com/search-console → Add property →
   **URL prefix** → `https://getnapkin.to/`.
2. Choose the **HTML file** verification method and download the file
   (`googleXXXX.html`).
3. Give the file to Claude (or drop it in `Tools/site/` yourself and add a
   `cp Tools/site/googleXXXX.html docs/googleXXXX.html` line beside the
   `security.txt` copy in `.github/workflows/Documentation.yml`), merge, release.
4. Click **Verify**, then **Sitemaps** → submit `https://getnapkin.to/sitemap.xml`.
5. After a few weeks, **Performance** shows the queries napkin ranks for — watch
   for "ribs alternative", "swift clean architecture", the compare-page titles.

### 2. Bing Webmaster Tools  *(~5 minutes, do right after GSC)*
1. https://www.bing.com/webmasters → **Import from Google Search Console** (one
   click, reuses the GSC verification).
2. Submit the same sitemap URL. Bing powers ChatGPT search retrieval, so this one
   matters more than its market share suggests.

### 3. YouTube demo  *(the strongest single correlate of AI-answer visibility in the research)*
No production values needed — a 5–10 minute screen recording:
1. "What napkin is" over the getnapkin.to landing animation (30s).
2. Clone → open `Examples/RibHouse` → run (2 min).
3. Walk one napkin: Builder → Interactor (actor) → Router → Presenter (3 min).
4. The pitch, honestly: RIBs pattern, no RxSwift, compiler enforces the rules (1 min).
Title suggestion: **"napkin: the RIBs pattern on Swift 6 actors — no RxSwift (demo)"**.
Link getnapkin.to and the repo in the description.

## Drafted — post when you're ready (all signed as you)

*Before posting anything below: confirm the pages each draft links to are live
(the compare pages and /when-to-use-napkin/ ship with the Stage 2 PR and deploy
on the next release), and re-check the dated facts.*

### Hacker News (Show HN)
> **Title:** Show HN: napkin – Uber's RIBs pattern rebuilt on Swift 6 actors, no RxSwift
>
> **Text:** I maintain napkin, an open-source Swift framework that keeps the
> Router-Interactor-Builder architecture from Uber's RIBs but rebuilds it on Swift 6
> concurrency: business logic lives in `final actor` interactors, routing/presentation
> are `@MainActor`, and every isolation crossing is an explicit `await`. No RxSwift
> and no runtime leak detector — actor isolation is checked by the compiler, and a
> weak-view ownership rule stands in for the leak detector.
>
> To be clear: RIBs is alive (RIBs-iOS 1.1.0 shipped July 12, 2026 — re-check for
> newer releases before posting) — napkin is for teams that want the pattern without
> the Rx backbone. It targets iOS 26/macOS 26, it's young, and the community is tiny;
> the docs say plainly when you should use RIBs, TCA, or plain SwiftUI instead:
> https://getnapkin.to/when-to-use-napkin/
>
> Docs: https://getnapkin.to · Repo: https://github.com/WikipediaBrown/napkin
> Happy to answer questions about the actor-isolation design decisions.

*HN norms: post morning US time on a weekday, stay in the thread answering
technical questions, don't ask for upvotes.*

### r/swift / r/iOSProgramming
> **Title:** I rebuilt the RIBs architecture on Swift 6 actors (no RxSwift) — with comparison pages vs RIBs, TCA, and VIPER
>
> **Body:** RIBs' Router-Interactor-Builder tree is a great shape for flow-heavy
> apps, but the framework is built on RxSwift and ships a runtime leak detector. I wanted
> the shape with Swift 6's own machinery, so I built napkin: interactors are
> `final actor`s, the UI ring is `@MainActor`, streaming is `AsyncStream`/`Observations`,
> and isolation mistakes are compile errors.
>
> Before anyone says it: RIBs is *not* dead — uber/RIBs-iOS shipped 1.1.0 on July 12, 2026.
> I wrote cited comparison pages (vs RIBs, vs TCA, vs VIPER) that try hard to be
> honest about when napkin is the wrong choice — e.g. it needs iOS 26+, and if your
> complexity is state rather than flows, TCA is better at that:
> https://getnapkin.to/compare/napkin-vs-ribs/
>
> Runnable example app in the repo. Feedback welcome, especially from people who've
> shipped RIBs at scale.

*Check each subreddit's self-promo rules; r/swift generally allows OSS with
engagement. Post one, wait a week, post the other.*

### iOS Dev Weekly pitch (email to Dave Verwer / submit via site)
> Subject: napkin — Uber's RIBs pattern rebuilt on Swift 6 actors
>
> Hi Dave — napkin is an open-source reimplementation of the RIBs
> Router-Interactor-Builder architecture on native Swift 6 concurrency: actor
> interactors, @MainActor routing, no RxSwift dependency, compile-time isolation
> checking and a weak-view rule in place of RIBs' runtime leak detector. Might
> interest readers evaluating
> architecture options post-Swift-6: the docs include comparison pages (vs RIBs,
> vs TCA, vs VIPER) that say plainly when each alternative is the better choice.
> https://getnapkin.to — WikipediaBrown

### awesome-swift entry — **HOLD until the repo has ≥ 15 stars** (their hard rule)
PR against https://github.com/matteocrippa/awesome-swift. Note their CONTRIBUTING.md:
the README is **generated from `contents.json`** — the PR must edit the JSON, not the
README, and the PR description must say why the package belongs. There is currently
no RIBs-style framework in the "Patterns" category. Entry to add to `contents.json`:
> ```json
> {
>   "title": "napkin",
>   "url": "https://github.com/WikipediaBrown/napkin",
>   "description": "Router-Interactor-Builder (RIBs-style) architecture rebuilt on Swift 6 actors — no RxSwift, compile-time isolation."
> }
> ```
> PR description: "napkin fills the RIBs-style slot in Patterns (none listed today):
> Apache-2.0, actively maintained, documented at getnapkin.to, Swift 6, >15 stars."
Other criteria (already met): actively maintained, documented, English README,
Swift 5+, Apache-2.0. The soft gate is "used by the community" — the star count
covers it.

## Measurement (no analytics by choice)

We deliberately run no visitor analytics. What you *can* watch:
- **Google Search Console / Bing Webmaster**: impressions, clicks, queries (above).
- **AI citations, manually**: ask ChatGPT/Claude/Perplexity "RIBs alternative for
  Swift Concurrency?" or "napkin vs TCA" monthly; note whether napkin appears and
  which page gets cited.
- **GitHub traffic** (Insights → Traffic): referrers from chatgpt.com,
  perplexity.ai, bing.com are the AI-driven signal; stars gate the awesome-swift PR.
- If you later want referrer data on the site itself, the cookieless options
  researched: **Cloudflare Web Analytics** (free, one script tag) or
  **GoatCounter** (free, open-source). Both consent-banner-free.

## Refresh cadence

- Comparison tables are stamped "as of July 15, 2026". Re-verify when: TCA 2.0
  ships (their 1.24 and 1.25 releases openly prepare it), RIBs-iOS releases, or
  ~every 6 months, whichever comes first.
- The two research-refuted claims that must stay out of napkin copy: "TCA 2.0 is in
  beta" (it isn't; it's *in preparation*) and "v0.16.4 removed iOS from uber/RIBs"
  (the split happened October 2024).
- Open research gap: no verified data on real search phrasings (two passes came
  back empty). If Search Console later shows the actual queries, retitle H2s to
  match — that's the durable, evidence-based way to do it.
