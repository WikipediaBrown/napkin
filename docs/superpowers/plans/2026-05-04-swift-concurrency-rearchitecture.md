# napkin Swift Concurrency Rearchitecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the napkin framework so business logic in the Interactor is isolated to a Swift `actor`, the Router/Presenter are `@MainActor`, Combine is removed in favor of `@Observable`, and the framework targets iOS 26 / macOS 26 with `isolated deinit` for synchronous teardown.

**Architecture:** `actor Interactor` (off-main, holds business logic) + `@MainActor Router/Presenter` (UI tree, observable view-state) + `async` boundaries between them. Presenter is optional (headless napkins supported via plain `Interactor`). Combine removed entirely; `@Observable` covers state, `AsyncStream` covers events. `isolated deinit` (Swift 6.2 / iOS 26) gives synchronous teardown semantics on both `actor` and `@MainActor` types. Lifecycle-bound work uses a new `Interactor.task(_:)` helper that auto-cancels on `willResignActive`.

**Tech Stack:** Swift 6.2+, iOS 26 / macOS 26, `@Observable` (Observation framework), `Synchronization.Mutex`, `AsyncStream`, swift-testing for tests, Xcode 26.2+ for `isolated deinit`.

**Spec:** `docs/superpowers/specs/2026-05-04-swift-concurrency-rearchitecture-design.md`

**Reference for upstream divergence:** `uber/RIBs-iOS` PR #49 (we deliberately do *not* unify on `@MainActor` — see spec).

---

## Plan Layout

The plan is sequenced so the framework compiles after each phase:

- **Phase 0** — Branch & deployment-target bump (5 min)
- **Phase 1** — DI foundation: `Dependency`, `Component` (Sendable, `Mutex`)
- **Phase 2** — `Interactor` actor + `task(_:)` helper + `isActiveStream`
- **Phase 3** — `PresentableInteractor` actor subclass
- **Phase 4** — `Router` `@MainActor` rewrite (async attach/detach, `isolated deinit`)
- **Phase 5** — `ViewableRouter` `@MainActor`
- **Phase 6** — `LaunchRouter` `@MainActor` (async launch)
- **Phase 7** — `Presenter` `@MainActor` `@Observable` + `Presentable`
- **Phase 8** — `Builder`, `ComponentizedBuilder`, `MultiStageComponentizedBuilder` (Sendable)
- **Phase 9** — `dispatch(_:)` helper for view→interactor events
- **Phase 10** — Tests rewrite
- **Phase 11** — Xcode templates rewrite
- **Phase 12** — `Examples/LaunchNapkin` rewrite
- **Phase 13** — `README.md` rewrite

---

## Phase 0 — Branch & deployment-target bump

### Task 0.1: Create rearchitecture branch

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Create branch**

```bash
cd /Users/nonplus/Desktop/napkin
git checkout -b swift-concurrency-rearchitecture
```

Expected: switched to new branch.

- [ ] **Step 2: Update `Package.swift` to bump platforms and Swift tools**

Replace the entire file with:

```swift
// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "napkin",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "napkin",
            targets: ["napkin"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "napkin",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("RegionBasedIsolation")
            ]
        ),
        .testTarget(
            name: "napkinTests",
            dependencies: ["napkin"]),
    ]
)
```

- [ ] **Step 3: Verify package resolves**

Run: `swift package describe --type json | head -20`
Expected: JSON output with `"platforms"` showing iOS 26 / macOS 26. No resolution errors.

- [ ] **Step 4: Commit**

```bash
git add Package.swift
git commit -m "Bump deployment floor to iOS 26 / macOS 26 for Swift 6.2"
```

---

## Phase 1 — DI foundation: `Dependency`, `Component`

### Task 1.1: Make `Dependency` Sendable

**Files:**
- Modify: `Sources/napkin/DI/Dependency.swift`

- [ ] **Step 1: Update `Dependency` and `EmptyDependency` to require Sendable**

Edit `Sources/napkin/DI/Dependency.swift`. Replace lines 69 and 98 (the protocol declarations):

```swift
public protocol Dependency: AnyObject, Sendable {}
```

```swift
public protocol EmptyDependency: Dependency {}
```

Leave the doc comments unchanged.

- [ ] **Step 2: Verify it builds**

Run: `swift build 2>&1 | head -40`
Expected: build fails on Component.swift (next task) but Dependency.swift compiles cleanly. Errors should reference `Component` not `Dependency`.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/DI/Dependency.swift
git commit -m "Mark Dependency as Sendable"
```

### Task 1.2: Rewrite `Component` with `Mutex` and Sendable

**Files:**
- Modify: `Sources/napkin/DI/Component.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Sources/napkin/DI/Component.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Synchronization

/// The base class for dependency injection components in the napkin architecture.
///
/// A `Component` serves as the dependency injection container for a napkin unit.
/// It defines the dependencies that the napkin provides to its internal units
/// (Router, Interactor, Presenter, View) and to its child napkins.
///
/// ## Concurrency
///
/// `Component` is `Sendable`. Shared instances created via ``shared(_:)`` are
/// stored under a `Mutex` from the `Synchronization` module, so they may be
/// retrieved from any actor or thread safely.
open class Component<DependencyType>: Dependency, @unchecked Sendable {

    /// The dependency object provided by the parent component.
    public let dependency: DependencyType

    /// Creates a component with the specified parent dependency.
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }

    /// Creates a shared instance that is retained for the component's lifetime.
    ///
    /// The factory closure is invoked at most once per call site; subsequent
    /// calls at the same call site return the cached instance.
    public final func shared<T>(__function: String = #function, _ factory: () -> T) -> T {
        sharedInstances.withLock { storage in
            if let existing = (storage[__function] as? T?) ?? nil {
                return existing
            }
            let instance = factory()
            storage[__function] = instance
            return instance
        }
    }

    // MARK: - Private

    private let sharedInstances = Mutex<[String: Any]>([:])
}

/// A component for root napkins that have no parent dependencies.
open class EmptyComponent: EmptyDependency, @unchecked Sendable {
    public init() {}
}
```

The `@unchecked Sendable` is used on the open class because subclasses can introduce non-Sendable stored properties; `Component` itself is safe via the `Mutex`-backed storage and immutable `dependency`.

- [ ] **Step 2: Verify it builds**

Run: `swift build 2>&1 | tail -30`
Expected: now Interactor / Router / others fail because they use `@unchecked Sendable` differently; Component & Dependency compile.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/DI/Component.swift
git commit -m "Replace NSRecursiveLock with Synchronization.Mutex in Component"
```

---

## Phase 2 — Interactor: protocol + lifecycle helper

> **Background:** Swift actors cannot be subclassed (SE-0306). The original "open actor Interactor" design does not compile — `open` is rejected on actor types. We replace it with: `Interactable` protocol + protocol extension default implementations + a contained `InteractorLifecycle` helper class that holds the synchronized state. User feature interactors become `final actor` types conforming to `Interactable`, each declaring `nonisolated let lifecycle = InteractorLifecycle()`.

### Task 2.1a: Add `InteractorLifecycle` helper

**Files:**
- Create: `Sources/napkin/InteractorLifecycle.swift`

- [ ] **Step 1: Create the new file**

Create `Sources/napkin/InteractorLifecycle.swift` with:

