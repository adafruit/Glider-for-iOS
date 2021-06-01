//
//  AutoConnectViewModel.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import Foundation

class AutoConnectViewModel: ObservableObject {
    // Config
    private static let kRssiRunningAverageFactor = 0.2

    // Published
    enum Destination {
        case fileTransfer
    }
    
    @Published var destination: Destination? = nil
    @Published var isScanning: Bool = false{
        didSet {
            if isScanning {
                startScanning()
            }
            else {
                stopScanning()
            }
        }
    }
    
    @Published var adafruitBoard: AdafruitBoard? = nil
    @Published var selectedPeripheral: BlePeripheral? = nil
    @Published var detailText: String = "Starting..."
    @Published var numPeripheralsScanned = 0
    @Published var numAdafruitPeripheralsScanned = 0
    @Published var numAdafruitPeripheralsWithFileTranferServiceScanned = 0
    @Published var numAdafruitPeripheralsWithFileTranferServiceNearby = 0
    
    // Data
    private let bleManager = BleManager.shared
    private var peripheralList = PeripheralList(bleManager: BleManager.shared)
    private var peripheralAutoConnect = PeripheralAutoConnect()
    
    
    func onAppear() {
        registerNotifications(enabled: true)
        startScanning()
    }
    
    func onDissapear() {
        stopScanning()
        registerNotifications(enabled: false)
    }
    
    // MARK: - Scanning
    private func setup() {
        // Disconnect if needed
        let connectedPeripherals = bleManager.connectedPeripherals()
        if connectedPeripherals.count == 1, let peripheral = connectedPeripherals.first {
            DLog("Disconnect from previously connected peripheral")
            // Disconnect from peripheral
            disconnect(peripheral: peripheral)
        }
        
        // Ble Notifications
//        registerNotifications(enabled: true)

        // Autoconnect
        peripheralAutoConnect.reset()
    }

    private func startScanning() {
        setup()
        
        updateScannedPeripherals()
        
        // Start scannning
        BlePeripheral.rssiRunningAverageFactor = Self.kRssiRunningAverageFactor     // Use running average for rssi
        if !bleManager.isScanning {
            bleManager.startScan()
            detailText = "Scanning..."
        }
        
        // Remove saved peripheral for autoconnect
        Settings.clearAutoconnectPeripheral()
    }
    
    private func stopScanning() {
        if bleManager.isScanning {
            bleManager.stopScan()
        }
    }
    
    // MARK: - Destinations
    private func gotoFileTransfer() {
        destination = .fileTransfer
    }

    // MARK: - Scanning
    private func updateScannedPeripherals() {
        // Update peripheralAutoconnect
        if let peripheral = peripheralAutoConnect.update(peripheralList: peripheralList) {
            // Connect to closest CPB
            connect(peripheral: peripheral)
        }
        
        // Update stats
        numPeripheralsScanned = bleManager.numPeripherals()
        numAdafruitPeripheralsScanned = bleManager.peripherals().filter{$0.isManufacturerAdafruit()}.count
        numAdafruitPeripheralsWithFileTranferServiceScanned = peripheralList.filteredPeripherals(forceUpdate: false).count
        numAdafruitPeripheralsWithFileTranferServiceNearby = peripheralAutoConnect.matchingPeripherals.count
    }

    // MARK: - Connections
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

        } else {
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let didUnDiscoverPeripheralObserver = didUnDiscoverPeripheralObserver {notificationCenter.removeObserver(didUnDiscoverPeripheralObserver)}
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
            if let peripheralDidUpdateNameObserver = peripheralDidUpdateNameObserver {notificationCenter.removeObserver(peripheralDidUpdateNameObserver)}
            if let willDiscoverServicesObserver = willDiscoverServicesObserver {notificationCenter.removeObserver(willDiscoverServicesObserver)}
        }
    }

    private func willConnectToPeripheral(notification: Notification) {
        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
                 DLog("willConnect to an unexpected peripheral")
                 return
             }

        detailText = "Connecting..."
    }

    private func didConnectToPeripheral(notification: Notification) {
        guard let selectedPeripheral = selectedPeripheral, let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID, selectedPeripheral.identifier == identifier else {
            DLog("didConnect to an unexpected peripheral")
            return
        }
        detailText = "Connected..."

        // Setup peripheral
        adafruitBoard = AdafruitBoard(connectedBlePeripheral: selectedPeripheral, services: [.filetransfer]) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                DLog("setupPeripheral finished")

                // Check if filetransfer was setup
                guard let adafruitBoard = self.adafruitBoard, adafruitBoard.isFileTransferEnabled else {
                    DLog("setupPeripheral fileTransfer not enabled")
                    self.detailText = "Error initializing FileTransfer"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1)    {
                        self.disconnect(peripheral: selectedPeripheral)
                    }
                    return
                }

                DLog("setupPeripheral success")
                self.detailText = "FileTransfer service ready"
                
                // Finished setup
                self.gotoFileTransfer()

            case .failure(let error):
                DLog("setupPeripheral error: \(error.localizedDescription)")

                /*
                let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: localizationManager.localizedString("scanner_error_startboard"), preferredStyle: .alert)
                let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
*/
                self.disconnect(peripheral: selectedPeripheral)
            }
        }
    }

    private func willDiscoverServices(notification: Notification) {
        detailText = "Discovering Services..."
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
        if let error = bleManager.error(from: notification) {
            detailText = "Disconnected \(error.localizedDescription)"
        }
        else {
            detailText = "Disconnected"
        }
    }

    private func peripheralDidUpdateName(notification: Notification) {
        let name = notification.userInfo?[BlePeripheral.NotificationUserInfoKey.name.rawValue] as? String
        DLog("centralManager peripheralDidUpdateName: \(name ?? "<unknown>")")
    }
}
