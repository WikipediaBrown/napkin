//
//  LaunchNapkinHostingViewController.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin
import Combine
import SwiftUI

protocol LaunchNapkinPresentableListener: AnyObject {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor class.
}

@MainActor final class LaunchNapkinViewController: UIHostingController<LaunchNapkinView>, LaunchNapkinPresentable {

    weak var listener: LaunchNapkinPresentableListener?

    init() {
        super.init(rootView: LaunchNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LaunchNapkinViewController: LaunchNapkinViewControllable {}
