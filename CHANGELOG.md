# Changelog

All notable changes to napkin are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `AGENTS.md` at the repo root — conventions for AI coding agents working
  in the codebase (napkin folder layout, isolation patterns, listener
  protocols, `dispatch { }` vs `Task { }`, file naming, iCloud-Drive
  artifact warning).
- `getnapkin.to/llms.txt` and `/llms-full.txt` — emerging conventions for
  LLM-readable site maps. The full variant is generated at deploy time
  from the DocC `.md` files so it stays in sync with the catalog.
- `Sources/napkin/napkin.docc/Articles/TutorialBuildingALoginFlow.md` —
  guided walkthrough of the runnable example app (Napkin's Rib House)
  through the napkin pattern, end to end. Uses `@TabNavigator`,
  `@Row`/`@Column`, asides, and `@Links(visualStyle: detailedGrid)`.
- "Step 7: Snapshot testing the views" section in the tutorial — covers
  declaring the package, target wiring, record-then-verify workflow, and
  the two ways to opt into re-record mode.
- `Examples/RibHouse/SnapshotTests/` — Point-Free
  [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  target. Reference PNGs under `__Snapshots__/` pin each view's
  appearance. The same PNGs are committed to
  `Sources/napkin/napkin.docc/Resources/` and `Tools/site/` so the
  tutorial and homepage display the exact images CI compares against.
- New "§ 04 · See it in motion" section on the homepage — auto-cycling
  4-step tutorial: iPhone-framed snapshot fades between LoggedOut and
  LoggedIn while code blocks stagger their lines in like an editor
  typing them out. Pure CSS animation + ~30 lines of vanilla JS;
  `prefers-reduced-motion` stacks the four steps statically.

### Changed

- `Examples/LaunchNapkinApp` renamed to `Examples/RibHouse` ("Napkin's
  Rib House") with a barbecue-themed `AuthService` mock. Display name
  is `Napkin's Rib House`; bundle ID is `com.napkin.example.RibHouse`.
- The example app's source tree is now organized one-napkin-per-folder
  (`App/`, `Shared/`, `LaunchNapkin/`, `LoggedOutNapkin/`,
  `LoggedInNapkin/`). UI test file renamed to `RibHouseUITests.swift`.
- The example app's `.xcodeproj` is now **tracked in source control** —
  the project opens via `open Examples/RibHouse/RibHouse.xcodeproj`
  without an XcodeGen step. `.gitignore` un-ignores the project
  explicitly while still ignoring user state.
- Example app architecture pivoted from the prior Counter + Quote demo
  to a login/logout flow that exercises service injection: a headless
  `LaunchNapkin` holds an `AuthService` (declared in the dependency
  protocol) and swaps a `LoggedOutNapkin` (single Login button) for
  a `LoggedInNapkin` (user name + barbecue food list) on tap. The
  `User` object flows through the full
  interactor → router → builder → child router chain.
- LoggedOut and LoggedIn views restyled with editorial vocabulary
  matching the marketing site — kicker (`§ 00 · WELCOME`),
  serif-italic headlines, hairline rules, spec-list pattern for the
  foods, ink + ghost buttons. Palette tokens in `Shared/Palette.swift`
  are derived from the site's OKLCH design tokens.
- `Sources/napkin/napkin.docc/theme-settings.json` link + intro-accent
  colors flipped from blue to moss-green so the docs and homepage
  read as the same design system.
- `social-preview.svg` now has `role="img"` + `<title>` + `<desc>` +
  `aria-labelledby` so screen readers reading the inline SVG get the
  same description as sighted users.
- `Gemfile.lock`: `activesupport` 8.1.2 → 8.1.3 (clears 3 moderate
  Dependabot alerts on Rails CVEs in `number_to_delimited`,
  `SafeBuffer#%`, and number helpers — fastlane transitive dep).
- `.github/workflows/Documentation.yml`: `actions/checkout` uses
  shallow + tags + explicit `ref: main`, fixing the APFS case-collision
  that masked deploys when `ci/...` namespaced branches existed
  alongside the stale `CI` branch.
- `.github/workflows/Release.yml`: narrows `remote.origin.fetch` to
  `main` before fastlane's `git_pull(only_tags: true)` to avoid the
  same case-collision.
- `.github/workflows/CodeQL.yml`: switched from `autobuild` to manual
  `swift build` after autobuild repeatedly tripped on a stale SPM
  cache reference to `swift-docc-plugin`.
- `CONTRIBUTING.md` paths updated for the RibHouse rename and the
  tracked-xcodeproj workflow (xcodegen is now optional).

### Removed

- `Examples/LaunchNapkinApp/` (renamed; see Changed).
- The "Counter" and "Quote" child napkins from the example app
  (replaced by LoggedOut and LoggedIn).
- Stale local-only `Sources/napkin/PresentableInteractor.swift` orphan
  — a pre-rearchitecture class-based interactor that referenced types
  removed in 2.0.0. Was untracked but present in iCloud-synced clones.
- The original `CI`, `Adding-Templates`, `Fastlane`, `TemplateFix`, and
  `swift-concurrency-rearchitecture` branches on origin (stale, all
  predate the v2 rearchitecture).

### Infrastructure

- Migrated public site to a custom domain: **https://getnapkin.to/**.
  Apex A records target GitHub Pages' anycast IPs; `www.getnapkin.to`
  CNAMEs to `wikipediabrown.github.io`; HTTPS enforced; cert covers
  both apex and `www`. `wikipediabrown.github.io/napkin/` 301s to the
  custom domain.
- Enabled GitHub Sponsors button via `.github/FUNDING.yml`.
- Enabled repository security analysis: secret scanning, push
  protection, Dependabot security updates, and private vulnerability
  reporting.
- Added branch protection on `main` and `develop` (block force-push
  and deletions; regular pushes still allowed).
- Repo About panel: homepage URL now `https://getnapkin.to/`;
  obsolete `combine` topic dropped; `swift-6` and
  `structured-concurrency` topics added.
- New CI workflow `.github/workflows/CodeQL.yml` runs weekly + on
  push/PR for Swift static analysis on the `macos-26` runner.

## [2.0.8]

### Changed

- Homepage footer reflows onto two lines: framework attribution on the first
  line, copyright + license on the second. The version is now a single
  hyperlink to the GitHub release page; the duplicate "view release on
  GitHub" link has been dropped.

## [2.0.7]

### Added

- `Tools/site/` — version stamping mechanism. The Documentation workflow
  resolves the latest git tag via `git describe --tags --abbrev=0` and
  substitutes `__NAPKIN_VERSION__` placeholders in `index.html` at deploy
  time so the footer always reflects the currently-shipping release.

### Changed

- Homepage footer rewritten with framework attribution, copyright, license
  link, and "view release" link. Replaces the placeholder footer shipped
  in 2.0.6.
- `Examples/LaunchNapkinApp/` consolidated: the app shell
  (`AppDelegate`/`SceneDelegate`/`Info.plist`) and the napkin
  implementations (`Launch`/`Counter`/`Quote`) now live side by side in
  `Sources/` rather than in separate sub-trees. Build product paths in
  `project.yml` updated accordingly.

## [2.0.6]

### Added

- `Tools/site/index.html`, `styles.css`, `napkin-icon*.png` — hand-crafted
  homepage that replaces DocC's missing root `index.html` with a real
  landing page (nav bar, hero, feature grid, footer). The Documentation
  workflow copies this into `./docs/` after the DocC build.
- `Sources/napkin/napkin.docc/header.html` — top-nav injected into every
  DocC page via `--experimental-enable-custom-templates`, so symbol and
  article pages share the homepage's navigation chrome.

## [2.0.5]

### Changed

- Replaced the ASCII-art isolation map in `IsolationModel.md` with a
  hand-drawn SVG diagram. Ships a light variant and a dark variant; DocC
  selects the appropriate one based on the reader's color scheme.

## [2.0.4]

### Added

- Hero metadata on the `napkin.md` landing page (`@PageImage`, `@CallToAction`,
  `@Available` directives) so the docs root renders with a hero card on the
  modern DocC renderer.
- `theme-settings.json` enabling DocC's `quickNavigation` (cmd-K
  fuzzy-search across symbols) and pinning the accent color to the
  napkin blue palette.

### Changed

- Two article pages (`IsolationModel.md`, `WorkingWithCombine.md`) use
  `@Row` / `@Column` for side-by-side before/after code snippets.
- `DefiningAFeature.md` adopts `@Snippet(path:)` for the five major
  Profile code blocks instead of inlining the Swift source.

## [2.0.3]

### Changed

- Corrected the etymology of the name "napkin" in the `GettingStarted`
  article — the framework is named after the noun "napkin" (as in
  back-of-the-napkin sketches of a feature's architecture), not a verb.

## [2.0.2]

### Added

- `.github/workflows/Documentation.yml` — builds the DocC catalog with
  `swift package generate-documentation` and deploys the static site to
  GitHub Pages via `actions/deploy-pages`. Site is live at
  `https://wikipediabrown.github.io/napkin/documentation/napkin/`.

## [2.0.1]

### Added

- `Sources/napkin/napkin.docc/` — DocC catalog with a landing page
  (`napkin.md`) and seven articles in `Articles/`: GettingStarted,
  DefiningAFeature, IsolationModel, RouterTree, ComponentsAndScopes,
  TestingAsyncFeatures, WorkingWithCombine.
- Comprehensive inline DocC comments on every public type and method
  in `Sources/napkin/`.

## [2.0.0]

Major rearchitecture: native Swift 6.2 concurrency, Combine removed.

This release breaks every public API surface and raises the deployment floor
to iOS 26 / macOS 26. There is no incremental migration path; consumers
re-adopt against the new shape.

### Added

- `Interactable` protocol — feature interactors are now `final actor` types
  conforming to it instead of subclasses of an `Interactor` base class. Swift
  actors cannot be subclassed (SE-0306); protocol composition replaces
  inheritance.
- `InteractorLifecycle` helper — single `final class @unchecked Sendable` that
  holds mutex-protected lifecycle state. Each `Interactable` declares
  `nonisolated let lifecycle = InteractorLifecycle()`. Default protocol
  extensions delegate `activate` / `deactivate` / `task(_:)` / `isActive` /
  `isActiveStream` to it.
- `PresentableInteractable` protocol — refines `Interactable` and adds a
  `nonisolated var presenter: PresenterType { get }` requirement. Replaces
  the old `PresentableInteractor<PresenterType>` base class.
- `Interactor.task(_:)` helper — spawns a `Task` whose lifetime is bound to
  the active scope (cancelled automatically in `deactivate()`). Napkin's
  analog of upstream RIBs's `disposeOnDeactivate`.
- `dispatch(_:)` helper — `@MainActor` function for forwarding async work
  from synchronous view callbacks (SwiftUI button handlers, UIKit `@objc`
  actions) into a `Task`.
- `Examples/LaunchNapkinApp` — minimal runnable iOS app generated by
  XcodeGen. Verified working on iPhone 17 / iOS 26.4.1 simulator.
- `isolated deinit` on `Router` (Swift 6.2 / iOS 26) — synchronous teardown
  on the main actor's executor without `Task.detached` workarounds.

### Changed

- **Deployment floor:** iOS 13.0+ / macOS 10.15+ → iOS 26.0+ / macOS 26.0+.
- **`Router`, `ViewableRouter`, `LaunchRouter`, `Routing`:** all
  `@MainActor`-isolated. `attachChild` / `detachChild` / `load` / `loaded` /
  `launch` are now `async`.
- **`loaded() async`** on `Router` replaces the
  `lifecycle: AnyPublisher<RouterLifecycle, Never>` Combine publisher. The
  `RouterLifecycle` enum has been removed.
- **`Presenter`:** `@MainActor @Observable open class`. Subclasses' stored
  properties are observable to SwiftUI views via `@Bindable` and to UIKit
  views via `Observations { presenter.foo }`. The `Presentable` protocol is
  `@MainActor`.
- **`Component`:** `Synchronization.Mutex` replaces `NSRecursiveLock` for
  shared-instance storage. `Component` and `EmptyComponent` are
  `@unchecked Sendable`.
- **`Builder`, `ComponentizedBuilder`, `MultiStageComponentizedBuilder`,
  `Buildable`:** `Sendable`. Concrete `build(...)` overloads should be
  `async @MainActor` when they construct a view controller.
- **`Listener` / `Routing` / `Presentable` protocol methods are `async`** —
  every cross-isolation call (interactor → router, interactor → presenter,
  parent's listener) goes through an explicit `await`.
- **`Dependency` protocol** is now `Sendable`.
- **Xcode templates** rewritten to emit code matching the new API — `final
  actor` interactors, `@MainActor` routers, async listener/presentable
  protocols, the `lifecycle` declaration.

### Removed

- All Combine usage. No `import Combine` in the framework, tests, examples,
  or templates.
- `Interactor` open class. Replaced by `Interactable` protocol +
  `InteractorLifecycle` helper.
- `PresentableInteractor<P>` open class. Replaced by `PresentableInteractable`
  protocol.
- `RouterLifecycle` enum, `RouterScope.lifecycle` publisher,
  `InteractorScope.isActiveStream` (Combine variant). The `isActiveStream`
  getter still exists but now returns `AsyncStream<Bool>`.
- The recursive `bindSubtreeActiveState` cascade in `Router`. Activation now
  flows explicitly through `attachChild` / `detachChild`.

### Migration guide

For each feature:

1. Replace `final class HomeInteractor: PresentableInteractor<HomePresentable>` with
   `final actor HomeInteractor: PresentableInteractable`.
2. Add `nonisolated let lifecycle = InteractorLifecycle()` and
   `nonisolated let presenter: HomePresentable` as stored properties; remove the
   `super.init(presenter:)` call.
3. Drop `override` keyword from `didBecomeActive` / `willResignActive` (they're
   protocol default implementations now, not class overrides). Mark them `async`.
4. Replace `cancellables` and Combine `.sink { … }` subscriptions with
   `task { for await … in Observations { … } }` inside `didBecomeActive`. The
   task is auto-cancelled on `deactivate`.
5. Mark routing protocol methods `async`. Remove every `Task { @MainActor in }`
   wrapper from routing method bodies — routers are already `@MainActor`.
6. Mark listener and presentable protocol methods `async`. Conform listener
   protocols to `Sendable`.
7. SwiftUI views: replace `@ObservedObject var viewModel: HomeViewModel` with
   `@Bindable var presenter: HomePresenter`. Replace event handlers with
   `dispatch { await listener?.didTapX() }`.
8. `Builder.build(...)` becomes `async @MainActor` when it constructs a view
   controller.

See `Examples/LaunchNapkinApp` and the rewritten `README.md` for working
reference code.

### Divergence from upstream Uber RIBs-iOS

Uber's `RIBs-iOS` PR #49 unifies the framework on `@MainActor` (Interactor
included). napkin deliberately keeps Interactors off the main actor so business
logic is not pinned to the main thread. The cost is an explicit `await` at
every cross-layer call; the benefit is enforced clean-architecture isolation
of business logic.

## [0.0.18] and earlier

See [GitHub Releases](https://github.com/WikipediaBrown/napkin/releases) for
prior changelog entries (auto-generated from git history).
