# napkin — Swift Concurrency Rearchitecture (Design)

**Status:** Approved (brainstorming phase)
**Date:** 2026-05-04
**Owner:** Wikipedia Brown
**Scope:** Major version bump. All breaking changes acceptable.

## Goal

Rearchitect napkin so its concurrency story is native Swift concurrency, with clean-architecture isolation honored: business logic (Interactor) is **off the main actor by construction**, and the View↔Interactor seam runs through the Presenter, making UIKit and SwiftUI fully interchangeable. Combine is removed entirely.

## Non-goals

- Backward-compatible migration path for existing consumers. This is a major version; consumers re-adopt.
- Supporting any deployment floor below iOS 26 / macOS 26.
- Rearchitecting RIBs-style patterns (Builder/Interactor/Router/Presenter tree). The patterns stay; their isolation and async surface change.

## Deployment floor

- iOS 26.0, macOS 26.0.
- `swift-tools-version` stays at 6.0 or higher (whatever ships with Xcode targeting iOS 26 SDK).
- Unlocks: `@Observable` macro, `Observations { }` async sequence builder, `Mutex` from `Synchronization`, region-based isolation, full Swift 6 language mode features.

## Isolation model

| Layer | Isolation | Sendability | Mutability story |
|---|---|---|---|
| `ViewControllable` | `@MainActor` | — | UI primitives |
| `Presenter` / `Presentable` | `@MainActor` | — | `@Observable`. Owns view-state. UIKit and SwiftUI views both read from it. **Mandatory**, not optional. |
| `Router` / `ViewableRouter` / `LaunchRouter` / `Routing` | `@MainActor` | — | Manages view tree. No locks. `attachChild` / `detachChild` are `async`. |
| `Interactor` / `PresentableInteractor` / `Interactable` | `actor` | implicit | Business logic. `activate()` / `deactivate()` and `didBecomeActive` / `willResignActive` are `async`. |
| `Builder` / `Buildable` | non-isolated | `Sendable` | `build(...)` is `async` when it constructs a view controller (hops to `@MainActor`); viewless builders stay sync. |
| `ComponentizedBuilder` / `MultiStageComponentizedBuilder` | non-isolated | `Sendable` | Same async/sync split as `Builder`. |
| `Component` / `Dependency` | non-isolated | `Sendable` | `shared { }` uses `Mutex<[ObjectIdentifier: Any]>` from `Synchronization`. No `NSRecursiveLock`. |

### Why these choices

- **`Interactor` as `actor`** honors clean architecture's dependency rule: the inner ring (use cases / business rules) does not depend on the outer ring (UI frameworks / `@MainActor`). Business logic runs off main by construction.
- **`Presenter` as `@MainActor @Observable`** is the architectural seam. The Interactor sends domain data across the seam via `await presenter.update(...)`. The view (UIKit or SwiftUI) reads `@Observable` state from the Presenter. SwiftUI gets sync `body` reads; UIKit gets imperative reads — both natural.
- **`Router` as `@MainActor`** matches what routers actually do: manipulate the view tree. Removes every `Task { @MainActor in }` from consumer routing code. Replaces the `NSLock`-protected `_children` array with plain mutable state.
- **Combine removed entirely.** No `import Combine` in `Sources/napkin`. `@Observable` covers state; `AsyncStream` / `async` functions cover events.

## Public-API changes

### `Interactor`
```swift
public protocol InteractorScope: AnyObject, Sendable {
    var isActive: Bool { get async }
    var isActiveStream: AsyncStream<Bool> { get }
}

public protocol Interactable: InteractorScope {
    func activate() async
    func deactivate() async
}

open actor Interactor: Interactable {
    public init() { … }
    open func didBecomeActive() async { }
    open func willResignActive() async { }
}
```
- `isActive` reads are `async` (actor isolation).
- `isActiveStream` is exposed for any off-main consumers that want to observe lifecycle; the framework itself does not consume it (see "Lifecycle cascade" below).

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
}
```
- `Router` is `@MainActor`. No locks.
- `attachChild` is `async` because it calls `await child.interactable.activate()`.
- `loaded()` is the replacement for the `lifecycle: AnyPublisher<RouterLifecycle, Never>` publisher: it returns once `didLoad()` has run; subsequent calls return immediately. The `RouterLifecycle` enum is removed.

### `Presenter`
```swift
@MainActor
@Observable
open class Presenter<ViewControllerType: ViewControllable> {
    public let viewController: ViewControllerType
    public init(viewController: ViewControllerType) { … }
}

