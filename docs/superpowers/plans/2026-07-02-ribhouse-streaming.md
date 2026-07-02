# RibHouse Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the RibHouse example app demonstrate all four "Streaming State Down the Tree" README recipes live: a stream-driven auth gate, a PitService fan-out to two subscribers, a pushed PitBoard napkin (four-seam vertical + `didMove` dismissal), a last-call event bus, and an `@Observable` specials service.

**Architecture:** Hybrid per the approved spec (`docs/superpowers/specs/2026-07-02-ribhouse-streaming-design.md`): `AuthService` becomes an actor broadcaster and `LaunchNapkinInteractor` routes from its stream; `LoggedInNapkin` becomes a nav-owning hub subscribing to `PitService.updates()` and hosting a headless `AnnouncementsNapkin`; a new `PitBoardNapkin` is pushed onto LoggedIn's navigation stack. Tutorial changes are confined to the gate fences; snapshots are re-recorded per task so every task ends green.

**Tech Stack:** Swift 6.2, napkin 2.x (`Interactable`, `task {}`, `Presenter`, `dispatch {}`), SwiftUI + `UIHostingController`, `UINavigationController`, swift-snapshot-testing, XCUITest, xcodegen.

## Global Constraints

- Test command (AGENTS.md, use for every task's verification): `cd /Users/nonplus/Desktop/napkin/Examples/RibHouse && xcodebuild -project RibHouse.xcodeproj -scheme RibHouse -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test`. Expect **TEST SUCCEEDED**. It is slow (minutes) — run it once per task, not per edit. For intermediate compile checks use `… build` instead of `… test`.
- Run `xcodegen` (from `Examples/RibHouse/`) ONLY in tasks that add a new top-level folder under `Sources/` (Tasks 4 and 5). New files inside existing folders are picked up without it. Commit the regenerated `.xcodeproj` changes with the task.
- Framework code (`Sources/napkin/`) must not change. `swift build && swift test` at repo root must stay green (checked in Task 7).
- File naming: `<Napkin><Type>.swift`, one napkin per folder. Two listener protocols per convention: `…PresentableListener` (view→interactor, `didTapX()` names) lives in the hosting VC file; `…Listener` (child→parent, `<self>NapkinDid<verb>()` names) lives in the interactor file.
- View→interactor always via `dispatch { [listener] in await listener?.… }`, never bare `Task {}`.
- Hosting view controllers keep the repo's dual-platform guards (`#if canImport(UIKit)` / `#elseif canImport(AppKit)`) exactly like the existing `LoggedInNapkinHostingViewController.swift`, EXCEPT UIKit-only navigation/`didMove` types which are `#if canImport(UIKit)` with no AppKit branch (the project is iOS-only; the guard just preserves convention).
- Accessibility identifiers only via `Sources/Shared/AccessibilityIdentifiers.swift` constants.
- Snapshot procedure when a view changes: delete the stale reference PNG, run the snapshot suite once (it records new references and FAILS with "re-run to assert"), run again (PASSES), commit the PNGs. Never commit after the recording run without the verifying run.
- Determinism: `PitService` seeds exactly 2 `.smoking` + 1 `.resting` items so the initial summary is `"2 SMOKING · 1 RESTING"`; tests may rely on that initial state and on "changes at least once under `-fastTicks`", never on specific later states.
- Commits: imperative subject, body explains why, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Before every commit: `find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf`
- Compile-verified facts — do not "improve" these away: broadcaster actors with per-subscriber continuation tables are the sanctioned pattern (mirrors `Snippets/Streaming/AuthStateStreaming.swift`); `Observations` iterated from a nonisolated `task {}` closure crashes the compiler — the loop must be `task { @MainActor [weak self] in … }` with the service hoisted to a local `let`; `Presenter` subclasses re-annotate `@Observable`; `Presenter`'s generic argument must be a concrete VC class.
- `SpecialsService` (a `@MainActor` class) is constructed by the nonisolated `AppComponent.init` — its `init` must be `nonisolated`. If the compiler rejects assigning its stored properties there, fall back to constructing it lazily on first use from a `@MainActor` context and report the deviation.

---

### Task 1: Shared services — PitService, SpecialsService, AppComponent wiring

**Files:**
- Create: `Examples/RibHouse/Sources/Shared/PitService.swift`
- Create: `Examples/RibHouse/Sources/Shared/SpecialsService.swift`
- Modify: `Examples/RibHouse/Sources/App/SceneDelegate.swift` (AppComponent only)

**Interfaces:**
- Consumes: nothing new.
- Produces (later tasks rely on these exact names): `struct PitItem { id: String; name: String; var stage: Stage }` with `Stage: Int, CaseIterable, Comparable` cases `lighting, smoking, resting, served` and `var label: String`; `enum PitEvent { case lastCall(itemName: String) }`; `actor PitService` with `init(tickSeconds: Double = 4)`, `private(set) var items: [PitItem]`, `func updates() -> AsyncStream<[PitItem]>`, `func events() -> AsyncStream<PitEvent>`, `func start()`, `func stop()`; `struct Special: Sendable, Equatable, Identifiable { id, name: String }`; `@MainActor @Observable final class SpecialsService` with `nonisolated init(rotationSeconds: Double = 6)`, `private(set) var specials: [Special]`, `func start()`, `func stop()`; `AppComponent.pitService` / `AppComponent.specialsService` stored `let`s; `-fastTicks` launch argument shrinking intervals to 0.5s / 0.75s.

- [ ] **Step 1: Create PitService.swift**

```swift
import Foundation

struct PitItem: Sendable, Equatable, Identifiable {
    enum Stage: Int, Sendable, CaseIterable, Comparable {
        case lighting, smoking, resting, served

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .lighting: "Lighting"
            case .smoking: "Smoking"
            case .resting: "Resting"
            case .served: "Served"
            }
        }
    }

    let id: String
    let name: String
    var stage: Stage
}

enum PitEvent: Sendable, Equatable {
    case lastCall(itemName: String)
}

// The live smoker. Streams follow the "Streaming State Down the Tree"
// recipes from the napkin README: `updates()` replays the current board to
// each new subscriber (the CurrentValueSubject replacement); `events()` has
// no replay (the PassthroughSubject replacement). Every call vends a fresh
// stream — AsyncStream is single-consumer, so that is what makes fan-out
// to the LoggedIn header AND the PitBoard safe.
actor PitService {

    private(set) var items: [PitItem]

    private var updateSubscribers: [UUID: AsyncStream<[PitItem]>.Continuation] = [:]
    private var eventSubscribers: [UUID: AsyncStream<PitEvent>.Continuation] = [:]
    private var ticker: Task<Void, Never>?
    private let tickSeconds: Double

    init(tickSeconds: Double = 4) {
        self.tickSeconds = tickSeconds
        self.items = Self.seededItems()
    }

    func updates() -> AsyncStream<[PitItem]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [PitItem].self)
        let id = UUID()
        updateSubscribers[id] = continuation
        continuation.yield(items)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeUpdateSubscriber(id) }
        }
        return stream
    }

    func events() -> AsyncStream<PitEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: PitEvent.self)
        let id = UUID()
        eventSubscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeEventSubscriber(id) }
        }
        return stream
    }

    /// Starts the simulation. Idempotent; the pit runs only while someone
    /// is logged in (LoggedInNapkin starts it on activate, stops it on
    /// deactivate).
    func start() {
        guard ticker == nil else { return }
        ticker = Task { [tickSeconds] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickSeconds))
                if Task.isCancelled { break }
                await self.tick()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Private

    private func tick() {
        // Advance the first item that isn't served; reseed when everything
        // has been eaten so the demo never goes quiet.
        guard let index = items.firstIndex(where: { $0.stage != .served }) else {
            items = Self.seededItems()
            broadcast()
            return
        }
        let next = PitItem.Stage(rawValue: items[index].stage.rawValue + 1) ?? .served
        items[index].stage = next
        if next == .resting {
            for continuation in eventSubscribers.values {
                continuation.yield(.lastCall(itemName: items[index].name))
            }
        }
        broadcast()
    }

    private func broadcast() {
        for continuation in updateSubscribers.values {
            continuation.yield(items)
        }
    }

    private func removeUpdateSubscriber(_ id: UUID) {
        updateSubscribers[id]?.finish()
        updateSubscribers.removeValue(forKey: id)
    }

    private func removeEventSubscriber(_ id: UUID) {
        eventSubscribers[id]?.finish()
        eventSubscribers.removeValue(forKey: id)
    }

    // Seeded so the initial summary is deterministic for tests:
    // 2 smoking + 1 resting = "2 SMOKING · 1 RESTING".
    private static func seededItems() -> [PitItem] {
        [
            PitItem(id: "brisket", name: "Brisket", stage: .smoking),
            PitItem(id: "pulled-pork", name: "Pulled Pork", stage: .smoking),
            PitItem(id: "ribs", name: "St. Louis Ribs", stage: .lighting),
            PitItem(id: "burnt-ends", name: "Burnt Ends", stage: .resting),
            PitItem(id: "sausage", name: "Smoked Sausage", stage: .lighting),
        ]
    }
}
```

- [ ] **Step 2: Create SpecialsService.swift**

```swift
import Foundation
import Observation

struct Special: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
}

// Main-actor state observed via `Observations` — the @Observable recipe
// from the napkin README. Consumers bind the observation loop to the main
// actor: `task { @MainActor [weak self] in for await … in Observations({ … }) }`.
@MainActor
@Observable
final class SpecialsService {

    private(set) var specials: [Special]

    @ObservationIgnored private var rotation: Task<Void, Never>?
    @ObservationIgnored private var offset = 0
    @ObservationIgnored private let rotationSeconds: Double

    private static let menu: [Special] = [
        Special(id: "hot-links", name: "Hot Links"),
        Special(id: "beef-rib", name: "Dino Beef Rib"),
        Special(id: "cornbread", name: "Skillet Cornbread"),
        Special(id: "banana-pudding", name: "Banana Pudding"),
    ]

    // nonisolated so the nonisolated AppComponent can construct it; it only
    // assigns Sendable stored values.
    nonisolated init(rotationSeconds: Double = 6) {
        self.rotationSeconds = rotationSeconds
        self.specials = Array(Self.menu.prefix(2))
    }

    /// Idempotent; PitBoard starts it on activate.
    func start() {
        guard rotation == nil else { return }
        rotation = Task { [rotationSeconds] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(rotationSeconds))
                if Task.isCancelled { break }
                self.rotate()
            }
        }
    }

    func stop() {
        rotation?.cancel()
        rotation = nil
    }

    private func rotate() {
        offset = (offset + 1) % Self.menu.count
        specials = [
            Self.menu[offset],
            Self.menu[(offset + 1) % Self.menu.count],
        ]
    }
}
```

- [ ] **Step 3: Wire AppComponent**

In `Examples/RibHouse/Sources/App/SceneDelegate.swift`, replace the `AppComponent` class with:

```swift
// Root dependency conforming to the launch napkin's dependency protocol.
// Provides the shared services at the top of the dependency tree; children
// read them through their Dependency protocols.
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    let authService: AuthService
    let pitService: PitService
    let specialsService: SpecialsService

    init(
        authService: AuthService = BarbecueAuthService(),
        fastTicks: Bool = ProcessInfo.processInfo.arguments.contains("-fastTicks")
    ) {
        self.authService = authService
        self.pitService = PitService(tickSeconds: fastTicks ? 0.5 : 4)
        self.specialsService = SpecialsService(rotationSeconds: fastTicks ? 0.75 : 6)
        super.init(dependency: EmptyComponent())
    }
}
```

Note: `LaunchNapkinDependency` does not yet require the two new properties — that arrives in Tasks 3 and 5. `BarbecueAuthService()` is still the current class in this task (Task 2 converts it); the call stays source-compatible.

- [ ] **Step 4: Build**

Run: `cd /Users/nonplus/Desktop/napkin/Examples/RibHouse && xcodebuild -project RibHouse.xcodeproj -scheme RibHouse -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. (New Shared files are picked up without xcodegen.)

- [ ] **Step 5: Commit**

```bash
git add Examples/RibHouse/Sources/Shared/PitService.swift Examples/RibHouse/Sources/Shared/SpecialsService.swift Examples/RibHouse/Sources/App/SceneDelegate.swift
git commit -m "feat(ribhouse): PitService and SpecialsService shared services

The live smoker (actor broadcaster: replay-latest updates + no-replay
last-call events) and the rotating specials (@MainActor @Observable),
seeded deterministically for tests and wired into AppComponent with a
-fastTicks launch argument for UI testing.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Stream-driven auth gate

**Files:**
- Modify: `Examples/RibHouse/Sources/Shared/AuthService.swift` (full rewrite below)
- Modify: `Examples/RibHouse/Sources/LaunchNapkin/LaunchNapkinInteractor.swift` (three methods)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `AuthService` protocol gains `func userStream() async -> AsyncStream<User?>`; `BarbecueAuthService` becomes an `actor`. `LaunchNapkinInteractor` routes ONLY from the stream; tap handlers are intent-only. Existing router methods `attachLoggedOut()` / `attachLoggedIn(user:)` are unchanged.

- [ ] **Step 1: Rewrite AuthService.swift**

```swift
import Foundation

protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
    func userStream() async -> AsyncStream<User?>
}

// Mock implementation that hands back Smokey Joe with a tray of barbecue.
// Now an actor broadcaster — the README's CurrentValueSubject replacement:
// it owns the current user and replays it to every new subscriber, so the
// LaunchNapkin's gate routes from state instead of from taps. In a real
// app a concrete implementation would talk to a server; the LaunchNapkin
// only depends on the protocol, so the wiring doesn't change.
actor BarbecueAuthService: AuthService {

    private(set) var currentUser: User?
    private var subscribers: [UUID: AsyncStream<User?>.Continuation] = [:]

    func login() async throws -> User {
        let user = User(
            name: "Smokey Joe",
            barbecueFoods: [
                "Brisket",
                "Pulled Pork",
                "St. Louis Ribs",
                "Burnt Ends",
                "Smoked Sausage",
            ]
        )
        setUser(user)
        return user
    }

    func logout() async throws {
        setUser(nil)
    }

    /// A fresh stream per subscriber: the current value immediately, then
    /// every change.
    func userStream() -> AsyncStream<User?> {
        let (stream, continuation) = AsyncStream.makeStream(of: User?.self)
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(currentUser)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    // MARK: - Private

    private func setUser(_ user: User?) {
        currentUser = user
        for continuation in subscribers.values {
            continuation.yield(user)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}
```

- [ ] **Step 2: Convert the gate in LaunchNapkinInteractor.swift**

Replace `didBecomeActive()`, `loggedOutDidTapLogin()`, and `loggedInDidTapLogout()` with:

```swift
    func didBecomeActive() async {
        // The auth gate: routing follows auth state, not taps. The stream
        // replays the current value (nil at launch), which is what attaches
        // the LoggedOut napkin. Bound to the active scope — cancelled
        // automatically on willResignActive.
        task {
            for await user in await self.authService.userStream() {
                if let user {
                    await self.router?.attachLoggedIn(user: user)
                } else {
                    await self.router?.attachLoggedOut()
                }
            }
        }
    }

    func willResignActive() async {}

    // MARK: - LoggedOutNapkinListener

    func loggedOutDidTapLogin() async {
        do {
            _ = try await authService.login()
            // No routing here — the gate above reacts to the stream.
        } catch {
            // Login failed — stay on the logged-out screen. Real apps would
            // surface an alert; we keep this demo silent.
        }
    }

    // MARK: - LoggedInNapkinListener

    func loggedInDidTapLogout() async {
        // Routing happens via the stream, same as login.
        try? await authService.logout()
    }
```

(The rest of the file — protocols, properties, `init`, `wire` — is unchanged.)

- [ ] **Step 3: Full test run (existing suites must stay green)**

Run: `cd /Users/nonplus/Desktop/napkin/Examples/RibHouse && xcodebuild -project RibHouse.xcodeproj -scheme RibHouse -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` — the UI tests exercise login/logout end-to-end, which now proves the gate routes from the stream.

- [ ] **Step 4: Commit**

```bash
git add Examples/RibHouse/Sources/Shared/AuthService.swift Examples/RibHouse/Sources/LaunchNapkin/LaunchNapkinInteractor.swift
git commit -m "feat(ribhouse): stream-driven auth gate

BarbecueAuthService becomes an actor broadcaster and the LaunchNapkin
gate routes from userStream() — the README's spine pattern, live. Tap
handlers shrink to intent-only calls; the stream's replay of nil
replaces the explicit initial attachLoggedOut.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: LoggedIn hub — navigation shell + live pit summary

**Files:**
- Create: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinNavigationController.swift`
- Modify: `Examples/RibHouse/Sources/LaunchNapkin/LaunchNapkinBuilder.swift` (thread `pitService`)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinBuilder.swift`
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinInteractor.swift`
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinHostingViewController.swift`
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinView.swift`
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinRouter.swift`
- Modify: `Examples/RibHouse/Sources/Shared/AccessibilityIdentifiers.swift`
- Test: `Examples/RibHouse/SnapshotTests/LoggedInNapkinViewSnapshotTests.swift` (+ re-recorded PNG)

**Interfaces:**
- Consumes: `PitService` from Task 1 (`updates()`, `start()`, `stop()`; seeded `"2 SMOKING · 1 RESTING"`).
- Produces: `LoggedInNapkinViewControllable` is now implemented by `LoggedInNapkinNavigationController` (the router's `viewControllable` is the nav); `LoggedInNapkinPresentable` gains `func present(pitSummary: String) async`; `LoggedInNapkinDependency` requires `var pitService: PitService { get }`; `LaunchNapkinDependency` requires the same (AppComponent already provides it); `LoggedInNapkinView` gains `var pitSummary: String = ""`; new identifier `NapkinAccessibility.LoggedIn.pitSummary = "loggedIn.pitSummary"`. Task 5 will extend the nav controller with `push`.

- [ ] **Step 1: Add the identifier**

In `AccessibilityIdentifiers.swift`, inside `enum LoggedIn`, add:

```swift
        public static let pitSummary = "loggedIn.pitSummary"
```

- [ ] **Step 2: Create LoggedInNapkinNavigationController.swift**

```swift
import napkin

#if canImport(UIKit)
import UIKit

// The LoggedIn napkin owns its own navigation stack (the LaunchNapkin just
// embeds this nav controller like any other child view). The nav bar stays
// hidden on the root screen to preserve the original full-bleed look and
// appears automatically on pushed children so they get a back button.
@MainActor
final class LoggedInNapkinNavigationController: UINavigationController,
    UINavigationControllerDelegate,
    LoggedInNapkinViewControllable
{

    init(root: UIViewController) {
        super.init(rootViewController: root)
        delegate = self
        navigationBar.tintColor = UIColor(
            red: 0.500, green: 0.810, blue: 0.600, alpha: 1
        ) // Palette.Dark.moss
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    nonisolated func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        MainActor.assumeIsolated {
            let isRoot = viewController === viewControllers.first
            setNavigationBarHidden(isRoot, animated: animated)
        }
    }
}
#endif
```

- [ ] **Step 3: Thread pitService through the dependency chain**

In `LaunchNapkinBuilder.swift`, `LaunchNapkinDependency` currently requires `authService`; add `pitService` to the protocol and forward it in `LaunchNapkinComponent`:

```swift
protocol LaunchNapkinDependency: Dependency {
    var authService: AuthService { get }
    var pitService: PitService { get }
}
```

and in `LaunchNapkinComponent` (alongside the existing `authService` forwarder):

```swift
    var pitService: PitService { dependency.pitService }
```

(If `LaunchNapkinDependency` / the component live in `LaunchNapkinBuilder.swift` with different exact spellings, anchor on the existing `authService` declarations and mirror them.)

In `LoggedInNapkinBuilder.swift`:

```swift
protocol LoggedInNapkinDependency: Dependency {
    // Threaded from the AppComponent through the LaunchNapkin. The pit
    // powers the live summary here and the PitBoard child.
    var authService: AuthService { get }
    var pitService: PitService { get }
}

final class LoggedInNapkinComponent: Component<LoggedInNapkinDependency>, @unchecked Sendable {

    var authService: AuthService { dependency.authService }
    var pitService: PitService { dependency.pitService }
}
```

and change `build(withListener:user:)` to construct the nav shell and hand the interactor the pit:

```swift
    @MainActor
    func build(
        withListener listener: LoggedInNapkinListener,
        user: User
    ) async -> LoggedInNapkinRouting {
        let component = LoggedInNapkinComponent(dependency: dependency)
        let hosting = LoggedInNapkinViewController(user: user)
        let navigation = LoggedInNapkinNavigationController(root: hosting)
        let interactor = LoggedInNapkinInteractor(
            presenter: hosting,
            user: user,
            pitService: component.pitService
        )
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: navigation,
            user: user
        )
        await interactor.wire(router: router, listener: listener)
        return router
    }
