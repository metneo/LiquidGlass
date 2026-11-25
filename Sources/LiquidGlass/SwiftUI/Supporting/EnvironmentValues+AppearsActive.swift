//
//  EnvironmentValues+AppearsActive.swift
//  LiquidGlass
//
//  Back-deploys the system `appearsActive` environment value to this package's
//  minimum deployment targets.
//

import SwiftUI

extension EnvironmentValues {
    /// The system `appearsActive` environment value, back-deployed to this
    /// package's minimum platforms.
    ///
    /// The system key is declared only on iOS 18 / macOS 15 / tvOS 18 /
    /// watchOS 11 and later, while the package supports iOS 15 / macOS 12 /
    /// tvOS 15 / watchOS 8. On the earlier runtimes this reports `true` — the
    /// system's default where appearance activity isn't tracked — so the glass
    /// keeps its active treatment.
    var liquidGlassAppearsActive: Bool {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) {
            return appearsActive
        }
        return true
    }
}