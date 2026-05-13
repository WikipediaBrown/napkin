//
//  AccessibilityIdentifiers.swift
//  napkin example
//
//  Centralized accessibility identifiers for UI testing. Shared between the
//  app target (which sets the identifiers via `.accessibilityIdentifier(...)`)
//  and the UI test target (which queries them via `app.buttons[...]` etc.).
//
//  Identifiers are namespaced by napkin so tests can reference, e.g.,
//  `NapkinAccessibility.Launch.showCounterButton`.
//

import Foundation

public enum NapkinAccessibility {

    public enum Launch {
        public static let greeting = "launch.greeting"
        public static let showCounterButton = "launch.showCounterButton"
        public static let showQuoteButton = "launch.showQuoteButton"
    }

    public enum Counter {
        public static let countLabel = "counter.countLabel"
        public static let incrementButton = "counter.incrementButton"
        public static let decrementButton = "counter.decrementButton"
        public static let doneButton = "counter.doneButton"
    }

    public enum Quote {
        public static let quoteLabel = "quote.quoteLabel"
        public static let newQuoteButton = "quote.newQuoteButton"
        public static let doneButton = "quote.doneButton"
    }
}
