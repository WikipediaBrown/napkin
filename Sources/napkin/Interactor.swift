//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// A protocol that exposes the active-state scope of an interactor.
///
/// `InteractorScope` separates the read-only "is this interactor currently
/// active?" surface from the rest of ``Interactable``. It is useful when you
/// want a non-mutating view of an interactor — for example, to drive UI from
/// ``isActiveStream`` without exposing ``Interactable/activate()`` or
/// ``Interactable/deactivate()``.
///
/// ## Overview
///
/// An interactor is "active" between a successful call to
/// ``Interactable/activate()`` and the next call to
/// ``Interactable/deactivate()``. Tasks spawned via ``Interactable/task(priority:_:)``
/// are bound to that window and are cancelled on deactivation.
///
/// Both members are safe to read from any actor or thread; ``isActiveStream``
/// is `nonisolated`, and ``isActive`` reads under the lifecycle's lock.
///
/// ## Topics
///
/// ### Reading State
///
/// - ``isActive``
/// - ``isActiveStream``
///
/// - SeeAlso: ``Interactable``
/// - SeeAlso: ``InteractorLifecycle``
public protocol InteractorScope: AnyObject, Sendable {

    /// Whether the interactor is currently active.
    ///
    /// Reads the active-state under the underlying ``InteractorLifecycle``
    /// lock, so the result reflects any in-flight ``Interactable/activate()``
    /// or ``Interactable/deactivate()`` that has already taken effect.
    var isActive: Bool { get async }

    /// A fresh `AsyncStream` that yields the current and subsequent
    /// active-state values.
    ///
    /// New subscribers receive the current state immediately, then receive
    /// `true` on each ``Interactable/activate()`` and `false` on each
    /// ``Interactable/deactivate()``. Each call returns an independent stream;
    /// multiple consumers may subscribe concurrently.
    nonisolated var isActiveStream: AsyncStream<Bool> { get }
}

/// The base protocol for all napkin interactors.
///
/// Business logic for a feature lives in a `final actor` that conforms to
/// `Interactable`. Default implementations of every lifecycle method are
/// provided in a protocol extension; the conforming actor only needs to:
///
/// 1. Declare a stored ``lifecycle`` property:
///    `nonisolated let lifecycle = InteractorLifecycle()`
/// 2. Optionally override ``didBecomeActive()`` / ``willResignActive()`` to
///    perform per-activation setup and teardown.
///
/// ## Overview
///
/// `Interactable` is composed from ``InteractorScope`` and `Actor` rather than
/// inherited from a base class. Swift actors cannot be subclassed, so napkin
/// uses protocol composition plus a default-implementation extension to
/// distribute lifecycle behaviour across many `final actor` types.
///
/// All mutable lifecycle state — the active flag, the bag of in-flight tasks,
/// and the `AsyncStream` continuations — lives in the ``InteractorLifecycle``
/// helper. The interactor itself only owns business state and the
/// `nonisolated let lifecycle` reference. Because the lifecycle is
/// `nonisolated`, its operations can be invoked from outside the actor (for
/// example, from a router on `@MainActor`) without hopping into the actor's
/// executor first.
///
/// ## Usage
///
/// A typical feature interactor looks like this:
///
/// ```swift
/// final actor HomeInteractor: PresentableInteractable, HomeInteractable {
///
///     nonisolated let lifecycle = InteractorLifecycle()
///     nonisolated let presenter: HomePresentable
///     weak var listener: HomeListener?
///
///     private let userService: UserService
///
///     init(presenter: HomePresentable, userService: UserService) {
///         self.presenter = presenter
///         self.userService = userService
///     }
///
///     func didBecomeActive() async {
///         task {
///             for await user in self.userService.userStream {
///                 await self.presenter.presentUser(user)
///             }
///         }
///     }
///
///     func willResignActive() async {
///         // Release any references that should not outlive the active scope.
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Lifecycle
///
/// - ``activate()``
/// - ``deactivate()``
/// - ``didBecomeActive()``
/// - ``willResignActive()``
///
/// ### State
///
/// - ``lifecycle``
/// - ``InteractorScope/isActive``
/// - ``InteractorScope/isActiveStream``
///
/// ### Tasks
///
/// - ``task(priority:_:)``
///
/// - SeeAlso: ``InteractorLifecycle``
/// - SeeAlso: ``InteractorScope``
/// - SeeAlso: ``PresentableInteractable``
public protocol Interactable: Actor, InteractorScope {

    /// The lifecycle helper that this interactor delegates state and
    /// lifecycle plumbing to.
    ///
    /// Conforming actors declare a single stored property:
    ///
    /// ```swift
    /// nonisolated let lifecycle = InteractorLifecycle()
    /// ```
    ///
    /// The default implementations of ``activate()``, ``deactivate()``,
    /// ``task(priority:_:)``, ``InteractorScope/isActive``, and
    /// ``InteractorScope/isActiveStream`` all forward to this helper.
    nonisolated var lifecycle: InteractorLifecycle { get }

    /// Activates the interactor.
    ///
    /// Idempotent: calling `activate()` while already active is a no-op.
    /// On the active→inactive→active transition, ``didBecomeActive()`` is
    /// awaited while the lifecycle observes `isActive == true`, so any task
    /// spawned via ``task(priority:_:)`` from within `didBecomeActive()` is
    /// bound to the new active scope.
    func activate() async

