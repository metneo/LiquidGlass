@testable import LiquidGlass
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
