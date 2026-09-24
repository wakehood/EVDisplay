//
//  VCUDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/2/26.
//

#if VCU_ENABLED
import SwiftUI
import OBD2Kit

struct VCUDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var manager: OBD2ConnectionManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showingVCUStatus = false

    private var isIPad: Bool { hSizeClass == .regular }

    private var anyAlert: Bool {
        manager.vcuAlertHiTemp == 1          ||
        manager.vcuAlertPowerLimit == 1      ||
        manager.vcuAlertMotorFault == 1      ||
        manager.vcuAlertElectricalFault == 1
    }

    var body: some View {
        BaseDashboardCard(themeColor: Color("Gold Accent")) {
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    let gaugeSize = min(min(geo.size.width * 0.82, geo.size.height * 0.60), isIPad ? GaugeMetrics.motorGaugeMaxIPad : GaugeMetrics.motorGaugeMaxPhone)

                    VStack(spacing: 0) {

                        // ── Motor speed gauge ──
                        Gauge(value: manager.rawVcuMotorRPM, in: 0...18_000) {
                            Text("RPM")
                        } currentValueLabel: {
                            Text(manager.rawVcuMotorRPM >= 1000
                                 ? String(format: "%.1fK", manager.rawVcuMotorRPM / 1000)
                                 : String(format: "%.0f", manager.rawVcuMotorRPM))
                        }
                        .gaugeStyle(SemicircleMotorSpeedGaugeStyle(valueFontSize: isIPad ? 64 : 44))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawVcuMotorRPM)
                        .frame(width: gaugeSize, height: gaugeSize)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .frame(maxHeight: .infinity)

                        Divider()
                            .padding(.horizontal, 4)

                        // ── Bottom bar: thermometer + alert button ──
                        HStack(alignment: .center, spacing: 12) {
                            VStack(spacing: 4) {
                                Text("VCU Temp")
                                    .font(.system(size: isIPad ? 14 : 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                TemperatureGaugeView(temp1: manager.rawVcuLowTemp, temp2: manager.rawVcuHighTemp)
                                    .frame(width: isIPad ? GaugeMetrics.thermometerWidthIPad  : GaugeMetrics.thermometerWidth,
                                           height: isIPad ? GaugeMetrics.thermometerHeightIPad : GaugeMetrics.thermometerHeight)
                            }

                            Spacer()

                            Button {
                                showingVCUStatus = true
                            } label: {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(anyAlert ? .red : Color("Primary Green"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(8)

                Text("VCU")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color("Gold Accent").opacity(0.8))
                    .tracking(1.5)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showingVCUStatus) {
            VCUStatusDashboardCardView()
                .environment(manager)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Previews

#Preview("Landscape – VCU Panel") {
    VCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 380, height: 380)
        .padding()
        .background(Color("Shadow Background"))
}

#Preview("Portrait – VCU Panel") {
    VCUDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 390, height: 300)
        .padding()
        .background(Color("Shadow Background"))
}
#endif
