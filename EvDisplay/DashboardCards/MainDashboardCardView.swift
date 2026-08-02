//
//  MainDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/1/26.
//

import SwiftUI

struct MainDashboardCardView: View {
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

        BaseDashboardCard(themeColor: Color("Deep Contrast Teal")) {
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    landscapeLayout(geo: geo, powerKW: powerKW, isCharging: isCharging,
                                    powerColor: powerColor, normalizedPower: normalizedPower)
                } else {
                    portraitLayout(geo: geo, powerKW: powerKW, isCharging: isCharging,
                                   powerColor: powerColor, normalizedPower: normalizedPower)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingHealth) {
            HealthDashboardCardView()
                .environment(manager)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Landscape (primary)
    //
    // VStack:
    //   HStack: SOC gauge | Power section | Temp gauge | Motor speed gauge
    //   Divider
    //   HStack: Connection status | Drive time | Alert button
    @ViewBuilder
    private func landscapeLayout(
        geo: GeometryProxy,
        powerKW: Double,
        isCharging: Bool,
        powerColor: Color,
        normalizedPower: Double
    ) -> some View {
        let gaugeSize = min(geo.size.height * 0.70, 190.0)
        let barHeight = gaugeSize * 0.80

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {

                // ── SOC gauge ──
                VStack(spacing: 4) {
                    Text("State of Charge")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                        Text("Charge")
                    } currentValueLabel: {
                        Text("\(manager.rawSOCPercentage)%")
                    }
                    .gaugeStyle(AdaptiveSemicircleSoCStyle())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                    .frame(width: gaugeSize, height: gaugeSize)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 6)

                Divider()

                // ── Power section ──
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Power")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(isCharging ? "CHARGE" : "DEMAND")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(powerColor)
                            .tracking(0.5)
                    }

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

                // ── Temperature gauge ──
                VStack(spacing: 4) {
                    Text("Temp")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    TemperatureGaugeView(temp1: manager.mcuLowTemp, temp2: manager.mcuHighTemp)
                        .frame(width: 56, height: barHeight)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 8)

                Divider()

                // ── Motor speed gauge ──
                VStack(spacing: 4) {
                    Text("Motor Speed")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    // rawMotorRPM telemetry not yet available — placeholder 0
                    Gauge(value: 0.0, in: 0...18_000) {
                        Text("RPM")
                    } currentValueLabel: {
                        Text("0")
                    }
                    .gaugeStyle(SemicircleMotorSpeedGaugeStyle())
                    .frame(width: gaugeSize, height: gaugeSize)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 6)
            }

            Divider()
                .padding(.horizontal, 4)

            statusBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Portrait (secondary)
    //
    // VStack:
    //   Row 1: SOC gauge | Motor speed gauge
    //   Row 2: Power bar + metrics | Temperature gauge
    //   Status bar row
    @ViewBuilder
    private func portraitLayout(
        geo: GeometryProxy,
        powerKW: Double,
        isCharging: Bool,
        powerColor: Color,
        normalizedPower: Double
    ) -> some View {
        let gaugeSize = min(geo.size.width * 0.42, 150.0)

        VStack(spacing: 12) {

            // ── Gauges row ──
            HStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text("State of Charge")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                        Text("Charge")
                    } currentValueLabel: {
                        Text("\(manager.rawSOCPercentage)%")
                    }
                    .gaugeStyle(AdaptiveSemicircleSoCStyle())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                    .frame(width: gaugeSize, height: gaugeSize)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 4) {
                    Text("Motor Speed")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Gauge(value: 0.0, in: 0...18_000) {
                        Text("RPM")
                    } currentValueLabel: {
                        Text("0")
                    }
                    .gaugeStyle(SemicircleMotorSpeedGaugeStyle())
                    .frame(width: gaugeSize, height: gaugeSize)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // ── Power + temperature row ──
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Power")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(isCharging ? "CHARGE" : "DEMAND")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(powerColor)
                        .tracking(0.5)
                }

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

                Spacer()

                VStack(spacing: 4) {
                    Text("Temp")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    TemperatureGaugeView(temp1: manager.mcuLowTemp, temp2: manager.mcuHighTemp)
                        .frame(width: 50, height: 100)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            statusBar
                .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom status bar (shared by both layouts)
    //
    // Connection status | Drive time | Alert button
    private var statusBar: some View {
        HStack(alignment: .center, spacing: 12) {
            ConnectionStatusRow(
                status: manager.connectionStatus,
                isConnected: manager.isConnected
            )

            Divider()
                .frame(height: 16)

            DriveTimeRow(seconds: manager.rawRunTimeSeconds)

            Spacer()

            Button {
                showingHealth = true
            } label: {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(anyAlert ? .red : Color("Primary Green"))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Log progress helper
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
                               alignment: threshold == thresholds.last ? .top
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

    private var hours: Int { seconds / 3600 }
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
    MainDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 900, height: 340)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Landscape – iPhone") {
    MainDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 667, height: 260)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Portrait – iPhone") {
    MainDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 390, height: 560)
        .padding()
        .background(Color(.systemGroupedBackground))
}
