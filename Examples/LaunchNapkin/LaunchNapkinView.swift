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
            Button("Tap") {
                dispatch { [listener] in await listener?.didTap() }
            }
        }
    }
}

#Preview {
    LaunchNapkinView()
}
