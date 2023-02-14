//
//  BleManagerImpl.swift
//  Glider
//
//  Created by Antonio García on 6/10/22.
//

import Foundation
import CoreBluetooth
import Combine

class BleManagerImpl: NSObject, BleManager {
    // Ble
    private var centralManager: CBCentralManager!
    
    var bleState: CBManagerState {
        return centralManager.state
    }
    
    // Publishers
    let bleStatePublisher = PassthroughSubject<CBManagerState, Never>()
    let bleDidDiscoverPublisher = PassthroughSubject<(CBPeripheral, [String: Any], Int), Never>()
    let bleDidConnectPublisher = PassthroughSubject<CBPeripheral, Never>()
    let bleDidFailToConnectPublisher = PassthroughSubject<(CBPeripheral, Error?), Never>()
    let bleDidDisconnectPublisher = PassthroughSubject<(CBPeripheral, Error?), Never>()

        
    // MARK: - Lifecycle
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .userInitiated), options: [:])
    }
    
    // MARK: - Actions
    func scanForPeripherals(withServices services: [CBUUID]? = nil, options: [String : Bool]? = nil) {
        centralManager.scanForPeripherals(withServices: services, options: options)
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    func connect(peripheral: CBPeripheral, options: [String : Bool]?) {
        centralManager.connect(peripheral, options: options)
    }
    
    func cancelPeripheralConnection(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return centralManager.retrievePeripherals(withIdentifiers: identifiers)
    }
    
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] {
        return centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs)
    }
   
}

// MARK: - CBCentralManagerDelegate
extension BleManagerImpl: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DLog("centralManagerDidUpdateState: \(central.state.rawValue)")
        
        NotificationCenter.default.post(name: .didUpdateBleState, object: nil, userInfo: [NotificationUserInfoKey.state.rawValue: central.state])
        
        bleStatePublisher.send(central.state)
    }
    
    /*
     func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
     
     }*/
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // DLog("didDiscover: \(peripheral.name ?? peripheral.identifier.uuidString)")
        let rssi = RSSI.intValue
        
        NotificationCenter.default.post(name: .didDiscoverPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
        
        bleDidDiscoverPublisher.send((peripheral, advertisementData, rssi))
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DLog("didConnect: \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        // Send notification
        NotificationCenter.default.post(name: .didConnectToPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
        
        bleDidConnectPublisher.send(peripheral)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DLog("didFailToConnect: \(peripheral.name ?? peripheral.identifier.uuidString). \(String(describing: error))")
        
        bleDidFailToConnectPublisher.send((peripheral, error))
        
        // Notify
        NotificationCenter.default.post(name: .didDisconnectFromPeripheral, object: nil, userInfo: [
            NotificationUserInfoKey.uuid.rawValue: peripheral.identifier,
            NotificationUserInfoKey.error.rawValue: error as Any
        ])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DLog("didDisconnectPeripheral: \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        bleDidDisconnectPublisher.send((peripheral, error))

        // Notify
        NotificationCenter.default.post(name: .didDisconnectFromPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
    }
}
