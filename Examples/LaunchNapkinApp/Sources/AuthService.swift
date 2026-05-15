import Foundation

protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
}

// Mock implementation that hands back Smokey Joe with a tray of barbecue.
// In a real app a concrete implementation would talk to a server; the
// LaunchNapkin only depends on the protocol, so the wiring doesn't change.
final class BarbecueAuthService: AuthService {
    func login() async throws -> User {
        User(
            name: "Smokey Joe",
            barbecueFoods: [
                "Brisket",
                "Pulled Pork",
                "St. Louis Ribs",
                "Burnt Ends",
                "Smoked Sausage",
            ]
        )
    }

    func logout() async throws {}
}
