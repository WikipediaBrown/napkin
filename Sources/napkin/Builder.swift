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

/// The base protocol that all builders should conform to.
///
/// A builder is responsible for instantiating a napkin unit and wiring up all its internal components.
/// Builders are the entry point for creating new napkin units in the application tree.
///
/// ## Overview
///
/// In the napkin architecture, builders serve as factories that:
/// - Create the ``Router``, ``Interactor``, and optionally ``Presenter`` for a napkin unit
/// - Wire up dependencies using a ``Component``
/// - Return a router that represents the fully constructed napkin
///
/// ## Conforming to Buildable
///
/// Custom builder protocols should extend `Buildable` to define their specific build methods:
///
/// ```swift
/// protocol MyFeatureBuildable: Buildable {
///     func build(withListener listener: MyFeatureListener) -> MyFeatureRouting
/// }
/// ```
///
/// - SeeAlso: ``Builder``
/// - SeeAlso: ``Component``
public protocol Buildable: AnyObject {}

/// A base class for creating napkin builders with dependency injection support.
///
/// `Builder` is a generic class that provides the foundation for constructing napkin units.
/// It receives dependencies from its parent napkin and uses them to create child components.
///
/// ## Overview
///
/// The builder is responsible for:
/// 1. Receiving dependencies from the parent napkin via the ``dependency`` property
/// 2. Creating a ``Component`` to provide dependencies to child napkins
/// 3. Instantiating the ``Interactor`` with required services
/// 4. Creating the ``Router`` and wiring it to the interactor
/// 5. Returning the router as the public interface to the napkin
///
/// ## Usage
///
/// Subclass `Builder` and implement a `build` method that constructs your napkin:
///
/// ```swift
/// final class MyFeatureBuilder: Builder<MyFeatureDependency>, MyFeatureBuildable {
///
///     func build(withListener listener: MyFeatureListener) -> MyFeatureRouting {
///         let component = MyFeatureComponent(dependency: dependency)
///         let interactor = MyFeatureInteractor(service: component.myService)
///         interactor.listener = listener
///         return MyFeatureRouter(interactor: interactor)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Builder
///
/// - ``init(dependency:)``
/// - ``dependency``
///
/// - SeeAlso: ``Buildable``
/// - SeeAlso: ``Component``
/// - SeeAlso: ``Router``
open class Builder<DependencyType>: Buildable {

    /// The dependency provided by the parent napkin.
    ///
    /// This property holds the dependencies required by this builder to construct the napkin.
    /// Dependencies are typically defined by a protocol that the parent's ``Component`` conforms to.
    ///
    /// Use this dependency to:
    /// - Pass services to the ``Component`` initializer
    /// - Access shared instances from the parent scope
    /// - Provide required dependencies to the ``Interactor``
    public let dependency: DependencyType

    /// Creates a new builder with the specified dependency.
    ///
    /// - Parameter dependency: The dependency object provided by the parent napkin,
    ///   typically conforming to a protocol that defines required services and objects.
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }
}
