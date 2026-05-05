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
        await lifecycle.activate { @Sendable [self] in await self.didBecomeActive() }
    }

    public func deactivate() async {
        await lifecycle.deactivate { @Sendable [self] in await self.willResignActive() }
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

/// An `Interactable` that owns a presenter.
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
