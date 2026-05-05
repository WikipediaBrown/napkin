# napkin — Swift Concurrency Rearchitecture (Design)

**Status:** Approved (brainstorming phase)
**Date:** 2026-05-04
**Owner:** Wikipedia Brown
**Scope:** Major version bump. All breaking changes acceptable.

## Goal

Rearchitect napkin so its concurrency story is native Swift concurrency, with clean-architecture isolation honored: **business logic lives in the Interactor and runs off the main actor by construction**, and the View↔Interactor seam runs through the Presenter, making UIKit and SwiftUI fully interchangeable. Combine is removed entirely.

## Non-goals

- Backward-compatible migration path for existing consumers. This is a major version; consumers re-adopt.
- Supporting any deployment floor below iOS 26 / macOS 26.
- Rearchitecting RIBs-style patterns (Builder/Interactor/Router/Presenter tree). The patterns stay; their isolation and async surface change.
- Following Uber's RIBs-iOS upstream concurrency direction (PR #49). They are unifying the framework on `@MainActor`. We are deliberately not — see "Divergence from upstream" below.

## Deployment floor

- iOS 26.0, macOS 26.0.
- `swift-tools-version` stays at 6.0 or higher (whatever ships with Xcode targeting iOS 26 SDK), with Swift language mode set to support `isolated deinit` (Swift 6.2+).
- Unlocks: `@Observable` macro, `Observations { }` async sequence builder, `Mutex` from `Synchronization`, region-based isolation, **`isolated deinit`**, full Swift 6 language mode.

## Divergence from upstream RIBs

Uber's `uber/RIBs-iOS` PR #49 unifies the entire framework on `@MainActor` (Interactor, Router, Presenter, Builder, Worker, etc.), reasoning that lifecycle, child attach/detach, and view updates form a single main-thread transaction.

We deliberately diverge: napkin's premise is that **business logic in the Interactor must not be pinned to the main actor**. Clean architecture's dependency rule treats `@MainActor` as a UI-framework concern (outer ring); the Interactor is documented as the home of business logic, so it cannot adopt `@MainActor` without violating the rule the framework claims to enforce.

Concrete consequences of the divergence:

- `await` hops at every Interactor↔Router and Interactor↔Presenter call. Accepted: each `await` documents a real architectural seam.
- `didBecomeActive` / `willResignActive` are `async`, so attaching immutable children inside them requires `await router.attachChild(...)`. Accepted.
- The simple "synchronous activation cascade" RIBs ships becomes a serial `await` chain. Accepted; lifecycle ordering is preserved by serial awaits and by the Router being `@MainActor` (one cascade-driver thread).

We keep three of Uber's PR #49 findings that strengthen our design:

