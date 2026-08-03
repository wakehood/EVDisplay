//
//  MCUDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/2/26.
//

import SwiftUI

struct MCUDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var manager: OBD2ConnectionManager
    @State private var showingHealth = false

    private let scaleThresholds: [Double] = [0, 2, 5, 10, 20, 50, 100, 200, 500]

    private var anyAlert: Bool {
        manager.alertHardware == 1 || manager.alertCCensus == 1 ||
        manager.alertTCensus == 1 || manager.alertHVC == 1  ||
        manager.alertLVC == 1    || manager.alertHiTemp == 1 ||
        manager.alertLoTemp == 1
    }

    var body: some View {
        let powerKW = (manager.rawPackVoltage * manager.rawPackCurrent) / 1000.0
        let isCharging = powerKW >= 0
        let powerColor: Color = isCharging ? Color("Primary Green") : .red
        let normalizedPower = calculateLogProgress(for: abs(powerKW))

        BaseDashboardCard(themeColor: Color("Deep Contrast Teal"), outlineOpacity: 0.9, outlineWidth: 2.0) {
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    if geo.size.width > geo.size.height {
                        landscapeLayout(geo: geo, powerKW: powerKW, isCharging: isCharging,
                                        powerColor: powerColor, normalizedPower: normalizedPower)
                    } else {
                        portraitLayout(geo: geo, powerKW: powerKW, isCharging: isCharging,
                                       powerColor: powerColor, normalizedPower: normalizedPower)
                    }
                }
                .padding(8)

                Text("MCU")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color("Deep Contrast Teal"))
                    .tracking(1.5)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showingHealth) {
            HealthDashboardCardView()
                .environment(manager)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Landscape
    @ViewBuilder
    private func landscapeLayout(
        geo: GeometryProxy,
        powerKW: Double,
        isCharging: Bool,
        powerColor: Color,
        normalizedPower: Double
    ) -> some View {
        let gaugeSize = min(geo.size.height * 0.72, 180.0)
        let barHeight = min(gaugeSize * 0.66, 120.0)

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {

                // ── SOC gauge + available energy ──
                Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                    Text("Charge")
                } currentValueLabel: {
                    Text("\(manager.rawSOCPercentage)%")
                }
                .gaugeStyle(AdaptiveSemicircleSoCStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                .frame(width: gaugeSize, height: gaugeSize)
                .overlay(alignment: .bottom) {
                    Text(String(format: "%.1f kWh", manager.rawAvailableEnergyKwh))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.bottom, gaugeSize * 0.12)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 6)

                Divider()
                    .padding(.horizontal, 9)

                // ── Pack power (top) + Cell voltage summary (bottom) ──
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Power")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        HStack(alignment: .center, spacing: 10) {
                            PowerBarView(
                                normalizedPower: normalizedPower,
                                powerColor: powerColor,
                                thresholds: scaleThresholds,
                                barHeight: barHeight
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: "%.2f kW", abs(powerKW)))
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.black)
                                    .foregroundColor(powerColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Divider()

                                Text(String(format: "Pack   %.1fV", manager.rawPackVoltage))
                                Text(String(format: "Current %.1fA", manager.rawPackCurrent))
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)

                    Divider()
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cells")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        CellSummaryView(manager: manager)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)

            }

            Divider()
                .padding(.horizontal, 4)

            mcuStatusBar
        }
    }

    // MARK: - Portrait
    @ViewBuilder
    private func portraitLayout(
        geo: GeometryProxy,
        powerKW: Double,
        isCharging: Bool,
        powerColor: Color,
        normalizedPower: Double
    ) -> some View {
        let gaugeSize = min(geo.size.width * 0.42, 150.0)

        VStack(spacing: 10) {

            // ── Top row: SOC gauge + power summary ──
            HStack(alignment: .top) {
                Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                    Text("Charge")
                } currentValueLabel: {
                    Text("\(manager.rawSOCPercentage)%")
                }
                .gaugeStyle(AdaptiveSemicircleSoCStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                .frame(width: gaugeSize, height: gaugeSize)
                .overlay(alignment: .bottom) {
                    Text(String(format: "%.1f kWh", manager.rawAvailableEnergyKwh))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.bottom, gaugeSize * 0.12)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                Divider()

                HStack(alignment: .center, spacing: 12) {
                    PowerBarView(
                        normalizedPower: normalizedPower,
                        powerColor: powerColor,
                        thresholds: scaleThresholds,
                        barHeight: 90
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(format: "%.2f kW", abs(powerKW)))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(powerColor)

                        Divider()

                        Text(String(format: "Pack   %.1fV", manager.rawPackVoltage))
                        Text(String(format: "Current %.1fA", manager.rawPackCurrent))
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }

            Divider()

            // ── Cell summary row ──
            VStack(alignment: .leading, spacing: 6) {
                Text("Cells")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                CellSummaryView(manager: manager)
            }
            .padding(.horizontal, 4)

            Divider()

            mcuStatusBar

            Spacer(minLength: 0)
        }
    }

    // MARK: - Status bar
    private var mcuStatusBar: some View {
        HStack(alignment: .center, spacing: 0) {
            ConnectionStatusRow(
                status: manager.connectionStatus,
                isConnected: manager.isConnected
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                Text("MCU Temp")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                TemperatureGaugeView(temp1: manager.rawMcuLowTemp, temp2: manager.rawMcuHighTemp)
                    .frame(width: 52, height: 72)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                showingHealth = true
            } label: {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(anyAlert ? .red : Color("Primary Green"))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func calculateLogProgress(for value: Double) -> Double {
        guard value > scaleThresholds[0] else { return 0.0 }
        guard value < scaleThresholds.last! else { return 1.0 }
        let segmentWeight = 1.0 / Double(scaleThresholds.count - 1)
        for i in 0..<scaleThresholds.count - 1 {
            let lo = scaleThresholds[i], hi = scaleThresholds[i + 1]
            if value >= lo && value <= hi {
                let local = lo == 0
                    ? (value - lo) / (hi - lo)
                    : (log(value) - log(lo)) / (log(hi) - log(lo))
                return (Double(i) + local) * segmentWeight
            }
        }
        return 0.0
    }
}

// MARK: - Cell Voltage Summary

private struct CellSummaryView: View {
    let manager: OBD2ConnectionManager

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 5) {
                CellMetricRow(label: "Min", value: manager.rawCellMin, unit: "V",  format: "%.3f")
                CellMetricRow(label: "Max", value: manager.rawCellMax, unit: "V",  format: "%.3f")
            }
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                CellMetricRow(label: "Avg", value: manager.rawCellMean,          unit: "V",  format: "%.3f")
                CellMetricRow(label: "σ",   value: manager.rawCellStdDev * 1000, unit: "mV", format: "%.1f")
            }
        }
    }
}

