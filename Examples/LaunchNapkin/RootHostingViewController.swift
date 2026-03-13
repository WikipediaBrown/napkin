//
//  RootHostingViewController.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin
import Combine
import SwiftUI

@MainActor protocol RootPresentableListener: AnyObject {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor class.
}

@MainActor final class RootViewController: UIHostingController<RootView>, RootPresentable {

    weak var listener: RootPresentableListener?

    init() {
        super.init(rootView: RootView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RootViewController: RootViewControllable {}
