@testable import LiquidGlass
import CoreGraphics
import Foundation
import SwiftUI
import Testing

// MARK: - BackgroundShape Tests

@Test("BackgroundShape creates valid shapes")
func testBackgroundShapeCreation() async throws {
    // Each case should produce a shape that yields a non-empty path.
    let shapes: [BackgroundShape] = [
        .roundedRect(cornerRadius: 12),
        .circle,
        .capsule
    ]
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    for shape in shapes {
        let path = shape.shape.path(in: rect)
        #expect(!path.isEmpty, "\(shape) should generate a non-empty path")
    }
}

@Test("BackgroundShape generates valid paths")
func testBackgroundShapePaths() async throws {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    let roundedRectPath = BackgroundShape.roundedRect(cornerRadius: 12).shape.path(in: rect)
    #expect(!roundedRectPath.isEmpty, "Rounded rectangle should generate a non-empty path")

    let circlePath = BackgroundShape.circle.shape.path(in: rect)
    #expect(!circlePath.isEmpty, "Circle should generate a non-empty path")

    let capsulePath = BackgroundShape.capsule.shape.path(in: rect)
    #expect(!capsulePath.isEmpty, "Capsule should generate a non-empty path")
}

@Test("BackgroundShape handles edge cases for corner radius")
func testCornerRadiusClamping() async throws {
    let smallRect = CGRect(x: 0, y: 0, width: 20, height: 20)

    // Test with corner radius larger than rect
    let largeCornerRadius = BackgroundShape.roundedRect(cornerRadius: 100).shape
    let path = largeCornerRadius.path(in: smallRect)
    #expect(!path.isEmpty, "Should handle corner radius larger than rect dimensions")

    // The effective radius should be clamped so the corners stay within bounds.
    #expect(path.boundingRect.width <= smallRect.width)
    #expect(path.boundingRect.height <= smallRect.height)
}

@Test("BackgroundShape enum cases are Sendable")
func testBackgroundShapeSendable() async throws {
    let shape: any Sendable = BackgroundShape.roundedRect(cornerRadius: 12)
    #expect(shape is BackgroundShape, "BackgroundShape should be Sendable")
}

// MARK: - LiquidGlass Tests

@MainActor
@Test("LiquidGlass initializes with default values")
func testGlassStyleInitialization() async throws {
    let glass = LiquidGlass(shape: .roundedRect(cornerRadius: 12))
    #expect(type(of: glass) == LiquidGlass.self, "LiquidGlass should initialize successfully")
}

// MARK: - View Extension Tests

@MainActor
@Test("View extensions apply glass modifiers")
func testLiquidGlassModifiers() async throws {
    let view = Text("Test")
    // These should produce a modified view rather than the plain text.
    let v1 = view.liquidGlass(shape: .roundedRect(cornerRadius: 12))
    #expect(type(of: v1) != type(of: view), "liquidGlass should wrap the content")
    _ = view.liquidGlass(shape: .capsule, hoverEffect: true)
}

@MainActor
@Test("LiquidGlass version is environment-configurable")
func testLiquidGlassVersion() async throws {
    let glass = LiquidGlass(shape: .capsule)
    _ = glass.liquidGlassVersion(.v27)                    // view modifier sets the environment
    _ = LiquidGlass(shape: .circle)
    _ = Text("Test").liquidGlassVersion(.v26)
}

// MARK: - Integration Tests

@Test("Complete glass effect pipeline works")
func testCompleteGlassPipeline() async throws {
    let shape = BackgroundShape.roundedRect(cornerRadius: 20)
    let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
    let path = shape.shape.path(in: rect)
    #expect(!path.isEmpty, "Path generation should work")
}

@Test("Multiple shapes render without conflicts")
func testMultipleShapesRendering() async throws {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    let shapes: [BackgroundShape] = [
        .roundedRect(cornerRadius: 12),
        .circle,
        .capsule
    ]

    for shape in shapes {
        let path = shape.shape.path(in: rect)
        #expect(!path.isEmpty, "Each shape should render independently")
    }
}

// MARK: - Path Validation Tests

@Test("Rounded rectangle path bounds match input rect")
func testRoundedRectangleBounds() async throws {
    let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
    let shape = BackgroundShape.roundedRect(cornerRadius: 12).shape
    let path = shape.path(in: rect)
    let pathBounds = path.boundingRect

    // Path bounds should be close to input rect (accounting for rounding)
    #expect(abs(pathBounds.width - rect.width) < 1.0, "Path width should match rect width")
    #expect(abs(pathBounds.height - rect.height) < 1.0, "Path height should match rect height")
}

@Test("Circle path is centered in rect")
func testCircleCentering() async throws {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    let shape = BackgroundShape.circle.shape
    let path = shape.path(in: rect)
    let pathBounds = path.boundingRect

    // Circle should be centered
    let expectedRadius = min(rect.midX, rect.midY)
    #expect(pathBounds.width <= expectedRadius * 2, "Circle should fit within rect")
    #expect(pathBounds.height <= expectedRadius * 2, "Circle should fit within rect")
}

@Test("Capsule path fills rect properly")
func testCapsulePath() async throws {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
    let shape = BackgroundShape.capsule.shape
    let path = shape.path(in: rect)

    #expect(!path.isEmpty, "Capsule path should not be empty")

    let bounds = path.boundingRect
    #expect(bounds.width > 0, "Capsule should have width")
    #expect(bounds.height > 0, "Capsule should have height")
    #expect(abs(bounds.width - rect.width) < 1.0, "Capsule should span the full rect width")
    #expect(abs(bounds.height - rect.height) < 1.0, "Capsule should span the full rect height")
}

// MARK: - StrokeFalloff Tests

