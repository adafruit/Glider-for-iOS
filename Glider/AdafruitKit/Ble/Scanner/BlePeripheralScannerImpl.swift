//
//  BlePeripheralScannerImpl.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation
import CoreBluetooth
import QuartzCore
import Combine

class BlePeripheralScannerImpl: BlePeripheralScanner {
    // Configuration
    private static let kStopScanningWhenConnectingToPeripheral = false
    private static let kAlwaysAllowDuplicateKeys = true

    // BlePeripheralScanner
    @Published private(set) var blePeripherals = [BlePeripheral]()
    var blePeripheralsPublisher: Published<[BlePeripheral]>.Publisher { $blePeripherals }

    @Published private(set) var bleLastError: Error? = nil
    var bleLastErrorPublisher: Published<Error?>.Publisher { $bleLastError }

    // Params
    var scanningServicesFilter: [CBUUID]? = nil
    
    // Scanning
    public var isScanning: Bool {
        return scanningStartTime != nil
    }
    public var scanningElapsedTime: TimeInterval? {
        guard let scanningStartTime = scanningStartTime else { return nil }
        return CACurrentMediaTime() - scanningStartTime
    }
    private var isScanningWaitingToStart = false
    internal var scanningStartTime: TimeInterval?        // Time when the scanning started. nil if stopped

    internal var peripheralsFound = [UUID: BlePeripheral]()
    internal var peripheralsFoundLock = NSLock()

    private let bleManager: BleManager
    private let includeConnectedPeripheralsWithServiceId: CBUUID?
    private var disposables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    init(bleManager: BleManager, includeConnectedPeripheralsWithServiceId: CBUUID?) {
        self.bleManager = bleManager
        self.includeConnectedPeripheralsWithServiceId = includeConnectedPeripheralsWithServiceId

        // Ble status observer
        bleManager.bleStatePublisher.sink { [weak self] state in
            self?.onBleStateChanged(state: state)
        }
        .store(in: &disposables)
        
        // Ble discover observer
        bleManager.bleDidDiscoverPublisher.sink { [weak self] (peripheral, advertisementData, rssi) in
            self?.onPeripheralDiscovered(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi)
        }
        .store(in: &disposables)
        
        // Ble connection failure observer
        bleManager.bleDidFailToConnectPublisher.sink { [weak self] (peripheral, error) in
            self?.onPeripheralDidFailToConnect(peripheral: peripheral, error: error)
        }
        .store(in: &disposables)
        
        // Ble disconnection observer
        bleManager.bleDidDisconnectPublisher.sink { [weak self] (peripheral, error) in
            self?.onPeripheralDidDisconnect(peripheral: peripheral, error: error)
        }
        .store(in: &disposables)
    }

    deinit {
        scanningServicesFilter?.removeAll()
        peripheralsFound.removeAll()
    }