1. **Presenter remains optional** (matches upstream's Default vs ownsView template split). Headless RIBs work.
2. **`isolated deinit`** is used on both `actor Interactor` and `@MainActor Router` for synchronous teardown.
3. **`disposeOnDeactivate` equivalent** — a lifecycle-scoped `Task` cancellation helper, the napkin analog of Uber's Rx-binding helper.

## Isolation model

| Layer | Isolation | Sendability | Mutability story |
|---|---|---|---|
| `ViewControllable` | `@MainActor` | — | UI primitives |
| `Presenter` / `Presentable` | `@MainActor` | — | `@Observable`. Owns view-state. UIKit and SwiftUI views both read from it. **Optional** (only when the napkin owns a view). |
| `Router` / `ViewableRouter` / `LaunchRouter` / `Routing` | `@MainActor` | — | Manages view tree. No locks. `attachChild` / `detachChild` are `async` (await child interactor activation). `isolated deinit` for synchronous teardown. |
| `Interactable` (protocol) + per-feature `final actor` | `actor` | implicit | Business logic, off-main by construction. Protocol composition replaces inheritance because Swift actors cannot be subclassed (SE-0306). Default implementations of `activate()` / `deactivate()` / `task(_:)` / observation are provided via protocol extension; the user-facing override hooks `didBecomeActive` / `willResignActive` are protocol requirements with empty default impls. |
| `InteractorLifecycle` (helper) | `final class`, `Sendable` | `@unchecked Sendable` | The single contained "manually synchronized" type in the framework. Holds `isActive` flag, lifecycle-bound tasks, and `AsyncStream` continuations under a `Synchronization.Mutex`. Exposed to users via the `nonisolated let lifecycle` on every `Interactable` actor; not subclassed. |
| `PresentableInteractable` (protocol) | actor | implicit | Refines `Interactable` with `nonisolated var presenter: PresenterType { get }`. Replaces the old `PresentableInteractor` base class. |
| `Builder` / `Buildable` | non-isolated | `Sendable` | `build(...)` is `async` when it constructs a view controller (hops to `@MainActor`); viewless builders stay sync. |
| `ComponentizedBuilder` / `MultiStageComponentizedBuilder` | non-isolated | `Sendable` | Same async/sync split as `Builder`. |
| `Component` / `Dependency` | non-isolated | `Sendable` | `shared { }` uses `Mutex<[ObjectIdentifier: Any]>` from `Synchronization`. No `NSRecursiveLock`. |

### Why these choices

- **`Interactor` as `actor`** honors clean architecture's dependency rule. Business logic in the Interactor runs off main by construction, without the user having to invent a separate "service" layer to hold it.
- **`Presenter` as `@MainActor @Observable`** is the architectural seam between business logic and view. Interactor sends domain data via `await presenter.update(...)`. View (UIKit or SwiftUI) reads `@Observable` state from Presenter. SwiftUI gets sync `body` reads; UIKit gets imperative reads.
- **Presenter is optional, not mandatory.** Headless napkins (auth gates, deep-link handlers, flow coordinators, analytics) use `Interactor` directly with no Presentable. Napkins with a view use `PresentableInteractor<P>`. Matches Uber's actual template split.
- **Presenter object is optional; Presentable protocol is the mandatory contract.** A view-owning napkin defines `protocol HomePresentable: Presentable { … }`; either a dedicated `Presenter<HomeViewControllable>` subclass or the `UIViewController`/`UIHostingController` itself can conform. Both are valid.
- **`Router` as `@MainActor`** matches what routers actually do: manipulate the view tree. Removes every `Task { @MainActor in }` from consumer routing code. Replaces the `NSLock`-protected `_children` array with plain mutable state.
- **Combine removed entirely.** No `import Combine` in `Sources/napkin`. `@Observable` covers state; `AsyncStream` / `async` functions cover events.
- **`isolated deinit`** preserves synchronous teardown semantics. `Router.deinit` and `Interactor.deinit` can call lifecycle methods on captured references safely without dropping into `Task.detached`.

## Public-API changes

### `Interactable` (protocol) + `InteractorLifecycle` (helper)

Swift actors cannot be subclassed (SE-0306). RIBs's open-class `Interactor` shape is therefore replaced with **protocol composition over a contained lifecycle helper**. Each user feature defines a `final actor` conforming to `Interactable`; default implementations of the lifecycle plumbing are provided by a protocol extension that delegates to a `nonisolated let lifecycle: InteractorLifecycle` property.

```swift
public protocol InteractorScope: AnyObject, Sendable {
    var isActive: Bool { get async }
    nonisolated var isActiveStream: AsyncStream<Bool> { get }
}

public protocol Interactable: Actor, InteractorScope {
    nonisolated var lifecycle: InteractorLifecycle { get }

    /// Override to perform setup when the interactor becomes active.
    func didBecomeActive() async

    /// Override to perform teardown before the interactor becomes inactive.
    func willResignActive() async
}

extension Interactable {
    public var isActive: Bool {
        get async { await lifecycle.isActive }
    }

    public nonisolated var isActiveStream: AsyncStream<Bool> {
        lifecycle.isActiveStream
    }

    public func activate() async {
        await lifecycle.activate { [self] in await self.didBecomeActive() }
    }

    public func deactivate() async {
        await lifecycle.deactivate { [self] in await self.willResignActive() }
    }

    /// Spawn a `Task` whose lifetime is bound to the active scope.
    /// The task is cancelled automatically in `deactivate()`.
    @discardableResult
    public func task(
        priority: TaskPriority? = nil,
        _ work: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> {
        lifecycle.register(priority: priority, work)
    }

    public func didBecomeActive() async {}
    public func willResignActive() async {}
}

/// The contained "manually synchronized" lifecycle helper. The single place in
/// the framework that uses `@unchecked Sendable` + `Mutex`. Auditable as a unit.
public final class InteractorLifecycle: @unchecked Sendable {
    public init() { … }

    public var isActive: Bool { get async { … } }      // mutex-read
    public nonisolated var isActiveStream: AsyncStream<Bool> { … }
    public func activate(invoking didBecomeActive: () async -> Void) async { … }
    public func deactivate(invoking willResignActive: () async -> Void) async { … }
    @discardableResult
    public func register(
        priority: TaskPriority?,
        _ work: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> { … }
}
```

User code shape:

```swift
final actor HomeInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()

    private let userService: UserService
    weak var listener: HomeListener?

    init(userService: UserService) { self.userService = userService }

    func didBecomeActive() async {
        task {
            for await user in self.userService.userStream {
                await self.handle(user)
            }
        }
    }
}
```

The user-visible delta from current napkin: `final class HomeInteractor: Interactor` becomes `final actor HomeInteractor: Interactable` plus one line declaring `lifecycle`. Everything else is the same.

### `PresentableInteractable`

```swift
public protocol PresentableInteractable: Interactable {
    associatedtype PresenterType
    nonisolated var presenter: PresenterType { get }
}
```

User code:

```swift
final actor HomeInteractor: PresentableInteractable {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: HomePresentable

    init(presenter: HomePresentable) { self.presenter = presenter }
}
```

Calls from a `PresentableInteractable` into its `presenter` cross from `actor` to `@MainActor` and use `await`.

### `Router`

```swift
@MainActor
public protocol Routing: AnyObject {
    var interactable: Interactable { get }
    var children: [Routing] { get }
    func load() async
    func loaded() async                     // replaces `lifecycle` publisher
    func attachChild(_ child: Routing) async
    func detachChild(_ child: Routing) async
}

@MainActor
open class Router<InteractorType>: Routing {
    public let interactor: InteractorType
    public let interactable: Interactable
    public init(interactor: InteractorType) { … }
    open func didLoad() async { }
    public final func attachChild(_ child: Routing) async { … }
    public final func detachChild(_ child: Routing) async { … }
    public final func loaded() async { … }

    isolated deinit {
        // Detach remaining children synchronously on the main actor.
        // Activates Interactor.deactivate() via Task at deinit time.
    }
}
```

- `Router` is `@MainActor`. No locks.
- `attachChild` is `async` because it calls `await child.interactable.activate()`.
- `loaded()` replaces the `lifecycle: AnyPublisher<RouterLifecycle, Never>` publisher. Returns once `didLoad()` has completed; subsequent calls return immediately. The `RouterLifecycle` enum is removed.
- `isolated deinit` lets the router synchronously walk its children and unwind state on the main actor's executor without async hops or detached tasks.

### `Presenter`

```swift
@MainActor
public protocol Presentable: AnyObject { }

@MainActor
@Observable
open class Presenter<ViewControllerType: ViewControllable> {
    public let viewController: ViewControllerType
    public init(viewController: ViewControllerType) { … }
}
```

- `@MainActor`, `@Observable`. Subclasses add `@Observable`-tracked stored properties for view-facing state.
- A feature defines `protocol HomePresentable: Presentable { … }` declaring methods the Interactor calls (e.g., `func presentUser(_ user: User)`). These are `@MainActor`-isolated; calls from the `actor` Interactor are `await`.
- The view (UIKit `UIViewController` subclass or SwiftUI `View` reading the Presenter via `@Bindable`) renders from the Presenter's observable state.
- A napkin without a view does not need a Presenter at all (use `Interactor`, not `PresentableInteractor`).

### `Builder`

```swift
public protocol Buildable: AnyObject, Sendable { }

open class Builder<DependencyType>: Buildable {
    public let dependency: DependencyType
    public init(dependency: DependencyType) { … }
}
```

- Concrete `build(withListener:)` overloads on subclasses are `async` when they construct a `UIViewController`/`UIHostingController` (must hop to `@MainActor`); viewless builders keep sync `build(...)`. The base class has no `build` method itself; subclasses define their own as today.
- `ComponentizedBuilder` and `MultiStageComponentizedBuilder` follow the same pattern.

### `Component`

- `shared { … }` uses `Mutex<[ObjectIdentifier: Any]>` from `Synchronization` (replaces the current `NSRecursiveLock`).
- `Component` is `Sendable`.

### Listener protocols (parent ← child events)

- Methods are `async` (parent's `Interactor` is an `actor`).
  ```swift
  protocol HomeListener: AnyObject, Sendable {
      func homeDidRequestLogout() async
  }
  ```

### Routing protocols (interactor → navigation)

- Methods are `async` (router is `@MainActor`, called from `actor` interactor).
  ```swift
  protocol HomeRouting: Routing {
      func routeToProfile() async
      func routeBackFromProfile() async
  }
  ```

### Presentable protocols (interactor → view-state)

- Methods are `async` (presenter is `@MainActor`, called from `actor` interactor).
  ```swift
  protocol HomePresentable: Presentable {
      func presentUser(_ user: User) async
  }
  ```

### PresentableListener (view → interactor events)

- View dispatches via `Task { await listener?.didTap…() }`. The framework provides a small `@MainActor` helper:
  ```swift
  @MainActor
  public func dispatch(_ action: @escaping @Sendable () async -> Void) {
      Task { await action() }
  }
  ```
  Used as `dispatch { await listener?.didTapLogout() }` from a UIKit action or SwiftUI button handler. Naming and exact shape may be refined during implementation.

## Lifecycle cascade

The current `bindSubtreeActiveState` observes the router's own interactor via Combine and cascades activate/deactivate to children. With the new model:

- The only thing that activates a router's interactor is its parent's `attachChild` (or `LaunchRouter.launch` for the root).
- Therefore the router *already knows* when its interactor flips — no observation needed.
- `attachChild(child)` performs in order:
  1. `_children.append(child)` (plain mutation; on `@MainActor`)
  2. `await child.interactable.activate()` — actor hop, awaits user `didBecomeActive`
  3. `await child.load()` — calls user `didLoad`
- `detachChild(child)` performs in order:
  1. `await child.interactable.deactivate()` — actor hop, awaits user `willResignActive`; cancels all tasks registered via `task(_:)`
  2. `_children.removeAll { $0 === child }`
- The recursive `setSubtreeActive` cascade is removed: activation is driven explicitly through `attachChild`/`detachChild` rather than reactively. The current code's reactive subtree cascade was guarding against a case (interactor flipping independently of the parent router) that does not occur in practice; we make this explicit.

## `deinit` semantics with `isolated deinit`

Swift 6.2's `isolated deinit` (available on iOS 26) makes deinitialization run on the actor's executor:

- `Router.deinit` is `isolated` (main actor). It synchronously walks `_children` and detaches them on the main actor, with each child's `interactable.deactivate()` dispatched via a non-blocking `Task` (the deinit can't `await`, but the call is scheduled on the actor and the actor's identity prevents reentrant deallocation issues).
- `Interactor.deinit` is `isolated` (the actor itself). It runs on the actor's executor, so it can synchronously touch isolated state (cancel registered tasks, complete the `isActiveStream` continuation, etc.) without races. This restores the synchronous safety-net semantics current napkin has via `NSRecursiveLock`, but using language-level isolation instead of locking.

This is meaningfully stronger than the "best-effort `Task.detached`" we'd have without `isolated deinit`. Keeping iOS 26 floor is partially justified by this guarantee.

## SwiftUI / UIKit interchangeability

The Presenter is the unified data source. Both view kinds read the same `@Observable` state.

**SwiftUI:**
```swift
@MainActor
final class HomePresenter: Presenter<HomeHostingController>, HomePresentable {
    var displayName: String = ""
    func presentUser(_ user: User) async {
        displayName = "\(user.firstName) \(user.lastName)"
    }
}

struct HomeView: View {
    @Bindable var presenter: HomePresenter
    weak var listener: HomePresentableListener?
    var body: some View {
        VStack {
            Text(presenter.displayName)
            Button("Logout") { dispatch { await listener?.didTapLogout() } }
        }
    }
}
```

**UIKit:**
```swift
@MainActor
final class HomeViewController: UIViewController, HomeViewControllable {
    private let presenter: HomePresenter
    private var observation: Task<Void, Never>?

    init(presenter: HomePresenter) { self.presenter = presenter; super.init(nibName: nil, bundle: nil) }

    override func viewDidLoad() {
        super.viewDidLoad()
        observation = Task { @MainActor in
            for await name in Observations({ presenter.displayName }) {
                self.nameLabel.text = name
            }
        }
    }

    deinit { observation?.cancel() }
}
```

Both views read from the same Presenter. The Interactor is unchanged across the two.

## Headless napkin (no view, no Presenter)

```swift
final actor AnalyticsInteractor: Interactor, AnalyticsInteractable {
    private let service: AnalyticsService

    init(service: AnalyticsService) {
        self.service = service
        super.init()
    }

    override func didBecomeActive() async {
        await super.didBecomeActive()
        task {
            for await event in self.service.eventStream {
                await self.service.record(event)
            }
        }
    }
}

final class AnalyticsRouter: Router<AnalyticsInteractable>, AnalyticsRouting {
    // No view. attachChild via parent router only.
}
```

No Presenter, no `@MainActor` machinery, business logic stays in the Interactor.

## Files touched

- `Sources/napkin/Interactor.swift` — replaced with `Interactable` protocol + protocol extension default impls + `PresentableInteractable` refinement. Combine removed. (No more `class Interactor`; the file is renamed conceptually but kept at the same path for git history.)
- `Sources/napkin/InteractorLifecycle.swift` — **new file**. Contains the `final class InteractorLifecycle` helper with `Mutex`-synchronized state, the `task(_:)` storage, and `AsyncStream` continuation management.
- `Sources/napkin/PresentableInteractor.swift` — file deleted; `PresentableInteractable` now lives in `Interactor.swift` next to `Interactable`.
- `Sources/napkin/Router.swift` — `@MainActor`, locks removed, async attach/detach, cascade simplified, Combine removed, `isolated deinit`.
- `Sources/napkin/ViewableRouter.swift` — `@MainActor`, no `Task { @MainActor in }` patterns.
- `Sources/napkin/LaunchRouter.swift` — `@MainActor`, async launch path.
- `Sources/napkin/Presenter.swift` — `@MainActor`, `@Observable`, optional in feature stacks.
- `Sources/napkin/Builder.swift` — `Sendable`, no behavioral change to base class.
- `Sources/napkin/ComponentizedBuilder.swift` — `Sendable`, no Combine.
- `Sources/napkin/MultiStageComponentizedBuilder.swift` — `Sendable`, no Combine.
- `Sources/napkin/ViewControllable.swift` — verify no Combine; otherwise unchanged.
- `Sources/napkin/DI/Component.swift` — `Mutex` instead of `NSRecursiveLock`, `Sendable`.
- `Sources/napkin/DI/Dependency.swift` — `Sendable`.
- `Tests/napkinTests/*` — rewritten for actor/MainActor isolation, async test methods, no Combine.
- `Tools/napkin/*.xctemplate/*` — updated templates emit the new API shape; preserve "headless" vs "owns view" template split.
- `Examples/LaunchNapkin/*` — rewritten against the new API.
- `Package.swift` — `platforms: [.iOS(.v26), .macOS(.v26)]`.
- `README.md` — Concurrency Model section rewritten; all code examples updated; explicit note on divergence from upstream RIBs concurrency direction.

## Versioning

Major version bump. Breaking changes are explicit, total, and intentional. CHANGELOG entry summarizes the migration and notes the divergence from upstream RIBs concurrency.

## Open questions to resolve in the implementation plan

- Exact name and shape of the `dispatch { … }` helper for view→interactor event forwarding.
- Whether `loaded() async` blocks indefinitely if the router is detached before loading, or returns/throws. Lean: returns immediately; document.
- Whether `Component.shared { }` should expose a non-blocking variant when a key is already present. Current behavior: brief `Mutex` block.
- Exact API of `Interactor.task(_:)` — return a handle for explicit cancellation, or fire-and-forget with cancellation only via lifecycle? Lean: fire-and-forget for the common case, plus a handle-returning variant.
- Whether `isActiveStream` exposes a fresh `AsyncStream` per call (multiple-consumer) or a shared one (single-consumer). Lean: fresh per call, with a small broadcaster behind it.
- How the templates split between "headless" and "owns view" — naming, content, and which is the default Xcode template entry.

These are scoped to implementation; design is approved.
