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

/// A builder for napkins that require multiple stages of construction.
///
/// `MultiStageComponentizedBuilder` supports building processes where the
/// component needs to be accessed multiple times before finalizing the napkin.
/// Within a single build pass, the same component instance is reused.
///
/// ## Overview
///
/// Some napkins require a multi-stage build process:
/// 1. Access the component to configure dependencies
/// 2. Build child napkins using the same component
/// 3. Finally build the parent napkin
///
/// This builder ensures component consistency throughout these stages.
///
/// ## Usage
///
/// ```swift
/// final class ComplexBuilder: MultiStageComponentizedBuilder<ComplexComponent,
///                                                             ComplexRouting,
///                                                             ComplexListener> {
///
///     init(dependency: ComplexDependency) {
///         super.init {
///             ComplexComponent(dependency: dependency)
///         }
///     }
///
///     func buildChildA() -> ChildARouting {
///         // Uses the same component instance
///         return ChildABuilder(dependency: componentForCurrentBuildPass).build()
///     }
///
///     func buildChildB() -> ChildBRouting {
///         // Uses the same component instance
///         return ChildBBuilder(dependency: componentForCurrentBuildPass).build()
///     }
///
///     override func finalStageBuild(with component: ComplexComponent,
///                                   _ listener: ComplexListener) -> ComplexRouting {
///         let interactor = ComplexInteractor()
///         interactor.listener = listener
///         return ComplexRouter(interactor: interactor,
///                              childA: buildChildA(),
///                              childB: buildChildB())
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Accessing the Component
///
/// - ``componentForCurrentBuildPass``
///
/// ### Building
///
/// - ``finalStageBuild(withDynamicDependency:)``
/// - ``finalStageBuild(with:_:)``
///
/// - SeeAlso: ``SimpleMultiStageComponentizedBuilder``
/// - SeeAlso: ``ComponentizedBuilder``
open class MultiStageComponentizedBuilder<Component, Router, DynamicBuildDependency>: Buildable {

    // Builder should not directly retain an instance of the component.
    // That would make the component's lifecycle longer than the built
    // napkin. Instead, whenever a new instance of the napkin is built, a new
    // instance of the DI component should also be instantiated.

    /// The DI component used for the current iteration of the multi-
    /// stage build process. Once `finalStageBuild` method is invoked,
    /// this property returns a separate new instance representing a
    /// new pass of the multi-stage building process.
    public var componentForCurrentBuildPass: Component {
        if let currentPassComponent = currentPassComponent {
            return currentPassComponent
        } else {
            let currentPassComponent = componentBuilder()

            // Ensure each invocation of componentBuilder produces a new
            // component instance.
            let newComponent = currentPassComponent as AnyObject
            if lastComponent === newComponent {
                assertionFailure("\(self) componentBuilder should produce new instances of component when build is invoked.")
            }
            lastComponent = newComponent

            self.currentPassComponent = currentPassComponent
            return currentPassComponent
        }
    }

    /// Initializer.
    ///
    /// - parameter componentBuilder: The closure to instantiate a new
    /// instance of the DI component that should be paired with this napkin.
    public init(componentBuilder: @escaping () -> Component) {
        self.componentBuilder = componentBuilder
    }

    /// Build a new instance of the napkin with the given dynamic dependency
    /// as the last stage of this mult-stage building process.
    ///
    /// - note: Subsequent access to the `component` property after this
    /// method is returned will result in a separate new instance of the
    /// component, representing a new pass of the multi-stage building
    /// process.
    /// - parameter dynamicDependency: The dynamic dependency to use.
    /// - returns: The router of the napkin.
    public final func finalStageBuild(withDynamicDependency dynamicDependency: DynamicBuildDependency) -> Router {
        let router = finalStageBuild(with: componentForCurrentBuildPass, dynamicDependency)
        defer {
            currentPassComponent = nil
        }
        return router
    }

    /// Abstract method that must be overriden to implement the napkin building
    /// logic using the given component and dynamic dependency, as the last
    /// building stage.
    ///
    /// - note: This method should never be invoked directly. Instead
    /// consumers of this builder should invoke `finalStageBuild(with dynamicDependency:)`.
    /// - parameter component: The corresponding DI component to use.
    /// - parameter dynamicDependency: The given dynamic dependency.
    /// - returns: The router of the napkin.
    open func finalStageBuild(with component: Component, _ dynamicDependency: DynamicBuildDependency) -> Router {
        fatalError("This method should be overridden by the subclass.")
    }

    // MARK: - Private

    private let componentBuilder: () -> Component
    private var currentPassComponent: Component?
    private weak var lastComponent: AnyObject?
}

/// A convenient base multi-stage builder class that does not require any
/// build dynamic dependencies.
///
/// - note: If the build method requires dynamic dependency, please
/// refer to `MultiStageComponentizedBuilder`.
///
/// - SeeAlso: MultiStageComponentizedBuilder
open class SimpleMultiStageComponentizedBuilder<Component, Router>: MultiStageComponentizedBuilder<Component, Router, ()> {

    /// Initializer.
    ///
    /// - parameter componentBuilder: The closure to instantiate a new
    /// instance of the DI component that should be paired with this napkin.
    public override init(componentBuilder: @escaping () -> Component) {
        super.init(componentBuilder: componentBuilder)
    }

    /// This method should not be directly invoked.
    public final override func finalStageBuild(with component: Component, _ dynamicDependency: ()) -> Router {
        return finalStageBuild(with: component)
    }

    /// Abstract method that must be overriden to implement the napkin building
    /// logic using the given component.
    ///
    /// - note: This method should never be invoked directly. Instead
    /// consumers of this builder should invoke `finalStageBuild()`.
    /// - parameter component: The corresponding DI component to use.
    /// - returns: The router of the napkin.
    open func finalStageBuild(with component: Component) -> Router {
        fatalError("This method should be overridden by the subclass.")
    }

    /// Build a new instance of the napkin as the last stage of this mult-
    /// stage building process.
    ///
    /// - note: Subsequent access to the `component` property after this
    /// method is returned will result in a separate new instance of the
    /// component, representing a new pass of the multi-stage building
    /// process.
    /// - returns: The router of the napkin.
    public final func finalStageBuild() -> Router {
        return finalStageBuild(withDynamicDependency: ())
    }
}
