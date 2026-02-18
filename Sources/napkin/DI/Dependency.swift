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

/// The base protocol for all dependency definitions in the napkin architecture.
///
/// A `Dependency` protocol defines the set of dependencies that a napkin requires
/// from its parent. The parent's ``Component`` must conform to this protocol to
/// provide the required dependencies.
///
/// ## Overview
///
/// Dependencies flow down the napkin tree:
/// 1. A child napkin defines a dependency protocol listing what it needs
/// 2. The parent's component conforms to that protocol
/// 3. The parent's component is passed to the child's builder
/// 4. The child's builder uses the dependency to construct its napkin
///
/// ## Defining Dependencies
///
/// Create a protocol that extends `Dependency` and declares the required services:
///
/// ```swift
/// protocol MyFeatureDependency: Dependency {
///     var userService: UserServiceProtocol { get }
///     var analyticsService: AnalyticsServiceProtocol { get }
///     var logger: LoggerProtocol { get }
/// }
/// ```
///
/// ## Providing Dependencies
///
/// The parent component conforms to the child's dependency protocol:
///
/// ```swift
/// final class ParentComponent: Component<ParentDependency>, MyFeatureDependency {
///
///     var userService: UserServiceProtocol {
///         return dependency.userService  // Pass through from grandparent
///     }
///
///     var analyticsService: AnalyticsServiceProtocol {
///         return shared { AnalyticsService() }  // Create locally
///     }
///
///     var logger: LoggerProtocol {
///         return shared { Logger() }
///     }
/// }
/// ```
///
/// - SeeAlso: ``Component``
/// - SeeAlso: ``EmptyDependency``
/// - SeeAlso: ``Builder``
public protocol Dependency: AnyObject {}

/// A dependency protocol for root napkins that require no parent dependencies.
///
/// Use `EmptyDependency` when creating the root napkin of your application,
/// which has no parent to provide dependencies.
///
/// ## Usage
///
/// The root component typically conforms to `EmptyDependency` via ``EmptyComponent``:
///
/// ```swift
/// final class AppComponent: EmptyComponent, RootDependency {
///     // Define root-level dependencies here
/// }
/// ```
///
/// Or create a custom root component:
///
/// ```swift
/// final class AppComponent: Component<EmptyDependency>, RootDependency {
///     init() {
///         super.init(dependency: EmptyComponent())
///     }
/// }
/// ```
///
/// - SeeAlso: ``Dependency``
/// - SeeAlso: ``EmptyComponent``
public protocol EmptyDependency: Dependency {}
