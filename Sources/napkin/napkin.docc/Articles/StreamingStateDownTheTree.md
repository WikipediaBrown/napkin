# Streaming State Down the Tree

How to replace Combine's `CurrentValueSubject`, `PassthroughSubject`, and `@Published` with actor-owned `AsyncStream`s and `Observations` sequences, consumed through lifecycle-bound ``Interactable/task(priority:_:)`` loops. The state recipe mirrors the shape of the framework's own ``InteractorScope/isActiveStream``.

## Overview

Data flows down the napkin tree; events flow up through listener protocols. Build-time injection covers a child's *initial* values — but for values that keep changing (auth state, session data, totals), Combine-era napkin put a subject on a service, shared the service through the parent's ``Component``, and let each interested interactor subscribe. That architecture is unchanged: the service is still created once with ``Component/shared(forCallerKey:_:)`` and threaded down through ``Dependency`` protocols. Only the streaming primitive changes — and **state** (has a current value) and **events** (fire-and-forget) get different tools.

> Note: Every napkin 2.x code block on this page is copied from the `snippet.show` region of a file under `Snippets/Streaming/`; `swift build` compiles them, so the examples here can't silently drift from working code. This article mirrors README.md's identically-titled section.

| Combine | napkin 2.x | Notes |
|---|---|---|
| `CurrentValueSubject` | `actor` service vending replay-latest streams | Replays current value; a fresh stream per subscriber |
| `@Published` / `ObservableObject` | `@Observable` service + `Observations {}` | Multi-consumer; each iterator starts with the current value |
| `PassthroughSubject` | The same fan-out actor, minus the initial `yield` | No replay |
| `.sink {}.store(in: &cancellables)` | `task { for await … }` | Auto-cancelled on deactivate |
| `.subscribe(presenter.someSubject)` | `await presenter.present(…)` in the loop body | Presentable protocols expose async methods, not subjects |
| `.catch` / `.retry` / subject `reset()` | `async throws` at the call site | Streams carry state, not failure; they never terminate on error |
| `.catch { presentError(…); return Just(fallback) }` | `do { for try await … } catch { await presenter.presentError(…) }` | Both are terminal — emit a fallback in the `catch` if you need one |
| `.map` / transforms mid-pipeline | Plain code in the loop body | It's just a `for` loop |
| `.receive(on: DispatchQueue.main)` | `await presenter.…` | The presenter is `@MainActor`; the crossing is explicit |
| `assign(to:on:)` / nested `ObservableObject` view model | Set the `@Observable` presenter property; SwiftUI reads it directly | The view-model layer disappears |
| `tapSubject` on the SwiftUI view + `.sink` in the VC | `dispatch { await listener?.didTapX() }` | See <doc:SwiftUIIntegration> |
| `publisher(for: \.keyPath)` (KVO on UIKit objects) | The UIKit override/callback KVO was wrapping + `dispatch {}` | Not every pipe becomes a stream |
| `combineLatest` / `merge` / `debounce` / `removeDuplicates` | [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) | Official Apple package, not part of the standard library |

## State: replacing CurrentValueSubject

The producer side — the half Combine users already wrote themselves and 2.x docs never showed. A service actor owns the current value and fans out to any number of subscribers:

### The 0.x producer this replaces

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

```swift
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

    /// Adapting a callback API — the 0.x manager wrapped an auth
    /// SDK's state-change listener; the 2.x service hops the callback
    /// onto the actor:
    func bind(to auth: AuthClient) {
        auth.addStateDidChangeListener { user in
            Task { await self.setUser(user) }
        }
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
```

Share it exactly as before — ``Component/shared(forCallerKey:_:)`` in the parent's ``Component``, forwarded through child ``Dependency`` protocols:

```swift
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
```

The root napkin's interactor is the auth gate — one lifecycle-bound subscription drives routing:

```swift
@MainActor
protocol RootRouting: ViewableRouting, Sendable {
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
```

Note what happened to the error handling: nothing replaced it. `signIn()` is `async throws`, so failures return to the call site that asked; the stream carries only state and can never terminate on error. The `catch`/`retry`/`reset()` chain isn't translated — it's deleted.

Teardown is a closed loop with no leak path: detaching the napkin cancels the `task {}`, cancellation fires the stream's `onTermination`, and `onTermination` removes the subscriber from the actor's table.

## From the service to the screen

One value crosses four seams on its way to a pixel: service → interactor (`task { for await }`), interactor → presenter (an `await`ed async method), presenter → view (a direct `@Observable` read), and view → interactor (`dispatch {}`). Here a second napkin, deeper in the tree, subscribes to the *same* service — each `userStream()` call is an independent stream, so fan-out just works. Because every stream starts with the current value, a napkin attached after login learns the auth state immediately — an upgrade over the PassthroughSubject original, where late subscribers waited for the next change. It carries the value through the presenter into SwiftUI:

### The 0.x pipeline this replaces