```

- [ ] **Step 4: Interactor — subscribe and summarize**

In `LoggedInNapkinInteractor.swift`, add to `LoggedInNapkinPresentable`:

```swift
protocol LoggedInNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: LoggedInNapkinPresentableListener? { get set }
    func present(pitSummary: String) async
}
```

and update the actor (new stored property, init parameter, and lifecycle):

```swift
final actor LoggedInNapkinInteractor: PresentableInteractable, LoggedInNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LoggedInNapkinPresentable
    nonisolated let user: User
    nonisolated let pitService: PitService

    weak var router: LoggedInNapkinRouting?
    weak var listener: LoggedInNapkinListener?

    init(presenter: LoggedInNapkinPresentable, user: User, pitService: PitService) {
        self.presenter = presenter
        self.user = user
        self.pitService = pitService
    }

    func wire(router: LoggedInNapkinRouting?, listener: LoggedInNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }

        // The pit runs only while someone is logged in.
        await pitService.start()

        // Fan-out subscriber #1: reduce each board snapshot to the header
        // summary. The transform lives in the loop body — this is where a
        // Combine `.map` went. Cancelled automatically on deactivate.
        task {
            for await items in await self.pitService.updates() {
                let smoking = items.count(where: { $0.stage == .smoking })
                let resting = items.count(where: { $0.stage == .resting })
                await self.presenter.present(pitSummary: "\(smoking) SMOKING · \(resting) RESTING")
            }
        }
    }

    func willResignActive() async {
        await pitService.stop()
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - LoggedInNapkinPresentableListener

    func didTapLogout() async {
        await listener?.loggedInDidTapLogout()
    }
}
```

- [ ] **Step 5: Hosting VC forwards the summary**

In `LoggedInNapkinHostingViewController.swift`, in BOTH platform branches, add below the `listener` property:

```swift
    func present(pitSummary: String) async {
        rootView.pitSummary = pitSummary
    }
