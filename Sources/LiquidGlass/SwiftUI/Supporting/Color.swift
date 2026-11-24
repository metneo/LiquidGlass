//
//  Color.swift
//  LiquidGlass
//
//  Created by Oren on 11/30/25.
//

import SwiftUI

/// Color constants for LiquidGlass effects.
///
/// These colors are defined in the asset catalog and automatically adapt
/// to light and dark appearance modes.
extension Color {
    /// Highlight color used for glass brightness effects.
    static let highlight = Color("highlightColor", bundle: .module)
    
    /// Shadow color used for depth and elevation effects.
    static let shadow = Color("shadowColor", bundle: .module)
    
    /// Stroke color used for glass edge highlighting.
    static let stroke = Color("strokeColor", bundle: .module)
}
