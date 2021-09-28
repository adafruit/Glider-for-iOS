//
//  ScanViewModel.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import Foundation

class ScanViewModel: ObservableObject {
    // Config
    private static let kRssiRunningAverageFactor = 0.2

    // Published
    enum Destination {
        case connected
        case troubleshootConnection
    }

    @Published var destination: Destination? = nil
    
    enum ConnectionStatus {
        case scanning
        case restoringConnection
        case connecting
        case connected
        case discovering
        case fileTransferError
        case fileTransferReady
        case disconnected(error: Error?)
    }
    @Published var connectionStatus: ConnectionStatus = .scanning
    
    @Published var selectedPeripheral: BlePeripheral? = nil
    @Published var numAdafruitPeripheralsWithFileTransferServiceScanned = 0
   
    // Data
    private let bleManager = BleManager.shared
    private var peripheralList = PeripheralList(bleManager: BleManager.shared)
    private var peripheralAutoConnect = PeripheralAutoConnect()
    
    // MARK: - Lifecycle
    func onAppear() {
        registerNotifications(enabled: true)
        /*
        let wasConnected = disconnectPeripheralAndResetAutoConnect()
        
        if wasConnected {
            DLog("User forced disconnection")
            AppState.shared.forceReconnect()
            startScanning()
        }
        else {
            */
            let isTryingToReconnect = AppState.shared.forceReconnect()
            if isTryingToReconnect {
                connectionStatus = .restoringConnection
            }
            else {
                startScanning()
            }
        //}
    }
    
    func onDissapear() {
        stopScanning()
        registerNotifications(enabled: false)
    }
    

    // MARK: - Scanning Actions
    /*
    /// Returns true if it was connnected
    private func disconnectPeripheralAndResetAutoConnect() -> Bool {
        var isConnected = false
        
        // Disconnect if needed
        let connectedPeripherals = bleManager.connectedPeripherals()
        if connectedPeripherals.count == 1, let peripheral = connectedPeripherals.first {
            DLog("Disconnect from previously connected peripheral")
            // Disconnect from peripheral
            disconnect(peripheral: peripheral)
            isConnected = true
        }
        
        // Autoconnect
        peripheralAutoConnect.reset()
        
        return isConnected
    }*/

    private func startScanning() {
        updateScannedPeripherals()
        
        // Start scannning
        BlePeripheral.rssiRunningAverageFactor = Self.kRssiRunningAverageFactor     // Use running average for rssi
        if !bleManager.isScanning {
            bleManager.startScan()
            connectionStatus = .scanning
        }
    }
    
    private func stopScanning() {
        if bleManager.isScanning {
            bleManager.stopScan()
        }
    }
    
    // MARK: - Destinations
    private func gotoConnected() {
        destination = .connected
    }

    // MARK: - Scanning Status
    private func updateScannedPeripherals() {
        // Update peripheralAutoconnect
        if let peripheral = peripheralAutoConnect.update(peripheralList: peripheralList) {
            // Connect to closest CPB
            connect(peripheral: peripheral)
        }
        
        // Update stats
        numAdafruitPeripheralsWithFileTransferServiceScanned = peripheralList.filteredPeripherals(forceUpdate: false).count
    }

    // MARK: - Connect / Disconnect
    private func connect(peripheral: BlePeripheral) {
        // Connect to selected peripheral
        selectedPeripheral = peripheral
        bleManager.connect(to: peripheral)
    }

    private func disconnect(peripheral: BlePeripheral) {
        selectedPeripheral = nil
        bleManager.disconnect(from: peripheral)
    }
    
