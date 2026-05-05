//___FILEHEADER___

import SwiftUI
import napkin

struct ___VARIABLE_productName___View: View {
    // TODO: Bind to presenter state with `@State`/`@Bindable`/`Observations`. Forward
    // user events to the listener with `dispatch { [listener] in await listener?.didTapX() }`
    // — the explicit `[listener]` capture is required for Sendable conformance.
    weak var listener: ___VARIABLE_productName___PresentableListener?

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    ___VARIABLE_productName___View()
}
