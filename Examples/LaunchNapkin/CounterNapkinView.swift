//
//  CounterNapkinView.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import SwiftUI
import napkin

struct CounterNapkinView: View {
    var count: Int = 0
    weak var listener: CounterNapkinPresentableListener?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(count)")
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.top, 60)
                    .accessibilityIdentifier(NapkinAccessibility.Counter.countLabel)

                HStack(spacing: 16) {
                    Button("-") {
                        dispatch { [listener] in await listener?.didTapDecrement() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier(NapkinAccessibility.Counter.decrementButton)

                    Button("+") {
                        dispatch { [listener] in await listener?.didTapIncrement() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier(NapkinAccessibility.Counter.incrementButton)
                }
                Spacer()
            }
            .navigationTitle("Counter")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dispatch { [listener] in await listener?.didTapDone() }
                    }
                    .accessibilityIdentifier(NapkinAccessibility.Counter.doneButton)
                }
            }
        }
    }
}

#Preview {
    CounterNapkinView()
}
