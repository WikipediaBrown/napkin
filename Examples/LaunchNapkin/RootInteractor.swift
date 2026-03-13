//
//  RootInteractor.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin
import Combine

@MainActor protocol RootRouting: LaunchRouting {
    // TODO: Declare methods the interactor can invoke to manage sub-tree via the router.
}

@MainActor protocol RootPresentable: Presentable {
    var listener: RootPresentableListener? { get set }
    // TODO: Declare methods the interactor can invoke the presenter to present data.
}

@MainActor protocol RootListener: AnyObject {
    // TODO: Declare methods the interactor can invoke to communicate with other napkins.
}

@MainActor final class RootInteractor: PresentableInteractor<RootPresentable>, RootInteractable, RootPresentableListener {

    weak var router: RootRouting?
    weak var listener: RootListener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init(presenter: RootPresentable) {
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
