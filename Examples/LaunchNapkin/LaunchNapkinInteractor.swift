//
//  LaunchNapkinInteractor.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin
import Combine

@MainActor protocol LaunchNapkinRouting: LaunchRouting {
    // TODO: Declare methods the interactor can invoke to manage sub-tree via the router.
}

@MainActor protocol LaunchNapkinPresentable: Presentable {
    var listener: LaunchNapkinPresentableListener? { get set }
    // TODO: Declare methods the interactor can invoke the presenter to present data.
}

@MainActor protocol LaunchNapkinListener: AnyObject {
    // TODO: Declare methods the interactor can invoke to communicate with other napkins.
}

@MainActor final class LaunchNapkinInteractor: PresentableInteractor<LaunchNapkinPresentable>, LaunchNapkinInteractable, LaunchNapkinPresentableListener {

    weak var router: LaunchNapkinRouting?
    weak var listener: LaunchNapkinListener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init(presenter: LaunchNapkinPresentable) {
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        // TODO: Implement business logic here.
    }

    override func willResignActive() {
        super.willResignActive()
        // TODO: Pause any business logic.
    }
}
