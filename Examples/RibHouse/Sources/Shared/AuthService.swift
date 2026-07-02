import Foundation

protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
    func userStream() async -> AsyncStream<User?>
}

// Mock implementation that hands back Smokey Joe with a tray of barbecue.
// Now an actor broadcaster — the README's CurrentValueSubject replacement:
// it owns the current user and replays it to every new subscriber, so the
// LaunchNapkin's gate routes from state instead of from taps. In a real
// app a concrete implementation would talk to a server; the LaunchNapkin
// only depends on the protocol, so the wiring doesn't change.
actor BarbecueAuthService: AuthService {

    private(set) var currentUser: User?
    private var subscribers: [UUID: AsyncStream<User?>.Continuation] = [:]

    func login() async throws -> User {
        let user = User(
            name: "Smokey Joe",
            barbecueFoods: [
                "Brisket",
                "Pulled Pork",
                "St. Louis Ribs",
                "Burnt Ends",
                "Smoked Sausage",
            ]
        )
        setUser(user)
        return user
    }

    func logout() async throws {
        setUser(nil)
    }

    /// A fresh stream per subscriber: the current value immediately, then
    /// every change.
    func userStream() -> AsyncStream<User?> {
        let (stream, continuation) = AsyncStream.makeStream(of: User?.self)
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(currentUser)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    // MARK: - Private

    private func setUser(_ user: User?) {
        currentUser = user
        for continuation in subscribers.values {
            continuation.yield(user)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}