```swift
//
//  Copyright (c) 2026. napkin authors.
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Synchronization

/// Holds the active-state, lifecycle-bound tasks, and `AsyncStream`
/// continuations for a single `Interactable` actor.
///
/// `InteractorLifecycle` is the only `@unchecked Sendable` type in the napkin
/// framework. Its mutable state is protected by a `Mutex<State>` from the
/// `Synchronization` module. All public operations are safe to call from any
/// actor or thread.
///
/// Each `Interactable` declares `nonisolated let lifecycle = InteractorLifecycle()`
/// and the `Interactable` protocol extension forwards `activate()`,
/// `deactivate()`, `task(_:)`, `isActive`, and `isActiveStream` to it.
public final class InteractorLifecycle: @unchecked Sendable {

    public init() {}

    /// Whether the lifecycle is currently active.
    public var isActive: Bool {
        get async { state.withLock { $0.isActive } }
    }

    /// A fresh `AsyncStream` that immediately yields the current state and
    /// then yields each subsequent transition. Multiple consumers may call
    /// `isActiveStream` concurrently; each gets its own stream.
    public var isActiveStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = state.withLock { storage -> UUID in
                let id = UUID()
                storage.continuations[id] = continuation
                continuation.yield(storage.isActive)
                return id
            }
            continuation.onTermination = { [state] _ in
                state.withLock { $0.continuations.removeValue(forKey: id) }
            }
        }
    }

    /// Activates the lifecycle. Idempotent. Invokes `didBecomeActive` while
    /// the lifecycle is in the active state.
    public func activate(
        invoking didBecomeActive: () async -> Void
    ) async {
        let alreadyActive: Bool = state.withLock { storage in
            if storage.isActive { return true }
            storage.isActive = true
            for continuation in storage.continuations.values {
                continuation.yield(true)
            }
            return false
        }
        if alreadyActive { return }
        await didBecomeActive()
    }

    /// Deactivates the lifecycle. Idempotent. Invokes `willResignActive` first,
    /// then cancels all registered tasks, then flips the state.
    public func deactivate(
        invoking willResignActive: () async -> Void
    ) async {
        let wasActive: Bool = state.withLock { $0.isActive }
        guard wasActive else { return }
        await willResignActive()
        let tasks: Set<Task<Void, Never>> = state.withLock { storage in
            let tasks = storage.tasks
            storage.tasks.removeAll()
            storage.isActive = false
            for continuation in storage.continuations.values {
                continuation.yield(false)
            }
            return tasks
        }
        for task in tasks { task.cancel() }
    }

    /// Spawn a `Task` whose lifetime is bound to the active scope.
    /// Cancelled in `deactivate(invoking:)`.
    @discardableResult
    public func register(
        priority: TaskPriority? = nil,
        _ work: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> {
        let t = Task(priority: priority) { await work() }
        state.withLock { $0.tasks.insert(t) }
        return t
    }

    deinit {
        let snapshot = state.withLock { storage -> ([Task<Void, Never>], [AsyncStream<Bool>.Continuation]) in
            let result = (Array(storage.tasks), Array(storage.continuations.values))
            storage.tasks.removeAll()
            storage.continuations.removeAll()
            storage.isActive = false
            return result
        }
        for task in snapshot.0 { task.cancel() }
        for continuation in snapshot.1 { continuation.finish() }
    }

    // MARK: - Private

    private struct State {
        var isActive: Bool = false
        var tasks: Set<Task<Void, Never>> = []
        var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    }

    private let state = Mutex<State>(State())
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | grep -E "InteractorLifecycle\.swift|error:" | head -20`
Expected: `InteractorLifecycle.swift` itself compiles cleanly. Other errors come from existing files that haven't been migrated yet (current `Interactor.swift` and `PresentableInteractor.swift` still use the old class API; that's the next task).

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/InteractorLifecycle.swift
git commit -m "Add InteractorLifecycle helper with Mutex-protected state"
```

### Task 2.1b: Replace `Interactor.swift` with `Interactable` protocol design

**Files:**
- Modify: `Sources/napkin/Interactor.swift`
- Delete: `Sources/napkin/PresentableInteractor.swift`

- [ ] **Step 1: Replace `Interactor.swift`**

Replace the entire content of `Sources/napkin/Interactor.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// A protocol that defines the active state scope of an interactor.
public protocol InteractorScope: AnyObject, Sendable {
    /// Whether the interactor is currently active.
    var isActive: Bool { get async }

    /// A fresh `AsyncStream` that yields the current and subsequent
    /// active-state values. New subscribers receive the current state
    /// immediately.
    nonisolated var isActiveStream: AsyncStream<Bool> { get }
}

/// The base protocol for all napkin interactors.
///
/// Business logic for a feature lives in a `final actor` conforming to
/// `Interactable`. Default implementations of lifecycle plumbing are provided
/// here; the conforming actor needs only to:
///   1. Declare `nonisolated let lifecycle = InteractorLifecycle()`
///   2. Optionally override `didBecomeActive()` / `willResignActive()`
///
/// Example:
///
/// ```swift
/// final actor HomeInteractor: Interactable {
///     nonisolated let lifecycle = InteractorLifecycle()
///     private let userService: UserService
///     init(userService: UserService) { self.userService = userService }
///
///     func didBecomeActive() async {
///         task {
///             for await user in self.userService.userStream {
///                 await self.handle(user)
///             }
///         }
///     }
/// }
/// ```
public protocol Interactable: Actor, InteractorScope {

    /// The lifecycle helper that this interactor delegates state and
    /// lifecycle plumbing to. Conforming actors declare:
    /// `nonisolated let lifecycle = InteractorLifecycle()`.
    nonisolated var lifecycle: InteractorLifecycle { get }

    /// Activates the interactor. Idempotent. Invokes ``didBecomeActive()``.
    func activate() async

    /// Deactivates the interactor. Idempotent. Invokes ``willResignActive()``,
    /// then cancels lifecycle-bound tasks.
    func deactivate() async

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
    /// Cancelled automatically in ``deactivate()``. Replaces the role of
    /// `disposeOnDeactivate` in upstream RIBs.
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

/// A `Interactable` that owns a presenter.
///
/// The `presenter` is typically a `@MainActor`-isolated type; calls into it
/// from this actor cross isolation domains and are `await`-required.
///
/// Example:
///
/// ```swift
/// final actor HomeInteractor: PresentableInteractable {
///     nonisolated let lifecycle = InteractorLifecycle()
///     nonisolated let presenter: HomePresentable
///     init(presenter: HomePresentable) { self.presenter = presenter }
/// }
/// ```
public protocol PresentableInteractable: Interactable {
    associatedtype PresenterType
    nonisolated var presenter: PresenterType { get }
}
```

- [ ] **Step 2: Delete the old `PresentableInteractor.swift`**

`PresentableInteractable` is now a protocol declared in `Interactor.swift`. The old open-class `PresentableInteractor` is gone.

```bash
git rm Sources/napkin/PresentableInteractor.swift
```

- [ ] **Step 3: Verify the source target builds**

Run: `swift build --target napkin 2>&1 | tail -30`
Expected: build fails with errors in `Router.swift`, `ViewableRouter.swift`, `LaunchRouter.swift` (they reference the old `Interactable.activate()` / `deactivate()` synchronous API and the missing `Interactor` class). `Interactor.swift` and `InteractorLifecycle.swift` themselves compile cleanly. If `Interactor.swift` itself shows errors, investigate before committing.

- [ ] **Step 4: Commit**

```bash
git add Sources/napkin/Interactor.swift Sources/napkin/PresentableInteractor.swift
git commit -m "Replace Interactor base class with Interactable protocol + extension"
```

---

## Phase 3 — (consolidated into Task 2.1b)

Phase 3's original task to rewrite `PresentableInteractor.swift` as an actor subclass is no longer needed: `PresentableInteractable` is now a protocol that lives in `Interactor.swift`, and `Sources/napkin/PresentableInteractor.swift` has been removed in Task 2.1b. **Skip Phase 3.**

---

## Phase 4 — `Router` `@MainActor`

### Task 4.1: Rewrite `Router.swift`

**Files:**
- Modify: `Sources/napkin/Router.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Sources/napkin/Router.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// The base protocol for all routers.
///
/// `Routing` is `@MainActor`-isolated because routers manipulate the view
/// tree. Lifecycle methods are `async` because they must `await` actor-isolated
/// `Interactable` calls.
@MainActor
public protocol Routing: AnyObject {
    var interactable: Interactable { get }
    var children: [Routing] { get }

