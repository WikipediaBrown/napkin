//
//  QuoteNapkinView.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import SwiftUI
import napkin

struct QuoteNapkinView: View {
    var quote: String = ""
    weak var listener: QuoteNapkinPresentableListener?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text(quote)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier(NapkinAccessibility.Quote.quoteLabel)
                Button("New Quote") {
                    dispatch { [listener] in await listener?.didTapNewQuote() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(NapkinAccessibility.Quote.newQuoteButton)
                Spacer()
            }
            .navigationTitle("Quote")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dispatch { [listener] in await listener?.didTapDone() }
                    }
                    .accessibilityIdentifier(NapkinAccessibility.Quote.doneButton)
                }
            }
        }
    }
}

#Preview {
    QuoteNapkinView()
}
