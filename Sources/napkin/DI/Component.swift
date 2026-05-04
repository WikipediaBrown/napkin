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
