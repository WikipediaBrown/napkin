# Streaming Follow-Ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox syntax.

**Goal:** Close out the review-queued follow-ups from PRs #150/#151: fix the leaking presenter shape in the published recipe, stop the CHANGELOG from recommending a compiler-crashing pattern, align older DocC articles with the new canonical spellings, lift the streaming section into a DocC article with producer rows in the migration table, and capture the simulator run recipe as a project skill.

**Architecture:** One branch (`docs/streaming-follow-ups`), docs + snippet + one project-skill file; no behavior changes anywhere. README code blocks stay token-mirrors of `Snippets/Streaming/*` shown regions (CI-compiled). Upstream context: the Observations crash is now swiftlang/swift#90370; repo issues #153/#154 track the framework-level items (NOT in this branch).

**Tech Stack:** Markdown/DocC, Swift snippet edit, `swift build`/`swift test`, `swift package generate-documentation`.

## Global Constraints

- README Swift blocks must remain token-for-token mirrors of the snippets' `// snippet.show` regions — edit the snippet first, mirror second.
- No framework `.swift` code changes; `Sources/napkin/Presenter.swift` doc-COMMENT edits only.
- The weak-presenter guidance everywhere is: store the presenter `weak` in the view (the presenter owns the VC that owns the view); read properties directly (`presenter?.x`); rebind locally with `@Bindable` inside `body` only when two-way bindings are needed.
- Commits: imperative subject + why + trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Cruft-clean before each commit: `find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf`
- Verify per task: `swift build && swift test` (Task 1 — it touches a compiled snippet) and `swift package generate-documentation --target napkin 2>&1 | tail -3` (Tasks 1–2; no new errors).

---

### Task 1: Corrections — weak presenter, CHANGELOG, DocC alignment

**Files:**
- Modify: `Snippets/Streaming/AuthStateStreaming.swift` (ProfileView block)
- Modify: `README.md` (mirror + two guidance sentences)
- Modify: `Sources/napkin/Presenter.swift` (doc comment example + one sentence)
- Modify: `Sources/napkin/napkin.docc/Articles/SwiftUIIntegration.md` (example + one sentence)
- Modify: `CHANGELOG.md` (2.0.0 migration step 4)
- Modify: `Sources/napkin/napkin.docc/Articles/Lifecycle.md`, `MigratingFromV0.md`, `HeadlessNapkins.md` (spelling alignment + Sendable)

- [ ] **Step 1: Snippet — weak presenter.** In `AuthStateStreaming.swift`, replace the `ProfileView` shown block with:

```swift
struct ProfileView: View {
    // Weak: the presenter owns the view controller, which owns this view —
    // a strong reference here would be a retain cycle. The interactor keeps
    // the presenter alive for the napkin's whole attached lifetime.
    weak var presenter: ProfilePresenter?

    var body: some View {
        Text(presenter?.greeting ?? "")
    }
}
```

Mirror the same block into README's "From the service to the screen" section, token-for-token.

- [ ] **Step 2: README guidance sentences.** (a) In the paragraph after that block ("The presenter *is* the view model…"), append: `Hold it weakly — the presenter owns the view controller that owns the view; rebind with `@Bindable` inside `body` when you need two-way bindings.` (b) In SwiftUI Integration's paragraph ending "…Re-annotate the subclass with `@Observable` so its stored properties are tracked.", change the earlier clause "let the view read the presenter via `@Bindable`" to "let the view hold the presenter `weak` and read its properties directly".

