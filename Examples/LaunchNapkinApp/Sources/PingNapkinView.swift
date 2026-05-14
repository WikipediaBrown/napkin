import SwiftUI
import napkin

struct PingNapkinView: View {
    var connectedCount: Int? = nil
    weak var listener: PingNapkinPresentableListener?

    private var connectedText: String {
        guard let n = connectedCount else { return "— napkins connected" }
        return "\(n) napkin\(n == 1 ? "" : "s") connected"
    }

    var body: some View {
        ZStack {
            // Soft, warm background distinguishes Ping from Pong at a glance.
            Color(red: 0.97, green: 0.94, blue: 0.86)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Ping")
                    .font(.system(size: 96, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.18, green: 0.32, blue: 0.27))
                    .accessibilityIdentifier(NapkinAccessibility.Ping.label)

                Text(connectedText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color(red: 0.18, green: 0.32, blue: 0.27).opacity(0.75))
                    .accessibilityIdentifier(NapkinAccessibility.Ping.connectedCount)

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
                .tint(Color(red: 0.18, green: 0.32, blue: 0.27))
                .accessibilityIdentifier(NapkinAccessibility.Ping.swapButton)
            }
        }
    }
}

#Preview {
    PingNapkinView()
}
