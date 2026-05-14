import SwiftUI
import napkin

struct PongNapkinView: View {
    var connectedCount: Int? = nil
    weak var listener: PongNapkinPresentableListener?

    private var connectedText: String {
        guard let n = connectedCount else { return "— napkins connected" }
        return "\(n) napkin\(n == 1 ? "" : "s") connected"
    }

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

                Text(connectedText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.92, blue: 0.84).opacity(0.7))
                    .accessibilityIdentifier(NapkinAccessibility.Pong.connectedCount)

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
