# RibHouse Streaming: Scrillionaire-Style Complexity in the Example App

- **Date:** 2026-07-02
- **Status:** Approved in conversation (design presented in five sections; user replied "approved"). Awaiting spec-file review.
- **Branch:** `feat/ribhouse-streaming` (off `develop` after PR #150 merged — user chose merge-first)

## Problem

RibHouse currently demonstrates zero streaming: `AuthService` is one-shot request/response, auth "state" flows up via listener callbacks and down via a build-time `User` snapshot, and nothing in the app exercises the recipes PR #150 added to the README ("Streaming State Down the Tree"). Users coming from Combine-era apps shaped like the Scrillionaire reference (subject-fed managers, root auth gate, multi-stream screens, KVO pipes) have no runnable example of the 2.x equivalents.

## Decisions already made (user-answered)

1. **Hybrid approach**: convert the auth gate to stream-driven (README spine, live) AND add new streaming napkins post-login. The tutorial's gate sections (~4 code fences + the flow diagram) get updated; the rest of the tutorial stays valid.
2. **All four patterns ship**: fan-out to two subscribers, pushed PitBoard napkin (four-seam vertical + `didMove` dismissal), event bus (last call), `@Observable` specials service.
3. **Branch base**: `develop` post-#150 (merged as c7bab25).

## Constraints

- Follow AGENTS.md exactly: one napkin per folder under `Examples/RibHouse/Sources/`, `<Napkin><Type>.swift` naming, the two listener protocols (`…PresentableListener` view→interactor; `…Listener` child→parent, methods named `<self>NapkinDid<verb>`), `dispatch {}` never bare `Task {}`, interactors are `final actor` + `nonisolated let lifecycle`, routers/VCs `@MainActor`.
- `xcodegen` regenerates the tracked `.xcodeproj` (new folders added).
- Snapshot reference PNGs double as README screenshots — visible changes to LoggedIn require re-recording and swapping the README images (`Sources/napkin/napkin.docc/Resources/rib-house-*.png`).
- No framework (`Sources/napkin`) code changes.
- Simulated streams must be deterministic enough for CI: injectable tick interval; snapshot tests render views from fixed state, never live services.

## Design

### 1. Domain: the live pit

**`PitService`** (new, `Sources/Shared/PitService.swift`) — an `actor` simulating a smoker, mirroring the README's broadcaster recipe:

```swift
struct PitItem: Sendable, Equatable, Identifiable {
    enum Stage: Int, Sendable, CaseIterable { case lighting, smoking, resting, served }
    let id: String        // stable, e.g. "brisket"
    let name: String      // "Brisket"
    var stage: Stage
}

enum PitEvent: Sendable, Equatable {
    case lastCall(itemName: String)
}

actor PitService {
    private(set) var items: [PitItem]          // seeded, fixed order
    func updates() -> AsyncStream<[PitItem]>   // replay-latest, fresh stream per subscriber
    func events() -> AsyncStream<PitEvent>     // no replay, fresh stream per subscriber
    func start()                               // begins ticking; idempotent
    init(tickSeconds: Double = 4)
}
```

Both stream methods use the per-subscriber-continuation table from the README recipe (`AsyncStream.makeStream`, yield-current-on-subscribe only for `updates()`, `onTermination` cleanup). The tick loop advances one item's stage per tick in a fixed rotation; an item entering `.resting` emits `.lastCall(itemName:)` on the events stream. When all items are `.served`, the pit reseeds and starts over (endless demo). `start()` is called from `LoggedInNapkinInteractor.didBecomeActive` — the pit runs only while someone is logged in.

**`SpecialsService`** (new, `Sources/Shared/SpecialsService.swift`) — the `@Observable` recipe:

```swift
struct Special: Sendable, Equatable, Identifiable { let id: String; let name: String }

@MainActor @Observable
final class SpecialsService {
    private(set) var specials: [Special]       // seeded
    func start()                               // rotates the list on a MainActor Task; idempotent
    init(rotationSeconds: Double = 6)
}
```

**Determinism hook**: `AppComponent` reads a `-fastTicks` launch argument (UI tests) to shrink both intervals (e.g. 0.5s); default intervals keep the demo watchable.

### 2. Stream-driven auth gate

`AuthService` protocol gains the stream; `BarbecueAuthService` becomes an actor broadcaster (same recipe):

```swift
protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
    func userStream() async -> AsyncStream<User?>
}
```

`LaunchNapkinInteractor`:
- `didBecomeActive()` spawns the gate: `task { for await user in await self.authService.userStream() { user == nil → attachLoggedOut, else attachLoggedIn(user:) } }`. The stream's replay of the initial `nil` replaces today's explicit `attachLoggedOut()` call.
- `loggedOutDidTapLogin()` becomes intent-only: `try await authService.login()`, catch keeps the comment that failures stay on the logged-out screen. **No routing in the tap path** — routing happens because state changed.
- `loggedInDidTapLogout()` likewise: `try await authService.logout()` only.

`LaunchNapkinRouter.attachLoggedIn/attachLoggedOut` keep their existing idempotence guards and detach-the-other behavior; they are now driven by the gate loop instead of the tap handlers. No visual change to either screen from this section alone.

### 3. LoggedInNapkin becomes the streaming hub

- **Navigation**: `LoggedInNapkinViewControllable` is now implemented by a `UINavigationController` owned by the LoggedIn napkin (Scrillionaire-`RootViewController`-style): the existing `LoggedInNapkinViewController` (hosting controller) becomes the nav's root; `LaunchNapkin`'s embed logic is untouched (it embeds the nav). The feature's `ViewControllable` gains `push`/`pop` affordances for the router. Nav bar hidden on the root screen to preserve the current look (minus the additions below).
- **Fan-out subscriber #1**: the interactor task-subscribes `pitService.updates()`, reduces each snapshot to a summary line (e.g. `"3 smoking · 1 resting"` — counts by stage; the mid-pipeline transform lives in the loop body), and forwards via the existing VC-as-presentable pattern: `func present(pitSummary: String) async` mutating `rootView`. LoggedIn deliberately keeps the **no-Presenter-class** style so the app shows both presentable styles (PitBoard uses the `Presenter` subclass).
- **Pit Board entry**: a "PIT BOARD" button (accessibility-identified) → `didTapPitBoard()` → listener → interactor → `router.attachPitBoard()` (build, attachChild, push).
- **Headless child**: router attaches `AnnouncementsNapkin` in `didLoad()` (viewless attach pattern). Its events surface as a banner: `announcementsNapkinDidHearLastCall(itemName:)` on the LoggedIn interactor → `present(banner: String?) async` → SwiftUI overlay on the LoggedIn view; the banner auto-clears after a few seconds via a lifecycle-bound `task` (or is replaced by the next event).
- **View updates**: status line + button + banner overlay added to `LoggedInNapkinView`; the LoggedIn snapshot is re-recorded and the README image swapped.

### 4. PitBoardNapkin — the four-seam vertical, pushed

New folder `Sources/PitBoardNapkin/` (Builder, Interactor, Router, View, HostingViewController + Presenter):

- **Interactor** (`final actor`): two lifecycle-bound subscriptions in `didBecomeActive()`:
  - `task { for await items in await self.pitService.updates() { … } }` (**fan-out subscriber #2** — multicast proven live): groups items by stage into ordered sections (the `.map`-in-loop-body transform), then `await presenter.present(sections:)`.
  - `task { @MainActor [weak self] in for await specials in Observations({ specialsService.specials }) { await self?.handle(specials:) } }` — the crash-avoiding shape from the README, with the service hoisted to a local `let`.
- **Presenter**: `@MainActor @Observable final class PitBoardNapkinPresenter: Presenter<PitBoardNapkinViewController>, PitBoardNapkinPresentable` with stored `sections` and `specials`. Mutations that reorder the board are wrapped in `withAnimation` (the animation note from the README, live). Construction order (the acyclic order README documents): builder creates the hosting VC first (root view with no presenter yet), then `PitBoardNapkinPresenter(viewController:)`, then hands the presenter to the VC, which assigns `rootView = PitBoardNapkinView(presenter:listener:)`.
- **View**: `List`/`ForEach` sections per stage with `.transition` + identifiers `pitBoard.item.<id>`; a "Specials" section fed from the presenter.
- **Dismissal — the KVO replacement, live**: the hosting VC overrides `didMove(toParent:)`; on `parent == nil` (UIKit back button popped it) it calls `dispatch { [listener] in await listener?.didDismiss() }` → interactor → `pitBoardNapkinDidDismiss()` up to LoggedIn → LoggedIn's router detaches the child (logical tree closed after the visual pop). Programmatic pop is not needed; back button is the only exit.

### 5. DI plumbing

`AppComponent` gains stored `let pitService: PitService` and `let specialsService: SpecialsService` (current stored-`let` style), constructed with intervals derived from launch arguments. Forwarding computed properties thread them: `LaunchNapkinComponent` → `LoggedInNapkinDependency` → `LoggedInNapkinComponent` → `PitBoardNapkinDependency` / `AnnouncementsNapkinDependency`. All services are `Sendable` by construction (actors / `@MainActor`).

### 6. Testing & verification

- **Snapshot tests**: new `PitBoardNapkinViewSnapshotTests` rendering the view from a fixed presenter state (mid-smoke board + specials); re-recorded `LoggedInNapkinViewSnapshotTests` (status line + button, no banner). Reference PNGs copied into `Sources/napkin/napkin.docc/Resources/` where they replace the README images.
- **UI tests** (with `-fastTicks`): login → status line appears; tap Pit Board → grouped item identifiers exist; back → re-push works (proves the logical tree was detached cleanly); logout returns to LoggedOut. A last-call banner assertion is included only if it proves stable under `-fastTicks`; otherwise the banner is covered by the snapshot of the overlay state and the UI test skips it (flaky-test risk accepted explicitly).
- **Determinism rule**: no test may depend on wall-clock stage progression beyond "changed at least once under fast ticks."
- **Full verification**: `swift build && swift test` (framework untouched, must stay green), `cd Examples/RibHouse && xcodegen && xcodebuild -project RibHouse.xcodeproj -scheme RibHouse -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test` per AGENTS.md.

### 7. Documentation updates (scoped)

- **Tutorial** (`TutorialBuildingALoginFlow.md`): only the gate-related fences (~4) and the tap→login flow diagram — rewritten to the stream-driven narrative ("the gate reacts to state, not taps"). New napkins are NOT added to the tutorial.
- **README**: the "Runnable example app" section gains a sentence + updated screenshots noting the app now exercises the Streaming State Down the Tree recipes (auth gate, fan-out, events, `@Observable`).
- Non-goals: framework changes; a DocC streaming article (queued follow-up from #150); MigratingFromV0/CHANGELOG updates (same follow-up list); no new unit-test target for RibHouse.

## Error handling

- `login()`/`logout()` failures stay at the call site (existing behavior/comment preserved); the user stream never terminates on error.
- `PitService`/`SpecialsService` simulations cannot fail; their streams carry no failure type.
- Banner display is best-effort UI; no error path.

## Open questions deliberately left to the plan

- Exact `LoggedInNapkinViewControllable` push/pop method shapes.
- Banner auto-clear duration and whether the UI test asserts it.
- Whether `PitService.start()` needs a `stop()` on logout (lean: yes — LoggedIn's `willResignActive` stops the tick so the pit pauses while logged out; streams stay alive).
