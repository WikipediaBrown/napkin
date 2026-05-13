// snippet.hide
import napkin
import SwiftUI

#if canImport(UIKit)
struct CounterView: View {
    var count: Int = 0
    weak var listener: CounterPresentableListener?
    var body: some View { Text("\(count)") }
}

@MainActor
protocol CounterViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}
#endif

// snippet.show
import napkin
import SwiftUI

protocol CounterPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

#if canImport(UIKit)
@MainActor
final class CounterViewController:
    UIHostingController<CounterView>,
    CounterPresentable
{
    weak var listener: CounterPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: CounterView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(count: Int) async {
        rootView.count = count
    }
}
#endif

#if canImport(UIKit)
extension CounterViewController: CounterViewControllable {}
#endif

// snippet.hide
protocol CounterPresentable: Presentable, Sendable {
    @MainActor var listener: CounterPresentableListener? { get set }
    func update(count: Int) async
}