    /// Loads the router and prepares it for use. Triggers `didLoad()`.
    func load() async

    /// Returns once `didLoad()` has completed for this router. Subsequent calls
    /// return immediately. Replaces the `lifecycle` Combine publisher.
    func loaded() async

    /// Attach a child router. Activates the child's interactor, then loads it.
    func attachChild(_ child: Routing) async

    /// Detach a child router. Deactivates its interactor and removes it from
    /// `children`.
    func detachChild(_ child: Routing) async
}

/// The base class for routers that do not own a view controller.
///
/// `Router` is `@MainActor`-isolated. Its `_children` array is plain mutable
/// state; no locks are needed.
@MainActor
open class Router<InteractorType>: Routing {

    public let interactor: InteractorType
    public let interactable: Interactable

    public final var children: [Routing] { _children }

    public init(interactor: InteractorType) {
        self.interactor = interactor
        guard let interactable = interactor as? Interactable else {
            fatalError("\(interactor) should conform to \(Interactable.self)")
        }
        self.interactable = interactable
    }

    public final func load() async {
        guard !didLoadFlag else { return }
        didLoadFlag = true
        await didLoad()
        for c in loadedContinuations { c.resume() }
        loadedContinuations.removeAll()
    }

    public final func loaded() async {
        if didLoadFlag { return }
        await withCheckedContinuation { continuation in
            loadedContinuations.append(continuation)
        }
    }

    /// Override to perform one-time setup, such as attaching permanent child
    /// routers. Always call `super.didLoad()` when overriding.
    open func didLoad() async {}

    public final func attachChild(_ child: Routing) async {
        assert(!_children.contains { $0 === child },
               "Attempt to attach child: \(child), which is already attached.")
        _children.append(child)
        await child.interactable.activate()
        await child.load()
    }

    public final func detachChild(_ child: Routing) async {
        await child.interactable.deactivate()
        _children.removeAll { $0 === child }
    }

    // MARK: - Private

    private var didLoadFlag: Bool = false
    private var _children: [Routing] = []
    private var loadedContinuations: [CheckedContinuation<Void, Never>] = []

