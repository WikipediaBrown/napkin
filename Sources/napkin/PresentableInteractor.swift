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

/// An interactor that owns and communicates with a presenter.
///
/// `PresentableInteractor` extends ``Interactor`` to add presenter ownership.
/// Use this class when your napkin uses the full MVP (Model-View-Presenter) pattern.
///
/// ## Overview
///
/// A presentable interactor:
/// - Owns a strongly-typed presenter
/// - Sends business data to the presenter for formatting
/// - Receives user events via presenter listener protocols
/// - Automatically registers the presenter for leak detection
///
/// ## Usage
///
/// ```swift
/// protocol MyPresentable: AnyObject {
///     func presentItems(_ items: [Item])
///     func presentLoading()
///     func presentError(_ error: Error)
/// }
///
/// final class MyInteractor: PresentableInteractor<MyPresentable>,
///                           MyInteractable,
///                           MyPresentableListener {
///
///     weak var router: MyRouting?
///     weak var listener: MyListener?
///
///     private let service: MyServiceProtocol
///     private var cancellables = Set<AnyCancellable>()
///
///     init(presenter: MyPresentable, service: MyServiceProtocol) {
///         self.service = service
///         super.init(presenter: presenter)
///     }
///
///     override func didBecomeActive() {
///         super.didBecomeActive()
///         loadItems()
///     }
///
///     private func loadItems() {
///         presenter.presentLoading()
///
///         service.fetchItems()
///             .sink(
///                 receiveCompletion: { [weak self] completion in
///                     if case .failure(let error) = completion {
///                         self?.presenter.presentError(error)
///                     }
///                 },
///                 receiveValue: { [weak self] items in
///                     self?.presenter.presentItems(items)
///                 }
///             )
///             .store(in: &cancellables)
///     }
///
///     // MARK: - MyPresentableListener
///
///     func didSelectItem(at index: Int) {
///         router?.routeToDetails(forItemAt: index)
///     }
/// }
/// ```
///
/// ## When to Use PresentableInteractor
///
/// Use `PresentableInteractor` when:
/// - You have complex data transformations between business models and view models
/// - You want clear separation between business logic and view formatting
/// - Multiple views display the same data differently
///
/// For simpler cases, use ``Interactor`` directly and communicate with the view
/// through the router or directly via a view listener protocol.
///
/// ## Topics
///
/// ### Creating a PresentableInteractor
///
/// - ``init(presenter:)``
/// - ``presenter``
///
/// - SeeAlso: ``Interactor``
/// - SeeAlso: ``Presenter``
open class PresentableInteractor<PresenterType>: Interactor {

    /// The presenter owned by this interactor.
    ///
    /// Use this property to send business data to the presenter for formatting
    /// and display. The presenter transforms the data into view-friendly formats.
    ///
    /// - Note: This property holds a strong reference to the presenter.
    public let presenter: PresenterType

    /// Creates an interactor with the specified presenter.
    ///
    /// - Parameter presenter: The presenter that will format data for the view.
    ///   The interactor retains the presenter strongly.
    public init(presenter: PresenterType) {
        self.presenter = presenter
    }

    // MARK: - Private

    deinit {
        LeakDetector.instance.expectDeallocate(object: presenter as AnyObject)
    }
}
