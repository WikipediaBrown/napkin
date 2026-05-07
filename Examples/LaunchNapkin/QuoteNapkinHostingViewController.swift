//
//  QuoteNapkinHostingViewController.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin
import SwiftUI

protocol QuoteNapkinPresentableListener: AnyObject, Sendable {
    func didTapNewQuote() async
    func didTapDone() async
}

#if canImport(UIKit)
@MainActor
final class QuoteNapkinViewController:
    UIHostingController<QuoteNapkinView>,
    QuoteNapkinPresentable
{

    weak var listener: QuoteNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: QuoteNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(quote: String) async {
        rootView.quote = quote
    }
}
#elseif canImport(AppKit)
@MainActor
final class QuoteNapkinViewController:
    NSHostingController<QuoteNapkinView>,
    QuoteNapkinPresentable
{

    weak var listener: QuoteNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: QuoteNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(quote: String) async {
        rootView.quote = quote
    }
}
#endif

extension QuoteNapkinViewController: QuoteNapkinViewControllable {}
