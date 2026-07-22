//
//  MockOBD2Manager.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/21/26.
//

import Foundation
import Observation

@Observable
class MockOBD2Manager: VehicleTelemetry {
    private var timer: Timer?
    
    override init() {
        super.init()
        var speed: Double = 65.0
 //       var stateOfCharge: Double = 0.78
        var maxCellTemp: Double = 35.0
        var isConnected: Bool = true
        
        var mcuRunTime = "--:--:--"
        var mcuVersion = "--.--"
        var mcuPackVoltage = "--.- V"
        var mcuPackCurrent = "--.- A"
        var mcuSOC = "--%"
        var cellMin = "--.---- V"
        var cellMax = "--.---- V"
        var cellMean = "--.---- V"
        var cellStdDev = "--.---- V"
        
        var rawRunTimeSeconds = 0
        var rawVersionData: (version: Int, revision: Int) = (0, 0)
        var rawPackVoltage = 0.0
        var rawPackCurrent = 0.0
        var rawSOCPercentage = 78
        var rawCellMin = 0.0
        var rawCellMax = 0.0
        var rawCellMean = 0.0
        var rawCellStdDev = 0.0
        
        // FIX: Separated single-line comma declarations to satisfy the Observation macro criteria
        var alertHardware = 0
        var alertCCensus = 0
        var alertTCensus = 0
        var alertHVC = 0
        var alertLVC = 0
        var alertHiTemp = 0
        var alertLoTemp = 0
        
        // Schedule the timer on the main run loop to align thread isolation
         timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
             guard let self = self else { return }
             
             // Force mutations to execute cleanly on the Main Actor thread
             Task { @MainActor in
                 self.speed = max(0, min(120, self.speed + Double.random(in: -3...3)))
                 self.maxCellTemp = max(15, min(60, self.maxCellTemp + Double.random(in: -0.4...0.4)))
                 
                 if self.rawSOCPercentage > 1 {
                     if Double.random(in: 0...1) > 0.5 { // Increased probability for faster visual confirmation
                         self.rawSOCPercentage -= 1
                     }
                 } else {
                     // Reset to 78% if it drains completely during testing
                     self.rawSOCPercentage = 78
                 }
             }
         }
        
    }

    // Fixed: Explicitly declare the deinitializer as nonisolated
    @MainActor  deinit {
        // Safe to clear timers here since Timer operations are thread-safe
        timer?.invalidate()
    }

}
