//
//  QuoteNapkinInteractor.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

@MainActor
protocol QuoteNapkinRouting: ViewableRouting, Sendable {
    // Declare methods the interactor can invoke to manage sub-tree via the router.
}

protocol QuoteNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: QuoteNapkinPresentableListener? { get set }
    func update(quote: String) async
}

protocol QuoteNapkinListener: AnyObject, Sendable {
    func quoteDidFinish() async
}

final actor QuoteNapkinInteractor: PresentableInteractable, QuoteNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: QuoteNapkinPresentable

    weak var router: QuoteNapkinRouting?
    weak var listener: QuoteNapkinListener?

    private let quotes: [String] = [
        "Programs must be written for people to read, and only incidentally for machines to execute.",
        "Premature optimization is the root of all evil.",
        "There are 2 hard things in computer science: cache invalidation, naming things, and off-by-one errors."
    ]

    init(presenter: QuoteNapkinPresentable) {
        self.presenter = presenter
    }

    func set(router: QuoteNapkinRouting?) {
        self.router = router
    }

    func set(listener: QuoteNapkinListener?) {
        self.listener = listener
    }

    func didBecomeActive() async {
        let quote = pickQuote()
        let presenter = self.presenter
        await presenter.update(quote: quote)
        await MainActor.run {
            presenter.listener = self
        }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run {
            presenter.listener = nil
        }
    }

    // MARK: - QuoteNapkinPresentableListener

    func didTapNewQuote() async {
        let quote = pickQuote()
        await presenter.update(quote: quote)
    }

    func didTapDone() async {
        await listener?.quoteDidFinish()
    }

    // MARK: - Private

    private func pickQuote() -> String {
        quotes.randomElement() ?? ""
    }
}
