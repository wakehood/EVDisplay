//
//  GeneralDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/27/26.
//

import SwiftUI
import OBD2Kit

struct GeneralDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: true)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    var body: some View {
        BaseDashboardCard(title: "General", themeColor: .teal) {
            VStack(spacing: 12) {
                ConnectionStatusRow(
                    status: manager.connectionStatus,
                    isConnected: manager.isConnected
                )

                Divider()

                DriveTimeRow(seconds: manager.rawRunTimeSeconds)
            }
            .padding(.horizontal)
        }
    }
}

private struct ConnectionStatusRow: View {
    let status: String
    let isConnected: Bool

    private var statusColor: Color {
        if isConnected { return .green }
        if status == String(localized: "Bluetooth Off") { return .red }
        return .orange
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Connection Status")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(status)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
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
            Text("Drive Time")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%02d", hours))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
            Text("h")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .baselineOffset(6)
                .padding(.trailing, 5)
            Text(String(format: "%02d", minutes))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
            Text("m")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .baselineOffset(6)
        }
        .foregroundColor(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}


#Preview {
    GeneralDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 400, height: 220)
        .padding()
}