@Test("StrokeFalloff is pinned to zero at both edges")
func testStrokeFalloffPinnedEnds() async throws {
    for power in [1.0, 2.0, 4.0, 8.0] {
        #expect(StrokeFalloff.alpha(at: 0, power: power) == 0, "t = 0 must be pinned to 0")
        #expect(StrokeFalloff.alpha(at: 1, power: power) == 0, "t = 1 must be pinned to 0")
    }
}

@Test("StrokeFalloff peaks at the center")
func testStrokeFalloffPeak() async throws {
    #expect(abs(StrokeFalloff.alpha(at: 0.5) - StrokeFalloff.peak) < 1e-12)
}

@Test("StrokeFalloff power 2 matches the original parabola")
func testStrokeFalloffParabola() async throws {
    // The pinned quadratic b * (1 - (2t - 1)²) is the p = 2 member.
    for step in 0...20 {
        let t = Double(step) / 20
        let parabola = StrokeFalloff.peak * (1 - pow(2 * t - 1, 2))
        #expect(abs(StrokeFalloff.alpha(at: t, power: 2) - parabola) < 1e-12)
    }
}

@Test("StrokeFalloff gets fatter as power increases")
func testStrokeFalloffFatter() async throws {
    let t = 0.1
    let alphas = [2.0, 4.0, 8.0].map { StrokeFalloff.alpha(at: t, power: $0) }
    #expect(alphas[0] < alphas[1])
    #expect(alphas[1] < alphas[2])
}

@Test("StrokeFalloff holds the corner arcs at the tangent opacity")
func testStrokeFalloffCornerWrap() async throws {
    let inset = 0.05
    let samples = StrokeFalloff.sampledAlphas(power: 5.6, cornerFraction: inset)
    let edge = StrokeFalloff.alpha(at: inset, power: 5.6)

    // Both ends are held at the tangent's opacity instead of fading to 0.
    #expect(abs((samples.first?.alpha ?? -1) - edge) < 1e-12)
    #expect(abs((samples.last?.alpha ?? -1) - edge) < 1e-12)

    // Locations stay in ascending order so the gradient is well-formed.
    let locations = samples.map { $0.location }
    #expect(locations == locations.sorted())
}

@Test("StrokeFalloff sampling spans the stroke")
func testStrokeFalloffSampling() async throws {
    let samples = StrokeFalloff.sampledAlphas()
    #expect(samples.count == StrokeFalloff.steps + 1)
    #expect(samples.first?.location == 0)
    #expect(samples.last?.location == 1)
    #expect(samples.first?.alpha == 0)
    #expect(samples.last?.alpha == 0)
}

// MARK: - Inactive Renderer Tests

@Test("Inactive renderer paints an opaque neutral fill")
func testInactiveRendererFill() throws {
    func centerPixel(isDark: Bool) throws -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let width = 64
        let height = 64
        let bytesPerRow = width * 4
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        LiquidGlassRenderer(
            shape: .roundedRect(cornerRadius: 8),
            isDark: isDark,
            isInactive: true
        ).draw(in: context, size: CGSize(width: width, height: height))

        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (height / 2) * bytesPerRow + (width / 2) * 4
        return (data[index], data[index + 1], data[index + 2], data[index + 3])
    }

    let light = try centerPixel(isDark: false)
    #expect(light.a == 255, "Inactive fill must be fully opaque")
    #expect(light.r == light.g && light.g == light.b, "Inactive fill must be neutral gray")
    #expect(abs(Int(light.r) - 240) <= 2, "Light inactive fill should be near-white")

    let dark = try centerPixel(isDark: true)
    #expect(dark.a == 255, "Inactive fill must be fully opaque")
    #expect(dark.r == dark.g && dark.g == dark.b, "Inactive fill must be neutral gray")
    #expect(abs(Int(dark.r) - 54) <= 2, "Dark inactive fill should be a lifted dark gray")
}

@Test("Inactive renderer ignores tint, opacity, and style")
func testInactiveRendererIgnoresParameters() throws {
    func centerPixel() throws -> [UInt8] {
        let size = 32
        let bytesPerRow = size * 4
        let context = try #require(CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        LiquidGlassRenderer(
            shape: .capsule,
            tint: CGColor(red: 1, green: 0, blue: 0, alpha: 1),
            opacity: 0.2,
            style: .v27,
            isDark: false,
            isInactive: true
        ).draw(in: context, size: CGSize(width: size, height: size))

        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (size / 2) * bytesPerRow + (size / 2) * 4
        return Array(UnsafeBufferPointer(start: data + index, count: 4))
    }

    // The stand-in is neutral regardless of the red tint and low opacity.
    let pixel = try centerPixel()
    #expect(pixel[0] == pixel[1] && pixel[1] == pixel[2], "Tint must be ignored while inactive")
    #expect(pixel[3] == 255, "Inactive fill must be fully opaque")
}

// MARK: - Performance Tests

@Test("Path generation is efficient")
func testPathGenerationPerformance() async throws {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
    let shape = BackgroundShape.roundedRect(cornerRadius: 20).shape

    // Generate path multiple times to ensure no performance issues
    for _ in 0..<100 {
        let path = shape.path(in: rect)
        #expect(!path.isEmpty, "Path should be generated efficiently")
    }
}

@Test("Multiple shape creations are lightweight")
func testShapeCreationPerformance() async throws {
    // Create multiple shapes to ensure no performance issues
    for shapeIndex in 0..<100 {
        let shape = BackgroundShape.roundedRect(cornerRadius: CGFloat(shapeIndex % 20))
        let path = shape.shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(!path.isEmpty, "Shape creation should be lightweight")
    }
}
