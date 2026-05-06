//
//  Copyright (c) 2026. napkin authors.
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// Dispatches an async action from a `@MainActor` synchronous context (e.g.
/// a SwiftUI button handler or a UIKit `@objc` action) into an unstructured
/// `Task`.
///
/// Used to forward user events from views into actor-isolated interactors
/// without blocking the view layer. The view stays synchronous; the
/// dispatched task picks up the work and `await`s the actor.
///
/// ## Usage
///
/// **SwiftUI:**
///
/// ```swift
/// Button("Logout") {
///     dispatch { await listener?.didTapLogout() }
/// }
/// ```
///
/// **UIKit `@objc` action:**
///
/// ```swift
/// @objc private func logoutButtonTapped() {
///     dispatch { [weak self] in
///         await self?.listener?.didTapLogout()
///     }
/// }
/// ```
///
/// - Parameters:
///   - priority: An optional `TaskPriority` for the spawned task. Pass
///     `nil` (the default) to inherit the priority of the calling
///     context.
///   - action: The async work to run. Captured `self` references should
///     be weak — the closure outlives the calling stack frame.
/// - Returns: The created unstructured `Task`. The result is discardable.
///   If the view is destroyed before the action completes, the task
///   continues running; cancel manually if you need that behaviour.
@MainActor
@discardableResult
public func dispatch(
    priority: TaskPriority? = nil,
    _ action: @escaping @Sendable () async -> Void
) -> Task<Void, Never> {
    Task(priority: priority) { await action() }
}
