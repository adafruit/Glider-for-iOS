//
//  BleManagerFake.swift
//  Glider
//
//  Created by Antonio García on 6/10/22.
//

import Foundation
import CoreBluetooth
import Combine

class BleManagerFake: BleManager {
    var bleState: CBManagerState { return .poweredOn }
    
    // Publishers
    let bleStatePublisher = PassthroughSubject<CBManagerState, Never>()
    let bleDidDiscoverPublisher = PassthroughSubject<(CBPeripheral, [String: Any], Int), Never>()
    let bleDidConnectPublisher = PassthroughSubject<CBPeripheral, Never>()
    let bleDidFailToConnectPublisher = PassthroughSubject<(CBPeripheral, Error?), Never>()
    let bleDidDisconnectPublisher = PassthroughSubject<(CBPeripheral, Error?), Never>()

    func scanForPeripherals(withServices services: [CBUUID]?, options: [String : Bool]? ) {}
    func stopScan() {}
    
    func connect(peripheral: CBPeripheral, options: [String : Bool]?) {}
    func cancelPeripheralConnection(peripheral: CBPeripheral) {}
    
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] { return []}
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] { return [] }
 
}
