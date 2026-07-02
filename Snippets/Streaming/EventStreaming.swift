// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// events (PassthroughSubject replacement). Keep the README code block
// in sync with the `snippet.show` region of this file.
//
import napkin
import Foundation
// snippet.show

enum AuthEvent: Sendable {
    case sessionExpired
    case passwordChanged
}

/// Replaces `PassthroughSubject`: the same fan-out actor, minus the
/// replay. New subscribers see only events sent after they subscribed.
actor AuthEventBus {

    private var subscribers: [UUID: AsyncStream<AuthEvent>.Continuation] = [:]

    func events() -> AsyncStream<AuthEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: AuthEvent.self)
        let id = UUID()
        subscribers[id] = continuation
        // No `continuation.yield(current)` here — that one line is the
        // whole difference between CurrentValueSubject and
        // PassthroughSubject.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    func send(_ event: AuthEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}

// Consumed exactly like state — a lifecycle-bound task:
final actor SessionMonitorInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    private let eventBus: AuthEventBus

    init(eventBus: AuthEventBus) {
        self.eventBus = eventBus
    }

    func didBecomeActive() async {
        task {
            for await event in await self.eventBus.events() {
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: AuthEvent) { /* … */ }
}