    // MARK: - BLE Notifications
    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var didUnDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var peripheralDidUpdateNameObserver: NSObjectProtocol?
    private weak var willDiscoverServicesObserver: NSObjectProtocol?
    private weak var willReconnectToKnownPeripheralObserver: NSObjectProtocol?
    private weak var didFailToReconnectToKnownPeripheralObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: {[weak self] _ in self?.updateScannedPeripherals()})
               didUnDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didUnDiscoverPeripheral, object: nil, queue: .main, using: {[weak self] _ in self?.updateScannedPeripherals()})
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.willConnectToPeripheral(notification: notification)})
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.didConnectToPeripheral(notification: notification)})
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.didDisconnectFromPeripheral(notification: notification)})
            peripheralDidUpdateNameObserver = notificationCenter.addObserver(forName: .peripheralDidUpdateName, object: nil, queue: .main, using: {[weak self] notification in self?.peripheralDidUpdateName(notification: notification)})
            willDiscoverServicesObserver = notificationCenter.addObserver(forName: .willDiscoverServices, object: nil, queue: .main, using: {[weak self] notification in self?.willDiscoverServices(notification: notification)})
            willReconnectToKnownPeripheralObserver = NotificationCenter.default.addObserver(forName: .willReconnectToKnownPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.willReconnectToKnownPeripheral(notification)})
            didFailToReconnectToKnownPeripheralObserver = NotificationCenter.default.addObserver(forName: .didFailToReconnectToKnownPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.didFailToReconnectToKnownPeripheral(notification)})


        } else {
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let didUnDiscoverPeripheralObserver = didUnDiscoverPeripheralObserver {notificationCenter.removeObserver(didUnDiscoverPeripheralObserver)}
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
            if let peripheralDidUpdateNameObserver = peripheralDidUpdateNameObserver {notificationCenter.removeObserver(peripheralDidUpdateNameObserver)}
            if let willDiscoverServicesObserver = willDiscoverServicesObserver {notificationCenter.removeObserver(willDiscoverServicesObserver)}
            if let willReconnectToKnownPeripheralObserver = willReconnectToKnownPeripheralObserver {NotificationCenter.default.removeObserver(willReconnectToKnownPeripheralObserver)}
            if let didFailToReconnectToKnownPeripheralObserver = didFailToReconnectToKnownPeripheralObserver {NotificationCenter.default.removeObserver(didFailToReconnectToKnownPeripheralObserver)}
        }
    }

    private func willReconnectToKnownPeripheral(_ notification: Notification) {
        DLog("willReconnectToKnownPeripheral")
        guard let peripheral = bleManager.peripheral(from: notification) else {
            //DLog("willReconnectToKnownPeripheral detected with unknown peripheral")
            return
        }

        DLog("Reconnect selected peripheral")
        selectedPeripheral = peripheral
    }
    
    private func didFailToReconnectToKnownPeripheral(_ notification: Notification) {
        DLog("Reconnect Failed. Start Scanning")
        startScanning()
    }
    
    private func willConnectToPeripheral(notification: Notification) {
        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
                 DLog("willConnect to an unexpected peripheral")
                 return
             }

        connectionStatus = .connecting
    }

    private func didConnectToPeripheral(notification: Notification) {
        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("didConnect to an unexpected peripheral: \(String(describing: notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID))")
            return
        }
        connectionStatus = .connected

        // Setup peripheral
        AppState.shared.fileTransferClient = FileTransferClient(connectedBlePeripheral: selectedPeripheral, services: [.filetransfer]) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                DLog("setupPeripheral finished")

                // Check if filetransfer was setup
                guard let fileTransferClient = AppState.shared.fileTransferClient, fileTransferClient.isFileTransferEnabled else {
                    DLog("setupPeripheral fileTransfer not enabled")
                    self.connectionStatus = .fileTransferError
                    //self.detailText = "Error initializing FileTransfer"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1)    {
                        self.disconnect(peripheral: selectedPeripheral)
                    }
                    return
                }

                DLog("setupPeripheral success")
                
                // Finished setup
                self.connectionStatus = .fileTransferReady
                //self.detailText = "FileTransfer service ready"
                self.gotoConnected()

            case .failure(let error):
                DLog("setupPeripheral error: \(error.localizedDescription)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.disconnect(peripheral: selectedPeripheral)
                }
            }
        }
    }

    private func willDiscoverServices(notification: Notification) {
        connectionStatus = .discovering
    }
    
    private func didDisconnectFromPeripheral(notification: Notification) {
        let peripheral = bleManager.peripheral(from: notification)
        
        let currentlyConnectedPeripheralsCount = bleManager.connectedPeripherals().count
        guard let selectedPeripheral = selectedPeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there are no peripherals connected (after a failed dfu update)
            return
        }

        // Clear selected peripheral
        self.selectedPeripheral = nil

        // Show error if needed
        connectionStatus = .disconnected(error: bleManager.error(from: notification))
    }

    private func peripheralDidUpdateName(notification: Notification) {
        let name = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.name.rawValue] as? String
        DLog("centralManager peripheralDidUpdateName: \(name ?? "<unknown>")")
    }
}
