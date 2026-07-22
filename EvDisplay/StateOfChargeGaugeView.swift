//
//  SOCGaugeView.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/15/26.
//

import SwiftUI

// MARK: - Semicircle SoC Gauge Style
struct SemicircleSoCGaugeStyle: GaugeStyle {
    // 9 o'clock is 180 degrees, 3 o'clock is 360 degrees (Perfect Semicircle)
    private let startAngle = Angle(degrees: 180)
    private let endAngle = Angle(degrees: 360)
    
    func makeBody(configuration: Configuration) -> some View {
        let percentage = configuration.value
        
        return ZStack {
            // 1. Semi-Transparent Background Scale Track
            Circle()
                .trim(from: startAngle.degrees / 360, to: endAngle.degrees / 360)
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(0))
            
            // 2. Active Charge Arc Spectrum + Ambient Shadow Glow
            Circle()
                .trim(from: startAngle.degrees / 360, to: angleRange(for: percentage) / 360)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .red,       // Critical State (< 10%)
                            .orange,    // Low State
                            .yellow,    // Medium State
                            .green      // Full State (100%)
                        ]),
                        center: .center,
                        startAngle: startAngle,
                        endAngle: endAngle
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(0))
                .shadow(color: .green.opacity(percentage > 0.5 ? 0.15 : 0.0), radius: 12)
                .shadow(color: .red.opacity(percentage <= 0.1 ? 0.3 : 0.0), radius: 8) // Warns red on low charge
            
            // 3. Central Charge Percentage Readout
            VStack(spacing: 0) {
                configuration.currentValueLabel
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                configuration.label
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(2.0)
            }
            .offset(y: 25)
            
            // 4. Static Axis Alignment Ticks
            HStack {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 8)
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 8)
            }
            .offset(y: 11)
            
            // 5. Static Boundary Endpoint Labels (0% to 100%)
            HStack {
                Text("0%")
                    .offset(x: -8)
                Spacer()
                Text("100%")
                    .offset(x: 8)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.8))
            .offset(y: 26)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func angleRange(for percentage: Double) -> Double {
        let sweep = endAngle.degrees - startAngle.degrees
        return startAngle.degrees + (sweep * percentage)
    }
}

// MARK: - Reusable State of Charge View (Production-Ready Component)
struct StateOfChargeGaugeView: View {
    // Two-way binding pipeline linked directly to your external vehicle or battery controller
    @Binding var chargeLevel: Double
    private let maxCharge: Double = 100.0
    
    var body: some View {
        Gauge(value: chargeLevel, in: 0...maxCharge) {
            Text("Charge")
        } currentValueLabel: {
            Text("\(Int(chargeLevel))%")
        }
        .gaugeStyle(SemicircleSoCGaugeStyle())
        .frame(width: 240, height: 240)
        // Spring physics creates natural momentum effects when values fluctuate externally
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: chargeLevel)
    }
}

// MARK: - Interactive Local Simulation Preview
struct SoCGaugePreviewView: View {
    // Simulating the external source of truth locally
    @State private var mockExternalCharge: Double = 65.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Instantiating the production view and passing the state reference using '$'
                StateOfChargeGaugeView(chargeLevel: $mockExternalCharge)
                
                // Hardware Simulation Control Rack
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("External Signal Input:")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(mockExternalCharge)) %")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white)
                    }
                    
                    Slider(value: $mockExternalCharge, in: 0...100, step: 1)
                        .tint(mockExternalCharge <= 10 ? .red : .green)
                    
                    HStack {
                        Button("Critical (5%)") { mockExternalCharge = 5 }
                        Spacer()
                        Button("Half (50%)") { mockExternalCharge = 50 }
                        Spacer()
                        Button("Full (100%)") { mockExternalCharge = 100 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .controlSize(.small)
                    .font(.caption)
                }
                .padding(24)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
    }
}

#Preview {
    SoCGaugePreviewView()
}

