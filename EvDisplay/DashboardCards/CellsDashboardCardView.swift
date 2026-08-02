//
//  CellsDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//

import SwiftUI

struct CellsDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: true)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // iPad (regular width): 9 cols → 2 rows per module, cells ~63pt tall.
    // iPhone landscape/portrait (compact width): 6 cols → 3 rows per module, cells ~57pt tall.
    // Portrait stacks modules vertically so each uses full width; landscape puts them side by side.
    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 9 : 6
        return Array(repeating: GridItem(.flexible(minimum: 28), spacing: 4), count: count)
    }

    private var isPortrait: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    @ViewBuilder
    private func moduleGrid(title: String, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(range, id: \.self) { index in
                    CellBlockView(
                        index: index,
                        minV: manager.rawCellMin,
                        maxV: manager.rawCellMax,
                        temperature: manager.rawCellTemp
                    )
                }
            }
        }
    }

    
    var body: some View {
        BaseDashboardCard(title: "Cells", themeColor: .orange) {
            VStack(spacing: 12) {
                
                // NEW: Section Label above the stats bar
                Text("Voltage Summary")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                // 1. Promoted Statistical Voltage Data Readout Bar
                HStack(spacing: 0) {
                    MiniStatView(label: "MIN", value: String(format: "%.3fV", manager.rawCellMin))
                    Spacer()
                    MiniStatView(label: "MAX", value: String(format: "%.3fV", manager.rawCellMax))
                    Spacer()
                    MiniStatView(label: "MEAN", value: String(format: "%.3fV", manager.rawCellMean))
                    Spacer()
                    MiniStatView(label: "STDEV", value: String(format: "%.4fV", manager.rawCellStdDev), isMonospaced: true)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .padding(.horizontal)
                
                
                // 2. Two 18-cell module grids
                // Portrait: stacked vertically (side-by-side would overflow the screen width).
                // Landscape/iPad: side by side.
                if isPortrait {
                    VStack(spacing: 12) {
                        moduleGrid(title: "Module A", range: 1...18)
                        moduleGrid(title: "Module B", range: 19...36)
                    }
                    .padding(.horizontal)
                } else {
                    HStack(spacing: 20) {
                        moduleGrid(title: "Module A", range: 1...18)
                        moduleGrid(title: "Module B", range: 19...36)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Diagnostic Text Component
struct MiniStatView: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: isMonospaced ? .monospaced : .default))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Temperature Legend Component
struct TemperatureLegendItem: View {
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Voltage Cell Component
struct CellBlockView: View {
    let index: Int
    let minV: Double
    let maxV: Double
    let temperature: Double
    
    private var temperatureColor: Color {
        switch temperature {
        case 50...:
            .red
        case 40..<50:
            .orange
        default:
            .green
        }
    }
    
    var body: some View {
        let simulatedCellVoltage = minV + (abs(sin(Double(index))) * (maxV - minV))
        
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(temperatureColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(temperatureColor.opacity(0.8), lineWidth: 1.5)
                )
                .aspectRatio(0.95, contentMode: .fit)
            
            VStack(spacing: 1) {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(temperatureColor)
                
                Text(String(format: "%.2fV", simulatedCellVoltage))
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(String(format: "%.0f°C", temperature))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(temperatureColor)
            }
        }
    }
}

// MARK: - Canvas Preview Block
#Preview {
    CellsDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 420, height: 350)
        .padding()
        .background(Color(.systemGroupedBackground))
}
