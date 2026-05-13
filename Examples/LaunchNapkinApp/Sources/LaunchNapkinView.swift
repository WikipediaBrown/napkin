//
//  LaunchNapkinView.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import SwiftUI
import napkin

struct LaunchNapkinView: View {
    // Forward user events to the listener with `dispatch { await listener?.didTapX() }`.
    weak var listener: LaunchNapkinPresentableListener?

    var body: some View {
        VStack(spacing: 16) {
            Text("Hello, World!")
                .font(.title2)
                .accessibilityIdentifier(NapkinAccessibility.Launch.greeting)
            Button("Show Counter") {
                dispatch { [listener] in await listener?.didTapShowCounter() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(NapkinAccessibility.Launch.showCounterButton)
            Button("Show Quote") {
                dispatch { [listener] in await listener?.didTapShowQuote() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(NapkinAccessibility.Launch.showQuoteButton)
        }
    }
}

#Preview {
    LaunchNapkinView()
}
