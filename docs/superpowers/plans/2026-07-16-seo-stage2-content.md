# SEO Stage 2 — Comparison Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the decision-content pages that research shows earn search ranking and AI-assistant citations: `/compare/napkin-vs-ribs/`, `/compare/napkin-vs-tca/`, `/when-to-use-napkin/`, an expanded FAQ, and a README comparison table — every factual claim verified and cited, in napkin's honest voice.

**Architecture:** New pages live in `Tools/site/compare/<slug>/index.html` and `Tools/site/when-to-use-napkin/index.html`, reusing the blog's `article.post` template and shared `styles.css` (which gains a `.compare-table` style). The deploy workflow copies them in; `gen_sitemap.py` learns to walk `compare/` (dated, like blog) and lists `when-to-use-napkin/`. All pages carry `TechArticle` JSON-LD with the Person author and are added to `llms.txt`, the landing footer, and each other's "related" links.

**Tech Stack:** Hand-rolled HTML (no SSG), Python 3 stdlib, GitHub Actions.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-11-seo-discoverability-design.md` (Stage 2 section).
- **Honesty rules:** RIBs is alive (1.1.0 shipped 2026-07-12) — never imply otherwise. Attribute maintainer claims as claims. Do not publish either refuted claim: "TCA 2.0 is in beta / has a @Feature macro" (2.0 is *in preparation* only) or "v0.16.4 removed iOS from uber/RIBs" (the split happened Oct 2024).
- **Date-stamp every comparison table** with "facts as of July 15, 2026" — versions/stars are point-in-time.
- No keyword stuffing. Cited sources, concrete numbers, direct quotations — the GEO-verified content shape.
- napkin's own weak points are stated plainly: young (v2.1.5), tiny community (2 GitHub stars), iOS 26/macOS 26+ floor, no code-gen tooling.
- Canonical RIBs iOS link is `https://github.com/uber/RIBs-iOS` (post-split repo).
- Never edit `docs/` (generated) except `docs/superpowers/`.
- Branch `seo/content`; commit per task; PR targets `develop`.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## Verified fact inventory (single source of truth for all page claims)

All 3-vote-verified 2026-07-15/16 unless noted. Cite the listed source on-page.