```swift
// The presentable protocol exposed subjects…
protocol ProfilePresentable: Presentable {
    var greeting: PassthroughSubject<String, Never> { get }
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

```swift
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
```

The presenter *is* the view model. Its `@Observable` stored property replaces the subject, the `assign`, the nested `ObservableObject`, and the `receive(on: main)` — SwiftUI reads it directly. Hold the presenter weakly (it owns the view controller that owns the view), and rebind with `@Bindable` inside `body` when you need two-way bindings:

```swift
@MainActor
@Observable
final class ProfilePresenter: Presenter<ProfileViewController>, ProfilePresentable {

    var greeting: String = ""

    func present(greeting: String) async {
        self.greeting = greeting
    }
}

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

(``Presenter``'s generic argument is your concrete hosting controller — here `ProfileViewController`, built by the feature's builder. A protocol can't satisfy it: existentials don't conform to their own protocols.)

Three notes from real migrations:

- **Many subjects collapse into one presenter.** Parallel subjects (`institutions`, `rank`, `user`) become stored properties on a single presenter — several pipes become several properties, not several streams. Collections included: `var institutions: [Institution]` drives `ForEach` directly, and per-subview view-model construction disappears (child views take presenter properties as plain values).
- **Formatting moves into the presenter.** 0.x ran `compactMap { currencyFormatter.string(from:) }` inside view-controller pipelines; that transform belongs in the presenter method — which is the ``Presenter`` class's stated job. Where the hosting controller also feeds UIKit chrome (a navigation title, a bar-button label), the same presenter serves both: a direct read for SwiftUI, `Observations {}` for UIKit — see <doc:SwiftUIIntegration>.
- **Animations.** `.transition` / `.animation(value:)` on the view keep working. Where 0.x relied on implicit animation from `objectWillChange`, wrap the mutation in `withAnimation` inside the presenter method — it's `@MainActor`, so this is legal and local.

## Events: replacing PassthroughSubject

Fire-and-forget events (no current value, no replay) are the same fan-out actor minus the replay:

```swift
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
        // No stored current value and no initial yield — the replay
        // is the whole difference between CurrentValueSubject and
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

> Warning: `AsyncStream` is single-consumer. Concurrent iteration of one `AsyncStream` instance is a programmer error ([SE-0314](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)). Never store one stream and hand it to multiple subscribers — vend a fresh stream per subscriber, as both recipes above do. Combine publishers multicast; streams don't.

## Main-actor state: @Observable + Observations

```swift
/// When state is main-actor-friendly anyway — view-adjacent session
/// state, say — skip the hand-rolled fan-out. An `@Observable` class
/// plus `Observations` gives you `CurrentValueSubject` semantics for
/// free: each iterator starts with the current value, and any number
/// of consumers can observe independently.
@MainActor
@Observable
final class SessionService {

    private(set) var currentUser: User?

    func set(user: User?) {
        currentUser = user
    }
}

final actor SettingsInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }

    func didBecomeActive() async {
        // The observation loop runs on the actor that owns the state —
        // bind it to the main actor, and hop back to this actor to
        // handle each value. Still lifecycle-bound: cancelled on
        // willResignActive.
        let sessionService = self.sessionService
        task { @MainActor [weak self] in
            for await user in Observations({ sessionService.currentUser }) {
                await self?.handle(user)
            }
        }
    }

    private func handle(_ user: User?) { /* … */ }
}
```

`Observations` ([SE-0475](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0475-observed.md)) is multi-consumer and primes each iterator with the current value — `CurrentValueSubject` semantics without writing a broadcaster. The trade-off: the state lives on the main actor, which is right for view-adjacent session state and wrong for business state that belongs off it (see <doc:CrossIsolationPatterns>).

## Not everything becomes a stream

Combine's KVO publishers were wrapping UIKit callbacks; 2.x uses the callbacks:

```swift
@MainActor
final class ProfileViewController: UIViewController {

    weak var listener: ProfilePresentableListener?

    // 0.x observed UIKit with Combine's KVO publisher:
    //
    //     publisher(for: \.parent)
    //         .sink { [weak self] parent in
    //             if parent == nil { self?.listener?.didDismiss() }
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
```

Tap enums with associated values (`case institution(itemId:institutionId:)`) get the same treatment: they become listener methods with parameters, and the enum-plus-`switch` ceremony deletes.

For operator-heavy pipelines — `combineLatest`, `merge`, `debounce`, `removeDuplicates` — reach for [swift-async-algorithms](https://github.com/apple/swift-async-algorithms), Apple's official package of `AsyncSequence` algorithms. Migration mechanics beyond streaming live in <doc:MigratingFromV0>; lifecycle binding rules in <doc:Lifecycle>; the `task {}` vs `Task {}` decision rules in <doc:CrossIsolationPatterns>.

## Cross-references

- ``Interactable/task(priority:_:)`` — the lifecycle-bound task every recipe on this page subscribes from.
- ``InteractorScope/isActiveStream`` — the framework's own instance of the replay-latest, fan-out pattern shown in the producer recipe above.
- ``Component`` / ``Dependency`` — how the streaming service is shared down the tree, unchanged from before.
- ``Presenter`` — the `@Observable` view-state holder the consumer recipes present into.

## See Also

- <doc:MigratingFromV0>
- <doc:Lifecycle>
- <doc:CrossIsolationPatterns>
- <doc:SwiftUIIntegration>
