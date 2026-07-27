//
//  GeneralDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/27/26.
//

import SwiftUI

struct GeneralDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: false)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    private var driveTimeWithoutSeconds: String {
        let parts = manager.mcuRunTime.split(separator: ":")
        guard parts.count == 3 else { return manager.mcuRunTime }
        return "\(parts[0]):\(parts[1])"
    }
    
    var body: some View {
        BaseDashboardCard(title: "General", themeColor: .teal) {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(spacing: 12) {
                    GeneralMetricRow(
                        label: "Time",
                        value: timeline.date.formatted(date: .omitted, time: .shortened)
                    )
                    
                    Divider()
                    
                    GeneralMetricRow(
                        label: "Drive Time",
                        value: driveTimeWithoutSeconds
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct GeneralMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview {
    GeneralDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 400, height: 170)
        .padding()
}
