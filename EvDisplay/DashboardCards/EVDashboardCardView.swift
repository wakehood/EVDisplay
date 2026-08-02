//
//  EVDashboardCardView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/20/26.
//
import SwiftUI

struct EVDashboardCard: View {
    @Environment(OBD2ConnectionManager.self) private var environmentManager: OBD2ConnectionManager?
    @State private var localPreviewSource = OBD2ConnectionManager(isPreviewMock: true)
    
    private var manager: OBD2ConnectionManager {
        environmentManager ?? localPreviewSource
    }
    
    private let scaleThresholds: [Double] = [0, 2, 5, 10, 20, 50, 100, 200, 500]
    
    var body: some View {
        // Calculate Power in kW (Watts divided by 1000)
        let powerKW = (manager.rawPackVoltage * manager.rawPackCurrent) / 1000.0
        let isCharging = powerKW >= 0
        let displayColor: Color = isCharging ? .green : .red
        
        // Compute normalized 0.0 to 1.0 progress based on your custom logarithmic steps
        let normalizedPowerProgress = calculateLogProgress(for: abs(powerKW))
        
        BaseDashboardCard(title: "EV", themeColor: .blue) {
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 12) {
                    Text("State of Charge")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Gauge(value: Double(manager.rawSOCPercentage), in: 0...100) {
                        Text("Charge")
                    } currentValueLabel: {
                        Text("\(manager.rawSOCPercentage)%")
                    }
                    .gaugeStyle(AdaptiveSemicircleSoCStyle())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.rawSOCPercentage)
                    .frame(width: 160, height: 160)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Power")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(isCharging ? "CHARGE" : "DEMAND")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(displayColor)
                            .tracking(0.5)
                    }
                    
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.06))
                                        .frame(width: 14)
                                    
                                    Capsule()
                                        .fill(displayColor)
                                        .frame(width: 14, height: geo.size.height * normalizedPowerProgress)
                                        .shadow(color: displayColor.opacity(0.15), radius: 4)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: normalizedPowerProgress)
                                }
                                .frame(maxWidth: 14)
                            }
                            .frame(width: 14, height: 145)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(scaleThresholds.reversed(), id: \.self) { threshold in
                                    Text("\(Int(threshold))")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(maxHeight: .infinity, alignment: threshold == scaleThresholds.last ? .top : (threshold == scaleThresholds.first ? .bottom : .center))
                                }
                            }
                            .frame(height: 145)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: "%.2f kW", abs(powerKW)))
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(displayColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            
                            Divider()
                            
                            Text(String(format: "Pack %.1fV", manager.rawPackVoltage))
                            Text(String(format: "Current %.1fA", manager.rawPackCurrent))
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
    
    /// Maps a raw absolute kW value into a clean linear 0.0 to 1.0 range across uneven segments
    private func calculateLogProgress(for value: Double) -> Double {
        guard value > scaleThresholds[0] else { return 0.0 }
        guard value < scaleThresholds.last! else { return 1.0 }
        
        let totalSegments = Double(scaleThresholds.count - 1)
        let segmentWeight = 1.0 / totalSegments
        
        for i in 0..<scaleThresholds.count - 1 {
            let lowBound = scaleThresholds[i]
            let highBound = scaleThresholds[i+1]
            
            if value >= lowBound && value <= highBound {
                let localPercentage: Double
                
                if lowBound == 0 {
                    localPercentage = (value - lowBound) / (highBound - lowBound)
                } else {
                    localPercentage = (log(value) - log(lowBound)) / (log(highBound) - log(lowBound))
                }
                
                return (Double(i) + localPercentage) * segmentWeight
            }
        }
        return 0.0
    }
}

#Preview {
    EVDashboardCard()
        .environment(OBD2ConnectionManager(isPreviewMock: true))
        .frame(width: 400, height: 320)
        .padding()
}




