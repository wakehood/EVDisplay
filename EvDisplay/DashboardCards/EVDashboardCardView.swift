//
//  EVDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//

import SwiftUI

struct EVDashboardCardView: View {
    // Search the environment for the explicit, single class manager type
    @Environment(OBD2ConnectionManager.self) private var manager
    
    var body: some View {
        BaseDashboardCard(title: "EV", themeColor: .blue) {
            VStack {
                Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                    Text("Charge")
                } currentValueLabel: {
                    Text("\(manager.rawSOCPercentage)%")
                }
                .gaugeStyle(AdaptiveSemicircleSoCStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                .frame(width: 220, height: 220)
                .padding(.bottom, 20)
            }
        }
    }
}

// Fixed Canvas Preview: Tell the manager to load in Mock Mode
#Preview {
    EVDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .padding()
}



