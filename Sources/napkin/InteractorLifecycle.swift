//
//  Copyright (c) 2026. napkin authors.
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Synchronization

/// Holds the active-state, lifecycle-bound tasks, and `AsyncStream`
/// continuations for a single ``Interactable`` actor.
///
/// ## Overview
///
/// Swift actors cannot be subclassed, so napkin distributes interactor
/// lifecycle behaviour through a protocol extension on ``Interactable``.
/// `InteractorLifecycle` is the one shared, mutable, thread-safe object that
/// every conforming actor delegates to. It owns three pieces of state:
///
/// - `isActive`: the current lifecycle phase.
/// - `tasks`: the set of unstructured `Task`s spawned via
///   ``Interactable/task(priority:_:)`` that should be cancelled on
///   ``Interactable/deactivate()``.
/// - `continuations`: the `AsyncStream<Bool>.Continuation`s handed out by
///   ``isActiveStream``, kept around so the lifecycle can yield transitions
///   and finish them on `deinit`.
///
/// All three live behind a single `Mutex<State>` from the `Synchronization`
/// module. The class is the only type in the framework that is
/// `@unchecked Sendable`: the `@unchecked` is justified because every public
/// operation reads or mutates `state` exclusively via `withLock`, never
/// re-entering the lock from within itself, and never holding the lock
/// across an `await`.
///
/// `Mutex` is non-recursive on its supported platforms — the implementation
/// is careful to release the lock before invoking client closures
/// (``activate(invoking:)``, ``deactivate(invoking:)``) and before cancelling
/// drained tasks.
///
/// ## Usage
///
/// Every conforming `Interactable` declares a single stored property:
///
/// ```swift
/// final actor HomeInteractor: PresentableInteractable {
///
///     nonisolated let lifecycle = InteractorLifecycle()
///     nonisolated let presenter: HomePresentable
///
///     init(presenter: HomePresentable) {
///         self.presenter = presenter
///     }
///
///     func didBecomeActive() async {
///         task {
///             for await user in userService.userStream {
///                 await presenter.presentUser(user)
///             }
///         }
///     }
/// }
/// ```
///
/// You generally do not call `InteractorLifecycle`'s methods directly.
/// `Interactable`'s default-implementation extension forwards
/// ``Interactable/activate()``, ``Interactable/deactivate()``,
/// ``Interactable/task(priority:_:)``, ``Interactable/isActive``, and
/// ``Interactable/isActiveStream`` here.
///
/// ## Topics
///
/// ### Creating a Lifecycle
///
/// - ``init()``
///
/// ### Reading State
///
/// - ``isActive``
/// - ``isActiveStream``
///
/// ### Driving Transitions
///
/// - ``activate(invoking:)``
/// - ``deactivate(invoking:)``
///
/// ### Spawning Bound Tasks
///
/// - ``register(priority:_:)``
///
/// - SeeAlso: ``Interactable``
/// - SeeAlso: ``InteractorScope``
public final class InteractorLifecycle: @unchecked Sendable {

    /// Creates a new lifecycle in the inactive state with no registered tasks
    /// or stream subscribers.
    public init() {}

    /// Whether the lifecycle is currently active.
    ///
    /// Reads under the internal `Mutex`, so the result reflects any
    /// activation or deactivation that has already taken effect.
    public var isActive: Bool {
        get async { state.withLock { $0.isActive } }
    }

