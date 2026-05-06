//
//  LaunchNapkinHostingViewController.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin
import SwiftUI

protocol LaunchNapkinPresentableListener: AnyObject, Sendable {
    // Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor actor; methods are async.
    func didTap() async
}

#if canImport(UIKit)
@MainActor final class LaunchNapkinViewController: UIHostingController<LaunchNapkinView>, LaunchNapkinPresentable {

    weak var listener: LaunchNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: LaunchNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#elseif canImport(AppKit)
@MainActor final class LaunchNapkinViewController: NSHostingController<LaunchNapkinView>, LaunchNapkinPresentable {

    weak var listener: LaunchNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: LaunchNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

extension LaunchNapkinViewController: LaunchNapkinViewControllable {}
