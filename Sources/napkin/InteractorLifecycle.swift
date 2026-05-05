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
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { storage -> Void in
                    storage.continuations.removeValue(forKey: id)
                }
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
        var tasks: Set<Task<Void, Never>> = []
        var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    }

    private let state = Mutex<State>(State())
}
