//
//  FileClientPeripheralConnectionManager.swift
//  Glider
//
//  Created by Antonio García on 21/6/21.
//

import Foundation
import CoreBluetooth

public class FileClientPeripheralConnectionManager: ObservableObject {
    // Singleton
    public static let shared = FileClientPeripheralConnectionManager()
    
    // Constants
    private static let knownPeripheralsKey = "knownPeripherals"
 
    // Published
    @Published public var peripherals = [BlePeripheral]()
    @Published public var isConnectedOrReconnecting = false

    private var isReconnectingPeripheral = [UUID: Bool]()
    private var fileTransferClients = [UUID: FileTransferClient]()
    
    public var selectedClient: FileTransferClient? {
        return fileTransferClients.values.first     // TODO: don't use the first one. Add a selector
    }
    
    // Parameters
    var userDefaults = UserDefaults.standard        // Can be replaced if data saved needs to be shared
    
    // Data
    //private var autoconnectingPeripheralUUIDs = [UUID]()
    private let reconnectTimeout: TimeInterval
  
    //  MARK: - Lifecycle
    public init(reconnectTimeout: TimeInterval = 2) {
        DLog("Init FileClientPeripheralConnectionManager")
        self.reconnectTimeout = reconnectTimeout
        
        // Init peripherals
        self.peripherals = BleManager.shared.connectedOrConnectingPeripherals()

        // Register notifications
        registerConnectionNotifications(enabled: true)
    }

    deinit {
        // Unregister notifications
        registerConnectionNotifications(enabled: false)
    }
    
    private func updateConnectionStatus() {
        isConnectedOrReconnecting = !peripherals.isEmpty || isReconnectingPeripheral.values.contains(true)
        //DLog("updateConnectionStatus: \(isConnectedOrReconnecting)")
    }

    //  MARK: - Actions
    /// Returns if is trying to reconnect, or false if it is quickly decided that there is not possible
    @discardableResult
    public func reconnect() -> Bool {
        let isTryingToReconnect = BleManager.shared.reconnecToPeripherals(peripheralUUIDs: knownPeripheralsUUIDs, withServices: [BlePeripheral.kFileTransferServiceUUID], timeout: reconnectTimeout)
        if isTryingToReconnect {
        }
        else {
            NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil)
            DLog("No previous connected peripherals detected")
        }

        return isTryingToReconnect
    }

    // MARK: - Reconnect previously connnected Ble Peripheral
    private func willConnectToPeripheral(_ notification: Notification) {
        guard let peripheralUUID = BleManager.shared.peripheralUUID(from: notification) else {
            DLog("Will connect to a not scanned peripheral")
            return
        }
        
        isReconnectingPeripheral[peripheralUUID] = true
        updateConnectionStatus()
    }
    
    private func didConnectToPeripheral(_ notification: Notification) {
        guard let peripheralUUID = BleManager.shared.peripheralUUID(from: notification) else { return }

        guard let peripheral = BleManager.shared.peripheral(from: notification) else {
            // Don't assume that it failed. It could have restored the connection but the internal database in BleManager does not have the BlePeripheral
            DLog("Connected to a not scanned peripheral: \(peripheralUUID)")
            NotificationCenter.default.post(name: .didReconnectToKnownPeripheral, object: nil, userInfo: nil)
            isReconnectingPeripheral[peripheralUUID] = false
            updateConnectionStatus()
            return
        }
        
        connected(peripheral: peripheral)
    }

    private func didDisconnectFromPeripheral(_ notification: Notification) {
        // Update peripherals
        self.peripherals = BleManager.shared.connectedOrConnectingPeripherals()
        updateConnectionStatus()
        
        guard let peripheralUUID = BleManager.shared.peripheralUUID(from: notification) else { return }
        
        if isReconnectingPeripheral[peripheralUUID] == true {
            isReconnectingPeripheral[peripheralUUID] = false
            updateConnectionStatus()
            NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil)
        }
    }
    
    private func connected(peripheral: BlePeripheral) {
        // Show restoring connection label
        NotificationCenter.default.post(name: .willReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
        
        // Update peripherals
        self.peripherals = BleManager.shared.connectedOrConnectingPeripherals()
        isReconnectingPeripheral[peripheral.identifier] = false // Finished reconnection process
        updateConnectionStatus()
        
        // Finish FileTransfer setup on connection
        let fileTransferClient = FileTransferClient(connectedBlePeripheral: peripheral, services: [.filetransfer]) { result in
            
            switch result {
            case .success(let client):
                if client.isFileTransferEnabled {
                    DLog("Reconnected to peripheral successfully")
                    self.addKnownPeripheralsUUIDs(peripheral.identifier)
                    NotificationCenter.default.post(name: .didReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
                }
                else {
                    DLog("Failed setup file transfer")
                    NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
                }
                
            case .failure(let error):
                DLog("Failed to setup peripheral: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
            }
        }
        self.fileTransferClients[peripheral.identifier] = fileTransferClient
    }
    
    
    // MARK: - Known periperhals
    private var knownPeripheralsUUIDs: [UUID] {
        guard let uuidStrings = userDefaults.array(forKey: Self.knownPeripheralsKey) as? [String] else { return [] }
        
        let uuids = uuidStrings.compactMap{ UUID(uuidString: $0) }
        return uuids
    }
    
    private func addKnownPeripheralsUUIDs(_ uuid: UUID) {
        var peripheralsUUIDs = knownPeripheralsUUIDs
        if !peripheralsUUIDs.contains(uuid) {
            DLog("Add autoconnect peripheral: \(uuid.uuidString)")
            peripheralsUUIDs.append(uuid)
        }
        userDefaults.set(peripheralsUUIDs.map{$0.uuidString}, forKey: Self.knownPeripheralsKey)
    }
    
    private func clearKnownPeripheralUUIDs() {
        userDefaults.set(nil, forKey: Self.knownPeripheralsKey )
    }

    // MARK: - Notifications
    private var willConnectToPeripheralObserver: NSObjectProtocol?
    private var didConnectToPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerConnectionNotifications(enabled: Bool) {
        if enabled {
            willConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.willConnectToPeripheral(notification)})
            didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.didConnectToPeripheral(notification)})
            didDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.didDisconnectFromPeripheral(notification)})
        } else {
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {NotificationCenter.default.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {NotificationCenter.default.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {NotificationCenter.default.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    public static let willReconnectToKnownPeripheral = Notification.Name(kPrefix+".willReconnectToKnownPeripheral")
    public static let didReconnectToKnownPeripheral = Notification.Name(kPrefix+".didReconnectToKnownPeripheral")
    public static let didFailToReconnectToKnownPeripheral = Notification.Name(kPrefix+".didFailToReconnectToKnownPeripheral")
}


