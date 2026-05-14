import SwiftUI
import napkin

struct LoggedOutNapkinView: View {
    weak var listener: LoggedOutNapkinPresentableListener?

    var body: some View {
        ZStack {
            Palette.Light.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                Spacer()

                // Kicker — same pattern as the site's `§ 00 · The framework`.
                HStack(spacing: 6) {
                    Text("§ 00").bold()
                    Text("·").foregroundStyle(Palette.Light.ink3.opacity(0.5))
                    Text("WELCOME")
                }
                .font(.system(.caption, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Palette.Light.ink3)

                // Hero title in editorial serif italic, like `<em>tree</em>`
                // on the homepage.
                (Text("Step inside the\n")
                    + Text("smokehouse").italic()
                    + Text("."))
                    .font(.system(size: 52, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.Light.ink)
                    .accessibilityIdentifier(NapkinAccessibility.LoggedOut.title)

                // Lede in serif body, matching `.hero__lede`.
                Text("Sign in to see what's on the tray today.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Palette.Light.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Palette.Light.ink3.opacity(0.35))
                    .frame(height: 1)

                Spacer()

                // Ink button — dark fill, paper text, mono caps tracked,
                // mirrors `.btn--ink` from the site.
                Button {
                    dispatch { [listener] in await listener?.didTapLogin() }
                } label: {
                    HStack(spacing: 14) {
                        Text("Login")
                            .font(.system(.body, design: .monospaced))
                            .textCase(.uppercase)
                            .tracking(2)
                        Text("→").font(.body)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .background(Palette.Light.ink)
                .foregroundStyle(Palette.Light.paper)
                .clipShape(Capsule())
                .accessibilityIdentifier(NapkinAccessibility.LoggedOut.loginButton)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    LoggedOutNapkinView()
}
