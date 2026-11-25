//
//  StrokeFalloff.swift
//  LiquidGlass
//

import Foundation
import SwiftUI
import Charts

/// The edge-highlight opacity falloff shared by every renderer.
///
/// The Platform 27 lens highlight fades from a peak at the center of each
/// straight edge down to zero at the corners. The SwiftUI renderer samples this
/// curve into a `LinearGradient`; the Core Graphics renderer — used by the
/// AppKit and UIKit host views — samples it into a Quartz linear gradient.
/// Tuning the curve here keeps all three platforms in step.
///
///     opacity(t) = peak * (1 - |2t - 1|^power)
///
/// The curve is pinned to zero at both ends — `alpha(at: 0)` and
/// `alpha(at: 1)` are exactly 0 for every `power` — while reaching `peak` at
/// the center.
enum StrokeFalloff {
    /// Peak opacity at the center of the stroke (`t = 0.5`).
    static let peak: Double = 1.0

    /// Fullness exponent of the falloff. `2` reproduces the original parabola;
    /// higher values keep the highlight bright farther toward the corners
    /// before it drops sharply to zero at the edges.
    static let power: Double = 2.0

    /// Number of equal intervals the curve is sampled at across the stroke
    /// (11 stops for the default of 10).
    static let steps = 10

    /// The edge-highlight opacity at position `t` along the stroke.
    ///
    /// - Parameters:
    ///   - t: Position along the stroke: 0 at the leading edge, 1 at the
    ///     trailing edge.
    ///   - peak: Peak opacity at the center (`t = 0.5`).
    ///   - power: Fullness exponent; higher values make the curve fatter.
    /// - Returns: The opacity, clamped to `0...1`.
    static func alpha(
        at t: Double,
        peak: Double = StrokeFalloff.peak,
        power: Double = StrokeFalloff.power
    ) -> Double {
        // 1 at the corners, 0 at the center.
        let distanceFromCenter = abs(2 * t - 1)
        let shape = 1 - pow(distanceFromCenter, power)
        return min(max(peak * shape, 0), 1)
    }

    /// The curve sampled at ``steps`` equal intervals across the stroke.
    ///
    /// Renderers map these onto their own gradient-stop types; the gradient
    /// then interpolates linearly between them.
    ///
    /// With a non-zero `cornerFraction`, the rounded corner arcs are held at
    /// the opacity where they meet the straight edge. The curve still reaches
    /// zero at `t = 0` and `t = 1` — those points sit at the *sides*, beyond
    /// the arcs — so the stroke wraps the corner instead of fading out inside
    /// it and leaving a gap.
    ///
    /// - Parameters:
    ///   - peak: Peak opacity at the center (`t = 0.5`).
    ///   - power: Fullness exponent; higher values make the curve fatter.
    ///   - cornerFraction: Width of one corner arc as a fraction of the
    ///     stroke's width (`radius / width`). `0` samples the bare curve.
    /// - Returns: `(location, alpha)` pairs in ascending location order.
    static func sampledAlphas(
        peak: Double = StrokeFalloff.peak,
        power: Double = StrokeFalloff.power,
        cornerFraction: Double = 0
    ) -> [(location: Double, alpha: Double)] {
        let samples: [(location: Double, alpha: Double)] = (0...steps).map { step in
            let location = Double(step) / Double(steps)
            return (location: location, alpha: alpha(at: location, peak: peak, power: power))
        }

        let inset = min(max(cornerFraction, 0), 0.5)
        guard inset > 0 else { return samples }

        // Hold each arc at the straight edge's opacity at the tangent point.
        let edge = alpha(at: inset, peak: peak, power: power)
        var stops: [(location: Double, alpha: Double)] = [
            (location: 0, alpha: edge),
            (location: inset, alpha: edge),
        ]
        stops += samples.filter { $0.location > inset && $0.location < 1 - inset }
        stops += [
            (location: 1 - inset, alpha: edge),
            (location: 1, alpha: edge),
        ]
        return stops
    }
}

