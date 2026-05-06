//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// The base protocol for all routers.
///
/// A router owns a slice of the napkin tree: it holds a reference to its
/// ``Interactable`` and to the child routers attached beneath it, and it
/// exposes the asynchronous lifecycle hooks the parent router uses to
/// activate, load, and tear that subtree down.
///
/// ## Overview
///
/// `Routing` is `@MainActor`-isolated because routers manipulate the view
/// tree and present view controllers. Lifecycle methods are `async` because
/// they must `await` actor-isolated calls into the underlying
/// ``Interactable``.
///
/// The ``children`` array reflects the routers currently attached to this
/// router. Mutation of the array goes exclusively through
/// ``attachChild(_:)`` and ``detachChild(_:)``; both methods drive the
/// child's interactor activation/deactivation in the right order. Routers
/// should not append to ``children`` directly.
///
/// ## Topics
///
/// ### Accessing the Subtree
///
/// - ``interactable``
/// - ``children``
///
/// ### Lifecycle
///
/// - ``load()``
/// - ``loaded()``
///
/// ### Managing Children
///
/// - ``attachChild(_:)``
/// - ``detachChild(_:)``
///
/// - SeeAlso: ``Router``
/// - SeeAlso: ``ViewableRouting``
/// - SeeAlso: ``LaunchRouting``
@MainActor
public protocol Routing: AnyObject {

    /// The interactor that owns this router's business logic, exposed as the
    /// type-erased ``Interactable``.
    ///
    /// Concrete subclasses of ``Router`` also expose a typed
    /// ``Router/interactor`` property; use this protocol-level requirement
    /// when you need to call ``Interactable/activate()`` or
    /// ``Interactable/deactivate()`` without knowing the concrete type.
    var interactable: Interactable { get }

    /// The routers currently attached to this router, in attachment order.
    ///
    /// Mutated only by ``attachChild(_:)`` and ``detachChild(_:)``.
    var children: [Routing] { get }

    /// Loads the router and prepares it for use.
    ///
    /// Idempotent: subsequent calls are no-ops. Triggers ``Router/didLoad()``
    /// on the concrete subclass and resumes any callers waiting on
    /// ``loaded()``.
    func load() async

    /// Suspends until ``Router/didLoad()`` has completed for this router.
    ///
    /// Subsequent calls return immediately. This replaces the `lifecycle`
    /// Combine publisher from upstream RIBs.
    func loaded() async

    /// Attaches a child router beneath this one.
    ///
    /// Activates the child's ``Interactable`` first, then loads the child.
    /// The child must not already be attached.
    ///
    /// - Parameter child: The router to attach.
    func attachChild(_ child: Routing) async

    /// Detaches a previously attached child router.
    ///
    /// Deactivates the child's ``Interactable`` and removes it from
    /// ``children``. If the child was never attached the call is a no-op.
    ///
    /// - Parameter child: The router to detach.
    func detachChild(_ child: Routing) async
}

/// The base class for routers that do not own a view controller.
///
/// `Router` is `@MainActor`-isolated. Its `_children` array is plain mutable
/// state guarded by main-actor isolation alone — no locks are needed
/// because every mutation of the array occurs through `@MainActor` API.
///
/// ## Overview
///
/// Subclass `Router` for headless napkins (a.k.a. "interactor-only"
/// napkins) — units of business logic that have no view of their own but
/// still attach child routers, listen to services, and expose a listener
/// surface to their parent. For napkins that own a view, subclass
/// ``ViewableRouter`` instead.
///
/// On `deinit` (which runs on the main actor) the router cancels any
/// outstanding ``loaded()`` continuations and best-effort deactivates its
/// own interactor along with each remaining child. `deinit` is `isolated`,
/// which lets it touch main-actor state synchronously; the per-child
/// deactivation is dispatched into a `Task` because ``Interactable`` calls
/// are async.
///
/// ## Usage
///
/// ```swift
/// @MainActor
/// final class HomeRouter: Router<HomeInteractor>, HomeRouting {
///
///     init(
///         interactor: HomeInteractor,
///         profileBuilder: ProfileBuildable
///     ) {
///         self.profileBuilder = profileBuilder
///         super.init(interactor: interactor)
///     }
///
///     override func didLoad() async {
///         await super.didLoad()
///         // One-time setup, e.g. attaching a permanent child router.
///     }
///
///     func routeToProfile() async {
///         guard profileRouter == nil else { return }
///         let r = await profileBuilder.build(withListener: interactor)
///         profileRouter = r
///         await attachChild(r)
///     }
///
///     func routeBackFromProfile() async {
///         guard let r = profileRouter else { return }
///         profileRouter = nil
///         await detachChild(r)
///     }
///
///     private let profileBuilder: ProfileBuildable
///     private var profileRouter: ProfileRouting?
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Router
///
/// - ``init(interactor:)``
///
/// ### Accessing the Interactor
///
/// - ``interactor``
/// - ``interactable``
///
/// ### Lifecycle
///
/// - ``load()``
/// - ``loaded()``
/// - ``didLoad()``
///
/// ### Managing Children
///
/// - ``children``
/// - ``attachChild(_:)``
/// - ``detachChild(_:)``
///
/// - SeeAlso: ``Routing``
/// - SeeAlso: ``ViewableRouter``
@MainActor
open class Router<InteractorType>: Routing {

