//
//  VehicleTelemetrySource.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/21/26.
//

import Foundation

@Observable
class VehicleTelemetry: NSObject {
    var speed: Double = 0.0
//    var stateOfCharge: Double = 0.0
    var maxCellTemp: Double = 0.0
    var isConnected: Bool = false
        
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
    var rawSOCPercentage = 0
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

}

