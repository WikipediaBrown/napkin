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

import UIKit

/// A protocol that provides access to the underlying UIKit view controller.
///
/// `ViewControllable` serves as the bridge between the napkin architecture and UIKit.
/// It allows routers to manage view controller presentation and hierarchy without
/// depending on concrete view controller types.
///
/// ## Overview
///
/// All view controllers used with ``ViewableRouter`` must conform to this protocol.
/// The protocol provides a single property that returns the underlying `UIViewController`.
///
/// ## UIKit View Controllers
///
/// For standard UIKit view controllers, conformance is automatic via the default
/// implementation:
///
/// ```swift
/// final class MyViewController: UIViewController, MyViewControllable {
///     // Automatically conforms via default implementation
/// }
/// ```
///
/// ## SwiftUI Views
///
/// For SwiftUI views, wrap them in a `UIHostingController`:
///
/// ```swift
/// import SwiftUI
///
/// protocol MyViewControllable: ViewControllable {}
///
/// final class MyHostingController: UIHostingController<MySwiftUIView>,
///                                  MyViewControllable {
///
///     init(viewModel: MyViewModel, listener: MyViewListener) {
///         let view = MySwiftUIView(viewModel: viewModel, listener: listener)
///         super.init(rootView: view)
///     }
///
///     required init?(coder: NSCoder) {
///         fatalError("init(coder:) has not been implemented")
///     }
/// }
/// ```
///
/// ## Defining Feature-Specific Protocols
///
/// Define a feature-specific protocol that extends `ViewControllable`:
///
/// ```swift
/// protocol MyFeatureViewControllable: ViewControllable {
///     func displayData(_ data: MyViewModel)
///     func displayError(_ message: String)
/// }
/// ```
///
/// - SeeAlso: ``ViewableRouter``
/// - SeeAlso: ``ViewableRouting``
public protocol ViewControllable: AnyObject {

    /// The underlying UIKit view controller.
    ///
    /// Use this property when you need to present, embed, or otherwise
    /// manipulate the view controller in the UIKit hierarchy.
    var uiviewController: UIViewController { get }
}

/// Default implementation that makes `UIViewController` subclasses
/// automatically conform to ``ViewControllable``.
///
/// This extension allows any `UIViewController` subclass to satisfy
/// the `ViewControllable` protocol without additional implementation.
public extension ViewControllable where Self: UIViewController {

    /// Returns `self` as the underlying view controller.
    var uiviewController: UIViewController {
        return self
    }
}