    /// Deactivates the interactor.
    ///
    /// Idempotent: only the first concurrent caller advances past an internal
    /// claim flag, so ``willResignActive()`` runs at most once per
    /// active→inactive transition. After `willResignActive()` returns, every
    /// task spawned via ``task(priority:_:)`` is cancelled and the active
    /// flag flips to `false`.
    func deactivate() async

    /// Override to perform setup when the interactor becomes active.
    ///
    /// Spawn long-running observation work via ``task(priority:_:)`` from
    /// inside this method; it will be cancelled automatically on
    /// ``deactivate()``.
    ///
    /// The default implementation is a no-op.
    func didBecomeActive() async

    /// Override to perform teardown before the interactor becomes inactive.
    ///
    /// Runs while the lifecycle still observes `isActive == true`. Use it to
    /// flush state, persist data, or notify the listener of a clean shutdown.
    /// You do not need to manually cancel tasks spawned via
    /// ``task(priority:_:)`` — the lifecycle cancels them after this method
    /// returns.
    ///
    /// The default implementation is a no-op.
    func willResignActive() async
}

extension Interactable {

    /// Whether the interactor is currently active.
    ///
    /// Default implementation forwarding to ``lifecycle``'s
    /// ``InteractorLifecycle/isActive``.
    public var isActive: Bool {
        get async { await lifecycle.isActive }
    }

    /// A fresh `AsyncStream` of active-state transitions.
    ///
    /// Default implementation forwarding to ``lifecycle``'s
    /// ``InteractorLifecycle/isActiveStream``. Each call returns a new
    /// independent stream.
    public nonisolated var isActiveStream: AsyncStream<Bool> {
        lifecycle.isActiveStream
    }

    /// Default implementation of ``Interactable/activate()`` that delegates
    /// to ``InteractorLifecycle/activate(invoking:)``, passing
    /// ``didBecomeActive()`` as the activation callback.
    public func activate() async {
        await lifecycle.activate { @Sendable [self] in await self.didBecomeActive() }
    }

    /// Default implementation of ``Interactable/deactivate()`` that delegates
    /// to ``InteractorLifecycle/deactivate(invoking:)``, passing
    /// ``willResignActive()`` as the deactivation callback.
    public func deactivate() async {
        await lifecycle.deactivate { @Sendable [self] in await self.willResignActive() }
    }

    /// Spawns a `Task` whose lifetime is bound to the active scope.
    ///
    /// The task is registered with the underlying ``lifecycle`` and is
    /// cancelled automatically by ``deactivate()``. This replaces the role of
    /// `disposeOnDeactivate` from upstream RIBs.
    ///
    /// ```swift
    /// func didBecomeActive() async {
    ///     task {
    ///         for await event in eventStream {
    ///             await self.handle(event)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - priority: An optional `TaskPriority` for the spawned task.
    ///   - work: The async work to run. Captured `self` references should be
    ///     weak or explicit — the closure is `@Sendable`.
    /// - Returns: The created `Task`. The result is discardable; callers
    ///   typically rely on the lifecycle to cancel it.
    @discardableResult
    public func task(
        priority: TaskPriority? = nil,
        _ work: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> {
        lifecycle.register(priority: priority, work)
    }

    /// Default implementation of ``Interactable/didBecomeActive()``: a no-op.
    public func didBecomeActive() async {}

    /// Default implementation of ``Interactable/willResignActive()``: a no-op.
    public func willResignActive() async {}
}

/// An ``Interactable`` that owns a presenter.
///
/// `PresentableInteractable` adds a single `nonisolated` ``presenter``
/// requirement to ``Interactable``. The presenter is typically a
/// `@MainActor`-isolated type, so calls into it from the interactor's actor
/// cross isolation domains and must be `await`-ed.
///
/// ## Overview
///
/// Use `PresentableInteractable` for any napkin that has a view; for
/// view-less ("headless") napkins, conform directly to ``Interactable``.
/// Pair this with a feature-specific `Presentable` protocol that the
/// presenter conforms to:
///
/// ```swift
/// protocol HomePresentable: Presentable {
///     func presentUser(_ user: User) async
/// }
/// ```
///
/// ## Usage
///
/// ```swift
/// final actor HomeInteractor: PresentableInteractable {
///
///     nonisolated let lifecycle = InteractorLifecycle()
///     nonisolated let presenter: HomePresentable
///     weak var listener: HomeListener?
///
///     init(presenter: HomePresentable) {
///         self.presenter = presenter
///     }
///
///     func didBecomeActive() async {
///         await presenter.presentUser(.placeholder)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Owning a Presenter
///
/// - ``presenter``
///
/// - SeeAlso: ``Interactable``
/// - SeeAlso: ``Presentable``
public protocol PresentableInteractable: Interactable {

    /// The associated presenter type, typically a feature-specific
    /// `Presentable` protocol.
    associatedtype PresenterType

    /// The presenter owned by this interactor.
    ///
    /// `nonisolated` so it can be passed to a router or queried by a
    /// non-actor caller without hopping into the actor's executor. The
    /// presenter itself is typically `@MainActor`, so individual method
    /// calls on it must be `await`-ed from the interactor.
    nonisolated var presenter: PresenterType { get }
}