**RIBs (uber/RIBs-iOS):**
- R1. Repo split Oct 2024: `uber/RIBs` = Android-only (Kotlin, ~7.9k stars); iOS = `uber/RIBs-iOS` (186 stars, Apache-2.0). [github.com/uber/RIBs README + API]
- R2. RIBs-iOS 1.1.0 published 2026-07-12; release notes: async/await interop helpers (`Single.fromAsync`, `Observable.fromAsync`, `onAsyncStep`) — verbatim "RxSwift stays the backbone". [releases/tag/1.1.0]
- R3. Package.swift pins `RxSwift "6.9.0"..<"7.0.0"` + RxRelay; no Combine/Concurrency-native variant (community forks only: ModernRIBs, RIBs-SwiftUI). [raw Package.swift]
- R4. Runtime LeakDetector ships at `RIBs/Classes/LeakDetector/LeakDetector.swift`. README verbatim quotables: "RIBs come with IDE tooling around code generation, memory leak detection, static analysis and runtime integrations - all which improve developer productivity for large teams or small" and "Strong opinions about how state should be communicated, using DI and Rx." [README + source file]
- R5. Min iOS 15.0, swift-tools 5.5. SPM canonical ("Swift Package Manager is now the canonical build" — 1.1.0 notes); CocoaPods stale (trunk has only 0.9.1; `pod 'RIBs' ~>1.0` won't resolve — medium confidence, 2-1 vote, present with that qualification). [Package.swift@1.1.0]

**TCA (pointfreeco/swift-composable-architecture):**
- T1. 1.26.0 published 2026-06-09 (incl. Xcode 27 Beta 1 fixes); 159 releases total; 7 releases in 2026; MIT; ~14.8k stars / ~1.7k forks. [releases + repo API]
- T2. 2.0 officially *in preparation*: 1.25.0 "a significant batch of deprecations that pave the way for Composable Architecture 2.0" (verbatim); 1.24.0 was "deprecations-only", hard-deprecating iOS <16, Swift <6.1, ViewStore, TaskResult, @BindingState. Current floor: swift-tools 6.1, iOS 16+. [release bodies]
- T3. Paradigm: State/Action/Reducer/Store; README verbatim "with composition, testing, and ergonomics in mind". [README]
- T4. Macros @Reducer + @ObservableState; Observation shipped v1.7 (Jan 29, 2024, "100% backwards compatible" — attribute to Point-Free), back-ported to iOS 13 via Perception; pre-iOS 17 needs `WithPerceptionTracking`. **So: @Observable is NOT a napkin differentiator vs TCA.** The honest distinction: napkin = Swift's native class-only @Observable on presenters; TCA = own @ObservableState macro for value types. [blog post 130, swift-perception, FAQ]
- T5. Official FAQ quotables (cite repo FAQ.md, not mirrors): "We do not recommend people use TCA when they are first learning Swift or SwiftUI"; "We also don't think TCA really shines when building simple 'reader' apps that mostly load JSON from the network and display it"; "Often people complain of boilerplate in TCA" (attributed largely to legacy view stores); maintainer LOC-parity claim — present as attributed claim. Also: fine to start vanilla SwiftUI and adopt TCA later. [FAQ.md]
- T6. TestStore exhaustive by default (verbatim in FAQ: "you must also assert on how effects feed their data back into the system"); non-exhaustive opt-out exists (`exhaustivity = .off`). [FAQ + docs]
- T7. Point-Free: maintenance subscriber-funded — verbatim "The honest truth is that this kind of support and turnaround for our open source projects is only thanks to the support of our subscribers."; canonical deep-dive = subscription episode collection "16 sections • 58 hr 30 min"; free DocC docs + free interactive tutorial exist. [blog post 218 + collection page]
- **Community pain-point claims (compile times, performance threads) did NOT survive verification — use only the first-party FAQ admissions above.**

**napkin (self-assessed from this repo):**
- N1. v2.1.5; Apache-2.0; iOS 26/macOS 26+; swift-tools 6.2, language mode v6; sole dependency swift-docc-plugin (docs-only). 2 GitHub stars — young, tiny community, no code-gen tooling, no runtime leak detector (compile-time isolation + weak-view rule instead); `final actor` interactors, `@MainActor` routers/presenters, native `@Observable` presenters, `Observations`/`AsyncStream` streaming; plain XCTest testing with mock rings (see FAQ).

**GATED (research wf_f2e18013-f09 in flight):** everything VIPER, and the search-phrasing list for title/H2 tuning. The VIPER page task is intentionally absent from this plan and will be appended as Task 9 with its own verified facts when that research lands. Do not draft VIPER content before then.

---

### Task 1: Comparison-table styles

**Files:**
- Modify: `Tools/site/styles.css` (append)

**Interfaces:**
- Produces: `.compare-table` (wrapper div `.compare-scroll` for small screens) used by Tasks 2–5.

- [ ] **Step 1: Append to `Tools/site/styles.css`:**

```css
/* ---- Comparison tables (compare pages, when-to-use) ---- */
.compare-scroll { overflow-x: auto; margin: 2rem 0; }
.compare-table { width: 100%; border-collapse: collapse; font-size: 0.95rem; }
.compare-table caption {
    text-align: left; font-size: 0.8rem; opacity: 0.7; padding-bottom: 0.5rem;
}
.compare-table th, .compare-table td {
    text-align: left; vertical-align: top; padding: 0.55rem 0.9rem;
    border-bottom: 1px solid var(--rule, rgba(127,127,127,0.25));
}
.compare-table thead th { border-bottom-width: 2px; }
.compare-table th[scope="row"] { font-weight: 600; white-space: nowrap; }
```

- [ ] **Step 2: Verify + commit**

Run: `grep -c 'compare-table' Tools/site/styles.css` → Expected: `>= 5`

```bash
git add Tools/site/styles.css
git commit -m "feat: comparison-table styles for compare pages

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Sitemap + workflow wiring for the new sections

**Files:**
- Modify: `Tools/site/gen_sitemap.py`, `Tools/site/tests/test_gen_sitemap.py`, `.github/workflows/Documentation.yml`

**Interfaces:**
- Consumes: Stage 1's `gen_sitemap.py` (`STATIC_PAGES`, `blog_posts(root)`).
- Produces: sitemap lists `when-to-use-napkin/` and every `compare/<slug>/` (with lastmod from `article:published_time`, same as blog). Workflow copies `Tools/site/compare/` and `Tools/site/when-to-use-napkin/` into `docs/`.

- [ ] **Step 1: Extend the test (TDD)** — in `test_gen_sitemap.py`, add to `make_fixture`:

```python
    page("when-to-use-napkin")
    page("compare/napkin-vs-ribs",
         '<html><head><meta property="article:published_time" content="2026-07-16">'
         "</head></html>")
```

and add assertions to `test_static_and_docc_pages_present`:

```python
                    "https://getnapkin.to/when-to-use-napkin/",
                    "https://getnapkin.to/compare/napkin-vs-ribs/",
```

and to `test_blog_lastmod_from_published_time`:

```python
        self.assertIn("<lastmod>2026-07-16</lastmod>", self.xml)
```

- [ ] **Step 2: Run — must fail** — `python3 Tools/site/tests/test_gen_sitemap.py` → FAIL (2 tests).

- [ ] **Step 3: Implement** — in `gen_sitemap.py`:

Change `STATIC_PAGES` to:

```python
STATIC_PAGES = ["", "about/", "faq/", "recipes/", "changelog/", "blog/",
                "when-to-use-napkin/"]
```

Rename `blog_posts` to `dated_pages(root, section)` (same body, `blog` → `section` parameter, yield prefix `f"{section}/{name}/"`), and in `main`:

```python
    entries += list(dated_pages(root, "blog"))
    entries += list(dated_pages(root, "compare"))
```

- [ ] **Step 4: Run — must pass** — `python3 Tools/site/tests/test_gen_sitemap.py` → OK.

- [ ] **Step 5: Workflow copy** — in `Documentation.yml`, after the blog copy block (`cp -R Tools/site/blog/. docs/blog/`), add:

```yaml
          # Comparison pages + decision guide (Stage 2 content).
          mkdir -p docs/compare docs/when-to-use-napkin
          cp -R Tools/site/compare/. docs/compare/
          cp Tools/site/when-to-use-napkin/index.html docs/when-to-use-napkin/index.html
```

- [ ] **Step 6: Verify YAML + commit**

```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/Documentation.yml"); puts "YAML OK"'
git add Tools/site/gen_sitemap.py Tools/site/tests/test_gen_sitemap.py .github/workflows/Documentation.yml
git commit -m "feat: sitemap + deploy wiring for compare pages and when-to-use guide

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `/compare/napkin-vs-ribs/`

**Files:**
- Create: `Tools/site/compare/napkin-vs-ribs/index.html`

**Interfaces:**
- Consumes: `.compare-table` (Task 1); blog `article.post` template classes; fact inventory R1–R5, N1.
- Produces: page linked by Tasks 5–7.

- [ ] **Step 1: Write the page.** Head: same pattern as a blog post (title/description/OG/canonical/`article:published_time content="2026-07-16"`), plus `TechArticle` JSON-LD with the Person author (same object as Stage 1). Title: `napkin vs RIBs (2026): the same pattern, two concurrency models`. Body structure (prose composed at execution strictly from R1–R5/N1, every external claim linked to its source):
  - Lede: RIBs is alive (1.1.0, July 12 2026); both frameworks are the Router-Interactor-Builder pattern; the real difference is RxSwift + runtime leak detector vs native Swift 6 concurrency + compile-time isolation.
  - H2 "Is RIBs dead? No." — repo split explained (R1, R2).
  - H2 "The actual difference: the reactive backbone" (R2, R3 vs N1).
  - H2 "Leak detection: runtime vs compile time" (R4 quote vs N1 weak-view rule).
  - H2 "Comparison table" — `.compare-table`, caption "Facts as of July 15, 2026", rows: Latest release (RIBs-iOS 1.1.0, 2026-07-12 / napkin 2.1.5); Reactive layer (RxSwift 6.9 + RxRelay / none — actors, AsyncStream, async/await); Swift Concurrency (interop helpers atop Rx / native, language mode v6); Leak detection (runtime LeakDetector / compile-time isolation, weak views); Code generation (IDE tooling per README / none); Min platform (iOS 15, tools 5.5 / iOS 26 & macOS 26, tools 6.2); Install (SPM canonical; CocoaPods stale — 0.9.1 only on trunk / SPM); License (Apache-2.0 / Apache-2.0); GitHub stars (186 / 2); Maturity (Uber-scale since 2017 / young, small community).
  - H2 "When to choose RIBs" / H2 "When to choose napkin" — mirror the positioning memory's recommendation lists, honest both ways.
  - Related links: vs TCA, when-to-use, FAQ.

- [ ] **Step 2: Validate + commit**

```bash
python3 - <<'PY'
import json, re
h = open('Tools/site/compare/napkin-vs-ribs/index.html').read()
assert 'article:published_time' in h and 'rel="canonical"' in h
d = json.loads(re.findall(r'<script type="application/ld\+json">(.*?)</script>', h, re.S)[0])
assert d["@type"] == "TechArticle" and d["author"]["name"] == "WikipediaBrown"
assert 'RIBs-iOS' in h and 'compare-table' in h
print("OK")
PY
git add Tools/site/compare/napkin-vs-ribs
git commit -m "feat: napkin vs RIBs comparison page (verified 2026 facts, cited)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `/compare/napkin-vs-tca/`

**Files:**
- Create: `Tools/site/compare/napkin-vs-tca/index.html`

Same template/JSON-LD/validation shape as Task 3. Title: `napkin vs The Composable Architecture (2026): tree of actors vs reducer graph`. Facts T1–T7 + N1 only; body structure:
  - Lede: different *kinds* of framework — TCA is a state-management architecture (State/Action/Reducer/Store); napkin is a screen/flow-tree architecture (Router-Interactor-Builder). Both are excellent at what they optimize for.
  - H2 "Two different shapes of app" (T3 vs N1).
  - H2 "Observation: not a differentiator — but different mechanics" (T4, honest per the inventory).
  - H2 "Testing" (T6 vs napkin's plain-XCTest story).
  - H2 "Cost of adoption" — TCA FAQ quotes (T5), platform floors (T2 vs N1 — note napkin's floor is *higher*: iOS 26 vs 16; honesty cuts both ways), 2.0-in-preparation churn (T2), Point-Free funding + learning resources (T7).
  - H2 "Comparison table" — caption "Facts as of July 15, 2026": Paradigm; Latest release (1.26.0, 2026-06-09 / 2.1.5); State observation (@ObservableState macro, iOS 13 backport / native @Observable classes); Testing (TestStore, exhaustive by default / XCTest + mocks); Min platform (iOS 16, tools 6.1 / iOS 26, tools 6.2); Dependencies (Point-Free ecosystem libs / swift-docc-plugin only); License (MIT / Apache-2.0); Stars (~14.8k / 2); Learning resources (free DocC + tutorial; 58.5 h subscription collection / DocC site + example app).
  - H2 "When to choose TCA" (their FAQ's own guidance, quoted) / H2 "When to choose napkin".
  - Related links + validation + commit as in Task 3 (`compare/napkin-vs-tca`).

---

### Task 5: `/when-to-use-napkin/`

**Files:**
- Create: `Tools/site/when-to-use-napkin/index.html`

Same template shape; `TechArticle`; title `When to use napkin — and when not to`. Content (N1 + cross-links; TCA FAQ quote T5-d's "start vanilla, adopt later" spirit applied to napkin too):
  - Honest "use napkin if": new app on Swift 6, iOS 26+/macOS 26+ floor acceptable, want RIB-style tree without RxSwift, prefer compile-time guarantees, small dependency budget.
  - Honest "don't use napkin if": need < iOS 26; existing working RIBs/TCA codebase; want a big ecosystem/community; want code-gen tooling; simple reader app (a plain SwiftUI app is fine — same honesty TCA's FAQ shows).
  - Decision table linking both compare pages; related links; validate + commit (`when-to-use-napkin`).

---

### Task 6: FAQ expansion

**Files:**
- Modify: `Tools/site/faq/index.html` (HTML sections + FAQPage JSON-LD `mainEntity`, keeping both in sync)

New Q&As (verbatim content; each also added as a `Question` in the JSON-LD):

1. **"Is RIBs dead?"** — No. Uber split the repos in October 2024 — `uber/RIBs` is the Android repo and `uber/RIBs-iOS` is the iOS repo, which released 1.1.0 on July 12, 2026 with async/await interop helpers on its RxSwift core. napkin exists because we wanted the same pattern *without* the RxSwift backbone, not because RIBs is abandoned. Link: /compare/napkin-vs-ribs/.
2. **"How is napkin different from The Composable Architecture (TCA)?"** — Different shapes: TCA structures an app as value-type State/Action/Reducer trees with a Store runtime; napkin structures it as a tree of screen/flow units with actor interactors and @MainActor routers/presenters. TCA runs on iOS 16+; napkin needs iOS 26+. Link: /compare/napkin-vs-tca/.
3. **"Should I use napkin for my app?"** — Short honest answer + link to /when-to-use-napkin/.

- [ ] Validate FAQPage JSON-LD still parses and question count grew by 3; then:

```bash
git add Tools/site/faq/index.html
git commit -m "feat: FAQ — RIBs status, TCA comparison, should-I-use-napkin

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: README comparison table + links

**Files:**
- Modify: `README.md` (new "How napkin compares" section after the intro paragraph)

```markdown
## How napkin compares

napkin is the Router-Interactor-Builder pattern rebuilt on Swift 6 concurrency. Honest
comparisons with the alternatives (facts as of July 2026):

|  | napkin | [RIBs-iOS](https://github.com/uber/RIBs-iOS) | [TCA](https://github.com/pointfreeco/swift-composable-architecture) |
|---|---|---|---|
| Shape | Tree of screen/flow units | Tree of screen/flow units | State/Action/Reducer/Store |
| Reactive layer | None — actors, `AsyncStream`, `async/await` | RxSwift 6.9 + RxRelay | Effects + Point-Free deps |
| Leak safety | Compile-time isolation | Runtime `LeakDetector` | N/A (value types) |
| Min platform | iOS 26 / macOS 26 | iOS 15 | iOS 16 |
| License | Apache-2.0 | Apache-2.0 | MIT |

Longer, cited write-ups: [napkin vs RIBs](https://getnapkin.to/compare/napkin-vs-ribs/) ·
[napkin vs TCA](https://getnapkin.to/compare/napkin-vs-tca/) ·
[when to use napkin](https://getnapkin.to/when-to-use-napkin/)
```

Also add the three links to the README's Table of Contents if it lists sections. Commit:

```bash
git add README.md
git commit -m "docs: README comparison table linking the cited compare pages

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: llms.txt + footer links + local assembly acceptance

**Files:**
- Modify: `Tools/site/llms.txt`, `Tools/site/index.html`

- [ ] Add to `llms.txt` under a new `## Compare` section (before `## Project`): the three new URLs with one-line descriptions.
- [ ] Landing footer: after the About link (Stage 1), add `<a class="link link--mono" href="/when-to-use-napkin/">When to use</a>` + separator.
- [ ] Re-run the Stage 1 local assembly (plan `2026-07-12-seo-stage1-technical-foundation.md` Task 10 Steps 1–2, extended with the Task 2 copy lines for compare/when-to-use) and assert additionally:

```bash
grep -q '<loc>https://getnapkin.to/compare/napkin-vs-ribs/</loc>' "$SITE/sitemap.xml"
grep -q '<loc>https://getnapkin.to/compare/napkin-vs-tca/</loc>' "$SITE/sitemap.xml"
grep -q '<loc>https://getnapkin.to/when-to-use-napkin/</loc>' "$SITE/sitemap.xml"
python3 Tools/site/tests/test_gen_sitemap.py && python3 Tools/site/tests/test_gen_robots.py
```

- [ ] Commit (`feat: wire compare pages into llms.txt, footer, and sitemap acceptance`).

---

### Task 9 (GATED — append before executing): `/compare/napkin-vs-viper/` + search-phrasing H2 tuning

Blocked on deep-research run `wf_f2e18013-f09`. When it completes: append the full task here with its verified fact inventory (VIPER canonical sources, quotable boilerplate critiques, component mapping, and the demand-evidence phrasing list), then execute in the same shape as Tasks 3–4 and revisit Tasks 3–5 H2s/titles only if the phrasing evidence argues for changes. If the research again yields nothing citable for VIPER, ship Stage 2 without the VIPER page and note it in the PR description — do not publish an uncited page.

### Task 10: Push + PR

```bash
git push -u origin seo/content
gh pr create --base develop --title "SEO stage 2: cited comparison pages, when-to-use guide, FAQ + README" --body "..."
```

PR body summarizes pages shipped, fact-verification method, the two refuted claims deliberately excluded, and whether Task 9 shipped or was held.

---

## Self-review notes

- Spec coverage: compare ×2 grounded now + 1 gated (spec's three), when-to-use ✓, FAQ ✓, README table ✓, sitemap/llms/nav wiring ✓. VIPER gating is explicit, not a placeholder.
- Name consistency: `dated_pages(root, section)` replaces `blog_posts` (Task 2 is the only consumer); `.compare-table`/`.compare-scroll` used in Tasks 3–5; footer link phrase "When to use".
- Honesty guardrails duplicated into Global Constraints so no task can drop them.