- [ ] **Step 3: Presenter.swift doc comment.** In the "Read it from SwiftUI" example (~line 112), change `@Bindable var presenter: HomePresenter` to `weak var presenter: HomePresenter?` and the body reads to optional (`presenter?.displayName ?? ""`; wrap the Button's listener call unchanged). Immediately before that example, add one doc line: `/// Hold the presenter weakly — it owns the view controller that owns the view. Rebind with `@Bindable` inside `body` for two-way bindings.` In the Overview's presenter-subclass bullet, append: `Re-annotate subclasses with `@Observable` so their own stored properties are tracked.`

- [ ] **Step 4: SwiftUIIntegration.md.** Find the `HomePresenter`/`@Bindable var presenter` example(s); apply the same weak-presenter change and, in the prose near line 10 ("``Presenter`` is `@Observable`, so SwiftUI sees mutations automatically"), append: `Subclasses re-annotate `@Observable` so their own stored properties are tracked too.`

- [ ] **Step 5: CHANGELOG step 4.** Replace the 2.0.0 migration guide's step 4 with:

```
4. Replace `cancellables` and Combine `.sink { … }` subscriptions with
   lifecycle-bound tasks inside `didBecomeActive`: `task { for await … in
   service.stream() { … } }` for service streams, or — for `@Observable`
   state — `task { @MainActor [weak self] in for await … in
   Observations({ … }) { … } }`. The observation loop must be bound to the
   actor that owns the state; iterating `Observations` directly inside the
   nonisolated `task {}` closure crashes the current Swift 6 compiler
   ([swiftlang/swift#90370](https://github.com/swiftlang/swift/issues/90370)).
   Tasks are auto-cancelled on `deactivate`.
```

- [ ] **Step 6: DocC alignment.** (a) `Lifecycle.md`, `MigratingFromV0.md`: every `userService.userStream` (parenless, in code or backticked prose) → `userService.userStream()`. (b) `HeadlessNapkins.md`: `self.eventBus.events` → `self.eventBus.events()` (and any parenless prose mention). (c) `MigratingFromV0.md` line ~30: `protocol HomeRouting: ViewableRouting {` → `protocol HomeRouting: ViewableRouting, Sendable {` — this is in the v2 "after" column/fence only; do not edit 0.x "before" code.

- [ ] **Step 7: Verify + commit.** `swift build && swift test` green; docs build green; README block diffed against snippet shown region (0 differences). Commit: `docs: weak-presenter recipe, CHANGELOG crash fix, DocC spelling alignment` + body (why: recipe taught the retain cycle #151 fixed in the app; CHANGELOG step 4 recommended the swiftlang/swift#90370 crash shape; canonical spellings are now methods) + trailer.

---

### Task 2: DocC article + migration-table producer rows

**Files:**
- Create: `Sources/napkin/napkin.docc/Articles/StreamingStateDownTheTree.md`
- Modify: `Sources/napkin/napkin.docc/napkin.md` (topics entry)
- Modify: `Tools/site/llms.txt` (article line)
- Modify: `Sources/napkin/napkin.docc/Articles/MigratingFromV0.md` (two table rows)
- Modify: `README.md` (closing links of the streaming section gain the article URL)

- [ ] **Step 1: Author the article** as a DocC lift of README's "Streaming State Down the Tree" section (the README section is the content source of truth — same recipes, same code blocks copied from the snippets' shown regions, same mapping table). Adaptations for DocC: an abstract line under the title; `<details>` blocks become plain subsections titled "The 0.x version this replaces"; in-page README anchors become `<doc:…>` links (`<doc:MigratingFromV0>`, `<doc:Lifecycle>`, `<doc:CrossIsolationPatterns>`, `<doc:SwiftUIIntegration>`); symbol mentions use ``double-backtick`` symbol links where they resolve (``InteractorScope/isActiveStream``, ``Interactable/task(priority:_:)``). Check one existing article (e.g. `MigratingFromV0.md`) for house style and follow it. Mention that every code block is compiled from `Snippets/Streaming/` by `swift build`.
- [ ] **Step 2: Register it.** Add `- <doc:StreamingStateDownTheTree>` to the appropriate topic group in `napkin.md` (alongside MigratingFromV0/Lifecycle); add a matching line to `Tools/site/llms.txt` following its exact format (`https://getnapkin.to/documentation/napkin/streamingstatedownthetree`: one-line description).
- [ ] **Step 3: Producer rows.** In `MigratingFromV0.md`'s "Diff, line by line" table, append two rows: `CurrentValueSubject` on a service → an `actor` service vending replay-latest `AsyncStream`s (fresh stream per subscriber) — "Producer recipes in <doc:StreamingStateDownTheTree>."; `PassthroughSubject` → the same fan-out actor minus the initial yield — "No replay.". Match the table's column structure exactly.
- [ ] **Step 4: README pointer.** In README's streaming-section closing paragraph (the one linking migratingfromv0/lifecycle/crossisolationpatterns), add the article as the primary link: `This section also lives as a DocC article: [Streaming State Down the Tree](https://getnapkin.to/documentation/napkin/streamingstatedownthetree).`
- [ ] **Step 5: Verify + commit.** Docs build green (`swift package generate-documentation --target napkin`) with the new article included and `<doc:…>` links resolving (no new warnings mentioning StreamingStateDownTheTree). Commit: `docs: DocC article for Streaming State Down the Tree + producer rows` + trailer.

---

### Task 3: run-ribhouse project skill

**Files:**
- Create: `.claude/skills/run-ribhouse/SKILL.md`

Content will be finalized under superpowers:writing-skills guidance at dispatch time; the verified recipe it must capture (from the 2026-07-02 session): find the iPhone 17 UDID (`xcrun simctl list devices available`), boot + `open -a Simulator`, `xcodebuild … -derivedDataPath <scratch> build`, `simctl install`/`simctl launch <UDID> com.napkin.example.RibHouse -fastTicks`, screenshot via `simctl io <UDID> screenshot`, and drive interactions by running the UI tests (`-only-testing:RibHouseUITests/…`) with a parallel screenshot loop — `simctl` cannot tap. Commit: `chore: project skill for running RibHouse on the simulator` + trailer.

---

### Task 4: Verify, PR, release

- [ ] `swift build && swift test` green; docs build green; `git diff c7bab25..HEAD --stat -- Sources/napkin` shows only `Presenter.swift` (doc comments) + `napkin.docc` files.
- [ ] Push, `gh pr create --base develop` (summary: the four follow-up groups + links to #153/#154/swiftlang#90370), merge to develop, then develop→main release PR (docs must reach the website), merge, confirm Release + Documentation workflows.
