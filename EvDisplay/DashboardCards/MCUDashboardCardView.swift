//
//  MCUDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/2/26.
//

import SwiftUI
import OBD2Kit

struct MCUDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var manager: OBD2ConnectionManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showingHealth = false

    private var isIPad: Bool { hSizeClass == .regular }

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
        }
        .sheet(isPresented: $showingHealth) {
            HealthDashboardCardView()
                .environment(manager)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Landscape
    //
    // Two rows:
    //   Top (expands):  Left = SOC + kWh  |  Right = Power (top) / Temp (bottom)
    //   Bottom (fixed): Left = Status + Alert  |  Right = Cells gauge
    @ViewBuilder
    private func landscapeLayout(
        geo: GeometryProxy,
        powerKW: Double,
        isCharging: Bool,
        powerColor: Color,
        normalizedPower: Double
    ) -> some View {
        let bottomH:  CGFloat = isIPad ? 110 : 70
        let topH      = geo.size.height - bottomH
        let gaugeSize = min(geo.size.width * 0.42, topH * 0.80,
                            isIPad ? GaugeMetrics.socGaugeMaxIPad : GaugeMetrics.socGaugeMaxPhone)
        let barHeight = min(topH * 0.78, isIPad ? 460.0 : 120.0)
        let tempH     = min(topH * 0.82, isIPad ? 340.0 : 90.0)
        let tempW: CGFloat = isIPad ? 72.0 : 40.0

        VStack(spacing: 0) {

            // ── Top row ──
            HStack(spacing: 0) {

                // Left half: SOC gauge + available energy
                VStack(spacing: 0) {
                    Text("Energy")
                        .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                    Spacer(minLength: 0)
                    Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                        Text("Charge")
                    } currentValueLabel: {
                        Text("\(manager.rawSOCPercentage)%")
                    }
                    .gaugeStyle(AdaptiveSemicircleSoCStyle(valueFontSize: isIPad ? 64 : 44))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                    .frame(width: gaugeSize, height: gaugeSize)

                    Text(String(format: "%.1f kWh", manager.rawAvailableEnergyKwh))
                        .font(.system(size: isIPad ? 26 : 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Right half: Power (left) | Temperature (right)
                HStack(spacing: 0) {

                    // Power sub-section: bar + kW (top), Pack V / Current (bottom)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Power")
                            .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)

                        HStack(alignment: .center, spacing: 12) {
                            PowerBarView(
                                normalizedPower: normalizedPower,
                                powerColor: powerColor,
                                thresholds: scaleThresholds,
                                barHeight: barHeight
                            )
                            Text(String(format: "%.2f kW", abs(powerKW)))
                                .font(.system(size: isIPad ? 28 : 20, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(powerColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxHeight: .infinity)

                        Divider()
                            .padding(.vertical, 6)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: "Pack   %.1fV", manager.rawPackVoltage))
                            Text(String(format: "Current %.1fA", manager.rawPackCurrent))
                        }
                        .font(.system(size: isIPad ? 20 : 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // Temperature sub-section
                    VStack(alignment: .center, spacing: 8) {
                        Spacer(minLength: 0)
                        Text("MCU Temp")
                            .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        TemperatureGaugeView(temp1: manager.rawMcuLowTemp, temp2: manager.rawMcuHighTemp)
                            .frame(width: tempW, height: tempH)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ── Bottom row (fixed height) ──
            HStack(spacing: 0) {

                // Left half: connection status + alert button
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(manager.connectionStatus)
                            .font(.system(size: isIPad ? 16 : 12, weight: .semibold, design: .rounded))
                            .foregroundColor(
                                manager.isConnected ? Color("Primary Green") :
                                manager.connectionStatus == String(localized: "Bluetooth Off") ? .red : .orange
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Button {
                        showingHealth = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: isIPad ? 36 : 24, weight: .semibold))
                            .foregroundColor(anyAlert ? .red : Color("Primary Green"))
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Right half: cell voltage range
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cells")
                        .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    CellVoltageRangeGaugeView(
                        cellMin:    manager.rawCellMin,
                        cellMax:    manager.rawCellMax,
                        lowCutoff:  manager.rawMcuLowVoltageCutoff,
                        highCutoff: manager.rawMcuHighVoltageCutoff
                    )
                    .frame(height: GaugeMetrics.cellGaugeHeight)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: bottomH)
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
        // Scale the gauge to fill available height; width limits keep it from overflowing on wider devices
        let gaugeSize = min(geo.size.height * 0.48, geo.size.width * 0.85)

        VStack(spacing: 10) {

            // ── SOC gauge (prominent, centered) ──
            VStack(spacing: 6) {
                Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                    Text("Charge")
                } currentValueLabel: {
                    Text("\(manager.rawSOCPercentage)%")
                }
                .gaugeStyle(AdaptiveSemicircleSoCStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                .frame(width: gaugeSize, height: gaugeSize)

                Text(String(format: "%.1f kWh", manager.rawAvailableEnergyKwh))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            Divider()

            // ── Power row: bar + metrics + temperature ──
            HStack(alignment: .center, spacing: 12) {
                Text("Power")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                PowerBarView(
                    normalizedPower: normalizedPower,
                    powerColor: powerColor,
                    thresholds: scaleThresholds,
                    barHeight: 80
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

                Spacer()

                VStack(spacing: 4) {
                    Text("Temp")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    TemperatureGaugeView(temp1: manager.rawMcuLowTemp, temp2: manager.rawMcuHighTemp)
                        .frame(width: 46, height: 80)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // ── Cell voltage range ──
            VStack(alignment: .leading, spacing: 6) {
                Text("Cells")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                CellVoltageRangeGaugeView(
                    cellMin:    manager.rawCellMin,
                    cellMax:    manager.rawCellMax,
                    lowCutoff:  manager.rawMcuLowVoltageCutoff,
                    highCutoff: manager.rawMcuHighVoltageCutoff
                )
                .frame(height: GaugeMetrics.cellGaugeHeight)
            }
            .padding(.horizontal, 4)

            Divider()

            // ── Compact status bar (temp shown in power row above) ──
            HStack(alignment: .center, spacing: 12) {
                ConnectionStatusRow(
                    status: manager.connectionStatus,
                    isConnected: manager.isConnected
                )
                Spacer()
                Button {
                    showingHealth = true
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(anyAlert ? .red : Color("Primary Green"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
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
                    .frame(width: isIPad ? GaugeMetrics.thermometerWidthIPad  : GaugeMetrics.thermometerWidth,
                           height: isIPad ? GaugeMetrics.thermometerHeightIPad : GaugeMetrics.thermometerHeight)
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
                        .frame(width: 26)
                    Capsule()
                        .fill(powerColor)
                        .frame(width: 26, height: geo.size.height * normalizedPower)
                        .shadow(color: powerColor.opacity(0.15), radius: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: normalizedPower)
                }
                .frame(maxWidth: 26)
            }
            .frame(width: 26, height: barHeight)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(thresholds.reversed(), id: \.self) { threshold in
                    Text("\(Int(threshold))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
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

// MARK: - Previews

#Preview("Landscape – iPad") {
    MCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 1000, height: 720)
        .padding()
        .background(Color("Shadow Background"))
}

#Preview("Portrait – iPhone") {
    MCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 390, height: 660)
        .padding()
        .background(Color("Shadow Background"))
}
