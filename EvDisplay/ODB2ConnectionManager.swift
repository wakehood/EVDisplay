//
//  ODB2ConnectionManager.swift
//  EvDisplay
//
//  Created by Sylvia Wake-Hood on 7/15/26.
//

import Foundation
import CoreBluetooth
import Observation

@Observable
class OBD2ConnectionManager: NSObject,  CBCentralManagerDelegate, CBPeripheralDelegate {
    var connectionStatus = "Initializing..."
    var isScanning = false
    var receivedLogs: [String] = []
    
    var isConnected: Bool = false
    var isChargingAllowed: Bool = false
    var isChargePlugConnected: Bool = false
    private var mockTimer: Timer?
    
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
    
    var rawCellTemp = 25.0 //temporary
    
    // FIX: Separated single-line comma declarations to satisfy the Observation macro criteria
    var alertHardware = 0
    var alertCCensus = 0
    var alertTCensus = 0
    var alertHVC = 0
    var alertLVC = 0
    var alertHiTemp = 0
    var alertLoTemp = 0
    
    private var centralManager: CBCentralManager!
    private var obdPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var incomingBuffer = ""
    private var pollingTimer: Timer?
    private var currentInitStep = 0
    private var masterTickCounter = 0
    private var cellCycleCounter = 0
    // Response gating: prevents sending the next command before the adapter finishes the current one.
    // Without this, a 0.5s timer can fire while the ECU is still responding, causing the adapter
    // to interrupt its CAN bus search and respond with "STOPPED" instead of data.
    private var waitingForResponse = false
    private var responseTimeoutTask: DispatchWorkItem?
    
    private let serialServiceUUID = CBUUID(string: "FFF0")
    private let writeCharacteristicUUID = CBUUID(string: "FFF1")
    private let notifyCharacteristicUUID = CBUUID(string: "FFF2")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    // 2. Initializer allowing you to spin up the manager in "Mock Mode"
    init(isPreviewMock: Bool = false) {
        super.init()
        
        if isPreviewMock {
            startMockDataStream()
        } else {
            // Put your actual CoreBluetooth initialization here:
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    // 3. Simple Mock Generator loop running safely on the MainActor
    func startMockDataStream() {
        self.rawSOCPercentage = 78
        self.isConnected = true
        self.isChargingAllowed = true
        self.isChargePlugConnected = true
        
        // 1. Establish your correct starting metrics configuration
        self.rawPackVoltage = 147.0
        self.rawPackCurrent = 16.8 // ~2.47 kW
        
        self.rawCellMin = 4.11
        self.rawCellMax = 4.14
        self.rawCellMean = 4.125
        self.rawCellStdDev = 0.008
        
        self.rawCellTemp = 30.0
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
               
                // 2. Keep the metrics alive and fluctuating inside the active thread loop!
                // This keeps your values from resetting back to zero on canvas redraws
                self.rawPackVoltage = max(100.0, min(160.0, self.rawPackVoltage + Double.random(in: -0.5...0.5)))
                self.rawPackCurrent = max(-100.0, min(150.0, self.rawPackCurrent + Double.random(in: -1.5...1.5)))
                
                // Cells logic stabilization
                let variance = Double.random(in: -0.01...0.01)
                self.rawCellMean = max(3.2, min(4.2, self.rawCellMean + variance))
                self.rawCellMin = self.rawCellMean - Double.random(in: 0.01...0.03)
                self.rawCellMax = self.rawCellMean + Double.random(in: 0.01...0.03)
                self.rawCellStdDev = max(0.002, min(0.040, self.rawCellStdDev + Double.random(in: -0.001...0.001)))
                
                if self.rawSOCPercentage > 1 && Double.random(in: 0...1) > 0.7 {
                    self.rawSOCPercentage -= 1
                }
            }
        }
    }
    
    @MainActor deinit {
        mockTimer?.invalidate()
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn
        else {
            return
        }
        isScanning = true;
        connectionStatus = "Scanning..."
        centralManager.scanForPeripherals(withServices: [serialServiceUUID], options: nil)
    }
    
    func disconnect() { if let p = obdPeripheral { centralManager.cancelPeripheralConnection(p) } }
    