```

Remove the `extension LoggedInNapkinViewController: LoggedInNapkinViewControllable {}` line at the bottom of the file — the nav controller is the `ViewControllable` now.

- [ ] **Step 6: View — the summary line**

In `LoggedInNapkinView.swift`, add the stored property after `user`:

```swift
    var pitSummary: String = ""
```

and insert this block directly AFTER the `Rectangle()` divider and BEFORE the `Text("BARBECUE FOODS")` kicker:

```swift
                if !pitSummary.isEmpty {
                    HStack(spacing: 6) {
                        Text("LIVE FROM THE PIT")
                        Text("·").foregroundStyle(Palette.Dark.ink3.opacity(0.5))
                        Text(pitSummary).foregroundStyle(Palette.Dark.amber)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.Dark.ink3)
                    .accessibilityIdentifier(NapkinAccessibility.LoggedIn.pitSummary)
                }
```

- [ ] **Step 7: Router viewControllable type**

`LoggedInNapkinRouter.swift` needs no structural change (it is generic over `LoggedInNapkinViewControllable`, now satisfied by the nav controller). Confirm the file compiles unmodified; if the `LoggedInNapkinViewControllable` protocol declaration lives in this file, it stays as-is in this task.

- [ ] **Step 8: Update the snapshot test and re-record**

In `LoggedInNapkinViewSnapshotTests.swift`, replace the test method:

```swift
    func testLoggedInNapkinView() {
        let view = LoggedInNapkinView(user: smokeyJoe, pitSummary: "2 SMOKING · 1 RESTING")
        let vc = UIHostingController(rootView: view)
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
```

Delete the stale reference: `rm Examples/RibHouse/SnapshotTests/__Snapshots__/LoggedInNapkinViewSnapshotTests/testLoggedInNapkinView.1.png`
Run the full test command once (snapshot records + that one test FAILS with "Record mode"/"re-run"), then run again — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add -A Examples/RibHouse
git commit -m "feat(ribhouse): LoggedIn hub — nav shell and live pit summary

LoggedIn owns a UINavigationController (bar hidden on root, shown on
pushes) and becomes fan-out subscriber #1: a lifecycle-bound task
reduces PitService.updates() snapshots to the LIVE FROM THE PIT header.
Snapshot re-recorded for the new header.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: AnnouncementsNapkin (headless) + last-call banner

**Files:**
- Create: `Examples/RibHouse/Sources/AnnouncementsNapkin/AnnouncementsNapkinBuilder.swift`
- Create: `Examples/RibHouse/Sources/AnnouncementsNapkin/AnnouncementsNapkinInteractor.swift`
- Create: `Examples/RibHouse/Sources/AnnouncementsNapkin/AnnouncementsNapkinRouter.swift`
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinBuilder.swift` (pass announcements builder to router)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinRouter.swift` (attach in `didLoad`)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinInteractor.swift` (listener conformance + banner)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinHostingViewController.swift` (banner forwarder)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinView.swift` (banner overlay)
- Modify: `Examples/RibHouse/Sources/Shared/AccessibilityIdentifiers.swift`
- Test: `Examples/RibHouse/SnapshotTests/LoggedInNapkinViewSnapshotTests.swift` (banner-state snapshot)

**Interfaces:**
- Consumes: `PitService.events()` / `PitEvent.lastCall(itemName:)` from Task 1; nav shell and presentable from Task 3.
- Produces: `AnnouncementsNapkinListener` with `func announcementsNapkinDidHearLastCall(itemName: String) async`; `AnnouncementsNapkinBuildable.build(withListener:) async -> AnnouncementsNapkinRouting`; `LoggedInNapkinPresentable` gains `func present(banner: String?) async`; identifier `NapkinAccessibility.LoggedIn.banner = "loggedIn.banner"`.

- [ ] **Step 1: Add the identifier**

In `AccessibilityIdentifiers.swift`, inside `enum LoggedIn`, add:

```swift
        public static let banner = "loggedIn.banner"
```

- [ ] **Step 2: Create AnnouncementsNapkinInteractor.swift**

```swift
import napkin

@MainActor
protocol AnnouncementsNapkinRouting: Routing, Sendable {}

protocol AnnouncementsNapkinListener: AnyObject, Sendable {
    func announcementsNapkinDidHearLastCall(itemName: String) async
}

// Headless consumer of the pit's no-replay event stream — the README's
// PassthroughSubject recipe, live. No view, no presenter: it turns pit
// events into business intents for its parent.
final actor AnnouncementsNapkinInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let pitService: PitService

    weak var router: AnnouncementsNapkinRouting?
    weak var listener: AnnouncementsNapkinListener?

    init(pitService: PitService) {
        self.pitService = pitService
    }

    func wire(router: AnnouncementsNapkinRouting?, listener: AnnouncementsNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        task {
            for await event in await self.pitService.events() {
                if case .lastCall(let itemName) = event {
                    await self.listener?.announcementsNapkinDidHearLastCall(itemName: itemName)
                }
            }
        }
    }

    func willResignActive() async {}
}
```

- [ ] **Step 3: Create AnnouncementsNapkinRouter.swift**

```swift
import napkin

// Viewless napkin: the plain Router base class, no ViewControllable.
@MainActor
final class AnnouncementsNapkinRouter:
    Router<AnnouncementsNapkinInteractor>,
    AnnouncementsNapkinRouting
{}
```

- [ ] **Step 4: Create AnnouncementsNapkinBuilder.swift**

```swift
import napkin

protocol AnnouncementsNapkinDependency: Dependency {
    var pitService: PitService { get }
}

final class AnnouncementsNapkinComponent: Component<AnnouncementsNapkinDependency>, @unchecked Sendable {

    var pitService: PitService { dependency.pitService }
}

protocol AnnouncementsNapkinBuildable: Buildable {
    func build(withListener listener: AnnouncementsNapkinListener) async -> AnnouncementsNapkinRouting
}

final class AnnouncementsNapkinBuilder: Builder<AnnouncementsNapkinDependency>, AnnouncementsNapkinBuildable, @unchecked Sendable {

    override init(dependency: AnnouncementsNapkinDependency) {
        super.init(dependency: dependency)
    }

    func build(withListener listener: AnnouncementsNapkinListener) async -> AnnouncementsNapkinRouting {
        let component = AnnouncementsNapkinComponent(dependency: dependency)
        let interactor = AnnouncementsNapkinInteractor(pitService: component.pitService)
        let router = await AnnouncementsNapkinRouter(interactor: interactor)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
```

(If `Router.init(interactor:)` is not `async`/`@MainActor` in the framework, drop the `await` — anchor on how the framework's `Router` initializer is declared; a viewless build method may also need `@MainActor` if the compiler demands it. Report any signature deviation.)

- [ ] **Step 5: Wire into LoggedIn**

In `LoggedInNapkinBuilder.swift`: make the component satisfy the child dependency and hand the router a builder —

```swift
extension LoggedInNapkinComponent: AnnouncementsNapkinDependency {}
```

and in `build(withListener:user:)`, construct and pass it:

```swift
        let announcementsBuilder = AnnouncementsNapkinBuilder(dependency: component)
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: navigation,
            user: user,
            announcementsBuilder: announcementsBuilder
        )
```

In `LoggedInNapkinRouter.swift`:

```swift
@MainActor
final class LoggedInNapkinRouter:
    ViewableRouter<LoggedInNapkinInteractor, LoggedInNapkinViewControllable>,
    LoggedInNapkinRouting
{
    let user: User

    private let announcementsBuilder: AnnouncementsNapkinBuildable
    private var announcementsRouter: AnnouncementsNapkinRouting?

    init(
        interactor: LoggedInNapkinInteractor,
        viewController: LoggedInNapkinViewControllable,
        user: User,
        announcementsBuilder: AnnouncementsNapkinBuildable
    ) {
        self.user = user
        self.announcementsBuilder = announcementsBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    override func didLoad() async {
        await super.didLoad()
        await attachAnnouncements()
    }

    // MARK: - Private

    private func attachAnnouncements() async {
        guard announcementsRouter == nil else { return }
        let router = await announcementsBuilder.build(withListener: interactor)
        announcementsRouter = router
        await attachChild(router)
    }
}
```

- [ ] **Step 6: Banner in the interactor, presentable, and view**

`LoggedInNapkinInteractor.swift` — add the conformance and methods:

```swift
final actor LoggedInNapkinInteractor: PresentableInteractable, LoggedInNapkinPresentableListener, AnnouncementsNapkinListener {
```

```swift
    // MARK: - AnnouncementsNapkinListener

    func announcementsNapkinDidHearLastCall(itemName: String) async {
        await presenter.present(banner: "LAST CALL · \(itemName)")
        // Auto-clear. A newer banner may be cleared early by an older
        // timer — acceptable for the demo, and the next event re-shows it.
        task {
            try? await Task.sleep(for: .seconds(3))
            await self.presenter.present(banner: nil)
        }
    }
```

`LoggedInNapkinPresentable` gains:

```swift
    func present(banner: String?) async
```

`LoggedInNapkinHostingViewController.swift` — in BOTH platform branches:

```swift
    func present(banner: String?) async {
        withAnimation(.easeInOut(duration: 0.25)) {
            rootView.banner = banner
        }
    }
```

`LoggedInNapkinView.swift` — add `var banner: String?` after `pitSummary`, and add this overlay modifier on the outer `ZStack` (after `.padding(.bottom, 48)`'s enclosing VStack, i.e. attached to the `ZStack` itself):

```swift
        .overlay(alignment: .top) {
            if let banner {
                Text(banner)
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.Dark.amber))
                    .foregroundStyle(Palette.Dark.paper)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier(NapkinAccessibility.LoggedIn.banner)
            }
        }
```

- [ ] **Step 7: Banner snapshot test**

Add to `LoggedInNapkinViewSnapshotTests.swift`:

```swift
    func testLoggedInNapkinViewWithBanner() {
        var view = LoggedInNapkinView(user: smokeyJoe, pitSummary: "1 SMOKING · 2 RESTING")
        view.banner = "LAST CALL · Brisket"
        let vc = UIHostingController(rootView: view)
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
```

- [ ] **Step 8: xcodegen + test twice (new snapshot records on first run)**

```bash
cd /Users/nonplus/Desktop/napkin/Examples/RibHouse && xcodegen
```
Then run the full test command once (new banner snapshot records + fails), then again — Expected: `** TEST SUCCEEDED **`. The Task 3 reference PNG must NOT need re-recording (default `banner == nil` renders identically); if the base snapshot fails, report it — do not silently re-record it.

- [ ] **Step 9: Commit**

```bash
git add -A Examples/RibHouse
git commit -m "feat(ribhouse): headless AnnouncementsNapkin and last-call banner

A viewless napkin consumes PitService.events() (the no-replay
PassthroughSubject recipe) and forwards last-call intents up the
listener chain; LoggedIn presents them as an auto-clearing banner.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: PitBoardNapkin — the pushed four-seam vertical

**Files:**
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinBuilder.swift`
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinInteractor.swift`
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinRouter.swift`
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinPresenter.swift`
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinView.swift`
- Create: `Examples/RibHouse/Sources/PitBoardNapkin/PitBoardNapkinHostingViewController.swift`
- Modify: `Examples/RibHouse/Sources/LaunchNapkin/LaunchNapkinBuilder.swift` (thread `specialsService`)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinBuilder.swift` (thread `specialsService`, pit board builder)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinRouter.swift` (attach/detach + push)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinInteractor.swift` (button intent + child listener)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinNavigationController.swift` (push)
- Modify: `Examples/RibHouse/Sources/LoggedInNapkin/LoggedInNapkinHostingViewController.swift` + `LoggedInNapkinView.swift` (PIT BOARD button)
- Modify: `Examples/RibHouse/Sources/Shared/AccessibilityIdentifiers.swift`
- Test: create `Examples/RibHouse/SnapshotTests/PitBoardNapkinViewSnapshotTests.swift`; modify `Examples/RibHouse/UITests/RibHouseUITests.swift`

**Interfaces:**
- Consumes: `PitService.updates()`, `PitItem`, `SpecialsService`/`Special` (Task 1); nav shell (Task 3); `LoggedInNapkinComponent` (Tasks 3–4).
- Produces: `PitBoardSection { id: Int; title: String; items: [PitItem] }`; `PitBoardNapkinListener.pitBoardNapkinDidDismiss() async`; `LoggedInNapkinViewControllable` gains `func push(_ child: ViewControllable)`; identifiers `PitBoard.title = "pitBoard.title"`, `PitBoard.itemPrefix = "pitBoard.item"`, `PitBoard.specialPrefix = "pitBoard.special"`, `LoggedIn.pitBoardButton = "loggedIn.pitBoardButton"`.

- [ ] **Step 1: Identifiers**

In `AccessibilityIdentifiers.swift` add to `enum LoggedIn`:

```swift
        public static let pitBoardButton = "loggedIn.pitBoardButton"
```

and a new enum after `LoggedIn`:

```swift
    public enum PitBoard {
        public static let title = "pitBoard.title"
        // Per-item identifiers are built as `\(itemPrefix).\(item.id)`.
        public static let itemPrefix = "pitBoard.item"
        // Per-special identifiers are built as `\(specialPrefix).\(special.id)`.
        public static let specialPrefix = "pitBoard.special"
    }
```

- [ ] **Step 2: Create PitBoardNapkinInteractor.swift**

```swift
import napkin

@MainActor
protocol PitBoardNapkinRouting: ViewableRouting, Sendable {}

protocol PitBoardNapkinListener: AnyObject, Sendable {
    func pitBoardNapkinDidDismiss() async
}

struct PitBoardSection: Sendable, Equatable, Identifiable {
    let id: Int
    let title: String
    let items: [PitItem]
}

protocol PitBoardNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: PitBoardNapkinPresentableListener? { get set }
    func present(sections: [PitBoardSection]) async
    func present(specials: [Special]) async
}

final actor PitBoardNapkinInteractor: PresentableInteractable, PitBoardNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: PitBoardNapkinPresentable
    nonisolated let pitService: PitService
    nonisolated let specialsService: SpecialsService

    weak var router: PitBoardNapkinRouting?
    weak var listener: PitBoardNapkinListener?

    init(
        presenter: PitBoardNapkinPresentable,
        pitService: PitService,
        specialsService: SpecialsService
    ) {
        self.presenter = presenter
        self.pitService = pitService
        self.specialsService = specialsService
    }

    func wire(router: PitBoardNapkinRouting?, listener: PitBoardNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }

        await specialsService.start()

        // Fan-out subscriber #2 to the same PitService the LoggedIn header
        // observes — each updates() call is an independent stream. The
        // grouping transform lives in the loop body.
        task {
            for await items in await self.pitService.updates() {
                let sections = PitItem.Stage.allCases.compactMap { stage -> PitBoardSection? in
                    let staged = items.filter { $0.stage == stage }
                    guard !staged.isEmpty else { return nil }
                    return PitBoardSection(id: stage.rawValue, title: stage.label, items: staged)
                }
                await self.presenter.present(sections: sections)
            }
        }

        // Main-actor state via Observations — the @Observable recipe. The
        // loop is bound to the actor that owns the state; each value hops
        // back here for handling. (Hoist + @MainActor closure: iterating
        // Observations from a nonisolated closure crashes the compiler.)
        let specialsService = self.specialsService
        task { @MainActor [weak self] in
            for await specials in Observations({ specialsService.specials }) {
                await self?.forward(specials: specials)
            }
        }
    }

    func willResignActive() async {
        await specialsService.stop()
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - PitBoardNapkinPresentableListener

    func didDismiss() async {
        await listener?.pitBoardNapkinDidDismiss()
    }

    // MARK: - Private

    private func forward(specials: [Special]) async {
        await presenter.present(specials: specials)
    }
}
```

Add `import Observation` at the top if the compiler asks for it (alongside `import napkin`).

- [ ] **Step 3: Create PitBoardNapkinPresenter.swift**

```swift
import napkin
import SwiftUI

// The Presenter-subclass style (LoggedIn shows the other style: the view
// controller conforming to the presentable directly). @Observable is
// re-annotated so THIS class's stored properties are tracked; the stored
// properties are the view model.
@MainActor
@Observable
final class PitBoardNapkinPresenter: Presenter<PitBoardNapkinViewController>, PitBoardNapkinPresentable {

    var sections: [PitBoardSection] = []
    var specials: [Special] = []

    @ObservationIgnored weak var listener: PitBoardNapkinPresentableListener? {
        didSet { viewController.listener = listener }
    }

    func present(sections: [PitBoardSection]) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.sections = sections
        }
    }

    func present(specials: [Special]) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.specials = specials
        }
    }
}
```

- [ ] **Step 4: Create PitBoardNapkinHostingViewController.swift**

```swift
import napkin
import SwiftUI

protocol PitBoardNapkinPresentableListener: AnyObject, Sendable {
    func didDismiss() async
}

#if canImport(UIKit)
@MainActor final class PitBoardNapkinViewController: UIHostingController<PitBoardNapkinView> {

    weak var listener: PitBoardNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PitBoardNapkinView())
        title = "The Pit"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Two-phase bind: the builder constructs this VC first, then the
    /// presenter (which needs the VC), then hands the presenter back so
    /// the view can read its @Observable state. This is the acyclic
    /// construction order the napkin README documents.
    func bind(presenter: PitBoardNapkinPresenter) {
        rootView.presenter = presenter
    }

    // 0.x observed this with Combine's KVO publisher
    // (`publisher(for: \.parent)`); 2.x uses the UIKit callback that KVO
    // was wrapping. Fires when the back button pops us: close the logical
    // tree to match the visual one.
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            dispatch { [listener] in await listener?.didDismiss() }
        }
    }
}

extension PitBoardNapkinViewController: PitBoardNapkinViewControllable {}
#endif
```

- [ ] **Step 5: Create PitBoardNapkinView.swift**

```swift
import SwiftUI
import napkin

struct PitBoardNapkinView: View {
    var presenter: PitBoardNapkinPresenter?
    weak var listener: PitBoardNapkinPresentableListener?

    var body: some View {
        ZStack {
            Palette.Dark.paperDeep.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 8)

                    HStack(spacing: 6) {
                        Text("§ 01").bold()
                        Text("·").foregroundStyle(Palette.Dark.ink3.opacity(0.5))
                        Text("THE PIT, LIVE")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.Dark.ink3)
                    .accessibilityIdentifier(NapkinAccessibility.PitBoard.title)

                    ForEach(presenter?.sections ?? []) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.title.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(Palette.Dark.moss)

                            ForEach(section.items) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 16) {
                                    Text(item.name)
                                        .font(.system(.title3, design: .serif))
                                        .foregroundStyle(Palette.Dark.ink)
                                    Spacer()
                                    Text(item.stage.label.uppercased())
                                        .font(.system(.caption2, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(Palette.Dark.amber)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("\(NapkinAccessibility.PitBoard.itemPrefix).\(item.id)")
                            }
                        }
                        .transition(.opacity)
                    }

                    Rectangle()
                        .fill(Palette.Dark.ink3.opacity(0.35))
                        .frame(height: 1)

                    Text("TODAY'S SPECIALS")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Palette.Dark.ink3)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(presenter?.specials ?? []) { special in
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text("★")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Palette.Dark.amber)
                                    .frame(width: 28, alignment: .leading)
                                Text(special.name)
                                    .font(.system(.title3, design: .serif))
                                    .foregroundStyle(Palette.Dark.ink)
                            }
                            .accessibilityIdentifier("\(NapkinAccessibility.PitBoard.specialPrefix).\(special.id)")
                        }
                    }
                    .transition(.opacity)

                    Spacer()
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    PitBoardNapkinView()
}
```

- [ ] **Step 6: Create PitBoardNapkinRouter.swift**

```swift
import napkin

@MainActor
protocol PitBoardNapkinViewControllable: ViewControllable {}

@MainActor
final class PitBoardNapkinRouter:
    ViewableRouter<PitBoardNapkinInteractor, PitBoardNapkinViewControllable>,
    PitBoardNapkinRouting
{}
```

- [ ] **Step 7: Create PitBoardNapkinBuilder.swift**

```swift
import napkin

protocol PitBoardNapkinDependency: Dependency {
    var pitService: PitService { get }
    var specialsService: SpecialsService { get }
}

final class PitBoardNapkinComponent: Component<PitBoardNapkinDependency>, @unchecked Sendable {

    var pitService: PitService { dependency.pitService }
    var specialsService: SpecialsService { dependency.specialsService }
}

protocol PitBoardNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: PitBoardNapkinListener) async -> PitBoardNapkinRouting
}

final class PitBoardNapkinBuilder: Builder<PitBoardNapkinDependency>, PitBoardNapkinBuildable, @unchecked Sendable {

    override init(dependency: PitBoardNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: PitBoardNapkinListener) async -> PitBoardNapkinRouting {
        let component = PitBoardNapkinComponent(dependency: dependency)
        // Acyclic construction: VC first, then the presenter that needs it,
        // then bind so the view reads the presenter's @Observable state.
        let viewController = PitBoardNapkinViewController()
        let presenter = PitBoardNapkinPresenter(viewController: viewController)
        viewController.bind(presenter: presenter)
        let interactor = PitBoardNapkinInteractor(
            presenter: presenter,
            pitService: component.pitService,
            specialsService: component.specialsService
        )
        let router = PitBoardNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
```

Note: the presenter's `listener` didSet forwards to `viewController.listener`; the interactor sets `presenter.listener = self` via its `didBecomeActive` (the presentable's `@MainActor var listener` requirement is satisfied by the presenter).

- [ ] **Step 8: Thread specialsService and the button through LoggedIn/Launch**

`LaunchNapkinBuilder.swift`: add to `LaunchNapkinDependency` and forward in the component (mirror the Task 3 pitService lines):

```swift
    var specialsService: SpecialsService { get }
```
```swift
    var specialsService: SpecialsService { dependency.specialsService }
```

`LoggedInNapkinBuilder.swift`: add `var specialsService: SpecialsService { get }` to `LoggedInNapkinDependency`, `var specialsService: SpecialsService { dependency.specialsService }` to the component, then:

```swift
extension LoggedInNapkinComponent: PitBoardNapkinDependency {}
```

and in `build(withListener:user:)` construct + pass the builder:

```swift
        let pitBoardBuilder = PitBoardNapkinBuilder(dependency: component)
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: navigation,
            user: user,
            announcementsBuilder: announcementsBuilder,
            pitBoardBuilder: pitBoardBuilder
        )
```

`LoggedInNapkinNavigationController.swift`: add inside the class:

```swift
    // MARK: - LoggedInNapkinViewControllable

    func push(_ child: ViewControllable) {
        pushViewController(child.uiviewController, animated: true)
    }
```

and extend the protocol in `LoggedInNapkinRouter.swift`:

```swift
@MainActor
protocol LoggedInNapkinViewControllable: ViewControllable {
    func push(_ child: ViewControllable)
}
```

`LoggedInNapkinRouter.swift` — add the pit board plumbing (routing protocol lives in the interactor file; see below):

```swift
    private let pitBoardBuilder: PitBoardNapkinBuildable
    private var pitBoardRouter: PitBoardNapkinRouting?
```

(init gains `pitBoardBuilder: PitBoardNapkinBuildable`, stored before `super.init`), plus:

```swift
    // MARK: - LoggedInNapkinRouting

    func attachPitBoard() async {
        guard pitBoardRouter == nil else { return }
        let router = await pitBoardBuilder.build(withListener: interactor)
        pitBoardRouter = router
        await attachChild(router)
        viewController.push(router.viewControllable)
    }

    func detachPitBoard() async {
        guard let router = pitBoardRouter else { return }
        pitBoardRouter = nil
        // The back button already popped the view; only the logical tree
        // needs closing.
        await detachChild(router)
    }
```

`LoggedInNapkinInteractor.swift`:

```swift
@MainActor
protocol LoggedInNapkinRouting: ViewableRouting, Sendable {
    func attachPitBoard() async
    func detachPitBoard() async
}
```

conformance list gains `PitBoardNapkinListener`; add:

```swift
    // MARK: - LoggedInNapkinPresentableListener

    func didTapPitBoard() async {
        await router?.attachPitBoard()
    }

    // MARK: - PitBoardNapkinListener

    func pitBoardNapkinDidDismiss() async {
        await router?.detachPitBoard()
    }
```

`LoggedInNapkinPresentableListener` (in the hosting VC file) gains:

```swift
    func didTapPitBoard() async
```

`LoggedInNapkinView.swift` — insert the PIT BOARD button ABOVE the Logout button (before the existing `Button` block), filled-moss style to contrast the ghost Logout:

```swift
                Button {
                    dispatch { [listener] in await listener?.didTapPitBoard() }
                } label: {
                    Text("Pit Board")
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(2)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .background(Capsule().fill(Palette.Dark.moss.opacity(0.25)))
                .overlay(Capsule().stroke(Palette.Dark.moss.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Palette.Dark.ink)
                .accessibilityIdentifier(NapkinAccessibility.LoggedIn.pitBoardButton)
```

- [ ] **Step 9: PitBoard snapshot test**

Create `Examples/RibHouse/SnapshotTests/PitBoardNapkinViewSnapshotTests.swift`:

```swift
//
//  PitBoardNapkinViewSnapshotTests.swift
//  RibHouse snapshot tests
//
//  Pins the PitBoard's appearance for a fixed board state: grouped stage
//  sections, amber stage tags, and the specials list.
//

import SnapshotTesting
import SwiftUI
import XCTest
@testable import RibHouse

@MainActor
final class PitBoardNapkinViewSnapshotTests: XCTestCase {

    func testPitBoardNapkinView() {
        let viewController = PitBoardNapkinViewController()
        let presenter = PitBoardNapkinPresenter(viewController: viewController)
        presenter.sections = [
            PitBoardSection(id: 0, title: "Lighting", items: [
                PitItem(id: "ribs", name: "St. Louis Ribs", stage: .lighting),
                PitItem(id: "sausage", name: "Smoked Sausage", stage: .lighting),
            ]),
            PitBoardSection(id: 1, title: "Smoking", items: [
                PitItem(id: "brisket", name: "Brisket", stage: .smoking),
                PitItem(id: "pulled-pork", name: "Pulled Pork", stage: .smoking),
            ]),
            PitBoardSection(id: 2, title: "Resting", items: [
                PitItem(id: "burnt-ends", name: "Burnt Ends", stage: .resting),
            ]),
        ]
        presenter.specials = [
            Special(id: "hot-links", name: "Hot Links"),
            Special(id: "beef-rib", name: "Dino Beef Rib"),
        ]
        viewController.bind(presenter: presenter)
        assertSnapshot(of: viewController, as: .image(on: .iPhone13Pro))
    }
}
```

- [ ] **Step 10: LoggedIn snapshot re-record (button added) + UI tests**

Delete `Examples/RibHouse/SnapshotTests/__Snapshots__/LoggedInNapkinViewSnapshotTests/testLoggedInNapkinView.1.png` AND `testLoggedInNapkinViewWithBanner.1.png` (the view gained a button).

Replace `testLoginRevealsBarbecueFoodsAndLogoutReturns` in `RibHouseUITests.swift` with the extended flow, and add the fast-ticks test:

```swift
    func testLoginRevealsBarbecueFoodsAndLogoutReturns() {
        app.buttons[NapkinAccessibility.LoggedOut.loginButton].tap()

        let nameLabel = app.staticTexts[NapkinAccessibility.LoggedIn.nameLabel]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(nameLabel.label, "Smokey Joe")

        XCTAssertTrue(
            app.staticTexts["\(NapkinAccessibility.LoggedIn.foodPrefix).Brisket"]
                .waitForExistence(timeout: 2)
        )

        // The live pit summary renders from the seeded board.
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.LoggedIn.pitSummary]
                .waitForExistence(timeout: 5)
        )

        // Push the pit board; the seeded brisket is on it (fan-out
        // subscriber #2 sees the same board as the header).
        app.buttons[NapkinAccessibility.LoggedIn.pitBoardButton].tap()
        XCTAssertTrue(
            app.otherElements["\(NapkinAccessibility.PitBoard.itemPrefix).brisket"]
                .waitForExistence(timeout: 5)
        )

        // Back pops the board; didMove(toParent: nil) detaches the child.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5))

        // Re-push proves the logical tree was detached cleanly.
        app.buttons[NapkinAccessibility.LoggedIn.pitBoardButton].tap()
        XCTAssertTrue(
            app.otherElements["\(NapkinAccessibility.PitBoard.itemPrefix).brisket"]
                .waitForExistence(timeout: 5)
        )
        app.navigationBars.buttons.firstMatch.tap()

        // Logout takes us back to the logged-out screen.
        app.buttons[NapkinAccessibility.LoggedIn.logoutButton].tap()
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.LoggedOut.title]
                .waitForExistence(timeout: 5)
        )
    }

    func testPitSummaryChangesUnderFastTicks() {
        app.terminate()
        app.launchArguments += ["-fastTicks"]
        app.launch()

        app.buttons[NapkinAccessibility.LoggedOut.loginButton].tap()
        let summary = app.staticTexts[NapkinAccessibility.LoggedIn.pitSummary]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let initial = summary.label

        // Under -fastTicks (0.5s) the board advances quickly; wait for the
        // summary to change at least once. Never assert a specific later
        // state — only that it moved.
        let changed = expectation(description: "pit summary changed")
        Task { @MainActor in
            for _ in 0..<40 {
                if summary.exists, summary.label != initial {
                    changed.fulfill()
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        wait(for: [changed], timeout: 15)
    }
```

If `app.otherElements[…]` doesn't match the combined accessibility element, try `app.staticTexts[…]` then `app.descendants(matching: .any)[…]` — pick the first that passes reliably and note which in the report. If a Task-based polling loop is awkward in XCUITest, an equivalent `XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initial), object: summary)` is acceptable — the assertion contract (changes at least once) is what matters.

- [ ] **Step 11: xcodegen + test twice**

```bash
cd /Users/nonplus/Desktop/napkin/Examples/RibHouse && xcodegen
```
Run the full test command once (three snapshots record + fail), then again — Expected: `** TEST SUCCEEDED **` including both new UI tests.

- [ ] **Step 12: Commit**

```bash
git add -A Examples/RibHouse
git commit -m "feat(ribhouse): pushed PitBoardNapkin — the four-seam vertical, live

Fan-out subscriber #2 on PitService.updates(), grouped in the loop
body, presented through an @Observable Presenter subclass into SwiftUI
with animated transitions; specials arrive via Observations bound to
the main actor; the back button's didMove(toParent:) closes the
logical tree — the KVO-replacement pattern, live.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Docs — tutorial gate fences, README blurb + screenshots

**Files:**
- Modify: `Sources/napkin/napkin.docc/Articles/TutorialBuildingALoginFlow.md`
- Modify: `README.md` (example-app section, ~lines 672-690 pre-edit)
- Replace: `Sources/napkin/napkin.docc/Resources/rib-house-logged-in.png`
- Create: `Sources/napkin/napkin.docc/Resources/rib-house-pit-board.png`

**Interfaces:**
- Consumes: final code from Tasks 2–5 (tutorial fences must mirror the real files) and the recorded PNGs from Task 5.

- [ ] **Step 1: Tutorial — update the flow description (line 20)**

Replace the sentence fragment "When the user taps it, the Launch interactor calls `authService.login()`, gets back a `User`, and tells its router to swap to a `LoggedInNapkin` that shows the user's name and a list of barbecue foods. Tapping **Logout** reverses the flow." with:

"When the user taps it, the Launch interactor calls `authService.login()` — and that is all it does. Routing happens in the interactor's *auth gate*: a lifecycle-bound subscription to `authService.userStream()` that swaps to a `LoggedInNapkin` when a `User` arrives and back when it becomes `nil`. Tapping **Logout** reverses the flow the same way: state changes, the gate reacts."

- [ ] **Step 2: Tutorial — replace the gate fences**

Replace the `didBecomeActive` fence (around line 177) and the `loggedOutDidTapLogin` fence (around line 182) with the exact code from `LaunchNapkinInteractor.swift` as it stands after Task 2 (copy from the file, not from this plan). Check the surrounding prose still reads correctly and adjust the one or two sentences that describe the old imperative flow ("calls login and tells the router") to the gate narrative. Also update the flow chain around line 552:

```
Login button tap
  → dispatch { await listener?.didTapLogin() }        (PresentableListener)
  → listener?.loggedOutDidTapLogin()                  (LoggedOutNapkinListener)
  → LaunchInteractor.loggedOutDidTapLogin()           (Launch conforms to the listener)
  → try await authService.login()                     (state changes…)
  → userStream() yields the User                      (…the gate hears it…)
  → router?.attachLoggedIn(user: user)                (…and routes)
```

Search the whole tutorial for any other fence or sentence contradicted by the gate (e.g. a `didBecomeActive` that calls `attachLoggedOut()` directly) and align it. Do NOT add sections about PitBoard/Announcements — the tutorial stays login-scoped.

- [ ] **Step 3: README example-app section**

In the "Runnable example app" section, after the sentence describing the LaunchNapkin/LoggedOut/LoggedIn structure, add:

"The app also exercises every recipe from [Streaming State Down the Tree](#streaming-state-down-the-tree), live: the Launch napkin's auth gate routes from `userStream()`, a `PitService` actor fans out to the LoggedIn header *and* a pushed Pit Board napkin, a headless Announcements napkin consumes the no-replay last-call stream, and the specials list arrives via `Observations`."

Copy the PNGs (names may differ slightly — take the actual recorded files):

```bash
cp Examples/RibHouse/SnapshotTests/__Snapshots__/LoggedInNapkinViewSnapshotTests/testLoggedInNapkinView.1.png Sources/napkin/napkin.docc/Resources/rib-house-logged-in.png
cp Examples/RibHouse/SnapshotTests/__Snapshots__/PitBoardNapkinViewSnapshotTests/testPitBoardNapkinView.1.png Sources/napkin/napkin.docc/Resources/rib-house-pit-board.png
```

Update the LoggedIn screenshot's alt text in README.md to mention the pit summary line and Pit Board button, and add a third image to the screenshot row with alt text describing the Pit Board (stage sections + specials), keeping the existing `<p align="center">` structure and `width="300"` sizing. Update the caption line to name all three napkins.

- [ ] **Step 4: Verify docs build**

Run: `cd /Users/nonplus/Desktop/napkin && swift package generate-documentation --target napkin 2>&1 | tail -3`
Expected: documentation build succeeds (warnings about unrelated pre-existing items are acceptable; new errors are not).

- [ ] **Step 5: Commit**

```bash
git add Sources/napkin/napkin.docc README.md
git commit -m "docs: stream-driven gate in the tutorial; RibHouse screenshots

The login tutorial now teaches the auth-gate narrative (state changes,
the gate reacts) matching the app; README example section points at the
streaming recipes the app now exercises, with a Pit Board screenshot.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Full verification and PR

**Files:** none; verification + PR only.

- [ ] **Step 1: Framework untouched check + build**

Run: `git diff c7bab25..HEAD --stat -- Sources/napkin | cat` — expected: ONLY `napkin.docc` files (tutorial + Resources PNGs); zero `.swift` framework sources.
Run: `cd /Users/nonplus/Desktop/napkin && swift build 2>&1 | tail -2 && swift test 2>&1 | tail -3` — expected: `Build complete!`, all tests passing.

- [ ] **Step 2: Full app test suite**

Run the full xcodebuild test command — expected `** TEST SUCCEEDED **` (2 snapshot suites, extended UI tests).

- [ ] **Step 3: Push and open the PR (base develop, never main)**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git push -u origin feat/ribhouse-streaming
gh pr create --base develop --title "RibHouse: live streaming — auth gate, pit fan-out, pushed Pit Board" --body "$(cat <<'EOF'
## Summary
- The example app now exercises every "Streaming State Down the Tree" recipe live (follow-up to #150):
  - **Auth gate**: `BarbecueAuthService` is an actor broadcaster; the LaunchNapkin routes from `userStream()` — taps only express intent.
  - **Fan-out**: `PitService` streams the smoker board to the LoggedIn header AND a pushed `PitBoardNapkin` (two independent streams from one actor).
  - **Four-seam vertical**: PitBoard groups updates in the loop body, presents through an `@Observable` `Presenter` subclass, renders with animated SwiftUI transitions.
  - **Event bus**: a headless `AnnouncementsNapkin` consumes the no-replay `events()` stream; last-call events surface as an auto-clearing banner.
  - **`@Observable` recipe**: `SpecialsService` observed via `Observations` bound to the main actor.
  - **KVO replacement**: the Pit Board's `didMove(toParent:)` closes the logical tree when the back button pops it.
- Tutorial updated only where the gate changed (state changes, the gate reacts); PitBoard/Announcements intentionally stay out of it.
- New/re-recorded snapshots double as README screenshots (LoggedIn + new Pit Board).

Spec: `docs/superpowers/specs/2026-07-02-ribhouse-streaming-design.md`
Plan: `docs/superpowers/plans/2026-07-02-ribhouse-streaming.md`

## Test plan
- `swift build` / `swift test` (framework untouched) green.
- Full RibHouse suite on iPhone 17 / iOS 26: snapshot tests (LoggedIn ×2, PitBoard) + UI tests (extended login→board→back→logout flow, `-fastTicks` summary-change test).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Stop — merging is the user's call.
