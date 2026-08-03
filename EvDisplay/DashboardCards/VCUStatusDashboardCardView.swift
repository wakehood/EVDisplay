//
//  VCUStatusDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 8/2/26.
//

import SwiftUI

struct VCUStatusDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: true)

    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }

    private var activeAlerts: [String] {
        var alerts: [String] = []
        if manager.vcuAlertHiTemp == 1          { alerts.append("High Temperature") }
        if manager.vcuAlertPowerLimit == 1      { alerts.append("Power Limit Active") }
        if manager.vcuAlertMotorFault == 1      { alerts.append("Motor/System Fault") }
        if manager.vcuAlertElectricalFault == 1 { alerts.append("Electrical Fault") }
        return alerts
    }

    private var healthColor: Color {
        activeAlerts.isEmpty ? Color("Primary Green") : .red
    }

    private var alertItems: [(label: String, isActive: Bool)] {
        [
            ("High Temperature",    manager.vcuAlertHiTemp == 1),
            ("Power Limit Active",  manager.vcuAlertPowerLimit == 1),
            ("Motor/System Fault",  manager.vcuAlertMotorFault == 1),
            ("Electrical Fault",    manager.vcuAlertElectricalFault == 1)
        ]
    }

    var body: some View {
        BaseDashboardCard(title: "VCU Status", themeColor: healthColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activeAlerts.isEmpty ? "No Active Alerts" : "Active Alerts")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(healthColor)

                    Spacer()

                    Text("\(activeAlerts.count)/4")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(alertItems, id: \.label) { item in
                        VCUAlertFlagView(label: item.label, isActive: item.isActive)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct VCUAlertFlagView: View {
    let label: String
    let isActive: Bool

    private var color: Color { isActive ? .red : Color("Primary Green") }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(isActive ? 0.5 : 0.25), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

#Preview {
    VCUStatusDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 400, height: 160)
        .padding()
}
