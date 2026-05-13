// snippet.hide
import napkin

protocol CounterPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

// snippet.show
import SwiftUI
import napkin

struct CounterView: View {
    var count: Int = 0
    weak var listener: CounterPresentableListener?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(count)")
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.top, 60)

                HStack(spacing: 16) {
                    Button("-") {
                        dispatch { [listener] in await listener?.didTapDecrement() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("+") {
                        dispatch { [listener] in await listener?.didTapIncrement() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
            .navigationTitle("Counter")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dispatch { [listener] in await listener?.didTapDone() }
                    }
                }
            }
        }
    }
}
