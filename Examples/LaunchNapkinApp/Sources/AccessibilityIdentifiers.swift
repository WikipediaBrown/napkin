//
//  AccessibilityIdentifiers.swift
//  napkin example
//
//  Centralized accessibility identifiers for UI testing. Shared between the
//  app target (which sets the identifiers via `.accessibilityIdentifier(...)`)
//  and the UI test target (which queries them via `app.buttons[...]` etc.).
//

import Foundation

public enum NapkinAccessibility {

    public enum Launch {
        // Container view ID — the UI test uses this to confirm the host is up.
        public static let container = "launch.container"
    }

    public enum Ping {
        public static let label = "ping.label"
        public static let connectedCount = "ping.connectedCount"
        public static let swapButton = "ping.swapButton"
    }

    public enum Pong {
        public static let label = "pong.label"
        public static let connectedCount = "pong.connectedCount"
        public static let swapButton = "pong.swapButton"
    }
}