private struct CellMetricRow: View {
    let label: String
    let value: Double
    let unit: String
    let format: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .leading)
            Text(String(format: format, value) + unit)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Shared sub-views

private struct PowerBarView: View {
    let normalizedPower: Double
    let powerColor: Color
    let thresholds: [Double]
    let barHeight: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 14)
                    Capsule()
                        .fill(powerColor)
                        .frame(width: 14, height: geo.size.height * normalizedPower)
                        .shadow(color: powerColor.opacity(0.15), radius: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: normalizedPower)
                }
                .frame(maxWidth: 14)
            }
            .frame(width: 14, height: barHeight)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(thresholds.reversed(), id: \.self) { threshold in
                    Text("\(Int(threshold))")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity,
                               alignment: threshold == thresholds.last  ? .top
                                        : threshold == thresholds.first ? .bottom
                                        : .center)
                }
            }
            .frame(height: barHeight)
        }
    }
}

private struct ConnectionStatusRow: View {
    let status: String
    let isConnected: Bool

    private var statusColor: Color {
        if isConnected { return Color("Primary Green") }
        if status == String(localized: "Bluetooth Off") { return .red }
        return .orange
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Status")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Text(status)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct DriveTimeRow: View {
    let seconds: Int

    private var hours: Int   { seconds / 3600 }
    private var minutes: Int { (seconds % 3600) / 60 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Drive")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
            Text(String(format: "%02d", hours))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
            Text("h")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .baselineOffset(5)
                .padding(.trailing, 4)
            Text(String(format: "%02d", minutes))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
            Text("m")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .baselineOffset(5)
        }
        .foregroundColor(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

// MARK: - Previews

#Preview("Landscape – iPad") {
    MCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 640, height: 380)
        .padding()
        .background(Color("Shadow Background"))
}

#Preview("Portrait – iPhone") {
    MCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 390, height: 540)
        .padding()
        .background(Color("Shadow Background"))
}
