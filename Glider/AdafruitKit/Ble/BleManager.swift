//
//  BleManager.swift
//  Glider
//
//  Created by Antonio García on 6/10/22.
//

import Foundation
import CoreBluetooth
import Combine

/*
 Wrapper to CBCentralManager
    - adds separate publishers instead of a single delegate
    - can be used to inject Test data
 */
protocol BleManager {
    var bleState: CBManagerState { get }
    var bleStatePublisher: PassthroughSubject<CBManagerState, Never> { get }
    
    var bleDidDiscoverPublisher: PassthroughSubject<(CBPeripheral, [String: Any], Int), Never> { get }
    var bleDidConnectPublisher: PassthroughSubject<CBPeripheral, Never> { get }
    var bleDidFailToConnectPublisher: PassthroughSubject<(CBPeripheral, Error?), Never> { get }
    var bleDidDisconnectPublisher: PassthroughSubject<(CBPeripheral, Error?), Never> { get }

    func scanForPeripherals(withServices services: [CBUUID]?, options: [String : Bool]? )
    func stopScan()
    
    func connect(peripheral: CBPeripheral, options: [String : Bool]?)
    func cancelPeripheralConnection(peripheral: CBPeripheral)
    
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral]
}

// Warning: Notifications are deprecated and they will be removed. Use the combine publishers
// Notifications
enum NotificationUserInfoKey: String {
    case uuid = "uuid"
    case error = "error"
    case state = "state"
}


// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    public static let didUpdateBleState = Notification.Name(kPrefix+".didUpdateBleState")
    public static let didDiscoverPeripheral = Notification.Name(kPrefix+".didDiscoverPeripheral")
    public static let willConnectToPeripheral = Notification.Name(kPrefix+".willConnectToPeripheral")
    public static let didConnectToPeripheral = Notification.Name(kPrefix+".didConnectToPeripheral")
    public static let willDisconnectFromPeripheral = Notification.Name(kPrefix+".willDisconnectFromPeripheral")
    public static let didDisconnectFromPeripheral = Notification.Name(kPrefix+".didDisconnectFromPeripheral")

}