/// One sample of the v27 edge-highlight falloff curve.
private struct StrokeFalloffSample: Identifiable {
    let id: Int
    let t: Double
    let alpha: Double
}

/// Samples of the falloff curve: a fine-grained one for the plot, plus the
/// stops the gradient actually uses (SwiftUI fades linearly between them).
private enum StrokeFalloffPlotData {
    /// The continuous curve, sampled finely for the plot.
    static func curve(power: Double) -> [StrokeFalloffSample] {
        let steps = 200
        return (0...steps).map { index in
            let t = Double(index) / Double(steps)
            return StrokeFalloffSample(
                id: index,
                t: t,
                alpha: StrokeFalloff.alpha(at: t, power: power)
            )
        }
    }

    /// The stops the gradient actually uses.
    static func stops(power: Double, cornerFraction: Double) -> [StrokeFalloffSample] {
        StrokeFalloff.sampledAlphas(power: power, cornerFraction: cornerFraction)
            .enumerated()
            .map { index, sample in
                StrokeFalloffSample(id: index, t: sample.location, alpha: sample.alpha)
            }
    }
}


/// Plots the edge-highlight falloff, with the gradient's sampled stops marked.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
struct StrokeFalloffChart: View {
    /// Fullness exponent to plot.
    let power: Double

    /// Corner arc width as a fraction of the stroke width; the renderers hold
    /// the arcs at the tangent's opacity.
    let cornerFraction: Double

    private var curve: [StrokeFalloffSample] {
        StrokeFalloffPlotData.curve(power: power)
    }

    private var stops: [StrokeFalloffSample] {
        StrokeFalloffPlotData.stops(power: power, cornerFraction: cornerFraction)
    }

    private var areaStyle: LinearGradient {
        LinearGradient(
            colors: [.blue.opacity(0.28), .blue.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Chart {
            ForEach(curve) { sample in
                areaMark(sample)
            }
            ForEach(curve) { sample in
                lineMark(sample)
            }
            ForEach(stops) { sample in
                stopMark(sample)
            }
            peakMark()
        }
        .chartXScale(domain: 0.0...1.0)
        .chartYScale(domain: 0.0...1.0)
        .chartXAxis {
            AxisMarks(values: .stride(by: 0.25))
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 0.3))
        }
        .chartXAxisLabel("position along edge (t)", alignment: .center)
        .chartYAxisLabel("stroke opacity")
        .chartLegend(.hidden)
        .frame(height: 200)
    }

    /// The quadratic falloff itself, filled underneath the line.
    private func areaMark(_ sample: StrokeFalloffSample) -> some ChartContent {
        AreaMark(
            x: PlottableValue.value("t", sample.t),
            y: PlottableValue.value("Opacity", sample.alpha)
        )
        .foregroundStyle(areaStyle)
    }

    /// The continuous curve.
    private func lineMark(_ sample: StrokeFalloffSample) -> some ChartContent {
        LineMark(
            x: PlottableValue.value("t", sample.t),
            y: PlottableValue.value("Opacity", sample.alpha)
        )
        .foregroundStyle(Color.blue)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    /// A stop the gradient actually samples.
    private func stopMark(_ sample: StrokeFalloffSample) -> some ChartContent {
        PointMark(
            x: PlottableValue.value("t", sample.t),
            y: PlottableValue.value("Opacity", sample.alpha)
        )
        .foregroundStyle(Color.blue)
        .symbolSize(50)
    }

    /// The peak of the curve at the center of the stroke.
    private func peakMark() -> some ChartContent {
        PointMark(
            x: PlottableValue.value("t", 0.5),
            y: PlottableValue.value("Opacity", StrokeFalloff.peak)
        )
        .foregroundStyle(Color.orange)
        .symbolSize(80)
        .annotation(position: .top) {
            Text("peak b = \(StrokeFalloff.peak)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