    /// A fresh `AsyncStream` that immediately yields the current active state
    /// and then yields each subsequent transition.
    ///
    /// Each call returns an independent stream with its own continuation;
    /// multiple consumers may subscribe concurrently. The continuation is
    /// removed automatically when its iterator is destroyed, so subscribers
    /// do not need explicit cleanup.
    public var isActiveStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = state.withLock { storage -> UUID in
                let id = UUID()
                storage.continuations[id] = continuation
                continuation.yield(storage.isActive)
                return id
            }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { storage -> Void in
                    storage.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Activates the lifecycle.
    ///
    /// Idempotent: if the lifecycle is already active, the closure is not
    /// invoked and no transition is broadcast. On the inactive→active edge,
    /// the active flag is flipped under the lock, every subscribed
    /// ``isActiveStream`` continuation is yielded `true`, the lock is
    /// released, and then `didBecomeActive` is awaited.
    ///
    /// - Parameter didBecomeActive: A callback to run while the lifecycle
    ///   observes `isActive == true`. Typically forwards to
    ///   ``Interactable/didBecomeActive()``. Awaited outside the lock so the
    ///   callback may freely call back into ``register(priority:_:)``,
    ///   ``isActive``, or other lifecycle members.
    /// - Important: The lock is non-recursive. Do not call back into
    ///   `activate(invoking:)` or ``deactivate(invoking:)`` from inside
    ///   `didBecomeActive` — schedule that work via ``register(priority:_:)``
    ///   instead.
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

    /// Deactivates the lifecycle.
    ///
    /// Idempotent under concurrency: only one caller advances past an
    /// internal claim flag, so `willResignActive` runs at most once per
    /// active→inactive transition.
    ///
    /// Order of operations:
    ///
    /// 1. Atomically claim deactivation under the lock. Concurrent callers
    ///    that observe `isActive == true` but `isDeactivating == true` bail
    ///    out without running `willResignActive`.
    /// 2. `await willResignActive()` while the lifecycle still observes
    ///    `isActive == true`.
    /// 3. Under the lock, flip `isActive` to `false`, drain the registered
    ///    task set, and yield `false` to every subscribed
    ///    ``isActiveStream`` continuation.
    /// 4. Cancel the drained tasks outside the lock (so a misbehaving task
    ///    cannot deadlock the lifecycle).
    ///
    /// - Parameter willResignActive: A callback to run before the lifecycle
    ///   transitions to inactive. Typically forwards to
    ///   ``Interactable/willResignActive()``.
    /// - Important: The lock is non-recursive. As with
    ///   ``activate(invoking:)``, do not call back into
    ///   `deactivate(invoking:)` or `activate(invoking:)` from inside
    ///   `willResignActive`.
    public func deactivate(
        invoking willResignActive: () async -> Void
    ) async {
        // Atomically claim deactivation. Only one caller proceeds; concurrent
        // callers observing isActive==true but isDeactivating==true bail out.
        let claimed: Bool = state.withLock { storage in
            guard storage.isActive, !storage.isDeactivating else { return false }
            storage.isDeactivating = true
            return true
        }
        guard claimed else { return }

        await willResignActive()

        let tasks: Set<Task<Void, Never>> = state.withLock { storage in
            let tasks = storage.tasks
            storage.tasks.removeAll()
            storage.isActive = false
            storage.isDeactivating = false
            for continuation in storage.continuations.values {
                continuation.yield(false)
            }
            return tasks
        }
        for task in tasks { task.cancel() }
    }

    /// Spawns a `Task` whose lifetime is bound to the active scope.
    ///
    /// The task is added to the lifecycle's bag of in-flight tasks and is
    /// cancelled by ``deactivate(invoking:)``. The default
    /// ``Interactable/task(priority:_:)`` implementation forwards to this
    /// method; prefer that surface from feature code.
    ///
    /// - Parameters:
    ///   - priority: An optional `TaskPriority` for the spawned task.
    ///   - work: The async work to run.
    /// - Returns: The created `Task`. The result is discardable; the
    ///   lifecycle retains the task and cancels it on deactivation.
    @discardableResult
    public func register(
        priority: TaskPriority? = nil,
        _ work: @Sendable @escaping () async -> Void
    ) -> Task<Void, Never> {
        let t = Task(priority: priority) { await work() }
        state.withLock { storage -> Void in
            storage.tasks.insert(t)
        }
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
        var isDeactivating: Bool = false
        var tasks: Set<Task<Void, Never>> = []
        var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    }

    private let state = Mutex<State>(State())
}