    /// The concretely typed interactor for this router.
    ///
    /// Subclasses use this property to call interactor-specific methods
    /// (for example, when attaching a child router and passing
    /// `withListener: interactor`). The protocol-level
    /// ``interactable`` exposes the same instance as the type-erased
    /// ``Interactable``.
    public let interactor: InteractorType

    /// The router's interactor, exposed as ``Interactable`` for protocol-
    /// level lifecycle operations.
    ///
    /// This is the same instance as ``interactor``; the cast is performed
    /// once in ``init(interactor:)``.
    public let interactable: Interactable

    /// The routers currently attached beneath this router, in attachment
    /// order.
    ///
    /// Mutated only by ``attachChild(_:)`` and ``detachChild(_:)``.
    public final var children: [Routing] { _children }

    /// Creates a router around the given interactor.
    ///
    /// - Parameter interactor: The router's interactor. Must conform to
    ///   ``Interactable``; the initializer traps if it does not.
    /// - Precondition: `interactor` conforms to ``Interactable``.
    public init(interactor: InteractorType) {
        self.interactor = interactor
        guard let interactable = interactor as? Interactable else {
            fatalError("\(interactor) should conform to \(Interactable.self)")
        }
        self.interactable = interactable
    }

    /// Loads the router.
    ///
    /// On the first call, awaits ``didLoad()`` and then resumes any callers
    /// suspended in ``loaded()``. Subsequent calls return immediately
    /// without re-running ``didLoad()``.
    public final func load() async {
        guard !didLoadFlag else { return }
        didLoadFlag = true
        await didLoad()
        for c in loadedContinuations { c.resume() }
        loadedContinuations.removeAll()
    }

    /// Suspends until ``didLoad()`` has completed.
    ///
    /// If ``load()`` has already finished, returns immediately. Otherwise
    /// suspends on a `CheckedContinuation` that ``load()`` will resume.
    public final func loaded() async {
        if didLoadFlag { return }
        await withCheckedContinuation { continuation in
            loadedContinuations.append(continuation)
        }
    }

    /// Override to perform one-time setup, such as attaching permanent
    /// child routers.
    ///
    /// Always call `await super.didLoad()` when overriding so future
    /// framework-level setup remains correctly composed.
    open func didLoad() async {}

    /// Attaches a child router.
    ///
    /// The child's ``Interactable`` is activated before the child is loaded,
    /// matching the order the parent router would have used to set up its
    /// own interactor. The child must not already be attached.
    ///
    /// - Parameter child: The router to attach.
    /// - Precondition: `child` is not already in ``children``.
    public final func attachChild(_ child: Routing) async {
        assert(!_children.contains { $0 === child },
               "Attempt to attach child: \(child), which is already attached.")
        _children.append(child)
        await child.interactable.activate()
        await child.load()
    }

    /// Detaches a previously attached child router.
    ///
    /// Deactivates the child's ``Interactable`` and then removes it from
    /// ``children``.
    ///
    /// - Parameter child: The router to detach.
    public final func detachChild(_ child: Routing) async {
        await child.interactable.deactivate()
        _children.removeAll { $0 === child }
    }

    // MARK: - Private

    private var didLoadFlag: Bool = false
    private var _children: [Routing] = []
    private var loadedContinuations: [CheckedContinuation<Void, Never>] = []

    /// `isolated deinit` lets teardown observe main-actor state synchronously.
    ///
    /// The router cancels any outstanding ``loaded()`` continuations and
    /// best-effort deactivates each remaining child interactor and its own
    /// interactor. The per-interactor deactivation is dispatched into a
    /// `Task` because ``Interactable/deactivate()`` is async; the task
    /// captures the interactor weakly via the local-variable hop and runs
    /// after `deinit` returns.
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
