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
    
    // Replace the old let columns definition with this responsive statement:
    private let columns = Array(repeating: GridItem(.adaptive(minimum: 45), spacing: 6), count: 6)

    
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
                HStack(spacing: 20) {
                    // --- MODULE A ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Module A")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(1...18, id: \.self) { index in
                                CellBlockView(index: index, minV: manager.rawCellMin, maxV: manager.rawCellMax)
                            }
                        }
                    }
                    
                    // --- MODULE B ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Module B")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(19...36, id: \.self) { index in
                                CellBlockView(index: index, minV: manager.rawCellMin, maxV: manager.rawCellMax)
                            }
                        }
                    }
                }
                .padding(.horizontal)
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

// MARK: - Voltage Cell Component
struct CellBlockView: View {
    let index: Int
    let minV: Double
    let maxV: Double
    
    var body: some View {
        let simulatedCellVoltage = minV + (abs(sin(Double(index))) * (maxV - minV))
        
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.green.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                )
                .aspectRatio(1.2, contentMode: .fit)
            
            VStack(spacing: 1) {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                
                Text(String(format: "%.2fV", simulatedCellVoltage))
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
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
