//
//  ChargingDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//

import SwiftUI

struct ChargingDashboardCardView: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: false)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    private var powerKW: Double {
        (manager.rawPackVoltage * manager.rawPackCurrent) / 1000.0
    }
    
    private var activeState: ChargingState {
        if powerKW > 0.05 { return .chargingInProgress }
        if manager.isChargePlugConnected { return .chargePlugConnected }
        if manager.isChargingAllowed { return .chargingAllowed }
        return .notCharging
    }
    
    var body: some View {
        BaseDashboardCard(title: "Charging", themeColor: activeState.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activeState.title)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(activeState.color)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f kW", max(powerKW, 0)))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                ChargingStateFlowView(activeState: activeState)
            }
            .padding(.horizontal)
        }
    }
}

private enum ChargingState: Int, CaseIterable, Identifiable {
    case notCharging
    case chargingAllowed
    case chargePlugConnected
    case chargingInProgress
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .notCharging:
            "Not Charging"
        case .chargingAllowed:
            "Charging Allowed"
        case .chargePlugConnected:
            "Plug Connected"
        case .chargingInProgress:
            "Charging"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .notCharging:
            "Not\nCharging"
        case .chargingAllowed:
            "Allowed"
        case .chargePlugConnected:
            "Plugged\nIn"
        case .chargingInProgress:
            "Charging"
        }
    }
    
    var symbolName: String {
        switch self {
        case .notCharging:
            "pause.circle"
        case .chargingAllowed:
            "checkmark.seal"
        case .chargePlugConnected:
            "powerplug"
        case .chargingInProgress:
            "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notCharging:
            .secondary
        case .chargingAllowed:
            .blue
        case .chargePlugConnected:
            .orange
        case .chargingInProgress:
            .green
        }
    }
}

private struct ChargingStateFlowView: View {
    let activeState: ChargingState
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(ChargingState.allCases) { state in
                    ChargingStateNode(
                        state: state,
                        isActive: state == activeState,
                        isComplete: state.rawValue < activeState.rawValue
                    )
                    
                    if state != ChargingState.allCases.last {
                        ChargingStateConnector(isComplete: state.rawValue < activeState.rawValue)
                    }
                }
            }
            
            HStack(spacing: 0) {
                ForEach(ChargingState.allCases) { state in
                    Text(state.shortTitle)
                        .font(.system(size: 9, weight: state == activeState ? .bold : .semibold, design: .rounded))
                        .foregroundColor(state == activeState ? activeState.color : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
            }
        }
    }
}

private struct ChargingStateNode: View {
    let state: ChargingState
    let isActive: Bool
    let isComplete: Bool
    
    private var displayColor: Color {
        if isActive { return state.color }
        if isComplete { return .green }
        return .secondary
    }
    
    var body: some View {
        Image(systemName: isComplete ? "checkmark" : state.symbolName)
            .font(.system(size: isActive ? 18 : 13, weight: .bold))
            .foregroundColor(isActive || isComplete ? .white : displayColor)
            .frame(width: isActive ? 38 : 30, height: isActive ? 38 : 30)
            .background(displayColor.opacity(isActive || isComplete ? 1.0 : 0.12))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(displayColor.opacity(isActive ? 0.35 : 0.25), lineWidth: isActive ? 4 : 1)
            )
            .frame(maxWidth: .infinity)
    }
}

private struct ChargingStateConnector: View {
    let isComplete: Bool
    
    var body: some View {
        Capsule()
            .fill(isComplete ? Color.green.opacity(0.85) : Color.secondary.opacity(0.25))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, -8)
    }
}



#Preview() {
    ChargingDashboardCardView()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 400, height: 180)
        .padding()
}


