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

/// The base protocol for all presenters in the napkin architecture.
///
/// Presenters act as an intermediary between the ``Interactor`` and the view layer.
/// They transform business models into view-friendly formats.
///
/// - SeeAlso: ``Presenter``
public protocol Presentable: AnyObject {}

/// A base class for presenters that transform business data for display.
///
/// The `Presenter` sits between the ``Interactor`` and the view controller,
/// providing a clear separation between business logic and view logic.
///
/// ## Overview
///
/// Presenters are optional in the napkin architecture. Use them when you need to:
/// - Transform complex business models into simple view models
/// - Format data for display (dates, currencies, etc.)
/// - Keep the interactor focused on business logic
/// - Keep the view controller focused on UI rendering
///
/// ## Usage
///
/// Create a presenter that transforms data for the view:
///
/// ```swift
/// protocol MyPresentable: AnyObject {
///     func presentItems(_ items: [Item])
///     func presentError(_ error: Error)
/// }
///
/// final class MyPresenter: Presenter<MyViewControllable>, MyPresentable {
///
///     func presentItems(_ items: [Item]) {
///         let viewModels = items.map { item in
///             ItemViewModel(
///                 title: item.name.uppercased(),
///                 subtitle: formatDate(item.date),
///                 imageURL: item.thumbnailURL
///             )
///         }
///         viewController.displayItems(viewModels)
///     }
///
///     func presentError(_ error: Error) {
///         let message = ErrorFormatter.format(error)
///         viewController.displayError(message)
///     }
///
///     private func formatDate(_ date: Date) -> String {
///         let formatter = DateFormatter()
///         formatter.dateStyle = .medium
///         return formatter.string(from: date)
///     }
/// }
/// ```
///
/// ## When to Use Presenters
///
/// Presenters are optional. Consider using one when:
/// - You have complex data transformations
/// - Multiple views display the same data differently
/// - You want to unit test view formatting logic
///
/// For simple cases, the interactor can communicate directly with the view.
///
/// ## Topics
///
/// ### Creating a Presenter
///
/// - ``init(viewController:)``
/// - ``viewController``
///
/// - SeeAlso: ``Presentable``
/// - SeeAlso: ``PresentableInteractor``
/// - SeeAlso: ``Interactor``
open class Presenter<ViewControllerType>: Presentable {

    /// The view controller that this presenter updates.
    ///
    /// Use this property to send formatted data to the view for display.
    /// The view controller should conform to a protocol that defines
    /// the available display methods.
    public let viewController: ViewControllerType

    /// Creates a presenter with the specified view controller.
    ///
    /// - Parameter viewController: The view controller that will display
    ///   the data formatted by this presenter.
    public init(viewController: ViewControllerType) {
        self.viewController = viewController
    }
}
