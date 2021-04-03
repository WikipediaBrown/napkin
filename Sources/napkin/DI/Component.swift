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

/// The base class for all components.
///
/// A component defines private properties a RIB provides to its internal `Router`, `Interactor`, `Presenter` and
/// view units, as well as public properties to its child RIBs.
///
/// A component subclass implementation should conform to child 'Dependency' protocols, defined by all of its immediate
/// children.
open class Component<DependencyType>: Dependency {

    /// The dependency of this `Component`.
    public let dependency: DependencyType

    /// Initializer.
    ///
    /// - parameter dependency: The dependency of this `Component`, usually provided by the parent `Component`.
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }
}

/// The special empty component.
open class EmptyComponent: EmptyDependency {

    /// Initializer.
    public init() {}
}
