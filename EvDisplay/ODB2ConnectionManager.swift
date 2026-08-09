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
class OBD2ConnectionManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var connectionStatus = String(localized: "Initializing...")
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
    var rawMcuHighVoltageCutoff = 0.0  //volts
    var rawMcuLowVoltageCutoff  = 0.0 //volts
    
    var rawMcuHighTemp = 0.0
    var rawMcuLowTemp = 0.0


    var rawPackCapacityKwh = 0.0
    var rawCurrentKwh = 0.0
    var rawAvailableEnergyKwh: Double { Double(rawSOCPercentage) / 100.0 * rawPackCapacityKwh }

    var rawVcuMotorRPM = 0.0
    var rawVcuHighTemp = 35.0
    var rawVcuLowTemp  = 28.0
 
    var alertHardware = 0
    var alertCCensus = 0
    var alertTCensus = 0
    var alertHVC = 0
    var alertLVC = 0
    var alertHiTemp = 0
    var alertLoTemp = 0

    var vcuAlertHiTemp = 0
    var vcuAlertPowerLimit = 0
    var vcuAlertMotorFault = 0
    var vcuAlertElectricalFault = 0

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

    let isPreviewMock: Bool

    private let serialServiceUUID = CBUUID(string: "FFF0")
    private let writeCharacteristicUUID = CBUUID(string: "FFF1")
    private let notifyCharacteristicUUID = CBUUID(string: "FFF2")
    
    //MCU PIDs and commands
    private let customServiceReq  = "22 "
    private let customServiceResp = "62 "
    
    //MCU Run Time
    private let mcuRunTimeReq: String   = "01 1F"
    private let mcuRunTimeResp: String  = "411F"
    
    //MCU Version
    private let mcuVersionPid: String   = "DD 80"
    var mcuVersionReq: String {
        get {self.customServiceReq + self.mcuVersionPid}
    }
    var mcuVersionResp: String {
        get {(self.customServiceResp + self.mcuVersionPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Status/Alerts
    private let mcuStatusPid: String    = "DD 81"
    var mcuStatusReq: String {
        get {self.customServiceReq + self.mcuStatusPid}
    }
    var mcuStatusResp: String {
        get {(self.customServiceResp + self.mcuStatusPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Pack Voltage
    private let mcuPackVoltPid: String  = "DD 83"
    var mcuPackVoltReq: String {
        get {self.customServiceReq + self.mcuPackVoltPid}
    }
    var mcuPackVoltResp: String {
        get {(self.customServiceResp + self.mcuPackVoltPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Pack Current
    private let mcuPackCurPid: String   = "DD 84"
    var mcuPackCurReq: String {
        get {self.customServiceReq + self.mcuPackCurPid}
    }
    var mcPackCurResp: String {
        get {(self.customServiceResp + self.mcuPackCurPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU State of Charge
    private let mcuSocPid: String       = "DD 85"
    var mcuSocReq: String {
        get {self.customServiceReq + self.mcuSocPid}
    }
    var mcuSocResp: String {
        get {(self.customServiceResp + self.mcuSocPid).replacingOccurrences(of: " ", with: "")}
    }
    
    
    //MCU Cell Min Voltage
    private let mcuCellMinPid: String   = "DD 86"
    var mcuCellMinReq: String {
        get {self.customServiceReq + self.mcuCellMinPid}
    }
    var mcuCellMinResp: String {
        get {(self.customServiceResp + self.mcuCellMinPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Cell Max Voltage
    private let mcuCellMaxPid: String   = "DD 87"
    var mcuCellMaxReq: String {
        get {self.customServiceReq + self.mcuCellMaxPid}
    }
    var mcuCellMaxResp: String {
        get {(self.customServiceResp + self.mcuCellMaxPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Cell Mean Voltage
    private let mcuCellAvgPid: String   = "DD 88"
    var mcuCellAvgReq: String {
        get {self.customServiceReq + self.mcuCellAvgPid}
    }
    var mcuCellAvgResp: String {
        get {(self.customServiceResp + self.mcuCellAvgPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Std Deviation Cell Voltages
    private let mcuStdDevPid: String    = "DD 89"
    var mcuStdDevReq: String {
        get {self.customServiceReq + self.mcuStdDevPid}
    }
    var mcuStdDevResp: String {
        get {(self.customServiceResp + self.mcuStdDevPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU High Voltage Cutoff
    private let mcuHvcPid: String       = "DD 8A"
    var mcuHvcReq: String {
        get {self.customServiceReq + self.mcuHvcPid}
    }
    var mcuHvcResp: String {
        get {(self.customServiceResp + self.mcuHvcPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Low voltage Cutoff
    private let mcuLvcPid: String       = "DD 8B"
    var mcuLvcReq: String {
        get {self.customServiceReq + self.mcuLvcPid}
    }
    var mcuLvcResp: String {
        get {(self.customServiceResp + self.mcuLvcPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU High and Low temperature
    private let mcuTempPid: String      = "DD 8C"
    var mcuTempReq: String {
        get {self.customServiceReq + self.mcuTempPid}
    }
    var mcuTempResp: String {
        get {(self.customServiceResp + self.mcuTempPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Max capacity in kWh
    private let mcuMaxKwhPid: String    = "DD 8D"
    var mcuMaxKwhReq: String {
        get {self.customServiceReq + self.mcuMaxKwhPid}
    }
    var mcuMaxKwhResp: String {
        get {(self.customServiceResp + self.mcuMaxKwhPid).replacingOccurrences(of: " ", with: "")}
    }
    
    //MCU Current Capacity in kWh
    private let mcuCurKwhPid: String    = "DD 8E"
    var mcuCurKwhReq: String {
        get {self.customServiceReq + self.mcuCurKwhPid}
    }
    var mcuCurKwhResp: String {
        get {(self.customServiceResp + self.mcuCurKwhPid).replacingOccurrences(of: " ", with: "")}
    }
    

    override init() {
        isPreviewMock = false
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    init(isPreviewMock: Bool = false) {
        self.isPreviewMock = isPreviewMock
        super.init()

        if isPreviewMock {
            startMockDataStream()
        } else {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    func startMockDataStream() {
        self.rawSOCPercentage = 78
        self.isConnected = true
        self.isChargingAllowed = true
        self.isChargePlugConnected = true

        self.rawPackVoltage = 147.0
        self.rawPackCurrent = 16.8 // ~2.47 kW

        self.rawCellMin = 2.9
        self.rawCellMax = 3.1
        self.rawCellMean = 3.0
        self.rawCellStdDev = 0.008
        self.rawMcuHighVoltageCutoff = 3.40  //volts
        self.rawMcuLowVoltageCutoff  = 2.40 //volts

        self.rawMcuLowTemp = 24.0
        self.rawMcuHighTemp = 31.0
        self.rawVcuMotorRPM = 3_500.0
        self.rawVcuLowTemp  = 35.0
        self.rawVcuHighTemp = 42.0

        self.rawPackCapacityKwh = 20.0
        self.rawCurrentKwh = Double(self.rawSOCPercentage) / 100.0 * self.rawPackCapacityKwh

        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.rawPackVoltage = max(100.0, min(160.0, self.rawPackVoltage + Double.random(in: -0.5...0.5)))
                self.rawPackCurrent = max(-100.0, min(150.0, self.rawPackCurrent + Double.random(in: -1.5...1.5)))

                let variance = Double.random(in: -0.01...0.01)
                self.rawCellMean = max(3.2, min(4.2, self.rawCellMean + variance))
                self.rawCellMin = self.rawCellMean - Double.random(in: 0.01...0.03)
                self.rawCellMax = self.rawCellMean + Double.random(in: 0.01...0.03)
                self.rawCellStdDev = max(0.002, min(0.040, self.rawCellStdDev + Double.random(in: -0.001...0.001)))

                // Temperatures drift slowly; high always stays above low
                self.rawMcuLowTemp  = max(15.0, min(45.0, self.rawMcuLowTemp  + Double.random(in: -0.3...0.3)))
                self.rawMcuHighTemp = max(self.rawMcuLowTemp + 2.0, min(60.0, self.rawMcuHighTemp + Double.random(in: -0.3...0.3)))

                self.rawVcuMotorRPM = max(0, min(18_000, self.rawVcuMotorRPM + Double.random(in: -300...300)))
                self.rawVcuLowTemp  = max(20.0, min(55.0, self.rawVcuLowTemp  + Double.random(in: -0.5...0.5)))
                self.rawVcuHighTemp = max(self.rawVcuLowTemp + 2.0, min(75.0, self.rawVcuHighTemp + Double.random(in: -0.5...0.5)))

                if self.rawSOCPercentage > 1 && Double.random(in: 0...1) > 0.7 {
                    self.rawSOCPercentage -= 1
                }
                self.rawCurrentKwh = Double(self.rawSOCPercentage) / 100.0 * self.rawPackCapacityKwh
            }
        }
    }

    @MainActor deinit {
        mockTimer?.invalidate()
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        connectionStatus = String(localized: "Scanning...")
        centralManager.scanForPeripherals(withServices: [serialServiceUUID], options: nil)
    }

    func disconnect() {
        if let p = obdPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }

    func sendCommand(_ command: String) {
        guard let p = obdPeripheral, let ch = txCharacteristic else { return }
        if let data = (command + "\r").data(using: .utf8) {
            let writeType: CBCharacteristicWriteType = ch.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            p.writeValue(data, for: ch, type: writeType)
            logMessage("Sent: \(command)")
            waitingForResponse = true
            responseTimeoutTask?.cancel()
            let task = DispatchWorkItem { [weak self] in self?.waitingForResponse = false }
            responseTimeoutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        }
    }

    private func logMessage(_ msg: String) {
        DispatchQueue.main.async {
            self.receivedLogs.append(msg)
            if self.receivedLogs.count > 25 {
                self.receivedLogs.removeFirst()
            }
        }
    }

    private func advanceHandshake() {
        currentInitStep += 1
        // AT Z needs ~1s for the chip to fully reset before accepting the next command.
        // A brief pause before polling starts lets the adapter settle after the version query.
        let delay: TimeInterval
        switch currentInitStep {
        case 1:  delay = 1.5
        case 11: delay = 0.5
        default: delay = 0.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            switch self.currentInitStep {
            case 1:  self.sendCommand("AT Z")
            case 2:  self.sendCommand("AT E0")
            case 3:  self.sendCommand("AT H1")
            case 4:  self.sendCommand("AT ST FF")  // maximum bus-search timeout (~1s)
            case 5:  self.sendCommand("AT SP 6")
            case 6:  self.sendCommand("AT SH 7DF")
            case 7:  self.sendCommand(self.mcuVersionReq)
            case 8:  self.sendCommand(self.mcuHvcReq)
            case 9:  self.sendCommand(self.mcuLvcReq)
            case 10: self.sendCommand(self.mcuMaxKwhReq)
            case 11: self.startAutomaticPolling()
            default: break
            }
        }
    }

    func startAutomaticPolling() {
        stopAutomaticPolling()
        masterTickCounter = 0
        cellCycleCounter = 0

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.80, repeats: true) { [weak self] _ in
            // Skip this tick if we're still waiting for the previous response.
            // masterTickCounter is only advanced when a command is actually sent, so the
            // same command will be retried on the next tick after the response arrives.
            guard let self = self, self.isConnected, !self.waitingForResponse else { return }

            switch self.masterTickCounter {
            case 0:
                self.sendCommand(self.mcuPackVoltReq)
            case 1:
                self.sendCommand(self.mcuPackCurReq)
            case 2:
                let inner = self.cellCycleCounter % 4
                if inner == 0 || inner == 2 {
                    self.sendCommand(mcuRunTimeReq)
                } else if inner == 1 {
                    self.sendCommand(mcuSocReq)
                } else if inner == 3 {
                    self.sendCommand(self.mcuStatusReq)
                }
            case 3:
                let cellQueue = [mcuCellMinReq, mcuCellMaxReq, mcuCellAvgReq, mcuStdDevReq]
                self.sendCommand(cellQueue[self.cellCycleCounter % 4])
                self.cellCycleCounter = (self.cellCycleCounter + 1) % 100
            case 4:
                self.sendCommand(self.mcuTempReq)
            case 5:
                self.sendCommand(self.mcuCurKwhReq)
            default:
                break
            }

            self.masterTickCounter = (self.masterTickCounter + 1) % 6
        }
    }

    func stopAutomaticPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        DispatchQueue.main.async {
            if c.state == .poweredOn {
                self.startScanning()
            } else {
                self.connectionStatus = String(localized: "Bluetooth Off")
                self.isConnected = false
                self.isScanning = false
            }
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        centralManager.stopScan()
        obdPeripheral = p
        p.delegate = self
        DispatchQueue.main.async {
            self.isScanning = false
            self.connectionStatus = String(localized: "Connecting...")
        }
        centralManager.connect(p, options: nil)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = String(localized: "Connected")
            self.isConnected = true
        }
        p.discoverServices([serialServiceUUID])
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        stopAutomaticPolling()
        currentInitStep = 0
        waitingForResponse = false
        responseTimeoutTask?.cancel()
        DispatchQueue.main.async {
            self.connectionStatus = String(localized: "Disconnected")
            self.isConnected = false
            self.obdPeripheral = nil
            self.txCharacteristic = nil
            self.rxCharacteristic = nil
            self.startScanning()
        }
        logMessage("Re-scanning...")
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = p.services {
            for s in services where s.uuid == serialServiceUUID {
                p.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], for: s)
            }
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        guard let characteristics = s.characteristics else { return }
        for ch in characteristics {
            if ch.properties.contains(.write) || ch.properties.contains(.writeWithoutResponse) {
                self.txCharacteristic = ch
            }
            if ch.properties.contains(.notify) || ch.properties.contains(.read) {
                self.rxCharacteristic = ch
                p.setNotifyValue(true, for: ch)
            }
        }
        if txCharacteristic != nil && rxCharacteristic != nil {
            currentInitStep = 0
            advanceHandshake()
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == rxCharacteristic?.uuid,
              let data = ch.value,
              let fragment = String(data: data, encoding: .utf8)
        else { return }

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

        if currentInitStep < 8 && (res.contains("OK") || res.contains("ELM327")) {
            advanceHandshake()
            return
        }

        let clean = res
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        parseCANResponse(clean)
    }

    // MARK: - CAN Response Parsing

    private func parseCANResponse(_ clean: String) {
        let getVal = { (sub: String) -> Int? in
            guard let r = clean.range(of: sub),
                  clean.count >= r.upperBound.utf16Offset(in: clean) + 4
            else { return nil }
            let a = String(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)])
            let b = String(clean[clean.index(r.upperBound, offsetBy: 2)..<clean.index(r.upperBound, offsetBy: 4)])
            return (Int(b, radix: 16) ?? 0) * 256 + (Int(a, radix: 16) ?? 0)
        }

        if let v = getVal(mcuRunTimeResp) {
            self.rawRunTimeSeconds = v
            self.mcuRunTime = String(format: "%02d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60)
        }

        if let v = getVal(mcuVersionResp) {
            let ver = v % 256, rev = v / 256
            self.rawVersionData = (version: ver, revision: rev)
            self.mcuVersion = "\(ver).\(rev)"
            if currentInitStep == 7 { advanceHandshake() }
        }

        if let v = getVal(mcuPackVoltResp) {
            self.rawPackVoltage = Double(v) * 0.1
            self.mcuPackVoltage = String(format: "%.1f V", self.rawPackVoltage)
        }

        if let v = getVal(mcPackCurResp) {
            self.rawPackCurrent = Double(Int(Int16(bitPattern: UInt16(v)))) * 0.1
            self.mcuPackCurrent = String(format: "%.1f A", self.rawPackCurrent)
        }

        if let r = clean.range(of: mcuSocResp),
           let soc = Int(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)], radix: 16) {
            self.rawSOCPercentage = min(soc, 100)
            self.mcuSOC = "\(self.rawSOCPercentage)%"
        }

        if let r = clean.range(of: self.mcuStatusResp),
           let byteAA = Int(String(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)]), radix: 16) {
            self.alertHardware = (byteAA >> 6) & 1
            self.alertCCensus  = (byteAA >> 5) & 1
            self.alertTCensus  = (byteAA >> 4) & 1
            self.alertHVC      = (byteAA >> 3) & 1
            self.alertLVC      = (byteAA >> 2) & 1
            self.alertHiTemp   = (byteAA >> 1) & 1
            self.alertLoTemp   = (byteAA >> 0) & 1
        }

        for did in [mcuCellMinResp, mcuCellMaxResp, mcuCellAvgResp, mcuStdDevResp,] {
            if let v = getVal(did) {
                let cellValue = Double(v) * 0.0001
                let strFormat = String(format: "%.4f V", cellValue)
                if      did == mcuCellMinResp {
                    self.rawCellMin   = cellValue; self.cellMin    = strFormat
                    
//                    let hexstring = String(v, radix: 16, uppercase: true)
//                    print("pid = \(mcuCellMinResp) v = \(v) rawCellMin = \(rawCellMin) cellMin = \(cellMin) hexstring = \(hexstring)")
                }
                else if did == mcuCellMaxResp {
                    self.rawCellMax   = cellValue; self.cellMax    = strFormat
                  //  print("pid = \(mcuCellMaxResp) v = \(v) rawCellMax = \(rawCellMax) cellMax = \(cellMax)")
                }
                else if did == mcuCellAvgResp {
                    self.rawCellMean  = cellValue; self.cellMean   = strFormat
                  //  print("pid = \(mcuCellAvgResp) v = \(v) rawCellMean = \(rawCellMean) cellMean = \(cellMean)")
                }
                else if did == mcuStdDevResp {
                    self.rawCellStdDev = cellValue; self.cellStdDev = strFormat
                  //  print("pid = \(mcuStdDevResp) v = \(v) rawCellStdDev = \(rawCellStdDev) cellStdDev = \(cellStdDev)")
                }
            }
        }
        for did in [mcuHvcResp, mcuLvcResp] {
            if let v = getVal(did) {
                let vcoValue = Double(v) * 0.0001
            //    let strFormat = String(format: "%.3f V", vcoValue)
                if did == mcuHvcResp {
                    self.rawMcuHighVoltageCutoff = vcoValue
                    if self.currentInitStep == 8 { self.advanceHandshake()
                    

//                    let hexstring = String(v, radix: 16, uppercase: true)
//                    print("pid = \(did) v = \(v) rawMcuHighVoltageCutoff = \(rawMcuHighVoltageCutoff) hexstring = \(hexstring)")
                    }
                }
                else if did == mcuLvcResp {
                    self.rawMcuLowVoltageCutoff = vcoValue
                    if self.currentInitStep == 9 { self.advanceHandshake()
                 //   print("pid = \(did) v = \(v) rawMcuLowVoltageCutoff = \(rawMcuLowVoltageCutoff)")
                    }
                }
            }
        }

        if let r = clean.range(of: mcuTempResp),
           clean.distance(from: r.upperBound, to: clean.endIndex) >= 4,
           let byteA = UInt8(String(clean[r.upperBound..<clean.index(r.upperBound, offsetBy: 2)]), radix: 16),
           let byteB = UInt8(String(clean[clean.index(r.upperBound, offsetBy: 2)..<clean.index(r.upperBound, offsetBy: 4)]), radix: 16) {
            self.rawMcuHighTemp = Double(Int8(bitPattern: byteA))
            self.rawMcuLowTemp  = Double(Int8(bitPattern: byteB))
        }

        if let v = getVal(mcuMaxKwhResp) {
            self.rawPackCapacityKwh = Double(v) * 0.1
            if self.currentInitStep == 10 { self.advanceHandshake() }
        }

        if let v = getVal(mcuCurKwhResp) {
            self.rawCurrentKwh = Double(v) * 0.1
        }
    }
}
