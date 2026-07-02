import SwiftUI
import napkin

struct LoggedInNapkinView: View {
    let user: User
    var pitSummary: String = ""
    var banner: String?
    weak var listener: LoggedInNapkinPresentableListener?

    var body: some View {
        ZStack {
            Palette.Dark.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 8)

                HStack(spacing: 6) {
                    Text("§ ∞").bold()
                    Text("·").foregroundStyle(Palette.Dark.ink3.opacity(0.5))
                    Text("SIGNED IN")
                }
                .font(.system(.caption, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Palette.Dark.ink3)

                // User name in serif italic — same gesture as the site's
                // italic `napkin` wordmark.
                Text(user.name)
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.Dark.ink)
                    .accessibilityIdentifier(NapkinAccessibility.LoggedIn.nameLabel)

                Rectangle()
                    .fill(Palette.Dark.ink3.opacity(0.35))
                    .frame(height: 1)

                if !pitSummary.isEmpty {
                    HStack(spacing: 6) {
                        Text("LIVE FROM THE PIT")
                        Text("·").foregroundStyle(Palette.Dark.ink3.opacity(0.5))
                        Text(pitSummary)
                            .foregroundStyle(Palette.Dark.amber)
                            .accessibilityIdentifier(NapkinAccessibility.LoggedIn.pitSummary)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.Dark.ink3)
                }

                Text("BARBECUE FOODS")
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.Dark.ink3)

                // Spec-list pattern from the homepage: numbered index in mono
                // caps + serif body, one row per item.
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(user.barbecueFoods.enumerated()), id: \.element) { index, food in
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Palette.Dark.moss)
                                .frame(width: 28, alignment: .leading)
                            Text(food)
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(Palette.Dark.ink)
                        }
                        .accessibilityIdentifier("\(NapkinAccessibility.LoggedIn.foodPrefix).\(food)")
                    }
                }

                Spacer()

                Button {
                    dispatch { [listener] in await listener?.didTapPitBoard() }
                } label: {
                    Text("Pit Board")
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(2)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .background(Capsule().fill(Palette.Dark.moss.opacity(0.25)))
                .overlay(Capsule().stroke(Palette.Dark.moss.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Palette.Dark.ink)
                .accessibilityIdentifier(NapkinAccessibility.LoggedIn.pitBoardButton)

                // Ghost button — outlined paper-on-paper-deep, mono caps.
                Button {
                    dispatch { [listener] in await listener?.didTapLogout() }
                } label: {
                    Text("Logout")
                        .font(.system(.body, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(2)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .overlay(Capsule().stroke(Palette.Dark.ink.opacity(0.45), lineWidth: 1))
                .foregroundStyle(Palette.Dark.ink)
                .accessibilityIdentifier(NapkinAccessibility.LoggedIn.logoutButton)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 48)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let banner {
                Text(banner)
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.Dark.amber))
                    .foregroundStyle(Palette.Dark.paper)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier(NapkinAccessibility.LoggedIn.banner)
            }
        }
    }
}

#Preview {
    LoggedInNapkinView(
        user: User(
            name: "Smokey Joe",
            barbecueFoods: ["Brisket", "Pulled Pork", "St. Louis Ribs", "Burnt Ends", "Smoked Sausage"]
        )
    )
}
