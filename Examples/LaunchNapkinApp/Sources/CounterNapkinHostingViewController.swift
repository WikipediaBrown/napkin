//
//  CounterNapkinHostingViewController.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin
import SwiftUI

protocol CounterNapkinPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

#if canImport(UIKit)
@MainActor
final class CounterNapkinViewController:
    UIHostingController<CounterNapkinView>,
    CounterNapkinPresentable
{

    weak var listener: CounterNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: CounterNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(count: Int) async {
        rootView.count = count
    }
}
#elseif canImport(AppKit)
@MainActor
final class CounterNapkinViewController:
    NSHostingController<CounterNapkinView>,
    CounterNapkinPresentable
{

    weak var listener: CounterNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: CounterNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(count: Int) async {
        rootView.count = count
    }
}
#endif

extension CounterNapkinViewController: CounterNapkinViewControllable {}
