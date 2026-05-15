// snippet.hide
import XCTest
import napkin

// Stand-in types for the snippet to compile without the example app context.
protocol CartPresentable: Presentable, Sendable {
    @MainActor var listener: CartPresentableListener? { get set }
    func update(items: [CartItem]) async
}
protocol CartPresentableListener: AnyObject, Sendable {
    func didTapAddItem(_ item: CartItem) async
}
struct CartItem: Sendable, Equatable {
    let name: String
}
final actor CartInteractor: PresentableInteractable, CartPresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: CartPresentable
    private var items: [CartItem] = []
    init(presenter: CartPresentable) { self.presenter = presenter }
    func didBecomeActive() async {}
    func willResignActive() async {}
    func didTapAddItem(_ item: CartItem) async {
        items.append(item)
        await presenter.update(items: items)
    }
}
// snippet.show

// Pattern: unit-test an actor interactor by mocking its protocols.
// No simulator, no XCTestExpectation, no scheduler tricks.

@MainActor
final class MockCartPresentable: CartPresentable {
    weak var listener: CartPresentableListener?

    // Recorded calls. The test asserts on these.
    var updateCalls: [[CartItem]] = []

    func update(items: [CartItem]) async {
        updateCalls.append(items)
    }
}

@MainActor
final class CartInteractorTests: XCTestCase {

    func testDidTapAddItem_appendsItemAndUpdatesPresenter() async {
        // Arrange
        let presenter = MockCartPresentable()
        let sut = CartInteractor(presenter: presenter)

        // Act
        await sut.didTapAddItem(CartItem(name: "brisket"))
        await sut.didTapAddItem(CartItem(name: "ribs"))

        // Assert — observable state, not internals.
        XCTAssertEqual(presenter.updateCalls.count, 2)
        XCTAssertEqual(presenter.updateCalls.last, [
            CartItem(name: "brisket"),
            CartItem(name: "ribs"),
        ])
    }
}