    // MARK: - Scan
    func start() {
        stop()
        
        isScanningWaitingToStart = true
        let bleState = bleManager.bleState
        guard bleState != .poweredOff && bleState != .unauthorized && bleState != .unsupported else {
            DLog("startScan failed because central manager is not ready")
            return
        }

        guard bleState == .poweredOn else {
            DLog("startScan failed because central manager is not powered on")
            return
        }
                
        if let includeConnectedPeripheralsWithServiceId = includeConnectedPeripheralsWithServiceId {
            self.discoverConnectedPeripherals(serviceId: includeConnectedPeripheralsWithServiceId)
        }

        // DLog("start scan")
        scanningStartTime = CACurrentMediaTime()
        NotificationCenter.default.post(name: .didStartScanning, object: nil)

        let options = Self.kAlwaysAllowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey: true] : nil
        bleManager.scanForPeripherals(withServices: scanningServicesFilter, options: options)
        isScanningWaitingToStart = false
    }

    func stop() {
        // DLog("stop scan")
        bleManager.stopScan()
        scanningStartTime = nil
        isScanningWaitingToStart = false
        NotificationCenter.default.post(name: .didStopScanning, object: nil)
    }
    
    func clearBleLastException() {
        bleLastError = nil
    }

    
    private func onBleStateChanged(state: CBManagerState) {
        if state == .poweredOn {
            if self.isScanningWaitingToStart {
                self.start()        // Continue scanning now that bluetooth is back
            }
        }
        else {
            if self.isScanning {
                self.isScanningWaitingToStart = true
            }
            self.scanningStartTime = nil
            
            // Remove all peripherals found (Important because the BlePeripheral queues could contain old commands that were processing when the bluetooth state changed)
            self.peripheralsFoundLock.lock(); defer { self.peripheralsFoundLock.unlock() }
            self.peripheralsFound.values.forEach { blePeripheral in
                blePeripheral.reset()
            }
            self.peripheralsFound.removeAll()
        }
    }
    
    
    private func onPeripheralDiscovered(peripheral: CBPeripheral, advertisementData: [String: Any]? = nil, rssi: Int? = nil) {
        peripheralsFoundLock.lock(); defer { peripheralsFoundLock.unlock() }

        /*
        if AppEnvironment.isDebug, peripheral.name?.starts(with: "CIRCUIT") != true {
            return
        }*/
        
        if let existingPeripheral = peripheralsFound[peripheral.identifier] {
            existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()

            if let rssi = rssi, rssi != BlePeripheral.kUndefinedRssiValue {     // only update rssi value if is defined ( 127 means undefined )
                existingPeripheral.rssi = rssi
            }

            if let advertisementData = advertisementData {
                for (key, value) in advertisementData {
                    existingPeripheral.advertisement.advertisementData.updateValue(value, forKey: key)
                }
            }
            peripheralsFound[peripheral.identifier] = existingPeripheral
        } else {      // New peripheral found
            let blePeripheral = BlePeripheral(peripheral: peripheral, bleManager: bleManager, advertisementData: advertisementData, rssi: rssi)
            peripheralsFound[peripheral.identifier] = blePeripheral
        }
        
        blePeripherals = Array(peripheralsFound.values)
    }
    
    private func onPeripheralDidFailToConnect(peripheral: CBPeripheral, error: Error?) {
        peripheralsFound[peripheral.identifier]?.reset()
        bleLastError = error
    }
    
    private func onPeripheralDidDisconnect(peripheral: CBPeripheral, error: Error?) {
        // Remove from peripheral list (after sending notification so the receiving objects can query about the peripheral before being removed)
        peripheralsFoundLock.lock()
        peripheralsFound.removeValue(forKey: peripheral.identifier)
        peripheralsFoundLock.unlock()
        bleLastError = error
    }
    
    
    // MARK: - Connected Peripherals
    func discoverConnectedPeripherals(serviceId: CBUUID) {

        let peripheralsWithService = bleManager.retrieveConnectedPeripherals(withServices: [serviceId])
        if !peripheralsWithService.isEmpty {
            
            //let existingPeripheralsIdentifiers = Array(peripheralsFound.keys)
            for peripheral in peripheralsWithService {
                //if !existingPeripheralsIdentifiers.contains(peripheral.identifier) {
                    DLog("Connected peripheral with known service: \(peripheral.name ?? peripheral.identifier.uuidString)")
                    let advertisementData = [CBAdvertisementDataServiceUUIDsKey: [serviceId]]
                    self.onPeripheralDiscovered(peripheral: peripheral, advertisementData: advertisementData)
                //}
            }
        }
    }
}


// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    public static let didStartScanning = Notification.Name(kPrefix+".didStartScanning")
    public static let didStopScanning = Notification.Name(kPrefix+".didStopScanning")
    public static let didUnDiscoverPeripheral = Notification.Name(kPrefix+".didUnDiscoverPeripheral")
}
