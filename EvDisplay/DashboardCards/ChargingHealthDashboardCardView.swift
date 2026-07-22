//
//  ChargingHealthDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//

import SwiftUI

struct ChargingHealthDashboardCardView: View {
    // Read the environment safely as an optional container configuration
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    
    // Provide an immediate local fallback instance to satisfy the view if the environment is missing
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: true)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    var body: some View {
        BaseDashboardCard(title: "Charging & Health", themeColor: .green) {
            VStack(alignment: .leading, spacing: 8) {
                Text("State of Charge")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                    Text("SOC")
                } currentValueLabel: {
                    Text("\(manager.rawSOCPercentage)%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .gaugeStyle(.linearCapacity)
                .tint(.green)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    ChargingHealthDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
}

