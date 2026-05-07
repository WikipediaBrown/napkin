// snippet.hide
import napkin

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

// snippet.show
import SwiftUI
import napkin

struct ProfileView: View {
    var displayName: String = ""
    weak var listener: ProfilePresentableListener?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(displayName).font(.title)
                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dispatch { [listener] in await listener?.didTapDone() }
                    }
                }
            }
        }
    }
}