    func sendCommand(_ command: String) {
        guard let p = obdPeripheral, let ch = txCharacteristic else { return }
        if let data = (command + "\r").data(using: .utf8) {
            p.writeValue(data, for: ch, type: ch.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
            logMessage("Sent: \(command)")
            waitingForResponse = true
            responseTimeoutTask?.cancel()
            let task = DispatchWorkItem { [weak self] in self?.waitingForResponse = false }
            responseTimeoutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        }
    }
    
    private func logMessage(_ msg: String) { DispatchQueue.main.async { self.receivedLogs.append(msg); if self.receivedLogs.count > 25 { self.receivedLogs.removeFirst() } } }
    
    private func advanceHandshake() {
        currentInitStep += 1
        // AT Z needs ~1s for the chip to fully reset before accepting the next command.
        // A brief pause before polling starts lets the adapter settle after the version query.
        let delay: TimeInterval
        switch currentInitStep {
        case 1: delay = 1.5
        case 8: delay = 0.5
        default: delay = 0.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            switch self.currentInitStep {
            case 1: self.sendCommand("AT Z")
            case 2: self.sendCommand("AT E0")
            case 3: self.sendCommand("AT H1")
            case 4: self.sendCommand("AT ST FF")  // maximum bus-search timeout (~1s)
            case 5: self.sendCommand("AT SP 6")
            case 6: self.sendCommand("AT SH 7DF")
            case 7: self.sendCommand("22 DD 80")
            case 8: self.startAutomaticPolling()
            default: break
            }
        }
    }
    
    func startAutomaticPolling() {
        stopAutomaticPolling(); masterTickCounter = 0; cellCycleCounter = 0
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.80, repeats: true) { [weak self] _ in
            // Skip this tick if we're still waiting for the previous response.
            // masterTickCounter is only advanced when a command is actually sent, so the
            // same command will be retried on the next tick after the response arrives.
            guard let self = self, self.connectionStatus == "Connected", !self.waitingForResponse else { return }
            switch self.masterTickCounter {
            case 0: self.sendCommand("22 DD 83")
            case 1: self.sendCommand("22 DD 84")
            case 2:
                let inner = self.cellCycleCounter % 4
                if inner == 0 || inner == 2 { self.sendCommand("01 1F") }
                else if inner == 1 { self.sendCommand("22 DD 85") }
                else if inner == 3 { self.sendCommand("22 DD 81") }
            case 3:
                let cellQueue = ["22 DD 86", "22 DD 87", "22 DD 88", "22 DD 89"]
                self.sendCommand(cellQueue[self.cellCycleCounter % 4])
                self.cellCycleCounter = (self.cellCycleCounter + 1) % 100
            default: break
            }
            self.masterTickCounter = (self.masterTickCounter + 1) % 4
        }
    }
    
