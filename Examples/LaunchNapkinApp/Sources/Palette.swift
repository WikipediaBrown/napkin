import SwiftUI

// Color tokens lifted from the marketing site's design system
// (Tools/site/styles.css, `--paper`, `--ink`, `--moss`, etc.) and converted
// from OKLCH to sRGB. LoggedOut uses the light palette; LoggedIn uses the
// dark palette so the two screens read as opposite ends of the same system.
enum Palette {

    enum Light {
        static let paper      = Color(red: 0.965, green: 0.940, blue: 0.870)
        static let paperDeep  = Color(red: 0.930, green: 0.895, blue: 0.815)
        static let ink        = Color(red: 0.105, green: 0.143, blue: 0.180)
        static let ink2       = Color(red: 0.214, green: 0.286, blue: 0.314)
        static let ink3       = Color(red: 0.430, green: 0.460, blue: 0.485)
        static let moss       = Color(red: 0.205, green: 0.408, blue: 0.275)
    }

    enum Dark {
        static let paper      = Color(red: 0.055, green: 0.082, blue: 0.065)
        static let paperDeep  = Color(red: 0.090, green: 0.118, blue: 0.098)
        static let ink        = Color(red: 0.957, green: 0.918, blue: 0.847)
        static let ink2       = Color(red: 0.820, green: 0.788, blue: 0.720)
        static let ink3       = Color(red: 0.564, green: 0.553, blue: 0.510)
        static let moss       = Color(red: 0.500, green: 0.810, blue: 0.600)
        static let amber      = Color(red: 0.910, green: 0.745, blue: 0.420)
    }
}
