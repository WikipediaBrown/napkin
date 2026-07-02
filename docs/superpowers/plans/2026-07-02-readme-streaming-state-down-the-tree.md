# README "Streaming State Down the Tree" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a README section teaching migrating Combine users how to stream state/events down the napkin tree with Swift Concurrency, backed by CI-compiled snippets, and fix two latent README bugs the compile-probes exposed.

**Architecture:** Four self-contained snippet files under `Snippets/Streaming/` (SwiftPM compiles each as its own target on `swift build`; a broken snippet fails CI — verified empirically). The README section's code blocks are hand-copied mirrors of the snippets' `// snippet.show` regions. The spec is `docs/superpowers/specs/2026-07-02-readme-streaming-state-down-the-tree-design.md`.

**Tech Stack:** Swift 6.2, SwiftPM snippets, napkin 2.x (`Interactable`, `InteractorLifecycle`, `task {}`, `Presenter`, `dispatch {}`), Observation framework (`@Observable`, `Observations`), `AsyncStream.makeStream`.

## Global Constraints

- Platforms: `.iOS(.v26), .macOS(.v26)` (Package.swift). Snippets must compile on **macOS** too — UIKit-only code goes inside `#if canImport(UIKit)`; cross-platform VC classes use a hidden `PlatformViewController` typealias (UIKit/AppKit).
- Snippet conventions (match `Snippets/Patterns/ServiceInjection.swift`, `Snippets/DefiningAFeature/CounterViewController.swift`): `// snippet.hide` / `// snippet.show` markers; each file **fully self-contained** (snippet files are separate modules — duplicate types across files are fine and required).
- No new package dependencies. swift-async-algorithms is only *linked*, never added.
- Branch: `docs/readme-streaming-examples` (already exists, contains the spec). All work commits here. PR back to `develop` (never to `main`).
- Commits: imperative subject, body explains why, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Before every commit, clear iCloud cruft: `find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf`
- **Compile-verified facts you must not "fix" back** (probes run 2026-07-02 on this toolchain):
  - `Presenter<SomeProtocol>` does **not** compile (existentials don't self-conform). Use a concrete VC class as the generic argument.
  - Iterating `Observations` from a nonisolated `@Sendable` closure (e.g. directly inside `task {}` on an actor) **crashes swift-frontend** (signal 6). The working form binds the loop to the main actor: `task { @MainActor [weak self] in for await … in Observations({ … }) { await self?.handle(…) } }` with the service hoisted into a local `let` first.
  - `@Observable` re-annotation on a `Presenter` subclass compiles and is required for the subclass's stored properties to be tracked.
  - The actor-broadcaster + `task { for await user in await self.authService.userStream() }` shape compiles as written below.

---

### Task 1: State snippet — actor broadcaster, auth gate, full vertical

**Files:**
- Create: `Snippets/Streaming/AuthStateStreaming.swift`

**Interfaces:**
- Produces: the `// snippet.show` regions that Task 5 copies verbatim into the README subsections "State: replacing CurrentValueSubject" and "From the service to the screen". Key names later tasks rely on: `actor AuthenticationService` with `func userStream() -> AsyncStream<User?>`, `func signIn(name:) async throws -> User`, `func signOut() async throws`; `RootInteractor`; `ProfileInteractor`; `ProfilePresenter` with `var greeting: String`; `ProfileView`.

- [ ] **Step 1: Write the snippet file**

Create `Snippets/Streaming/AuthStateStreaming.swift` with exactly:

```swift
// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// state (CurrentValueSubject replacement) and the service-to-screen
// vertical. Keep the README code blocks in sync with the
// `snippet.show` regions of this file.
//
import napkin
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
typealias PlatformViewController = NSViewController
#endif

struct User: Sendable, Equatable {
    let name: String
}
// snippet.show

// MARK: - Producer (the service the parent's Component shares)

/// Replaces `CurrentValueSubject`: replays the current value to each new
/// subscriber, fans out to any number of subscribers, and never
/// terminates on error. Same shape as the framework's own
/// `isActiveStream`. The actor is the lock — no `Mutex`, no
/// `@unchecked Sendable`.
actor AuthenticationService {

    private(set) var currentUser: User?
    private var subscribers: [UUID: AsyncStream<User?>.Continuation] = [:]

    /// A fresh stream per subscriber: the current value immediately,
    /// then every change. `AsyncStream` is single-consumer — vending a
    /// new stream per call is what makes fan-out safe.
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

    /// Errors surface here, at the call site that asked — not on the
    /// stream. This is why the Combine version's catch/reset/retry
    /// ceremony has no translation: it has no job left.
    func signIn(name: String) async throws -> User {
        let user = User(name: name)   // e.g. try await backend.signIn()
        setUser(user)
        return user
    }

    func signOut() async throws {
        setUser(nil)                  // e.g. try await backend.signOut()
    }

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

// MARK: - Sharing it down the tree (unchanged from 0.x)

protocol RootDependency: Dependency {}

final class RootComponent: Component<RootDependency>, @unchecked Sendable {
    var authService: AuthenticationService {
        shared { AuthenticationService() }
    }
}

protocol ProfileDependency: Dependency {
    var authService: AuthenticationService { get }
}

extension RootComponent: ProfileDependency {}

// MARK: - Consumer 1: the root auth gate

@MainActor
protocol RootRouting: ViewableRouting {
    func routeToHome(user: User) async
    func routeToLogin() async
}

final actor RootInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: RootRouting?

    private let authService: AuthenticationService

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    func didBecomeActive() async {
        // One long-lived subscription drives routing. Bound to the
        // active scope: cancelled automatically on willResignActive.
        task {
            for await user in await self.authService.userStream() {
                if let user {
                    await self.router?.routeToHome(user: user)
                } else {
                    await self.router?.routeToLogin()
                }
            }
        }
    }
}

// MARK: - Consumer 2: a deeper napkin carries the value to the screen

protocol ProfilePresentable: Presentable, Sendable {
    func present(greeting: String) async
}

final actor ProfileInteractor: PresentableInteractable {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    private let authService: AuthenticationService

    init(presenter: ProfilePresentable, authService: AuthenticationService) {
        self.presenter = presenter
        self.authService = authService
    }

    func didBecomeActive() async {
        task {
            // A second, independent stream from the same service: the
            // root gate above and this napkin both see every change.
            for await user in await self.authService.userStream() {
                // What `.map` did mid-pipeline is now plain code.
                let greeting = user.map { "Welcome back, \($0.name)" } ?? "Signed out"
                // The `await` is the main-actor crossing — this is
                // where `.receive(on: DispatchQueue.main)` went.
                await self.presenter.present(greeting: greeting)
            }
        }
    }
}

// snippet.hide
@MainActor
protocol ProfileViewControllable: ViewControllable {}

@MainActor
final class ProfileViewController: PlatformViewController, ProfileViewControllable {}
// snippet.show

// MARK: - The presenter is the view model

@MainActor
@Observable
final class ProfilePresenter: Presenter<ProfileViewController>, ProfilePresentable {

    var greeting: String = ""

    func present(greeting: String) async {
        self.greeting = greeting
    }
}

struct ProfileView: View {
    @Bindable var presenter: ProfilePresenter

    var body: some View {
        Text(presenter.greeting)
    }
}
```

- [ ] **Step 2: Build to verify the snippet compiles**

Run: `swift build 2>&1 | tail -3`
Expected: `Build complete!` with no errors or warnings mentioning `AuthStateStreaming`.
If it fails, fix the snippet until green — do not weaken the shown API shapes (they're spec'd); scaffolding in `snippet.hide` regions may change freely.

- [ ] **Step 3: Commit**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git add Snippets/Streaming/AuthStateStreaming.swift
git commit -m "docs(snippets): auth-state streaming — actor broadcaster to screen

CurrentValueSubject replacement: replay-latest fan-out actor, root
auth gate, and a second consumer carrying the value through the
presenter into SwiftUI. Compiled by swift build so it cannot rot.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Events snippet — PassthroughSubject replacement

**Files:**
- Create: `Snippets/Streaming/EventStreaming.swift`

**Interfaces:**
- Produces: the `// snippet.show` region Task 5 copies into the README subsection "Events: replacing PassthroughSubject". Key names: `actor AuthEventBus` with `func events() -> AsyncStream<AuthEvent>`, `func send(_:)`; `SessionMonitorInteractor`.

- [ ] **Step 1: Write the snippet file**

Create `Snippets/Streaming/EventStreaming.swift` with exactly:

```swift
// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// events (PassthroughSubject replacement). Keep the README code block
// in sync with the `snippet.show` region of this file.
//
import napkin
import Foundation
// snippet.show

enum AuthEvent: Sendable {
    case sessionExpired
    case passwordChanged
}

/// Replaces `PassthroughSubject`: the same fan-out actor, minus the
/// replay. New subscribers see only events sent after they subscribed.
actor AuthEventBus {

    private var subscribers: [UUID: AsyncStream<AuthEvent>.Continuation] = [:]

    func events() -> AsyncStream<AuthEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: AuthEvent.self)
        let id = UUID()
        subscribers[id] = continuation
        // No `continuation.yield(current)` here — that one line is the
        // whole difference between CurrentValueSubject and
        // PassthroughSubject.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    func send(_ event: AuthEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}

// Consumed exactly like state — a lifecycle-bound task:
final actor SessionMonitorInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    private let eventBus: AuthEventBus

    init(eventBus: AuthEventBus) {
        self.eventBus = eventBus
    }

    func didBecomeActive() async {
        task {
            for await event in await self.eventBus.events() {
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: AuthEvent) { /* … */ }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1 | tail -3`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git add Snippets/Streaming/EventStreaming.swift
git commit -m "docs(snippets): event streaming — PassthroughSubject replacement

Same fan-out actor as the state recipe minus the replay yield; the
one-line diff is the teaching beat.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: @Observable snippet — main-actor state via Observations

**Files:**
- Create: `Snippets/Streaming/ObservableStateStreaming.swift`

**Interfaces:**
- Produces: the `// snippet.show` region Task 5 copies into the README subsection "Main-actor state: @Observable + Observations". Key names: `@MainActor @Observable final class UserService` with `private(set) var currentUser: User?`; `SettingsInteractor`.
- **Constraint (compiler crash):** the `Observations` loop MUST be inside `task { @MainActor [weak self] in … }` with the service hoisted to a local `let` — see Global Constraints.

- [ ] **Step 1: Write the snippet file**

Create `Snippets/Streaming/ObservableStateStreaming.swift` with exactly:

```swift
// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// main-actor state via @Observable + Observations. Keep the README
// code block in sync with the `snippet.show` region of this file.
//
// NOTE: iterating `Observations` directly inside the nonisolated
// `task {}` closure crashes the Swift 6.2 frontend (verified
// 2026-07-02). The `task { @MainActor in … }` binding below is the
// working form — do not "simplify" it.
//
import napkin
import Foundation
import Observation

struct User: Sendable, Equatable {
    let name: String
}
// snippet.show

/// When state is main-actor-friendly anyway — view-adjacent session
/// state, say — skip the hand-rolled fan-out. An `@Observable` class
/// plus `Observations` gives you `CurrentValueSubject` semantics for
/// free: each iterator starts with the current value, and any number
/// of consumers can observe independently.
@MainActor
@Observable
final class UserService {

    private(set) var currentUser: User?

    func set(user: User?) {
        currentUser = user
    }
}

final actor SettingsInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    func didBecomeActive() async {
        // The observation loop runs on the actor that owns the state —
        // bind it to the main actor, and hop back to this actor to
        // handle each value. Still lifecycle-bound: cancelled on
        // willResignActive.
        let userService = self.userService
        task { @MainActor [weak self] in
            for await user in Observations({ userService.currentUser }) {
                await self?.handle(user)
            }
        }
    }

    private func handle(_ user: User?) { /* … */ }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1 | tail -3`
Expected: `Build complete!` — in particular NO `signal 6` / frontend crash.

- [ ] **Step 3: Commit**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git add Snippets/Streaming/ObservableStateStreaming.swift
git commit -m "docs(snippets): @Observable state consumed via Observations

Documents the working isolation shape: the Observations loop bound to
the main actor inside a lifecycle task. Iterating it from the
nonisolated task closure crashes the 6.2 frontend.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: KVO snippet — "not everything becomes a stream"

**Files:**
- Create: `Snippets/Streaming/NotEverythingBecomesAStream.swift`

**Interfaces:**
- Produces: the `// snippet.show` region Task 5 copies into the README callout "Not everything becomes a stream". Key names: `ProfileViewController.didMove(toParent:)`, `ProfilePresentableListener.didDismiss()`.

- [ ] **Step 1: Write the snippet file**

Create `Snippets/Streaming/NotEverythingBecomesAStream.swift` with exactly:

```swift
// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// "Not everything becomes a stream" (KVO publisher replacement).
// UIKit-only by nature; compiles to nothing on macOS.
//
import napkin

#if canImport(UIKit)
import UIKit

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didDismiss() async
}
// snippet.show
final class ProfileViewController: UIViewController {

    weak var listener: ProfilePresentableListener?

    // 0.x observed UIKit with Combine's KVO publisher:
    //
    //     publisher(for: \.parent)
    //         .sink { [weak self] parent in
    //             if parent == nil { self?.listener?.onDismiss() }
    //         }
    //         .store(in: &cancellables)
    //
    // 2.x uses the UIKit callback that KVO was wrapping:
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            dispatch { [listener] in await listener?.didDismiss() }
        }
    }
}
// snippet.hide
#endif
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1 | tail -3`
Expected: `Build complete!` (on macOS the file compiles to an empty module — that is correct; CI's iOS-side coverage comes from the same toolchain's type-checking when the docs pipeline builds for iOS, and the guard matches the existing `CounterViewController.swift` convention).

- [ ] **Step 3: Commit**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git add Snippets/Streaming/NotEverythingBecomesAStream.swift
git commit -m "docs(snippets): KVO publisher pipelines don't become streams

publisher(for: \\.parent) migrates to the UIKit override it was
wrapping, plus dispatch {} to reach the interactor.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: README — new section, ToC, cross-links, and the two latent-bug fixes

**Files:**
- Modify: `README.md` (six edits, exact anchors below — line numbers are pre-edit)

**Interfaces:**
- Consumes: the `snippet.show` regions from Tasks 1–4. Every Swift block in the new section MUST be copied from those regions (imports and hidden scaffolding omitted). If a snippet changed during its build step, copy the final on-disk version, not this plan's.

- [ ] **Step 1: Add the ToC entry**

After the line `- [Routing & Navigation](#routing--navigation)` (line 32), insert:

```markdown
- [Streaming State Down the Tree](#streaming-state-down-the-tree)
```

- [ ] **Step 2: Link the tree-flow sentence (line 90)**

Replace:

```markdown
Data flows down the tree. Events flow up via listener protocols.
```

with:

```markdown
Data flows down the tree. Events flow up via listener protocols. For values that keep changing after a child is built, see [Streaming State Down the Tree](#streaming-state-down-the-tree).
```

- [ ] **Step 3: Fix the Concurrency Model sentence (line 111)**

Replace:

```markdown
Combine has been removed. View-state changes flow through `@Observable` properties on the Presenter; lifecycle-bound subscriptions use `Interactor.task { for await … in Observations { … } }`.
```

with:

```markdown
Combine has been removed. View-state changes flow through `@Observable` properties on the Presenter; lifecycle-bound subscriptions use `task { for await … }` over a service's `AsyncStream` or an `Observations` sequence — recipes in [Streaming State Down the Tree](#streaming-state-down-the-tree).
```

- [ ] **Step 4: Fix the Interactor example (lines 254–261) — latent frontend-crash pattern**

In the `HomeInteractor` example inside **### Interactor**, replace:

```swift
    func didBecomeActive() async {
        // Lifecycle-bound subscription: cancelled automatically on willResignActive.
        task {
            for await user in Observations({ userService.currentUser }) {
                await presenter.presentUser(user)
            }
        }
    }
```

with:

```swift
    func didBecomeActive() async {
        // Lifecycle-bound subscription: cancelled automatically on willResignActive.
        task {
            for await user in await self.userService.userStream() {
                await self.presenter.presentUser(user)
            }
        }
    }
```

And after the paragraph that ends `…cancelled automatically when the interactor deactivates.` (line 279), append to that same paragraph:

```markdown
The service side of `userStream()` — and every other Combine-replacement recipe — is in [Streaming State Down the Tree](#streaming-state-down-the-tree).
```

- [ ] **Step 5: Fix the Presenter example (line 373) — latent compile bug**

In **### Presenter (Optional)**, replace:

```swift
@MainActor
final class HomePresenter: Presenter<HomeViewControllable>, HomePresentable {
```

with:

```swift
@MainActor
@Observable
final class HomePresenter: Presenter<HomeViewController>, HomePresentable {
```

And in **## SwiftUI Integration** (line 601), replace:

```markdown
When you *do* want a separate `@Observable` presenter holding formatted view-state, use the `Presenter` base class as shown in [Core Components](#core-components) — it's parameterized over the `ViewControllable` protocol, which is what keeps that construction acyclic.
```

with:

```markdown
When you *do* want a separate `@Observable` presenter holding formatted view-state, use the `Presenter` base class as shown in [Core Components](#core-components) — it's parameterized over your concrete view-controller type: build the view controller first, hand it to `Presenter`'s initializer, and let the view read the presenter via `@Bindable`. Re-annotate the subclass with `@Observable` so its stored properties are tracked.
```

- [ ] **Step 6: Insert the new section before `## Launching the App` (line 482)**

Insert the following, exactly, between the end of **## Routing & Navigation** and `## Launching the App`. Swift blocks marked `⟨from TaskN⟩` are copied from that task's final on-disk `snippet.show` regions:

````markdown
## Streaming State Down the Tree

Data flows down the napkin tree; events flow up through listener protocols. Build-time injection covers a child's *initial* values — but for values that keep changing (auth state, session data, totals), Combine-era napkin put a subject on a service, shared the service through the parent's `Component`, and let each interested interactor subscribe. That architecture is unchanged: the service is still created once with `shared {}` and threaded down through `Dependency` protocols. Only the streaming primitive changes — and **state** (has a current value) and **events** (fire-and-forget) get different tools.

| Combine | napkin 2.x | Notes |
|---|---|---|
| `CurrentValueSubject` | `actor` service vending replay-latest streams | Replays current value; a fresh stream per subscriber |
| `@Published` / `ObservableObject` | `@Observable` service + `Observations {}` | Multi-consumer; each iterator starts with the current value |
| `PassthroughSubject` | The same fan-out actor, minus the initial `yield` | No replay |
| `.sink {}.store(in: &cancellables)` | `task { for await … }` | Auto-cancelled on deactivate |
| `.subscribe(presenter.someSubject)` | `await presenter.present(…)` in the loop body | Presentable protocols expose async methods, not subjects |
| `.catch` / `.retry` / subject `reset()` | `async throws` at the call site | Streams carry state, not failure; they never terminate on error |
| `.catch { presentError(…); return Just(fallback) }` | `do { for try await … } catch { await presenter.presentError(…) }` | Same terminal semantics as Combine's `.catch`-with-replacement |
| `.map` / transforms mid-pipeline | Plain code in the loop body | It's just a `for` loop |
| `.receive(on: DispatchQueue.main)` | `await presenter.…` | The presenter is `@MainActor`; the crossing is explicit |
| `assign(to:on:)` / nested `ObservableObject` view model | Set the `@Observable` presenter property; SwiftUI reads via `@Bindable` | The view-model layer disappears |
| `tapSubject` on the SwiftUI view + `.sink` in the VC | `dispatch { await listener?.didTapX() }` | See [SwiftUI Integration](#swiftui-integration) |
| `publisher(for: \.keyPath)` (KVO on UIKit objects) | The UIKit override/callback KVO was wrapping + `dispatch {}` | Not every pipe becomes a stream |
| `combineLatest` / `merge` / `debounce` / `removeDuplicates` | [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) | Official Apple package, not part of the standard library |

### State: replacing CurrentValueSubject

The producer side — the half Combine users already wrote themselves and 2.x docs never showed. A service actor owns the current value and fans out to any number of subscribers:

<details>
<summary>The 0.x version this replaces</summary>

```swift
// The manager owned a subject; errors terminated it, so the manager
// grew a reset() that swapped in a fresh subject…
protocol AuthenticationManaging {
    var userSubject: PassthroughSubject<User?, Error> { get }
    func reset() -> AuthenticationManager
    func signIn()
    func signOut()
}

// …and every subscriber needed catch/retry ceremony to survive:
authenticationManager.userSubject
    .catch { error -> PassthroughSubject<User?, Error> in
        self.presenter.presentError(error: error)
        return self.authenticationManager.reset().userSubject
    }
    .retry(.max)
    .assertNoFailure()
    .sink(receiveValue: handleUser)
    .store(in: &cancellables)
```

</details>

⟨from Task 1: `AuthenticationService` actor block⟩

Share it exactly as before — `shared {}` in the parent's `Component`, forwarded through child `Dependency` protocols:

⟨from Task 1: DI wiring block (`RootDependency` through `extension RootComponent: ProfileDependency {}`)⟩

The root napkin's interactor is the auth gate — one lifecycle-bound subscription drives routing:

⟨from Task 1: `RootRouting` + `RootInteractor` block⟩

Note what happened to the error handling: nothing replaced it. `signIn()` is `async throws`, so failures return to the call site that asked; the stream carries only state and can never terminate on error. The `catch`/`retry`/`reset()` chain isn't translated — it's deleted.

Teardown is a closed loop with no leak path: detaching the napkin cancels the `task {}`, cancellation fires the stream's `onTermination`, and `onTermination` removes the subscriber from the actor's table.

### From the service to the screen

One value crosses four seams on its way to a pixel: service → interactor (`task { for await }`), interactor → presenter (an `await`ed async method), presenter → view (`@Observable` read via `@Bindable`), and view → interactor (`dispatch {}`). Here a second napkin, deeper in the tree, subscribes to the *same* service — each `userStream()` call is an independent stream, so fan-out just works — and carries the value through the presenter into SwiftUI:

<details>
<summary>The 0.x version this replaces</summary>

```swift
// The presentable protocol exposed subjects…
protocol ProfilePresentable: Presentable {
    var greeting: PassthroughSubject<String?, Never> { get }
}

// …the interactor piped into them…
userManager.userPublisher
    .map { user in user.map { "Welcome back, \($0.name)" } ?? "Signed out" }
    .subscribe(presenter.greeting)
    .store(in: &cancellables)

// …and the hosting controller re-piped into a nested view model:
greeting
    .receive(on: DispatchQueue.main)
    .assign(to: \.viewModel.greeting, on: rootView)
    .store(in: &cancellables)
```

</details>

⟨from Task 1: `ProfilePresentable` + `ProfileInteractor` block⟩

The presenter *is* the view model. Its `@Observable` stored property replaces the subject, the `assign`, the nested `ObservableObject`, and the `receive(on: main)` — SwiftUI reads it directly:

⟨from Task 1: `ProfilePresenter` + `ProfileView` block⟩

Three notes from real migrations:

- **Many subjects collapse into one presenter.** Parallel subjects (`institutions`, `rank`, `user`) become stored properties on a single presenter — several pipes become several properties, not several streams. Collections included: `var institutions: [Institution]` drives `ForEach` directly, and per-subview view-model construction disappears (child views take presenter properties as plain values).
- **Formatting moves into the presenter.** 0.x ran `compactMap { currencyFormatter.string(from:) }` inside view-controller pipelines; that transform belongs in the presenter method — which is the `Presenter` class's stated job. Where the hosting controller also feeds UIKit chrome (a navigation title, a bar-button label), the same presenter serves both: `@Bindable` for SwiftUI, `Observations {}` for UIKit — see [SwiftUI Integration](#swiftui-integration).
- **Animations.** `.transition` / `.animation(value:)` on the view keep working. Where 0.x relied on implicit animation from `objectWillChange`, wrap the mutation in `withAnimation` inside the presenter method — it's `@MainActor`, so this is legal and local.

### Events: replacing PassthroughSubject

Fire-and-forget events (no current value, no replay) are the same fan-out actor minus one line:

⟨from Task 2: full shown region⟩

> **Warning — `AsyncStream` is single-consumer.** Concurrent iteration of one `AsyncStream` instance is a programmer error ([SE-0314](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)). Never store one stream and hand it to multiple subscribers — vend a fresh stream per subscriber, as both recipes above do. Combine publishers multicast; streams don't.

### Main-actor state: @Observable + Observations

⟨from Task 3: full shown region⟩

`Observations` ([SE-0475](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0475-observed.md)) is multi-consumer and primes each iterator with the current value — `CurrentValueSubject` semantics without writing a broadcaster. The trade-off: the state lives on the main actor, which is right for view-adjacent session state and wrong for business state that belongs off it (see [Concurrency Model](#concurrency-model)).

### Not everything becomes a stream

Combine's KVO publishers were wrapping UIKit callbacks; 2.x uses the callbacks:

⟨from Task 4: `ProfileViewController` block⟩

Tap enums with associated values (`case institution(itemId:institutionId:)`) get the same treatment: they become listener methods with parameters, and the enum-plus-`switch` ceremony deletes.

For operator-heavy pipelines — `combineLatest`, `merge`, `debounce`, `removeDuplicates` — reach for [swift-async-algorithms](https://github.com/apple/swift-async-algorithms), Apple's official package of `AsyncSequence` algorithms. Migration mechanics beyond streaming live in [Migrating from v0](https://getnapkin.to/documentation/napkin/migratingfromv0); lifecycle binding rules in [the lifecycle guide](https://getnapkin.to/documentation/napkin/lifecycle); the `task {}` vs `Task {}` decision rules in [Cross-Isolation Patterns](https://getnapkin.to/documentation/napkin/crossisolationpatterns).
````

- [ ] **Step 7: Verify anchors and mirror-fidelity**

Run: `grep -n 'streaming-state-down-the-tree' README.md` — expected: 4 hits (ToC, line-90 link, Concurrency Model link, Interactor link) plus the heading itself via `grep -n '^## Streaming State Down the Tree' README.md` (1 hit).
Then for each Swift block copied from a snippet, `diff` it mentally against the snippet's `snippet.show` region — they must match token-for-token (no imports, no hidden scaffolding).

- [ ] **Step 8: Commit**

```bash
find /Users/nonplus/Desktop/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
git add README.md
git commit -m "docs(readme): add Streaming State Down the Tree section

The missing producer-side story for Combine migrators: replay-latest
fan-out actor, PassthroughSubject and @Observable variants, the
four-seam service-to-screen vertical, and a mapping table. Also fixes
two latent README bugs the compiled snippets exposed: Presenter
parameterized over a protocol (cannot compile — existentials don't
self-conform) and Observations iterated from the nonisolated task
closure (crashes the Swift 6.2 frontend).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Full verification and PR

**Files:** none created; verification + PR only.

- [ ] **Step 1: Full build and test**

Run: `swift build 2>&1 | tail -2 && swift test 2>&1 | tail -3`
Expected: `Build complete!` and all tests passing (`Test run with N tests passed`).

- [ ] **Step 2: Confirm every snippet target built**

Run: `ls .build/debug | grep -iE 'AuthState|EventStreaming|ObservableState|NotEverything'`
Expected: one binary per snippet (macOS skips none — `NotEverythingBecomesAStream` builds empty but still links).

- [ ] **Step 3: Push and open the PR (to develop, never main)**

```bash
git push -u origin docs/readme-streaming-examples
gh pr create --base develop --title "README: Streaming State Down the Tree (Combine → Swift Concurrency)" --body "$(cat <<'EOF'
## Summary
- New README section teaching the producer side of streaming state/events down the napkin tree — the gap every existing doc left (all showed `for await` consumption of streams no doc ever built).
- Four CI-compiled snippets under `Snippets/Streaming/` back every code block (`swift build` fails if they rot).
- Fixes two latent README bugs the compiled snippets exposed:
  - `Presenter<HomeViewControllable>` cannot compile (existentials don't self-conform) → concrete view-controller type + `@Observable` re-annotation.
  - `task { for await … in Observations({…}) }` on an actor crashes the Swift 6.2 frontend → stream form in the Interactor example; main-actor-bound form documented in the new section.

Spec: `docs/superpowers/specs/2026-07-02-readme-streaming-state-down-the-tree-design.md`

## Follow-ups (not in this PR)
- CHANGELOG 2.0.0 migration step 4 recommends the frontend-crashing `Observations` shape — same fix as the Interactor example.
- Swift bug report for the `Observations`-in-`@Sendable`-closure frontend crash (signal 6, reproducible).
- Lift this section into a DocC article; extend RibHouse with a streaming example; producer-side rows for MigratingFromV0's diff table.

## Test plan
- `swift build` (compiles all four new snippets) and `swift test` green locally.
- README anchors verified (`#streaming-state-down-the-tree` × 4 cross-links).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Stop here — merging is the user's call.
