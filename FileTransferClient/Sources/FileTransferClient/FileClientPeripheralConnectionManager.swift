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
    @Published public var peripherals = [BlePeripheral]()           // Peripherals connected or connecting
    @Published public var isConnectedOrReconnecting = false         // Is any peripheral connected or trying to connect
    @Published public var selectedPeripheral: BlePeripheral?        // Selected peripheral from all the connected peripherals. User can select it using setSelectedClient, but the system picks one automatically if it gets disconnected or the user didnt select one
    @Published public var isSelectedPeripheralReconnecting = false

    // Parameters
    var userDefaults = UserDefaults.standard        // Can be replaced if data saved needs to be shared
    
    // Data
    private let reconnectTimeout: TimeInterval
    
    private var isReconnectingPeripheral = [UUID: Bool]()           // Is reconnecting the peripheral with identifier
    private var fileTransferClients = [UUID: FileTransferClient]()  // FileTransferClient for each peripheral
    private var userSelectedTransferClient: FileTransferClient? {   // User selected client (or picked automatically by the system if user didnt pick or got disconnected)
        didSet {
            updateSelectedPeripheral()
        }
    }
    private var recoveryPeripheralIdentifier: UUID? // (UUID, Timer)?      // Data for a peripheral that was disconnected. There is a timer

    //  MARK: - Lifecycle
    public init(reconnectTimeout: TimeInterval = 2) {
        //DLog("Init FileClientPeripheralConnectionManager")
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
 

    //  MARK: - Actions
    public var selectedClient: FileTransferClient? {
        return userSelectedTransferClient ?? fileTransferClients.values.first
    }

    public func setSelectedClient(blePeripheral: BlePeripheral) {
        if let client = fileTransferClients[blePeripheral.identifier] {
            setSelectedClient(client)
        }
    }
    
    public func setSelectedClient(_ client: FileTransferClient) {
        userSelectedTransferClient = client
    }
    
    /// Returns if is trying to reconnect, or false if it is quickly decided that there is not possible
    @discardableResult
    public func reconnect() -> Bool {
        
        // Filter-out from knownPeripherals those that are not connected or connecting at the moment
        let alreadyConnectedOrConnectingUUIDs = peripherals.map{$0.identifier}
        let reconnectUUIDs = knownPeripheralsUUIDs.filter{ !alreadyConnectedOrConnectingUUIDs.contains($0) }
        
        // Reconnect
        let isTryingToReconnect = BleManager.shared.reconnecToPeripherals(peripheralUUIDs: reconnectUUIDs, withServices: [BlePeripheral.kFileTransferServiceUUID], timeout: reconnectTimeout)
        if !isTryingToReconnect {
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
        
        // Get identifier for the disconnected peripheral
        guard let peripheralUUID = BleManager.shared.peripheralUUID(from: notification) else {
            DLog("warning: unknown peripheral disconnected")
            updateConnectionStatus()
            return
        }
        
        if isReconnectingPeripheral[peripheralUUID] == true {
            DLog("recover failed for \(peripheralUUID.uuidString)")
            setReconnectionFailed(peripheralUUID: peripheralUUID)
            if self.recoveryPeripheralIdentifier == peripheralUUID {        // If it was recovering then remove it because it failed
                self.recoveryPeripheralIdentifier = nil
            }
            self.updateSelectedPeripheral()
        }
        // If it was the selected peripheral try to recover the connection because a peripheral can be disconnected momentarily when writing to the filesystem.
        else if selectedClient?.blePeripheral?.identifier == peripheralUUID {
            userSelectedTransferClient = nil
            
            // Wait for recovery before connecting to a different one
            DLog("Try to recover disconnected peripheral: \(selectedPeripheral?.name ?? selectedPeripheral?.identifier.uuidString ?? "nil")")
            self.recoveryPeripheralIdentifier = peripheralUUID
            self.isSelectedPeripheralReconnecting = true
            
            DispatchQueue.main.async {      // Important: add delay because the disconnection process will remove the peripheral from the discovered list and the reconnectToPeripherals will add it back, so wait before adding or it will be removed
                // Reconnect
                let isTryingToReconnect = BleManager.shared.reconnecToPeripherals(peripheralUUIDs: [peripheralUUID], withServices: [BlePeripheral.kFileTransferServiceUUID], timeout: self.reconnectTimeout)
                if !isTryingToReconnect {
                    DLog("recover failed. Autoselect another peripheral")
                    self.fileTransferClients[peripheralUUID] = nil      // Remove info from disconnnected peripheral (it will change selectedClient)
                    self.updateSelectedPeripheral()
                    self.isSelectedPeripheralReconnecting = false
                }
            }
        }
                
        updateConnectionStatus()
    }
    
    private func setReconnectionFailed(peripheralUUID: UUID) {
        isReconnectingPeripheral[peripheralUUID] = false
        
        if peripheralUUID == selectedPeripheral?.identifier {       // If it the selectedPeripheral, then the reconnection failed
            self.isSelectedPeripheralReconnecting = false
        }
        fileTransferClients[peripheralUUID] = nil  // Remove info from disconnnected peripheral
        NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil)
    }
    
    // MARK: - Utils
    private func updateConnectionStatus() {
        let isConnectedOrReconnecting = !peripherals.isEmpty || isReconnectingPeripheral.values.contains(true) || recoveryPeripheralIdentifier != nil
        guard isConnectedOrReconnecting != self.isConnectedOrReconnecting else { return }       // Only update if changed

        // Update @Published value
        self.isConnectedOrReconnecting = isConnectedOrReconnecting
        //DLog("updateConnectionStatus: \(isConnectedOrReconnecting)")
    }
    
    private func updateSelectedPeripheral() {
        guard selectedClient?.blePeripheral != selectedPeripheral else { return }
        
        // Update @Published value
        selectedPeripheral = selectedClient?.blePeripheral
        
        DLog("selectedPeripheral: \(selectedPeripheral?.name ?? selectedPeripheral?.identifier.uuidString ?? "nil")")
        NotificationCenter.default.post(name: .didSelectPeripheralForFileTransfer, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: selectedPeripheral?.identifier as Any])
        
        // Check that the selected client corresponds to the selected peripheral
        if let selectedPeripheralIdentifier = selectedPeripheral?.identifier, let selectedPeripheralClient = fileTransferClients[selectedPeripheralIdentifier], userSelectedTransferClient != selectedPeripheralClient {
            setSelectedClient(selectedPeripheralClient)
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
        let _ = FileTransferClient(connectedBlePeripheral: peripheral, services: [.filetransfer]) { result in
            
            switch result {
            case .success(let client):
                if client.isFileTransferEnabled {
                    //DLog("Reconnected to peripheral successfully")
                    self.fileTransferClients[peripheral.identifier] = client

                    if peripheral.identifier == self.selectedPeripheral?.identifier {       // If it the selectedPeripheral, then the reconnection finished successfuly
                        self.isSelectedPeripheralReconnecting = false
                    }

                    self.updateSelectedPeripheral()
                    self.addKnownPeripheralsUUIDs(peripheral.identifier)
                    
                    NotificationCenter.default.post(name: .didReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
                }
                else {
                    DLog("Failed setup file transfer")
                    self.setReconnectionFailed(peripheralUUID: peripheral.identifier)
                }
                
            case .failure(let error):
                DLog("Failed to setup peripheral: \(error.localizedDescription)")
                self.setReconnectionFailed(peripheralUUID: peripheral.identifier)
            }
        }
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
    public static let didSelectPeripheralForFileTransfer = Notification.Name(kPrefix+".didSelectPeripheralForFileTransfer")
}