@MainActor
public protocol Presentable: AnyObject { }
```
- `Presenter` is `@MainActor` and `@Observable`. Subclasses add `@Observable`-tracked stored properties for view-facing state.
- A typical feature defines `protocol HomePresentable: Presentable { … }` declaring methods the Interactor calls (e.g., `func presentUser(_ user: User)`). These are `@MainActor`-isolated; calls from the `actor` Interactor are `await`.
- The view (UIKit `UIViewController` subclass or SwiftUI `View` reading the Presenter as `@Bindable`/`@State`) renders from the Presenter's observable state.

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
- View dispatches via `Task { await listener?.didTap…() }`. The framework provides a small helper:
  ```swift
  @MainActor
  public func dispatch(_ action: @escaping @Sendable () async -> Void) {
      Task { await action() }
  }
  ```
  Used as `dispatch { await listener?.didTapLogout() }` from a UIKit action or SwiftUI button handler. Naming and exact shape may be refined during implementation.

## Lifecycle cascade

The current `bindSubtreeActiveState` observes the router's own interactor via Combine and cascades activate/deactivate to children. With the new model:

- The only thing that activates a router's interactor is its parent's `attachChild` (and the root's `LaunchRouter.launch`).
- Therefore the router *already knows* when its interactor flips — no observation needed.
- `attachChild(child)` performs in order:
  1. `_children.append(child)` (plain mutation; on `@MainActor`)
  2. `await child.interactable.activate()` — actor hop, awaits user `didBecomeActive`
  3. `await child.load()` — calls user `didLoad`
- `detachChild(child)` performs in order:
  1. `await child.interactable.deactivate()` — actor hop, awaits user `willResignActive`
  2. `_children.removeAll { $0 === child }`
- The recursive `setSubtreeActive` cascade is removed because activation is now driven explicitly through `attachChild`/`detachChild` rather than reactively. The current code's reactive subtree cascade was guarding against a case (interactor flipping independently of the parent router) that does not occur in practice; we make this explicit.

## `deinit` semantics

- Today `Interactor.deinit` calls `deactivate()` synchronously as a safety net; `Router.deinit` calls `interactable.deactivate()` and `detachAllChildren()`.
- With `actor` Interactor, those calls cannot be `await`ed from `deinit`.
- New contract: **the router that attached a child is responsible for detaching it before dropping.** `LaunchRouter` cleans up the full tree on app termination.
- Best-effort safety net in `Router.deinit`: spawn a `Task.detached` that awaits `interactable.deactivate()` on captured references. Documented as best-effort, not guaranteed.
- This is weaker than today's synchronous safety net. We accept this cost. Tests will assert correct teardown ordering rather than relying on `deinit`.

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
}
```

Both views read from the same Presenter. The Interactor is unchanged across the two.

## Files touched

- `Sources/napkin/Interactor.swift` — rewritten as `actor`, Combine removed.
- `Sources/napkin/PresentableInteractor.swift` — actor, async overrides.
- `Sources/napkin/Router.swift` — `@MainActor`, locks removed, async attach/detach, cascade simplified, Combine removed.
- `Sources/napkin/ViewableRouter.swift` — `@MainActor`, no longer needs `Task { @MainActor in }` patterns.
- `Sources/napkin/LaunchRouter.swift` — `@MainActor`, async launch path.
- `Sources/napkin/Presenter.swift` — `@MainActor`, `@Observable`, mandatory in feature stacks.
- `Sources/napkin/Builder.swift` — `Sendable`, no behavioral change to base class.
- `Sources/napkin/ComponentizedBuilder.swift` — `Sendable`, no Combine.
- `Sources/napkin/MultiStageComponentizedBuilder.swift` — `Sendable`, no Combine.
- `Sources/napkin/ViewControllable.swift` — unchanged in spirit; verify no Combine.
- `Sources/napkin/DI/Component.swift` — `Mutex` instead of `NSRecursiveLock`, `Sendable`.
- `Sources/napkin/DI/Dependency.swift` — `Sendable`.
- `Tests/napkinTests/*` — rewritten for actor/MainActor isolation, async test methods, no Combine.
- `Tools/napkin/*.xctemplate/*` — updated templates emit the new API shape.
- `Examples/LaunchNapkin/*` — rewritten against the new API.
- `Package.swift` — `platforms: [.iOS(.v26), .macOS(.v26)]`.
- `README.md` — Concurrency Model section rewritten; all code examples updated.

## Versioning

Major version bump. Breaking changes are explicit, total, and intentional. CHANGELOG entry summarizes the migration.

## Open questions to resolve in the implementation plan

- Exact name and shape of the `dispatch { … }` helper for view→interactor event forwarding.
- Whether `loaded() async` blocks indefinitely if the router is detached before loading, or returns/throws (lean toward: returns immediately; document).
- Whether `Component.shared { }` should expose a non-blocking variant if a key is already present (current behavior: blocks briefly under `Mutex`).
- How (and whether) to provide a sync convenience for testing where awaiting actor lifecycle is tedious — likely: tests just become `async`, since `swift-testing` supports it natively.

These are scoped to implementation; design is approved.
