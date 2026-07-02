import SwiftUI

struct PitBoardNapkinView: View {
    weak var presenter: PitBoardNapkinPresenter?

    var body: some View {
        ZStack {
            Palette.Dark.paperDeep.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 8)

                    HStack(spacing: 6) {
                        Text("§ 01").bold()
                        Text("·").foregroundStyle(Palette.Dark.ink3.opacity(0.5))
                        Text("THE PIT, LIVE")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.Dark.ink3)
                    .accessibilityIdentifier(NapkinAccessibility.PitBoard.title)

                    ForEach(presenter?.sections ?? []) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.title.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(Palette.Dark.moss)

                            ForEach(section.items) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 16) {
                                    Text(item.name)
                                        .font(.system(.title3, design: .serif))
                                        .foregroundStyle(Palette.Dark.ink)
                                    Spacer()
                                    Text(item.stage.label.uppercased())
                                        .font(.system(.caption2, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(Palette.Dark.amber)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("\(NapkinAccessibility.PitBoard.itemPrefix).\(item.id)")
                            }
                        }
                        .transition(.opacity)
                    }

                    Rectangle()
                        .fill(Palette.Dark.ink3.opacity(0.35))
                        .frame(height: 1)

                    Text("TODAY'S SPECIALS")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Palette.Dark.ink3)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(presenter?.specials ?? []) { special in
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text("★")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Palette.Dark.amber)
                                    .frame(width: 28, alignment: .leading)
                                Text(special.name)
                                    .font(.system(.title3, design: .serif))
                                    .foregroundStyle(Palette.Dark.ink)
                            }
                            .accessibilityIdentifier("\(NapkinAccessibility.PitBoard.specialPrefix).\(special.id)")
                        }
                    }
                    .transition(.opacity)

                    Spacer()
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    PitBoardNapkinView()
}
