//
//  FileTransferConnectionManager.swift
//  Glider
//
//  Created by Antonio García on 21/6/21.
//

import Foundation
import CoreBluetooth
import Combine
import FileTransferClient

// Note: this is a fake replacement for FileTransferConnectionManager to make it work on the simulator which doesn't support bluetooth
// Important: dont add this file to the Glider target. Use it only for testing purposes
public class FileTransferConnectionManager: ObservableObject {
    // Singleton
    public static let shared = FileTransferConnectionManager()
    
    // Published
    @Published public var peripherals = [BlePeripheralSimulated]()           // Peripherals connected or connecting
    @Published public var selectedPeripheral: BlePeripheralSimulated?        // Selected peripheral from all the connected peripherals. User can select it using setSelectedClient. The system picks one automatically if it gets disconnected or the user didnt select one
    @Published public var isSelectedPeripheralReconnecting = false  // Is the selected peripheral reconnecting
    @Published public var isConnectedOrReconnecting = false         // Is any peripheral connected or trying to connect
    @Published public var isAnyPeripheralConnecting = false

    // Parameters
    public var userDefaults = UserDefaults.standard        // Can be replaced if data saved needs to be shared

    // Data
    private var fileTransferClients = [UUID: FileTransferClient]()  // FileTransferClient for each peripheral
    private var userSelectedTransferClient: FileTransferClient?
    
    //  MARK: - Lifecycle
    private init() {
     
    }

    //  MARK: - Actions
    public func simulateConnect() {
        let peripheral = BlePeripheralSimulated()
        peripheral.simulateConnect()
        peripherals.append(peripheral)
        
        let _ = FileTransferClient(connectedBlePeripheral: peripheral, services: [.filetransfer]) { result in
            switch result {
            case .success(let client):
                self.fileTransferClients[peripheral.identifier] = client
                
            case .failure(let error):
                DLog("error: \(error)")
            }
        }
    }
    
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
    
    public func peripheral(fromIdentifier identifier: UUID) -> BlePeripheral? {
        return self.peripherals.first(where: {$0.identifier == identifier})
    }
    
    public func fileTransferClient(fromIdentifier identifier: UUID) -> FileTransferClient? {
        return self.fileTransferClients[identifier]
    }
    
    public func isReconnectingPeripheral(withIdentifier identifier: UUID) -> Bool {
        return false
    }
    
    public func waitForKnownBleStatusSynchronously() {
    }
    
    public func waitForStableConnectionsSynchronously() {
    }
    
    /// Returns if is trying to reconnect, or false if it is quickly decided that there is not possible
    @discardableResult
    public func reconnect() -> Bool {
        return false
    }

}

