import Foundation

struct PitItem: Sendable, Equatable, Identifiable {
    enum Stage: Int, Sendable, CaseIterable, Comparable {
        case lighting, smoking, resting, served

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .lighting: "Lighting"
            case .smoking: "Smoking"
            case .resting: "Resting"
            case .served: "Served"
            }
        }
    }

    let id: String
    let name: String
    var stage: Stage
}

enum PitEvent: Sendable, Equatable {
    case lastCall(itemName: String)
}

// The live smoker. Streams follow the "Streaming State Down the Tree"
// recipes from the napkin README: `updates()` replays the current board to
// each new subscriber (the CurrentValueSubject replacement); `events()` has
// no replay (the PassthroughSubject replacement). Every call vends a fresh
// stream — AsyncStream is single-consumer, so that is what makes fan-out
// to the LoggedIn header AND the PitBoard safe.
actor PitService {

    private(set) var items: [PitItem]

    private var updateSubscribers: [UUID: AsyncStream<[PitItem]>.Continuation] = [:]
    private var eventSubscribers: [UUID: AsyncStream<PitEvent>.Continuation] = [:]
    private var ticker: Task<Void, Never>?
    private let tickSeconds: Double

    init(tickSeconds: Double = 4) {
        self.tickSeconds = tickSeconds
        self.items = Self.seededItems()
    }

    func updates() -> AsyncStream<[PitItem]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [PitItem].self)
        let id = UUID()
        updateSubscribers[id] = continuation
        continuation.yield(items)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeUpdateSubscriber(id) }
        }
        return stream
    }

    func events() -> AsyncStream<PitEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: PitEvent.self)
        let id = UUID()
        eventSubscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeEventSubscriber(id) }
        }
        return stream
    }

    /// Starts the simulation. Idempotent; the pit runs only while someone
    /// is logged in (LoggedInNapkin starts it on activate, stops it on
    /// deactivate).
    func start() {
        guard ticker == nil else { return }
        ticker = Task { [tickSeconds] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickSeconds))
                if Task.isCancelled { break }
                await self.tick()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Private

    private func tick() {
        // Advance the first item that isn't served; reseed when everything
        // has been eaten so the demo never goes quiet.
        guard let index = items.firstIndex(where: { $0.stage != .served }) else {
            items = Self.seededItems()
            broadcast()
            return
        }
        let next = PitItem.Stage(rawValue: items[index].stage.rawValue + 1) ?? .served
        items[index].stage = next
        if next == .resting {
            for continuation in eventSubscribers.values {
                continuation.yield(.lastCall(itemName: items[index].name))
            }
        }
        broadcast()
    }

    private func broadcast() {
        for continuation in updateSubscribers.values {
            continuation.yield(items)
        }
    }

    private func removeUpdateSubscriber(_ id: UUID) {
        updateSubscribers[id]?.finish()
        updateSubscribers.removeValue(forKey: id)
    }

    private func removeEventSubscriber(_ id: UUID) {
        eventSubscribers[id]?.finish()
        eventSubscribers.removeValue(forKey: id)
    }

    // Seeded so the initial summary is deterministic for tests:
    // 2 smoking + 1 resting = "2 SMOKING · 1 RESTING".
    private static func seededItems() -> [PitItem] {
        [
            PitItem(id: "brisket", name: "Brisket", stage: .smoking),
            PitItem(id: "pulled-pork", name: "Pulled Pork", stage: .smoking),
            PitItem(id: "ribs", name: "St. Louis Ribs", stage: .lighting),
            PitItem(id: "burnt-ends", name: "Burnt Ends", stage: .resting),
            PitItem(id: "sausage", name: "Smoked Sausage", stage: .lighting),
        ]
    }
}
