import SwiftUI
import napkin

struct PongNapkinView: View {
    weak var listener: PongNapkinPresentableListener?

    var body: some View {
        ZStack {
            // Cool, deep background so Pong reads as the opposite of Ping.
            Color(red: 0.08, green: 0.13, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Pong")
                    .font(.system(size: 96, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.84))
                    .accessibilityIdentifier(NapkinAccessibility.Pong.label)

                Button {
                    dispatch { [listener] in await listener?.didTapSwap() }
                } label: {
                    Text("Swap")
                        .font(.system(.title3, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(2)
                        .frame(minWidth: 200, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.95, green: 0.78, blue: 0.30))
                .accessibilityIdentifier(NapkinAccessibility.Pong.swapButton)
            }
        }
    }
}

#Preview {
    PongNapkinView()
}
