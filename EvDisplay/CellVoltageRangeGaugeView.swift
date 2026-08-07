//
//  CellVoltageRangeGaugeView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/6/26.
//

import SwiftUI

/// Horizontal linear gauge showing cell voltage spread within the MCU cutoff range.
///
/// Gradient: red (low cutoff) → orange → yellow → green → blue → cyan → white (high cutoff).
/// A white outlined rectangle spans from cellMin to cellMax, marking the current spread.
struct CellVoltageRangeGaugeView: View {
    var cellMin: Double
    var cellMax: Double
    var lowCutoff: Double
    var highCutoff: Double

    private func xFraction(_ voltage: Double) -> CGFloat {
        guard highCutoff > lowCutoff else { return 0 }
        let clamped = min(max(voltage, lowCutoff), highCutoff)
        return CGFloat((clamped - lowCutoff) / (highCutoff - lowCutoff))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            let labelH: CGFloat  = 12
            let spacer: CGFloat  = 4
            let cutoffH: CGFloat = 11
            let barH: CGFloat    = GaugeMetrics.gaugeStrokeWidth
            let barTop = labelH + spacer
            let needleInset: CGFloat = 3

            let minX = xFraction(cellMin) * w
            let maxX = xFraction(cellMax) * w

            ZStack(alignment: .topLeading) {

                // ── Gradient bar ──
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .cyan, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: w, height: barH)
                .clipShape(RoundedRectangle(cornerRadius: barH / 2))
                .position(x: w / 2, y: barTop + barH / 2)

                // ── White outlined rectangle from cellMin to cellMax ──
                Rectangle()
                    .fill(Color.white.opacity(0.70))
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                    .frame(width: max(maxX - minX, 4), height: barH + needleInset * 2)
                    .position(x: (minX + maxX) / 2, y: barTop + barH / 2)

                // ── Min/max voltage labels above bar (collision-aware) ──
                let rawMinLX:  CGFloat = min(max(minX, 18), w - 18)
                let rawMaxLX:  CGFloat = min(max(maxX, 18), w - 18)
                let labelSepX: CGFloat = 44   // min center-to-center distance (label width + breathing room)
                let labelMidX  = (rawMinLX + rawMaxLX) / 2
                let halfSepX   = max(abs(rawMaxLX - rawMinLX) / 2, labelSepX / 2)
                let adjMinLX   = min(max(labelMidX - halfSepX, 18), w - 18)
                let adjMaxLX   = min(max(labelMidX + halfSepX, 18), w - 18)

                Text(String(format: "%.3fV", cellMin))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: adjMinLX, y: labelH / 2)

                Text(String(format: "%.3fV", cellMax))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: adjMaxLX, y: labelH / 2)

                // ── Cutoff labels below bar ──
                Text(String(format: "%.2fV", lowCutoff))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.90))
                    .position(x: 18, y: barTop + barH + spacer + cutoffH / 2)

                Text(String(format: "%.2fV", highCutoff))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .position(x: w - 18, y: barTop + barH + spacer + cutoffH / 2)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(white: 0.10)
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Normal").font(.caption2).foregroundStyle(.white)
                CellVoltageRangeGaugeView(
                    cellMin: 3.10, cellMax: 3.25,
                    lowCutoff: 2.40, highCutoff: 3.40
                )
                .frame(height: 60)
            }
            VStack(spacing: 4) {
                Text("Low").font(.caption2).foregroundStyle(.white)
                CellVoltageRangeGaugeView(
                    cellMin: 2.50, cellMax: 2.70,
                    lowCutoff: 2.40, highCutoff: 3.40
                )
                .frame(height: 60)
            }
            VStack(spacing: 4) {
                Text("High (near cutoff)").font(.caption2).foregroundStyle(.white)
                CellVoltageRangeGaugeView(
                    cellMin: 3.20, cellMax: 3.38,
                    lowCutoff: 2.40, highCutoff: 3.40
                )
                .frame(height: 60)
            }
        }
        .padding(24)
    }
}