    func stopAutomaticPolling() { pollingTimer?.invalidate(); pollingTimer = nil }
    
    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        DispatchQueue.main.async {
            if c.state == .poweredOn {
                self.startScanning()
            }
            else {
                self.connectionStatus = "Bluetooth Off";
                self.isScanning = false
            }
        }
    }
    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) { centralManager.stopScan(); obdPeripheral = p; p.delegate = self; DispatchQueue.main.async { self.isScanning = false; self.connectionStatus = "Connecting..." }; centralManager.connect(p, options: nil) }
    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) { DispatchQueue.main.async { self.connectionStatus = "Connected" }; p.discoverServices([serialServiceUUID]) }
    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) { stopAutomaticPolling(); currentInitStep = 0; waitingForResponse = false; responseTimeoutTask?.cancel(); DispatchQueue.main.async { self.connectionStatus = "Disconnected"; self.obdPeripheral = nil; self.txCharacteristic = nil; self.rxCharacteristic = nil; self.startScanning() }; logMessage("Re-scanning...") }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) { if let services = p.services { for s in services where s.uuid == serialServiceUUID { p.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], for: s) } } }
    
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        guard let characteristics = s.characteristics else { return }
        for ch in characteristics {
            if ch.properties.contains(.write) || ch.properties.contains(.writeWithoutResponse) { self.txCharacteristic = ch }
            if ch.properties.contains(.notify) || ch.properties.contains(.read) { self.rxCharacteristic = ch; p.setNotifyValue(true, for: ch) }
        }
        if txCharacteristic != nil && rxCharacteristic != nil { currentInitStep = 0; advanceHandshake() }
    }
    
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == rxCharacteristic?.uuid, let data = ch.value, let fragment = String(data: data, encoding: .utf8) else { return }
        incomingBuffer += fragment
        // The ELM327 always terminates a complete response with ">". Waiting for ">" instead
        // of any "\r" ensures we don't process partial multi-line responses prematurely.
        guard incomingBuffer.contains(">") else { return }
        let res = incomingBuffer.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        incomingBuffer = ""
        guard !res.isEmpty else { return }

        // Response received — clear the gate and cancel the safety timeout.
        waitingForResponse = false
        responseTimeoutTask?.cancel()

        logMessage("Received: \(res)")

        // "STOPPED" means the adapter interrupted its previous CAN bus search because a new
        // command arrived before it finished. The adapter is now idle and ready for the next
        // command. During handshake this is safe to treat as a completion signal; during
        // polling we just clear the gate above and let the next timer tick send the next command.
        if res.contains("STOPPED") {
            if currentInitStep < 8 { advanceHandshake() }
            return
        }

        if currentInitStep < 8 && (res.contains("OK") || res.contains("ELM327")) { advanceHandshake(); return }
        parseCANResponse(res.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""))
    }

    private func parseCANResponse(_ clean: String) {
        let getVal = { (sub: String) -> Int? in
            guard let r = clean.range(of: sub), clean.count >= r.upperBound.utf16Offset(in: clean) + 4 else { return nil }
            let a = String(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)]), b = String(clean[clean.index(r.upperBound, offsetBy: 2)..<clean.index(r.upperBound, offsetBy: 4)])
            return (Int(b, radix: 16) ?? 0) * 256 + (Int(a, radix: 16) ?? 0)
        }
        if let v = getVal("411F") { self.rawRunTimeSeconds = v; self.mcuRunTime = String(format: "%02d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60) }
        if let v = getVal("62DD80") { let ver = v % 256, rev = v / 256; self.rawVersionData = (version: ver, revision: rev); self.mcuVersion = "\(ver).\(rev)"; if currentInitStep == 7 { advanceHandshake() } }
        if let v = getVal("62DD83") { self.rawPackVoltage = Double(v) * 0.1; self.mcuPackVoltage = String(format: "%.1f V", self.rawPackVoltage) }
        if let v = getVal("62DD84") { self.rawPackCurrent = Double(Int(Int16(bitPattern: UInt16(v)))) * 0.1; self.mcuPackCurrent = String(format: "%.1f A", self.rawPackCurrent) }
        if let r = clean.range(of: "62DD85"), let soc = Int(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)], radix: 16) { self.rawSOCPercentage = min(soc, 100); self.mcuSOC = "\(self.rawSOCPercentage)%" }
        if let r = clean.range(of: "62DD81"), let byteAA = Int(String(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)]), radix: 16) {
            self.alertHardware = (byteAA >> 6) & 1; self.alertCCensus = (byteAA >> 5) & 1; self.alertTCensus = (byteAA >> 4) & 1
            self.alertHVC = (byteAA >> 3) & 1; self.alertLVC = (byteAA >> 2) & 1; self.alertHiTemp = (byteAA >> 1) & 1; self.alertLoTemp = (byteAA >> 0) & 1
        }
        for did in ["62DD86", "62DD87", "62DD88", "62DD89"] {
            if let v = getVal(did) {
                let cellValue = Double(Int(Int16(bitPattern: UInt16(v)))) * 0.0001, strFormat = String(format: "%.4f V", cellValue)
                if did == "62DD86" { self.rawCellMin = cellValue; self.cellMin = strFormat }
                else if did == "62DD87" { self.rawCellMax = cellValue; self.cellMax = strFormat }
                else if did == "62DD88" { self.rawCellMean = cellValue; self.cellMean = strFormat }
                else if did == "62DD89" { self.rawCellStdDev = cellValue; self.cellStdDev = strFormat }
            }
        }
    }
}

