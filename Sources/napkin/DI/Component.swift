//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// The base class for dependency injection components in the napkin architecture.
///
/// A `Component` serves as the dependency injection container for a napkin unit.
/// It defines the dependencies that the napkin provides to its internal units
/// (Router, Interactor, Presenter, View) and to its child napkins.
///
/// ## Overview
///
/// Components form a tree structure that mirrors the router tree. Each component:
/// - Receives dependencies from its parent via the ``dependency`` property
/// - Provides dependencies to its own napkin units
/// - Conforms to child dependency protocols to provide dependencies to children
///
/// ## Creating a Component
///
/// Subclass `Component` with your parent's dependency protocol as the generic type:
///
/// ```swift
/// // Define what this napkin needs from its parent
/// protocol MyFeatureDependency: Dependency {
///     var analyticsService: AnalyticsServiceProtocol { get }
///     var userSession: UserSession { get }
/// }
///
/// // Define what this napkin provides to its children
/// protocol MyFeatureChildDependency: Dependency {
///     var myService: MyServiceProtocol { get }
///     var analyticsService: AnalyticsServiceProtocol { get }
/// }
///
/// final class MyFeatureComponent: Component<MyFeatureDependency>, MyFeatureChildDependency {
///
///     // Pass through from parent
///     var analyticsService: AnalyticsServiceProtocol {
///         return dependency.analyticsService
///     }
///
///     // Create a shared instance scoped to this component
///     var myService: MyServiceProtocol {
///         return shared { MyService(session: dependency.userSession) }
///     }
///
///     // Create a new instance each time (not shared)
///     var viewModel: MyViewModel {
///         return MyViewModel(service: myService)
///     }
/// }
/// ```
///
/// ## Shared vs Non-Shared Dependencies
///
/// Use the ``shared(_:)`` method to create singleton-like dependencies scoped to
/// the component's lifetime:
///
/// ```swift
/// // Shared: Same instance returned every time
/// var database: DatabaseProtocol {
///     return shared { Database() }
/// }
///
/// // Not shared: New instance every time
/// var viewModel: ViewModel {
///     return ViewModel(database: database)
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Component
///
/// - ``init(dependency:)``
/// - ``dependency``
///
/// ### Managing Shared Dependencies
///
/// - ``shared(_:)``
///
/// - SeeAlso: ``Dependency``
/// - SeeAlso: ``EmptyComponent``
/// - SeeAlso: ``Builder``
open class Component<DependencyType>: Dependency {

    /// The dependency object provided by the parent component.
    ///
    /// Use this property to access dependencies from the parent scope.
    /// The dependency object typically conforms to a protocol that defines
    /// the required services and objects.
    public let dependency: DependencyType

    /// Creates a component with the specified parent dependency.
    ///
    /// - Parameter dependency: The dependency object from the parent component,
    ///   typically the parent's component conforming to this napkin's dependency protocol.
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }

    /// Creates a shared instance that is retained for the component's lifetime.
    ///
    /// Use this method to create dependencies that should be shared within the
    /// component's scope. The factory closure is only called once; subsequent
    /// calls return the cached instance.
    ///
    /// ```swift
    /// var myService: MyServiceProtocol {
    ///     return shared { MyService() }
    /// }
    /// ```
    ///
    /// - Important: The factory closure must not switch threads, as this could
    ///   cause a deadlock due to the internal locking mechanism.
    ///
    /// - Parameter factory: A closure that creates the shared instance.
    /// - Returns: The shared instance, either newly created or cached.
    ///
    /// - Note: This method is thread-safe.
    public final func shared<T>(__function: String = #function, _ factory: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }

        // Additional nil coalescing is needed to mitigate a Swift bug appearing in Xcode 10.
        // see https://bugs.swift.org/browse/SR-8704.
        // Without this measure, calling `shared` from a function that returns an optional type
        // will always pass the check below and return nil if the instance is not initialized.
        if let instance = (sharedInstances[__function] as? T?) ?? nil {
            return instance
        }

        let instance = factory()
        sharedInstances[__function] = instance

        return instance
    }

    // MARK: - Private

    private var sharedInstances = [String: Any]()
    private let lock = NSRecursiveLock()
}

/// A component for root napkins that have no parent dependencies.
///
/// Use `EmptyComponent` as the base for your application's root component:
///
/// ```swift
/// final class AppComponent: EmptyComponent, RootDependency {
///
///     var analyticsService: AnalyticsServiceProtocol {
///         return shared { AnalyticsService() }
///     }
///
///     var networkService: NetworkServiceProtocol {
///         return shared { NetworkService() }
///     }
/// }
/// ```
///
/// - SeeAlso: ``EmptyDependency``
/// - SeeAlso: ``Component``
open class EmptyComponent: EmptyDependency {

    /// Creates an empty component.
    public init() {}
}
