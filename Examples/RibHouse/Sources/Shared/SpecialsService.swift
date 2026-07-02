import Foundation
import Observation

struct Special: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
}

// Main-actor state observed via `Observations` — the @Observable recipe
// from the napkin README. Consumers bind the observation loop to the main
// actor: `task { @MainActor [weak self] in for await … in Observations({ … }) }`.
@MainActor
@Observable
final class SpecialsService {

    private(set) var specials: [Special]

    @ObservationIgnored private var rotation: Task<Void, Never>?
    @ObservationIgnored private var offset = 0
    @ObservationIgnored private let rotationSeconds: Double

    private static let menu: [Special] = [
        Special(id: "hot-links", name: "Hot Links"),
        Special(id: "beef-rib", name: "Dino Beef Rib"),
        Special(id: "cornbread", name: "Skillet Cornbread"),
        Special(id: "banana-pudding", name: "Banana Pudding"),
    ]

    // Constructed on the main actor (SceneDelegate's launch Task) and
    // passed into the nonisolated AppComponent as a Sendable value — the
    // @Observable macro's init accessors are actor-isolated, so this init
    // cannot be nonisolated.
    init(rotationSeconds: Double = 6) {
        self.rotationSeconds = rotationSeconds
        self.specials = Array(Self.menu.prefix(2))
    }

    /// Idempotent; PitBoard starts it on activate.
    func start() {
        guard rotation == nil else { return }
        rotation = Task { [rotationSeconds] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(rotationSeconds))
                if Task.isCancelled { break }
                self.rotate()
            }
        }
    }

    func stop() {
        rotation?.cancel()
        rotation = nil
    }

    private func rotate() {
        offset = (offset + 1) % Self.menu.count
        specials = [
            Self.menu[offset],
            Self.menu[(offset + 1) % Self.menu.count],
        ]
    }
}
