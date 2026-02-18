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

/// A builder that ensures a one-to-one relationship between napkin and component instances.
///
/// `ComponentizedBuilder` provides an alternative to ``Builder`` that guarantees each
/// napkin instance receives a fresh component instance. This is useful when you need
/// strict lifecycle coupling between the napkin and its dependency scope.
///
/// ## Overview
///
/// Unlike ``Builder``, which receives a pre-existing dependency, `ComponentizedBuilder`:
/// - Creates a new component instance for each build invocation
/// - Supports dynamic dependencies for both building and component creation
/// - Validates that the component builder produces new instances
///
/// ## When to Use
///
/// Use `ComponentizedBuilder` when:
/// - You need guaranteed fresh dependency scopes per napkin instance
/// - You're building reusable napkins that may be instantiated multiple times
/// - You need to pass runtime values to the component
///
/// For simpler cases, use ``SimpleComponentizedBuilder`` or the standard ``Builder``.
///
/// ## Topics
///
/// ### Creating a Builder
///
/// - ``init(componentBuilder:)``
///
/// ### Building
///
/// - ``build(withDynamicBuildDependency:dynamicComponentDependency:)-4t8bp``
/// - ``build(withDynamicBuildDependency:dynamicComponentDependency:)-3vxfl``
/// - ``build(with:_:)``
///
/// - SeeAlso: ``SimpleComponentizedBuilder``
/// - SeeAlso: ``Builder``
/// - SeeAlso: ``MultiStageComponentizedBuilder``
open class ComponentizedBuilder<Component, Router, DynamicBuildDependency, DynamicComponentDependency>: Buildable {

    // Builder should not directly retain an instance of the component.
    // That would make the component's lifecycle longer than the built
    // napkin. Instead, whenever a new instance of the napkin is built, a new
    // instance of the DI component should also be instantiated.

    /// Creates a builder with the specified component factory.
    ///
    /// - Parameter componentBuilder: A closure that creates a new component instance.
    ///   This closure is called each time ``build(withDynamicBuildDependency:dynamicComponentDependency:)-4t8bp``
    ///   is invoked.
    public init(componentBuilder: @escaping (DynamicComponentDependency) -> Component) {
        self.componentBuilder = componentBuilder
    }

    /// Builds a new napkin instance with the given dynamic dependencies.
    ///
    /// This method creates a fresh component and uses it to build the napkin.
    ///
    /// - Parameters:
    ///   - dynamicBuildDependency: Runtime dependencies needed for building the napkin.
    ///   - dynamicComponentDependency: Runtime dependencies needed for creating the component.
    /// - Returns: The router representing the built napkin.
    public final func build(withDynamicBuildDependency dynamicBuildDependency: DynamicBuildDependency, dynamicComponentDependency: DynamicComponentDependency) -> Router {
        return build(withDynamicBuildDependency: dynamicBuildDependency, dynamicComponentDependency: dynamicComponentDependency).1
    }

    /// Builds a new napkin instance and returns both the component and router.
    ///
    /// Use this method when you need access to the component after building,
    /// for example to use it as a dependency for sibling napkins.
    ///
    /// - Parameters:
    ///   - dynamicBuildDependency: Runtime dependencies needed for building the napkin.
    ///   - dynamicComponentDependency: Runtime dependencies needed for creating the component.
    /// - Returns: A tuple containing the component and router.
    public final func build(withDynamicBuildDependency dynamicBuildDependency: DynamicBuildDependency, dynamicComponentDependency: DynamicComponentDependency) -> (Component, Router) {
        let component = componentBuilder(dynamicComponentDependency)

        // Ensure each componentBuilder invocation produces a new component
        // instance.
        let newComponent = component as AnyObject
        if lastComponent === newComponent {
            assertionFailure("\(self) componentBuilder should produce new instances of component when build is invoked.")
        }
        lastComponent = newComponent

        return (component, build(with: component, dynamicBuildDependency))
    }

    /// Override this method to implement the napkin building logic.
    ///
    /// - Important: Do not call this method directly. Use
    ///   ``build(withDynamicBuildDependency:dynamicComponentDependency:)-4t8bp`` instead.
    ///
    /// - Parameters:
    ///   - component: The freshly created component to use for dependency injection.
    ///   - dynamicBuildDependency: The runtime dependencies for building.
    /// - Returns: The router representing the built napkin.
    open func build(with component: Component, _ dynamicBuildDependency: DynamicBuildDependency) -> Router {
        fatalError("This method should be overridden by the subclass.")
    }

    // MARK: - Private

    private let componentBuilder: (DynamicComponentDependency) -> Component
    private weak var lastComponent: AnyObject?
}

/// A simplified componentized builder that requires no dynamic dependencies.
///
/// `SimpleComponentizedBuilder` is a convenience subclass of ``ComponentizedBuilder``
/// for cases where neither the build process nor component creation require
/// runtime dependencies.
///
/// ## Usage
///
/// ```swift
/// final class MyFeatureBuilder: SimpleComponentizedBuilder<MyFeatureComponent, MyFeatureRouting>,
///                               MyFeatureBuildable {
///
///     init(dependency: MyFeatureDependency) {
///         super.init {
///             MyFeatureComponent(dependency: dependency)
///         }
///     }
///
///     override func build(with component: MyFeatureComponent) -> MyFeatureRouting {
///         let interactor = MyFeatureInteractor()
///         return MyFeatureRouter(interactor: interactor)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Builder
///
/// - ``init(componentBuilder:)``
///
/// ### Building
///
/// - ``build()``
/// - ``build(with:)``
///
/// - SeeAlso: ``ComponentizedBuilder``
/// - SeeAlso: ``Builder``
open class SimpleComponentizedBuilder<Component, Router>: ComponentizedBuilder<Component, Router, (), ()> {

    /// Creates a builder with the specified component factory.
    ///
    /// - Parameter componentBuilder: A closure that creates a new component instance.
    public init(componentBuilder: @escaping () -> Component) {
        super.init(componentBuilder: componentBuilder)
    }

    /// Internal override. Do not call directly.
    public final override func build(with component: Component, _ dynamicDependency: ()) -> Router {
        return build(with: component)
    }

    /// Override this method to implement the napkin building logic.
    ///
    /// - Important: Do not call this method directly. Use ``build()`` instead.
    ///
    /// - Parameter component: The freshly created component to use for dependency injection.
    /// - Returns: The router representing the built napkin.
    open func build(with component: Component) -> Router {
        fatalError("This method should be overridden by the subclass.")
    }

    /// Builds a new napkin instance.
    ///
    /// This method creates a fresh component and uses it to build the napkin.
    ///
    /// - Returns: The router representing the built napkin.
    public final func build() -> Router {
        return build(withDynamicBuildDependency: (), dynamicComponentDependency: ())
    }
}