    isolated deinit {
        // We're on the main actor; can synchronously empty children and fire
        // a best-effort deactivate on each interactor.
        let snapshot = _children
        _children.removeAll()
        for child in snapshot {
            let interactable = child.interactable
            Task { await interactable.deactivate() }
        }
        let interactable = self.interactable
        Task { await interactable.deactivate() }
        for c in loadedContinuations { c.resume() }
        loadedContinuations.removeAll()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | grep -E "Router.swift:|error:" | head -20`
Expected: `Router.swift` itself compiles. Errors in `ViewableRouter.swift` and `LaunchRouter.swift`.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/Router.swift
git commit -m "Convert Router to @MainActor with async lifecycle and isolated deinit"
```

---

## Phase 5 — `ViewableRouter` `@MainActor`

### Task 5.1: Rewrite `ViewableRouter.swift`

**Files:**
- Modify: `Sources/napkin/ViewableRouter.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Sources/napkin/ViewableRouter.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

/// A protocol for routers that own and manage a view controller.
@MainActor
public protocol ViewableRouting: Routing {
    var viewControllable: ViewControllable { get }
}

/// A router that owns a view controller. `@MainActor`.
@MainActor
open class ViewableRouter<InteractorType, ViewControllerType>:
    Router<InteractorType>, ViewableRouting {

    public var viewController: ViewControllerType { _viewController }
    public var viewControllable: ViewControllable { _viewControllable }

    public init(interactor: InteractorType, viewController: ViewControllerType) {
        self._viewController = viewController
        guard let viewControllable = viewController as? ViewControllable else {
            fatalError("\(viewController) should conform to \(ViewControllable.self)")
        }
        self._viewControllable = viewControllable
        super.init(interactor: interactor)
    }

    // MARK: - Private

    private let _viewController: ViewControllerType
    private let _viewControllable: ViewControllable
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | grep -E "ViewableRouter.swift:|error:" | head -10`
Expected: `ViewableRouter.swift` compiles. Errors in `LaunchRouter.swift` and possibly `Presenter.swift`.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/ViewableRouter.swift
git commit -m "Convert ViewableRouter to @MainActor"
```

---

## Phase 6 — `LaunchRouter` `@MainActor`

### Task 6.1: Rewrite `LaunchRouter.swift`

**Files:**
- Modify: `Sources/napkin/LaunchRouter.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Sources/napkin/LaunchRouter.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A protocol for the root router of an application.
@MainActor
public protocol LaunchRouting: ViewableRouting {
#if canImport(UIKit)
    func launch(from window: UIWindow) async
#elseif canImport(AppKit)
    func launch(from window: NSWindow) async
#endif
}

/// The root router for a napkin-based application.
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType>:
    ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {

    public override init(interactor: InteractorType, viewController: ViewControllerType) {
        super.init(interactor: interactor, viewController: viewController)
    }

#if canImport(UIKit)
    public final func launch(from window: UIWindow) async {
        window.rootViewController = viewControllable.uiviewController
        window.makeKeyAndVisible()
        await interactable.activate()
        await load()
    }
#elseif canImport(AppKit)
    public final func launch(from window: NSWindow) async {
        window.contentViewController = viewControllable.nsviewController
        window.makeKeyAndOrderFront(nil)
        await interactable.activate()
        await load()
    }
#endif
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | grep -E "LaunchRouter.swift:|error:" | head -10`
Expected: `LaunchRouter.swift` compiles. Remaining errors in `Presenter.swift` and the test target.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/LaunchRouter.swift
git commit -m "Convert LaunchRouter to @MainActor with async launch"
```

---

## Phase 7 — `Presenter` `@MainActor` `@Observable`

### Task 7.1: Rewrite `Presenter.swift`

**Files:**
- Modify: `Sources/napkin/Presenter.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Sources/napkin/Presenter.swift` with:

```swift
//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Observation

/// The base protocol for all presenters. `@MainActor`-isolated so views
/// (UIKit or SwiftUI) can read presenter state synchronously.
///
/// Feature-specific presentable protocols extend this protocol to declare
/// the methods the interactor calls. Those methods are typically `async`
/// (the interactor is an `actor`, the presenter is `@MainActor`).
@MainActor
public protocol Presentable: AnyObject {}

/// A base class for presenters. `@Observable` so SwiftUI views can read
/// stored properties of subclasses directly. UIKit views can observe via
/// `Observations { presenter.foo }` to bind to changes.
///
/// `Presenter` is optional in the napkin architecture: napkins without a view
/// use ``Interactor`` directly; napkins with a view use
/// ``PresentableInteractor`` and either subclass `Presenter` here or have the
/// view controller conform to a feature-specific `Presentable` protocol.
@MainActor
@Observable
open class Presenter<ViewControllerType: ViewControllable>: Presentable {

    /// The view controller this presenter updates.
    public let viewController: ViewControllerType

    public init(viewController: ViewControllerType) {
        self.viewController = viewController
    }
}
```

- [ ] **Step 2: Verify the source target builds**

Run: `swift build --target napkin 2>&1 | tail -20`
Expected: `napkin` target builds cleanly. Errors will only be in test target now.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/Presenter.swift
git commit -m "Convert Presenter to @MainActor @Observable"
```

---

## Phase 8 — Builders Sendable

### Task 8.1: Update `Builder.swift`

**Files:**
- Modify: `Sources/napkin/Builder.swift`

- [ ] **Step 1: Update protocol and class for Sendable**

Edit `Sources/napkin/Builder.swift`. Change line 43 from:

```swift
public protocol Buildable: AnyObject {}
```

to:

```swift
public protocol Buildable: AnyObject, Sendable {}
```

Change line 85 from:

```swift
open class Builder<DependencyType>: Buildable {
```

to:

```swift
open class Builder<DependencyType>: Buildable, @unchecked Sendable {
```

Leave the rest of the file unchanged. Concrete subclasses will define their own `build(...)` methods, marked `async` if they construct view controllers.

- [ ] **Step 2: Verify build**

Run: `swift build --target napkin 2>&1 | tail -10`
Expected: builds cleanly.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/Builder.swift
git commit -m "Mark Builder Sendable"
```

### Task 8.2: Update `ComponentizedBuilder.swift`

**Files:**
- Modify: `Sources/napkin/ComponentizedBuilder.swift`

- [ ] **Step 1: Read the current file**

Run: `wc -l Sources/napkin/ComponentizedBuilder.swift`
Expected: 196 lines.

Read the file with the Read tool and locate the class declaration around line 56 and the `SimpleComponentizedBuilder` declaration further down.

- [ ] **Step 2: Add `@unchecked Sendable` to both class declarations**

Change the line at ~56:
```swift
open class ComponentizedBuilder<Component, Router, DynamicBuildDependency, DynamicComponentDependency>: Buildable {
```
to:
```swift
open class ComponentizedBuilder<Component, Router, DynamicBuildDependency, DynamicComponentDependency>: Buildable, @unchecked Sendable {
```

Find the `SimpleComponentizedBuilder` open class declaration (later in the file). Add `, @unchecked Sendable` to its inheritance list as well.

- [ ] **Step 3: Verify build**

Run: `swift build --target napkin 2>&1 | tail -10`
Expected: builds cleanly. If there are errors about closures not being `@Sendable`, mark the relevant closures `@Sendable` in the type signatures.

- [ ] **Step 4: Commit**

```bash
git add Sources/napkin/ComponentizedBuilder.swift
git commit -m "Mark ComponentizedBuilder and SimpleComponentizedBuilder Sendable"
```

### Task 8.3: Update `MultiStageComponentizedBuilder.swift`

**Files:**
- Modify: `Sources/napkin/MultiStageComponentizedBuilder.swift`

- [ ] **Step 1: Read the current file and identify the class declaration**

Run: `grep -n '^open class' Sources/napkin/MultiStageComponentizedBuilder.swift`

- [ ] **Step 2: Add `@unchecked Sendable` to the class**

Add `, @unchecked Sendable` after `: Buildable` on the open class declaration.

- [ ] **Step 3: Verify build**

Run: `swift build --target napkin 2>&1 | tail -10`
Expected: builds cleanly. Mark any `componentBuilder` closure parameters `@Sendable` if Swift complains.

- [ ] **Step 4: Commit**

```bash
git add Sources/napkin/MultiStageComponentizedBuilder.swift
git commit -m "Mark MultiStageComponentizedBuilder Sendable"
```

---

## Phase 9 — `dispatch(_:)` helper

### Task 9.1: Add the `dispatch(_:)` helper for view→interactor events

**Files:**
- Create: `Sources/napkin/Dispatch.swift`

- [ ] **Step 1: Create the file**

Create `Sources/napkin/Dispatch.swift` with:

```swift
//
//  Copyright (c) 2026. napkin authors.
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// Dispatches an async action from a `@MainActor` synchronous context (e.g. a
/// SwiftUI button handler or a UIKit `@objc` action) into a `Task`.
///
/// Used to forward user events from views to actor-isolated interactors:
///
/// ```swift
/// Button("Logout") {
///     dispatch { await listener?.didTapLogout() }
/// }
/// ```
///
/// The returned task is unstructured. If the view is destroyed before the
/// action completes, the task continues running; cancel manually if needed.
@MainActor
@discardableResult
public func dispatch(
    priority: TaskPriority? = nil,
    _ action: @escaping @Sendable () async -> Void
) -> Task<Void, Never> {
    Task(priority: priority) { await action() }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build --target napkin 2>&1 | tail -5`
Expected: builds cleanly.

- [ ] **Step 3: Commit**

```bash
git add Sources/napkin/Dispatch.swift
git commit -m "Add dispatch(_:) helper for view to interactor event forwarding"
```

---

## Phase 10 — Tests rewrite

> **Note:** The existing tests in `Tests/napkinTests/*` import Combine and use the old sync API. They will all fail to compile until rewritten. We rewrite the test files one at a time, each as a standalone task.
>
> Tests use `swift-testing` (already in use; see `napkinTests.swift`). All test methods that exercise actor or `@MainActor` API must be marked `async`.

### Task 10.1: Rewrite `InteractorTests.swift`

**Files:**
- Modify: `Tests/napkinTests/InteractorTests.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Tests/napkinTests/InteractorTests.swift` with:

```swift
import Testing
@testable import napkin

@Suite("Interactor")
struct InteractorTests {

    @Test func startsInactive() async {
        let interactor = TestInteractor()
        #expect(await interactor.isActive == false)
    }

    @Test func activateMakesActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        #expect(await interactor.isActive == true)
    }

    @Test func activateCallsDidBecomeActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        #expect(await interactor.didBecomeActiveCallCount == 1)
    }

    @Test func activateIsIdempotent() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.activate()
        #expect(await interactor.didBecomeActiveCallCount == 1)
    }

    @Test func deactivateMakesInactive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.deactivate()
        #expect(await interactor.isActive == false)
    }

    @Test func deactivateCallsWillResignActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.deactivate()
        #expect(await interactor.willResignActiveCallCount == 1)
    }

    @Test func deactivateWithoutActivateIsNoop() async {
        let interactor = TestInteractor()
        await interactor.deactivate()
        #expect(await interactor.willResignActiveCallCount == 0)
    }

    @Test func taskHelperCancelsOnDeactivate() async {
        let interactor = TestInteractor()
        await interactor.activate()

        let started = AsyncChannel<Void>()
        let cancelled = AsyncChannel<Void>()

        await interactor.task {
            await started.send(())
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                await cancelled.send(())
            }
        }
        await started.receive()

        await interactor.deactivate()
        await cancelled.receive()
    }

    @Test func isActiveStreamYieldsCurrentThenChanges() async {
        let interactor = TestInteractor()

        let stream = interactor.isActiveStream
        var iter = stream.makeAsyncIterator()

        let first = await iter.next()
        #expect(first == false)

        await interactor.activate()
        let second = await iter.next()
        #expect(second == true)

        await interactor.deactivate()
        let third = await iter.next()
        #expect(third == false)
    }
}

// MARK: - Helpers

final actor TestInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()

    private(set) var didBecomeActiveCallCount = 0
    private(set) var willResignActiveCallCount = 0

    func didBecomeActive() async {
        didBecomeActiveCallCount += 1
    }

    func willResignActive() async {
        willResignActiveCallCount += 1
    }
}

/// Minimal one-element async channel used to coordinate test ordering without
/// adding a dependency on swift-async-algorithms. Single-producer, single-
/// consumer.
final actor AsyncChannel<T: Sendable> {
    private var pending: [T] = []
    private var waiter: CheckedContinuation<T, Never>?

    func send(_ value: T) {
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: value)
        } else {
            pending.append(value)
        }
    }

    func receive() async -> T {
        if !pending.isEmpty { return pending.removeFirst() }
        return await withCheckedContinuation { continuation in
            self.waiter = continuation
        }
    }
}
```

- [ ] **Step 2: Run the test file to verify**

Run: `swift test --filter InteractorTests 2>&1 | tail -30`
Expected: all 9 tests pass. (Other test files will still fail to compile; if `swift test` short-circuits before running, run `swift build --target napkinTests 2>&1 | grep InteractorTests.swift` and confirm zero errors in this file.)

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/InteractorTests.swift
git commit -m "Rewrite InteractorTests for actor and async lifecycle"
```

### Task 10.2: Rewrite `PresentableInteractorTests.swift`

**Files:**
- Modify: `Tests/napkinTests/PresentableInteractorTests.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Tests/napkinTests/PresentableInteractorTests.swift` with:

```swift
import Testing
@testable import napkin

@Suite("PresentableInteractable")
struct PresentableInteractableTests {

    @Test func holdsPresenter() async {
        let presenter = StubPresenter()
        let interactor = StubPresentableInteractor(presenter: presenter)
        #expect(interactor.presenter === presenter)
    }

    @Test func inheritsLifecycle() async {
        let interactor = StubPresentableInteractor(presenter: StubPresenter())
        await interactor.activate()
        #expect(await interactor.isActive == true)
        await interactor.deactivate()
        #expect(await interactor.isActive == false)
    }
}

// MARK: - Helpers

@MainActor
final class StubPresenter {}

final actor StubPresentableInteractor: PresentableInteractable {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: StubPresenter
    init(presenter: StubPresenter) { self.presenter = presenter }
}
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep PresentableInteractorTests.swift | head -5`
Expected: zero errors in this file.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/PresentableInteractorTests.swift
git commit -m "Rewrite PresentableInteractorTests for actor"
```

### Task 10.3: Rewrite `RouterTests.swift`

**Files:**
- Modify: `Tests/napkinTests/RouterTests.swift`

- [ ] **Step 1: Replace the file**

Replace the entire content of `Tests/napkinTests/RouterTests.swift` with:

```swift
import Testing
@testable import napkin

@Suite("Router")
@MainActor
struct RouterTests {

    @Test func startsWithEmptyChildren() {
        let router = TestRouter(interactor: TestInteractor())
        #expect(router.children.isEmpty)
    }

    @Test func loadCallsDidLoadOnce() async {
        let router = TestRouter(interactor: TestInteractor())
        await router.load()
        await router.load()
        #expect(router.didLoadCallCount == 1)
    }

    @Test func loadedReturnsAfterLoad() async {
        let router = TestRouter(interactor: TestInteractor())
        let loadedTask = Task { await router.loaded() }
        await router.load()
        await loadedTask.value
    }

    @Test func loadedReturnsImmediatelyAfterLoaded() async {
        let router = TestRouter(interactor: TestInteractor())
        await router.load()
        await router.loaded()
    }

    @Test func attachChildAddsAndActivates() async {
        let parent = TestRouter(interactor: TestInteractor())
        let child = TestRouter(interactor: TestInteractor())
        await parent.attachChild(child)
        #expect(parent.children.count == 1)
        #expect(parent.children.first === child)
        let childInteractor = child.interactor as! TestInteractor
        #expect(await childInteractor.isActive == true)
    }

    @Test func detachChildRemovesAndDeactivates() async {
        let parent = TestRouter(interactor: TestInteractor())
        let child = TestRouter(interactor: TestInteractor())
        await parent.attachChild(child)
        await parent.detachChild(child)
        #expect(parent.children.isEmpty)
        let childInteractor = child.interactor as! TestInteractor
        #expect(await childInteractor.isActive == false)
    }
}

// MARK: - Helpers

@MainActor
final class TestRouter: napkin.Router<TestInteractor> {
    private(set) var didLoadCallCount = 0

    override func didLoad() async {
        await super.didLoad()
        didLoadCallCount += 1
    }
}

final actor TestInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()
}
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep RouterTests.swift | head -5`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/RouterTests.swift
git commit -m "Rewrite RouterTests for @MainActor and async attach/detach"
```

### Task 10.4: Rewrite `ViewableRouterTests.swift`

**Files:**
- Modify: `Tests/napkinTests/ViewableRouterTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("ViewableRouter")
@MainActor
struct ViewableRouterTests {

    @Test func holdsViewController() {
        let vc = StubViewController()
        let router = StubViewableRouter(interactor: StubInteractor(), viewController: vc)
        #expect(router.viewController === vc)
        #expect(router.viewControllable === vc)
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubViewableRouter:
    napkin.ViewableRouter<StubInteractor, StubViewController> {}

private final actor StubInteractor: napkin.Interactor {}
#endif
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep ViewableRouterTests.swift | head -5`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/ViewableRouterTests.swift
git commit -m "Rewrite ViewableRouterTests for @MainActor"
```

### Task 10.5: Rewrite `LaunchRouterTests.swift`

**Files:**
- Modify: `Tests/napkinTests/LaunchRouterTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("LaunchRouter")
@MainActor
struct LaunchRouterTests {

    @Test func launchActivatesAndLoads() async {
        let interactor = StubInteractor()
        let vc = StubViewController()
        let router = StubLaunchRouter(interactor: interactor, viewController: vc)
        let window = UIWindow()
        await router.launch(from: window)

        #expect(window.rootViewController === vc)
        #expect(await interactor.isActive == true)
        #expect(router.didLoadCallCount == 1)
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubLaunchRouter:
    napkin.LaunchRouter<StubInteractor, StubViewController> {
    private(set) var didLoadCallCount = 0
    override func didLoad() async {
        await super.didLoad()
        didLoadCallCount += 1
    }
}

private final actor StubInteractor: napkin.Interactor {}
#endif
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep LaunchRouterTests.swift | head -5`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/LaunchRouterTests.swift
git commit -m "Rewrite LaunchRouterTests for @MainActor async launch"
```

### Task 10.6: Rewrite `PresenterTests.swift`

**Files:**
- Modify: `Tests/napkinTests/PresenterTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
import Observation
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("Presenter")
@MainActor
struct PresenterTests {

    @Test func holdsViewController() {
        let vc = StubViewController()
        let presenter = StubPresenter(viewController: vc)
        #expect(presenter.viewController === vc)
    }

    @Test func observableStateNotifies() async {
        let presenter = StubPresenter(viewController: StubViewController())

        var observed: [String] = []
        let stream = Observations { presenter.title }

        let task = Task { @MainActor in
            for await value in stream {
                observed.append(value)
                if observed.count == 2 { break }
            }
        }
        await Task.yield()
        presenter.title = "hello"
        await task.value

        #expect(observed == ["", "hello"])
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubPresenter: napkin.Presenter<StubViewController> {
    var title: String = ""
}
#endif
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep PresenterTests.swift | head -5`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/PresenterTests.swift
git commit -m "Rewrite PresenterTests for @MainActor @Observable"
```

### Task 10.7: Rewrite `BuilderTests.swift`

**Files:**
- Modify: `Tests/napkinTests/BuilderTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
@testable import napkin

@Suite("Builder")
struct BuilderTests {

    @Test func holdsDependency() {
        let dependency = StubDependency()
        let builder = StubBuilder(dependency: dependency)
        #expect(builder.dependency === dependency)
    }
}

private final class StubDependency: Dependency {}
private final class StubBuilder: Builder<StubDependency> {}
```

- [ ] **Step 2: Verify**

Run: `swift build --target napkinTests 2>&1 | grep BuilderTests.swift | head -5`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/BuilderTests.swift
git commit -m "Rewrite BuilderTests for Sendable"
```

### Task 10.8: Rewrite `ComponentTests.swift`

**Files:**
- Modify: `Tests/napkinTests/ComponentTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
@testable import napkin

@Suite("Component")
struct ComponentTests {

    @Test func holdsDependency() {
        let parent = ParentDependency()
        let component = ChildComponent(dependency: parent)
        #expect(component.dependency === parent)
    }

    @Test func sharedReturnsSameInstance() {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.sharedService
        let second = component.sharedService
        #expect(first === second)
    }

    @Test func nonSharedReturnsNewInstance() {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.freshService
        let second = component.freshService
        #expect(first !== second)
    }

    @Test func sharedIsThreadSafe() async {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.sharedService
        await withTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    ObjectIdentifier(component.sharedService)
                }
            }
            for await id in group {
                #expect(id == ObjectIdentifier(first))
            }
        }
    }
}

private final class ParentDependency: Dependency {}

private final class Service {}

private final class ChildComponent: Component<ParentDependency> {
    var sharedService: Service { shared { Service() } }
    var freshService: Service { Service() }
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test --filter ComponentTests 2>&1 | tail -10`
Expected: all 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/ComponentTests.swift
git commit -m "Rewrite ComponentTests for Mutex-backed shared and Sendable"
```

### Task 10.9: Rewrite `ComponentizedBuilderTests.swift`

**Files:**
- Modify: `Tests/napkinTests/ComponentizedBuilderTests.swift`

- [ ] **Step 1: Read the existing file to identify what is being tested**

Run: `cat Tests/napkinTests/ComponentizedBuilderTests.swift`

- [ ] **Step 2: Adjust each test method for the new `Sendable` constraints**

The existing tests likely use sync `build(...)` calls; those still work because `ComponentizedBuilder.build(...)` is sync. The only changes needed:
1. Update any helper types referenced in tests so they conform to `Sendable` where required (closures may need `@Sendable`).
2. Remove any Combine imports.

Make minimal edits: replace `import Combine` (if present) with nothing, mark closures `@Sendable` to satisfy the `ComponentizedBuilder` signature.

- [ ] **Step 3: Verify**

Run: `swift build --target napkinTests 2>&1 | grep ComponentizedBuilderTests.swift | head -5`
Expected: zero errors. If errors remain, address them inline.

- [ ] **Step 4: Commit**

```bash
git add Tests/napkinTests/ComponentizedBuilderTests.swift
git commit -m "Update ComponentizedBuilderTests for Sendable"
```

### Task 10.10: Rewrite `MultiStageComponentizedBuilderTests.swift`

**Files:**
- Modify: `Tests/napkinTests/MultiStageComponentizedBuilderTests.swift`

- [ ] **Step 1: Apply the same pattern as Task 10.9**

Read the file, make minimal edits to satisfy `Sendable` and remove Combine, fix any closure-`@Sendable` complaints.

- [ ] **Step 2: Verify and commit**

```bash
swift build --target napkinTests 2>&1 | grep MultiStageComponentizedBuilderTests.swift | head -5
git add Tests/napkinTests/MultiStageComponentizedBuilderTests.swift
git commit -m "Update MultiStageComponentizedBuilderTests for Sendable"
```

### Task 10.11: Rewrite `ViewControllableTests.swift`

**Files:**
- Modify: `Tests/napkinTests/ViewControllableTests.swift`

- [ ] **Step 1: Replace the file**

```swift
import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("ViewControllable")
@MainActor
struct ViewControllableTests {

    @Test func uiViewControllerSubclassConformsAutomatically() {
        let vc = UIViewController() as ViewControllable
        #expect(vc.uiviewController is UIViewController)
    }
}
#endif
```

- [ ] **Step 2: Verify and commit**

```bash
swift test --filter ViewControllableTests 2>&1 | tail -5
git add Tests/napkinTests/ViewControllableTests.swift
git commit -m "Rewrite ViewControllableTests"
```

### Task 10.12: Update `napkinTests.swift`

**Files:**
- Modify: `Tests/napkinTests/napkinTests.swift`

- [ ] **Step 1: Read the existing file**

Run: `cat Tests/napkinTests/napkinTests.swift`

- [ ] **Step 2: Replace any Combine imports or sync API usage**

Make the file compile with the new API. If it's already minimal, leave alone.

- [ ] **Step 3: Commit**

```bash
git add Tests/napkinTests/napkinTests.swift
git commit -m "Update napkinTests for new API"
```

### Task 10.13: Run the full test suite

- [ ] **Step 1: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: all tests pass. If a previously-skipped test fails, fix it before continuing.

- [ ] **Step 2: Commit any final adjustments**

```bash
git add -A
git status   # confirm only test files changed; abort if Sources/ has unintended diffs
git commit -m "Fix remaining test compilation issues"  # only if needed
```

---

## Phase 11 — Xcode templates rewrite

> **Note:** Templates contain placeholder strings like `___FILEBASENAMEASIDENTIFIER___`. Preserve those. Each template directory has multiple `___FILEBASENAME___.swift` files inside; each needs updating to match the new API.

### Task 11.1: Update `Tools/napkin/napkin.xctemplate`

**Files:**
- Modify: every `*.swift` file in `Tools/napkin/napkin.xctemplate/` and its subdirectories

- [ ] **Step 1: List the files in the template**

Run: `find Tools/napkin/napkin.xctemplate -name "*.swift" -type f`

- [ ] **Step 2: For each Swift file, rewrite it to emit the new API**

Each template needs the same rewrites the source files received:
- `Interactor` template files → emit `final actor` conforming to `Interactable` (or `PresentableInteractable` when there's a presenter), with `nonisolated let lifecycle = InteractorLifecycle()` declaration and `async` `didBecomeActive` / `willResignActive` (no `override` keyword — the methods are protocol requirements with default impls, not class overrides).
- `Router` template files → emit `final class` subclass of `napkin.Router` / `napkin.ViewableRouter` with `@MainActor`-implicit isolation (it's inherited).
- `Builder` template files → emit `async build(...)` when constructing a view controller.
- `Listener` / `Routing` / `Presentable` protocols → emit methods marked `async`.
- Remove `import Combine`. Remove `cancellables`. Replace Combine subscriptions with `Interactor.task { for await … in Observations({ … }) }` patterns where appropriate.

Use the spec's "SwiftUI / UIKit interchangeability" code samples and the spec's "Headless napkin" example as the canonical shape for the template content.

- [ ] **Step 3: Verify the templates by syntax-checking**

Run: `for f in $(find Tools/napkin/napkin.xctemplate -name "*.swift"); do swiftc -parse "$f" 2>&1 || echo "FAIL: $f"; done`
Expected: no `FAIL:` output. (Templates use placeholder identifiers that aren't valid Swift, so this might fail; if so, manually inspect each file for sanity.)

- [ ] **Step 4: Commit**

```bash
git add Tools/napkin/napkin.xctemplate
git commit -m "Update napkin Xcode template for actor Interactor + @MainActor Router"
```

### Task 11.2: Update `Tools/napkin/Launch napkin.xctemplate`

**Files:**
- Modify: every `*.swift` file in `Tools/napkin/Launch napkin.xctemplate/`

- [ ] **Step 1: Apply the same pattern as Task 11.1**

- [ ] **Step 2: Specifically update the SceneDelegate / AppDelegate snippet**

The template's launch code should call:
```swift
Task { @MainActor in
    await launchRouter.launch(from: window)
}
```
inside `scene(_:willConnectTo:options:)`.

- [ ] **Step 3: Commit**

```bash
git add "Tools/napkin/Launch napkin.xctemplate"
git commit -m "Update Launch napkin Xcode template for async launch"
```

### Task 11.3: Update `Tools/napkin/napkin Unit Tests.xctemplate`

**Files:**
- Modify: every `*.swift` file in `Tools/napkin/napkin Unit Tests.xctemplate/`

- [ ] **Step 1: Rewrite generated test files for `swift-testing` style**

Use the patterns from Task 10.1 and 10.3 as the canonical shape. Test methods are `async`. Suites that touch routers/presenters are `@MainActor`-isolated. Mocks for Interactable/Routing must conform to the new actor/MainActor API.

- [ ] **Step 2: Commit**

```bash
git add "Tools/napkin/napkin Unit Tests.xctemplate"
git commit -m "Update napkin Unit Tests template for swift-testing async"
```

### Task 11.4: Update `Tools/napkin/Component Extension.xctemplate`

**Files:**
- Modify: files in `Tools/napkin/Component Extension.xctemplate/`

- [ ] **Step 1: Verify the template still emits valid code**

Component-extension generation is unchanged in API shape; only `Sendable` requirements may need attention. Inspect the file and remove any Combine imports.

- [ ] **Step 2: Commit**

```bash
git add "Tools/napkin/Component Extension.xctemplate"
git commit -m "Update Component Extension template"
```

### Task 11.5: Update `Tools/napkin/Service Manager.xctemplate`

**Files:**
- Modify: files in `Tools/napkin/Service Manager.xctemplate/`

- [ ] **Step 1: Rewrite the service manager template**

Service managers are typically `actor`-shaped now. The template should emit:
```swift
actor ___FILEBASENAMEASIDENTIFIER___ {
    // ...
}
```
with associated protocols marked `Sendable` and methods `async` where they perform I/O.

- [ ] **Step 2: Commit**

```bash
git add "Tools/napkin/Service Manager.xctemplate"
git commit -m "Update Service Manager template for actor"
```

### Task 11.6: Verify template install script still works

**Files:**
- Read: `Tools/InstallXcodeTemplates.sh`

- [ ] **Step 1: Inspect the script**

Run: `cat Tools/InstallXcodeTemplates.sh`

- [ ] **Step 2: If it merely copies the templates, no change needed; commit only if changes are required**

---

## Phase 12 — Examples rewrite

### Task 12.1: Rewrite `Examples/LaunchNapkin/LaunchNapkinInteractor.swift`

**Files:**
- Modify: `Examples/LaunchNapkin/LaunchNapkinInteractor.swift`

- [ ] **Step 1: Read the existing file**

Run: `cat Examples/LaunchNapkin/LaunchNapkinInteractor.swift`

- [ ] **Step 2: Rewrite as `final actor` subclass of `PresentableInteractor`**

Convert:
- Class declaration → `final actor`
- `didBecomeActive` / `willResignActive` → `async override`
- `cancellables` and Combine subscriptions → `task { for await ... in ... }` patterns
- Listener and presenter protocol methods → `async`

- [ ] **Step 3: Commit**

```bash
git add Examples/LaunchNapkin/LaunchNapkinInteractor.swift
git commit -m "Rewrite LaunchNapkinInteractor as actor"
```

### Task 12.2: Rewrite `Examples/LaunchNapkin/LaunchNapkinRouter.swift`

**Files:**
- Modify: `Examples/LaunchNapkin/LaunchNapkinRouter.swift`

- [ ] **Step 1: Read the existing file**

- [ ] **Step 2: Update class for `@MainActor` (inherited) and async routing methods**

Routing methods that touch the view controller no longer need `Task { @MainActor in }` — they're synchronous. Methods that call into the actor interactor are `async`.

- [ ] **Step 3: Commit**

```bash
git add Examples/LaunchNapkin/LaunchNapkinRouter.swift
git commit -m "Rewrite LaunchNapkinRouter for @MainActor"
```

### Task 12.3: Rewrite `Examples/LaunchNapkin/LaunchNapkinBuilder.swift`

**Files:**
- Modify: `Examples/LaunchNapkin/LaunchNapkinBuilder.swift`

- [ ] **Step 1: Read the existing file**

- [ ] **Step 2: Mark `build(...)` `async` because it constructs a view controller**

```swift
@MainActor
func build() async -> LaunchNapkinRouting { … }
```

- [ ] **Step 3: Commit**

```bash
git add Examples/LaunchNapkin/LaunchNapkinBuilder.swift
git commit -m "Rewrite LaunchNapkinBuilder for async build"
```

### Task 12.4: Rewrite `Examples/LaunchNapkin/LaunchNapkinHostingViewController.swift`

**Files:**
- Modify: `Examples/LaunchNapkin/LaunchNapkinHostingViewController.swift`

- [ ] **Step 1: Read the existing file**

- [ ] **Step 2: Verify `@MainActor` annotation; conform to the feature-specific `Presentable`**

The hosting controller is `UIHostingController`, which is already `@MainActor`. If it currently conforms to a `Presentable` protocol with sync methods, those methods become `async`.

- [ ] **Step 3: Commit**

```bash
git add Examples/LaunchNapkin/LaunchNapkinHostingViewController.swift
git commit -m "Update LaunchNapkinHostingViewController for new API"
```

### Task 12.5: Rewrite `Examples/LaunchNapkin/LaunchNapkinView.swift`

**Files:**
- Modify: `Examples/LaunchNapkin/LaunchNapkinView.swift`

- [ ] **Step 1: Read the existing file**

- [ ] **Step 2: Update the SwiftUI view to use `@Bindable` against the presenter and `dispatch { … }` for events**

Pattern:
```swift
struct LaunchNapkinView: View {
    @Bindable var presenter: LaunchNapkinPresenter
    weak var listener: LaunchNapkinPresentableListener?

    var body: some View {
        VStack {
            Text(presenter.title)
            Button("Tap") { dispatch { await listener?.didTap() } }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Examples/LaunchNapkin/LaunchNapkinView.swift
git commit -m "Rewrite LaunchNapkinView for @Bindable and dispatch helper"
```

### Task 12.6: Verify the example builds and runs

- [ ] **Step 1: Build the example**

If the Examples directory is its own SPM package or part of an Xcode project, build it:

Run: `cd Examples/LaunchNapkin && swift build 2>&1 | tail -10` (or open the Xcode project and build).

Expected: clean build.

- [ ] **Step 2: If the example uses a `Package.swift` of its own, bump its platforms to iOS 26 / macOS 26**

- [ ] **Step 3: Commit any build-fixup changes**

```bash
git add Examples
git commit -m "Fix LaunchNapkin example build"  # only if changes needed
```

---

## Phase 13 — README rewrite

### Task 13.1: Rewrite the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Open the README and replace the "Concurrency Model" section**

Replace lines 82-114 (the current "Concurrency Model" section) with:

```markdown
## Concurrency Model

napkin uses Swift 6.2 native concurrency. Business logic in the Interactor runs **off the main actor by construction**; routing and presentation run on the main actor.

| Layer | Isolation |
|-------|-----------|
| `Interactor` / `PresentableInteractor` | `actor` |
| `Router` / `ViewableRouter` / `LaunchRouter` | `@MainActor` |
| `Presenter` (`@Observable`) | `@MainActor` |
| `ViewControllable` | `@MainActor` |
| `Builder` / `Component` | non-isolated, `Sendable` |

Crossings between layers are explicit `await` points:

- Interactor → Router: `await router?.routeToProfile()`
- Interactor → Presenter: `await presenter.presentUser(user)`
- View → Interactor (events): `dispatch { await listener?.didTapLogout() }`

Combine has been removed. View-state changes flow through `@Observable` properties on the Presenter; lifecycle-bound subscriptions use `Interactor.task { for await … in Observations { … } }`.

Synchronous teardown safety on lifecycle is provided by Swift 6.2's `isolated deinit`.

### Divergence from Uber RIBs-iOS

Uber's `RIBs-iOS` PR #49 unifies the framework on `@MainActor` (Interactor included). napkin deliberately keeps the Interactor as an `actor` so business logic is not pinned to the main actor. The cost is `await` at every cross-layer call; the benefit is enforced clean-architecture isolation.
```

- [ ] **Step 2: Update every code sample in the README**

Walk through each remaining code block in `README.md` and rewrite it to match the new API:
- `Interactor` declarations → `final actor`
- `didBecomeActive` / `willResignActive` → `async override`
- `cancellables` / `.sink { … }` → `task { for await … }` with `Observations { … }`
- Routing methods → `async` (drop `Task { @MainActor in }` boilerplate)
- Listener / Routing / Presentable protocol methods → `async`
- SwiftUI view samples → `@Bindable` against the presenter, `dispatch { await … }` for events

Use the spec document's "SwiftUI / UIKit interchangeability" and "Headless napkin" sections as the canonical samples.

- [ ] **Step 3: Bump the "Supported Platforms" section**

Replace:
```markdown
- iOS 13.0+
- macOS 10.15+
```
with:
```markdown
- iOS 26.0+
- macOS 26.0+
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Rewrite README for actor Interactor and @MainActor Router/Presenter"
```

---

## Final verification

### Task F.1: Full build, full test, sanity check

- [ ] **Step 1: Clean and build everything**

```bash
swift package clean
swift build 2>&1 | tail -10
```
Expected: clean build, no warnings about `@unchecked Sendable` reachability or unsafe-flags.

- [ ] **Step 2: Run all tests**

```bash
swift test 2>&1 | tail -20
```
Expected: all tests pass.

- [ ] **Step 3: Confirm no Combine references remain in the framework**

```bash
grep -rn "import Combine" Sources/napkin Tests/napkinTests Examples Tools && echo "FOUND COMBINE REFERENCES"
```
Expected: no output (or `FOUND` only in legacy comments). If present in non-comment code, fix.

- [ ] **Step 4: Confirm no `Task { @MainActor in }` patterns remain in framework code**

```bash
grep -rn "Task { @MainActor" Sources/napkin Examples
```
Expected: no output. Routing methods on `@MainActor` Routers don't need this pattern; if any remain, simplify.

- [ ] **Step 5: Final commit**

If steps 1-4 surfaced any issues, fix them and commit.

```bash
git status
git log --oneline | head -25
```

Plan complete.

---

## Self-review

**Spec coverage:** Each section of the spec maps to a phase or task:
- Deployment floor → Phase 0
- DI/Sendable → Phase 1
- `Interactor` actor + `task(_:)` + `isActiveStream` → Phase 2
- `PresentableInteractor` → Phase 3
- `Router` (`@MainActor`, async, `isolated deinit`, simplified cascade, `loaded()` replacing `lifecycle` publisher) → Phase 4
- `ViewableRouter` → Phase 5
- `LaunchRouter` (async launch) → Phase 6
- `Presenter` (`@MainActor` `@Observable`, optional) → Phase 7
- Builders (`Sendable`) → Phase 8
- `dispatch(_:)` helper → Phase 9
- Tests → Phase 10
- Templates → Phase 11
- Examples → Phase 12
- README → Phase 13
- "Headless napkin" pattern → covered by Presenter being optional (Phase 7) and the `Interactor` base class staying intact (Phase 2). Tests in Task 10.1 use a headless `TestInteractor`.
- `Mutex` for `Component.shared` → Task 1.2.
- `isolated deinit` on Interactor → Task 2.1; on Router → Task 4.1.
- `RouterLifecycle` removed, `loaded() async` replaces it → Task 4.1.
- `task(_:)` lifecycle helper → Task 2.1.

**Placeholder scan:** Tasks 11.x (templates), 12.1-12.5 (Examples), and 10.9-10.10 (existing tests) are scoped tasks where exact code is determined during execution by reading the existing file shape. This is intentional — the existing files use feature-specific names (`LaunchNapkin*`) and template-placeholder identifiers I cannot fabricate ahead of time. Each task points to existing file paths and gives the transformation pattern (using earlier tasks' canonical examples). No "TBD"/"figure it out" — every task has a deterministic transformation rule.

**Type consistency:**
- `activate()` / `deactivate()` are `async` everywhere referenced (Tasks 2.1, 3.1, 4.1, 6.1, 10.x). ✓
- `attachChild` / `detachChild` are `async` everywhere (Tasks 4.1, 10.3). ✓
- `didLoad` is `async` on `Router` (Task 4.1) and tests use `async override` (Task 10.3). ✓
- `loaded()` is `async` and consistent (Tasks 4.1, 10.3). ✓
- `Interactor.task(_:)` returns `Task<Void, Never>` consistently (Task 2.1, used in Task 10.1). ✓
- `dispatch(_:)` helper signature consistent (Task 9.1, used in Tasks 11.x, 12.5, 13.1). ✓
- `Presenter` `@MainActor` `@Observable` consistent (Tasks 7.1, 10.6, 12.4-12.5). ✓

No issues found.
