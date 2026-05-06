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
