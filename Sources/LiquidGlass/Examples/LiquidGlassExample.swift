//
//  LiquidGlassExample.swift
//  LiquidGlass
//
//  SwiftUI previews demonstrating the LiquidGlass library features.
//

import SwiftUI

// MARK: - Preview Container

/// A preview demonstrating the various glass effects and shapes available in LiquidGlass.
struct LiquidGlassExample: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // MARK: Header
                
                VStack(spacing: 8) {
                    Text("Liquid Glass")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Frosted Glass Backgrounds for SwiftUI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // MARK: - Basic Shapes Section
                
                VStack(alignment: .center, spacing: 20) {
                    Text("Basic Shapes")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Rounded Rectangle
                    VStack(spacing: 8) {
                        Text("Rounded Rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Hello, World!")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(20)
                            .liquidGlass(shape: .roundedRect(cornerRadius: 16))
                    }
                    
                    // Circle
                    VStack(spacing: 8) {
                        Text("Circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("🌟")
                            .font(.largeTitle)
                            .padding(20)
                            .liquidGlass(shape: .circle)
                    }
                    
                    // Capsule
                    VStack(spacing: 8) {
                        Text("Capsule")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Liquid Glass")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .liquidGlass(shape: .capsule)
                    }
                }
                
                // MARK: - Tinted Glass Section
                
                VStack(alignment: .center, spacing: 20) {
                    Text("Tinted Glass (Custom LiquidGlass)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        // Blue tint
                        VStack {
                            Text("Blue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LiquidGlass(shape: .roundedRect(cornerRadius: 12))
                                .tint(.blue)
                                .frame(width: 80, height: 80)
                        }
                        
                        // Green tint
                        VStack {
                            Text("Green")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LiquidGlass(shape: .roundedRect(cornerRadius: 12))
                                .tint(.green)
                                .frame(width: 80, height: 80)
                        }
                        
                        // Pink tint
                        VStack {
                            Text("Pink")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LiquidGlass(shape: .roundedRect(cornerRadius: 12))
                                .tint(.pink)
                                .frame(width: 80, height: 80)
                        }
                    }
                }
                
                // MARK: - Hover Effect Section
                
                VStack(alignment: .center, spacing: 20) {
                    Text("Hover Effect")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    Text("Hover to see the effect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Hover Me!")
                        .font(.headline)
                        .padding(20)
                        .liquidGlass(shape: .roundedRect(cornerRadius: 12), hoverEffect: true)
                }
                
                // MARK: - Target Platform Version Section

                VStack(alignment: .center, spacing: 20) {
                    Text("Target Platform Version")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)

                    // Per-view: apply the modifier to any view to target Platform 27
                    // (darker border, 0° highlight on the custom fallback renderer)
                    Text("Platform 27")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .liquidGlass(shape: .capsule)
                        .liquidGlassVersion(.v27)

                    // Or set it on a LiquidGlass background directly
                    Text("Platform 27 (view)")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LiquidGlass(shape: .capsule)
                                .liquidGlassVersion(.v27)
                        )

                    // App-wide: switch a whole subtree with the View modifier
                    VStack(spacing: 12) {
                        Text("Platform 26 (default)")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .liquidGlass(shape: .capsule)

                        Text("Platform 27")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .liquidGlass(shape: .capsule)
                    }
                    .liquidGlassVersion(.v27)
                }

                // MARK: - Complex Content Section

                VStack(alignment: .leading, spacing: 20) {
                    Text("Complex Content")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Glass Card")
                                    .font(.headline)
                                Text("Beautiful frosted effect")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .liquidGlass(shape: .roundedRect(cornerRadius: 16), hoverEffect: true)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(
            DemoBackground()
        )
    }
}

struct DemoBackground: View {
    var body: some View {
        // Background gradient to show glass effect better
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - SwiftUI Preview

#Preview("Liquid Glass Demo") {
    let capsuleView = Text("Liquid Glass")
        .font(.largeTitle)
        .fontWeight(.medium)
        .padding(.horizontal, 42)
        .padding(.vertical, 18)
        .liquidGlass(shape: .capsule)
        
    VStack {
        capsuleView
    }
    .padding(100)
    .background(
        DemoBackground()
    )
}

#Preview("Shapes") {
    HStack(spacing: 20) {
        Text("Rounded Rectangle")
            .padding(20)
            .liquidGlass(shape: .roundedRect(cornerRadius: 16))
        
        Text("Circle")
            .padding(20)
            .liquidGlass(shape: .circle)
        
        Text("Capsule")
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .liquidGlass(shape: .capsule)
    }
    .padding(50)
    .background(
        DemoBackground()
    )
}

#Preview("LiquidGlass Gallery") {
    if #available(iOS 15.0, macOS 12.0, *) {
        LiquidGlassExample()
    } else {
        Text("Preview requires iOS 15+ or macOS 12+")
    }
}

#Preview("Dark Mode") {
    if #available(iOS 15.0, macOS 12.0, *) {
        LiquidGlassExample()
            .preferredColorScheme(.dark)
    } else {
        Text("Preview requires iOS 15+ or macOS 12+")
    }
}

#Preview("Light Mode") {
    if #available(iOS 15.0, macOS 12.0, *) {
        LiquidGlassExample()
            .preferredColorScheme(.light)
    } else {
        Text("Preview requires iOS 15+ or macOS 12+")
    }
}
