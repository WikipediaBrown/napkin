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
        public static let container = "launch.container"
    }

    public enum LoggedOut {
        public static let title = "loggedOut.title"
        public static let loginButton = "loggedOut.loginButton"
    }

    public enum LoggedIn {
        public static let nameLabel = "loggedIn.nameLabel"
        public static let logoutButton = "loggedIn.logoutButton"
        // Per-food identifiers are built as `\(foodPrefix).\(food)`.
        public static let foodPrefix = "loggedIn.food"
        public static let pitSummary = "loggedIn.pitSummary"
        public static let banner = "loggedIn.banner"
    }
}
