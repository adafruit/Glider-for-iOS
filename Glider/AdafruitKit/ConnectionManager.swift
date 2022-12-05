//
//  ConnectionManager.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation
import Combine
import CoreBluetooth

class ConnectionManager: ObservableObject {
    // Constants
    private static let kReconnectTimeout: TimeInterval = 5
    
    // Published
    @Published var scanningState: Scanner.ScanningState = .idle
    
    @Published var peripherals = [Peripheral]()
    
    @Published var currentFileTransferClient: FileTransferClient? = nil
    @Published var isReconnectingToBondedPeripherals = false
    @Published var peripheralAddressesBeingSetup = Set<String>()

    var bleScanningLastErrorPublisher: Published<Error?>.Publisher
    @Published var lastReconnectionError: Error?

    // Data
    private let bleManager: BleManager
    private let scanner: Scanner
    private let onWifiPeripheralGetPasswordForHostName: ((_ name: String, _ hostName: String) -> String?)?
    private let onBlePeripheralBonded: ((_ name: String, _ uuid: UUID) -> Void)?
    private var disposables = Set<AnyCancellable>()

    private var fileTransferClients = [String: FileTransferClient]()  // FileTransferClient for each peripheral
    private var managedBlePeripherals = [(BleFileTransferPeripheral, Cancellable)]()
    
    /// Is reconnecting the peripheral with identifier
    private var isReconnectingPeripheral = [String: Bool]()
    private var isDisconnectingPeripheral = [String: Bool]()
    
    /// User selected client (or picked automatically by the system if user didn't pick or got disconnected)
    private var userSelectedTransferClient: FileTransferClient? = nil

    public enum ConnectionError: Error {
        case undefinedPeripheralType
        case cannotConnectToBondedPeripheral
    }
    
    struct BondedPeripheralData {
        var name: String?
        let uuid: UUID
        let state: CBPeripheralState?
    }
    
    // MARK: - Lifecycle
    init(
        bleManager: any BleManager,
        blePeripheralScanner: any BlePeripheralScanner,
        wifiPeripheralScanner: any BonjourScanner,
        onBlePeripheralBonded: ((_ name: String, _ uuid: UUID) -> Void)?,
        onWifiPeripheralGetPasswordForHostName: ((_ name: String, _ hostName: String) -> String?)?
    ) {
        self.bleManager = bleManager
        self.scanner = Scanner(blePeripheralScanner: blePeripheralScanner, wifiPeripheralScanner: wifiPeripheralScanner)
        self.onBlePeripheralBonded = onBlePeripheralBonded
        self.onWifiPeripheralGetPasswordForHostName = onWifiPeripheralGetPasswordForHostName
        
        bleScanningLastErrorPublisher = scanner.bleLastErrorPublisher
        
        scanner.$scanningState
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            //.receive(on: RunLoop.main)
            .sink { state in
            // Update state
            self.scanningState = state

            // Update peripherals
            if case let .scanning(peripherals) = state {
                self.peripherals = peripherals
            }
            else {
                self.peripherals = []
            }
        }
        .store(in: &disposables)
    }

    // MARK: - Actions
    func startScan() {
        scanner.start()
    }
    
    func stopScan() {
        scanner.stop()
        disposables.removeAll()
    }
    
    private func connect(peripheral: Peripheral, completion: @escaping ((Result<FileTransferClient, Error>) -> Void)) {
        var fileTransferPeripheral: FileTransferPeripheral?
        switch peripheral {
        case let wifiPeripheral as WifiPeripheral:
            fileTransferPeripheral = WifiFileTransferPeripheral(
                wifiPeripheral: wifiPeripheral,
                onGetPasswordForHostName: onWifiPeripheralGetPasswordForHostName
            )
            
        case let blePeripheral as BlePeripheral:
            fileTransferPeripheral = BleFileTransferPeripheral(
                blePeripheral: blePeripheral,
                onBonded: onBlePeripheralBonded
            )
            
        default:
            fileTransferPeripheral = nil
        }
        
        guard let fileTransferPeripheral = fileTransferPeripheral else {
            completion(.failure(ConnectionError.undefinedPeripheralType))
            return
        }
     
        // Connect
        connect(fileTransferPeripheral: fileTransferPeripheral, completion: completion)
    }
    

    func setSelectedPeripheral(peripheral: Peripheral) {
        if let fileTransferClient = fileTransferClients[peripheral.address] {
            userSelectedTransferClient = fileTransferClient
            updateSelectedPeripheral()
        }
        else {
            connect(peripheral: peripheral) { [weak self] result in
                guard let self = self else { return }
                
                let fileTransferClient = try? result.get()
                
                self.userSelectedTransferClient = fileTransferClient
                self.updateSelectedPeripheral()
            }
        }
    }
    
    func reconnectToBondedBlePeripherals(knownUuids identifiers: [UUID], timeout: TimeInterval? = nil) {
        let knownPeripherals = bleManager.retrievePeripherals(withIdentifiers: identifiers)
        
        guard !knownPeripherals.isEmpty else { DLog("knownPeripherals isEmpty"); return }
        isReconnectingToBondedPeripherals = true

        reconnectToBondedPeripherals(knownPeripherals: knownPeripherals, timeout: Self.kReconnectTimeout) { [weak self] readyBleFileTransferClients in
            guard let self = self else { return }
            self.isReconnectingToBondedPeripherals = false
            
            if let firstConnectedBleFileTransferClient = readyBleFileTransferClients.first {
                DLog("Reconnected to \(firstConnectedBleFileTransferClient.peripheral.nameOrAddress)")
                
                self.setSelectedPeripheral(peripheral: firstConnectedBleFileTransferClient.peripheral)
            }
            else {      // Is empty
                DLog("Cannot connect to bonded peripheral")
                self.lastReconnectionError = ConnectionError.cannotConnectToBondedPeripheral
            }
        }
    }
    
    /*
    func reconnectToAlreadyConnectedPeripherals(withServices services: [CBUUID], timeout: TimeInterval?, completion: @escaping (_ connectedBlePeripherals: [BleFileTransferPeripheral]) -> Void) {
        var connectedAndSetupPeripherals = [BleFileTransferPeripheral]()

        let peripheralsWithServices = bleManager.retrieveConnectedPeripherals(withServices: services)
        guard !peripheralsWithServices.isEmpty else { completion(connectedAndSetupPeripherals); return }
    
        // TODO
        
    }*/
    
    private func reconnectToBondedPeripherals(knownPeripherals: [CBPeripheral], timeout: TimeInterval? = nil, completion: @escaping (_ connectedBlePeripherals: [FileTransferClient]) -> Void) {

        var connectedAndSetupPeripherals = [FileTransferClient]()

        let knownUuids = knownPeripherals.map{$0.identifier}
        var awaitingConnection = knownUuids
        
        func connectionFinished(knownPeripheral: CBPeripheral) {
            awaitingConnection.removeAll { $0 == knownPeripheral.identifier }
            
            // Call completion when all awaiting peripherals have finished reconnection
            if awaitingConnection.isEmpty {
                completion(connectedAndSetupPeripherals)
            }
        }
        
        for knownPeripheral in knownPeripherals {
            DLog("Try to connect to known peripheral: \(knownPeripheral.identifier)")
            
            if knownPeripheral.state == .connected, let fileTransferClient = fileTransferClient(address: knownPeripheral.identifier.uuidString) {
                
                connectedAndSetupPeripherals.append(fileTransferClient)
                connectionFinished(knownPeripheral: knownPeripheral)
                
                setSelectedPeripheral(peripheral: fileTransferClient.peripheral)
                
            }
            else if knownPeripheral.state == .connected || knownPeripheral.state == .disconnected {
                
                let blePeripheral = BlePeripheral(peripheral: knownPeripheral, bleManager: bleManager, advertisementData: nil, rssi: nil)
                
                let bleFileTransferPeripheral = BleFileTransferPeripheral(
                    blePeripheral: blePeripheral,
                    onBonded: onBlePeripheralBonded
                )

                connect(fileTransferPeripheral: bleFileTransferPeripheral, connectionTimeout: timeout) { result in
                    switch result {
                    case .success(let fileTransferClient):
                        connectedAndSetupPeripherals.append(fileTransferClient)
                        
                    case .failure:
                        break
                    }
                    
                    connectionFinished(knownPeripheral: knownPeripheral)
                }
            }
            else {
                DLog("warning: trying to connect to a peripheral that is transient state: \(knownPeripheral.name ?? knownPeripheral.identifier.uuidString)")
                
                connectionFinished(knownPeripheral: knownPeripheral)
            }
        }
    }

    func connect(
        fileTransferPeripheral: FileTransferPeripheral,
        connectionTimeout: TimeInterval? = nil,
        completion: @escaping ((Result<FileTransferClient, Error>) -> Void)
    ) {
        peripheralAddressesBeingSetup.insert(fileTransferPeripheral.peripheral.address)
        
        fileTransferPeripheral.connectAndSetup(connectionTimeout: connectionTimeout) { [weak self] result in
            guard let self = self else { return }
            
            DLog("FileTransferClient connect success: \(result.isSuccess)")
            
            DispatchQueue.main.async {
                self.peripheralAddressesBeingSetup.remove(fileTransferPeripheral.peripheral.address)
                switch result {
                case .success:
                    let fileTransferClient = FileTransferClient(fileTransferPeripheral: fileTransferPeripheral)
                    self.fileTransferClients[fileTransferPeripheral.peripheral.address] = fileTransferClient
                    
                    self.updateSelectedPeripheral()
                    
                    // If is a Bluetooth Peripheral, add it to managed connections
                    if let bleFileTransferPeripheral = fileTransferPeripheral as? BleFileTransferPeripheral {
                        self.addPeripheralToAutomaticallyManagedBleConnection(fileTransferPeripheral: bleFileTransferPeripheral)
                    }
                    
                    completion(.success(fileTransferClient))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func disconnectFileTransferClient(address: String) {
        // Remove from managed connections
       // removePeripheralFromAutomaticallyManagedConnection(address: address)
        self.isDisconnectingPeripheral[address] = true
        
        // If is the user selected peripheral, set the new user selected to nil
        if let existingFileTransferClient = fileTransferClient(address: address), userSelectedTransferClient?.peripheral.address == existingFileTransferClient.peripheral.address {
            userSelectedTransferClient = nil
        }
        
        // Disconnect if exists
        fileTransferClients[address]?.peripheral.disconnect()
        
        // Update
        updateSelectedPeripheral()
    }

    func updateWifiPeripheralPassword(address: String, newPassword: String) -> Bool {
        let wifiFileTransferPeripheral = fileTransferClients[address]?.fileTransferPeripheral as? WifiFileTransferPeripheral
        if wifiFileTransferPeripheral != nil {
            wifiFileTransferPeripheral!.password = newPassword
            return true         // Successfully changed
        }
        else {
            return false        // The peripheral is not in connectionManager
        }
    }
    
    
    // MARK: - Get state
    func fileTransferClient(address: String) -> FileTransferClient? {
        return fileTransferClients[address]
    }
    
    /*
        Receives an array of SavedBondedBlePeripherals.PeripheralData and returns the same array but adding internal peripheral info [BondedPeripheralData]
        Useful for UI
     */
    func bondedBlePeripheralDataWithState(peripheralsData: [SavedBondedBlePeripherals.PeripheralData]) -> [BondedPeripheralData] {
        
        return peripheralsData.map {
            let state = (fileTransferClient(address: $0.uuid.uuidString)?.peripheral as? BlePeripheral)?.state.value
            
            return BondedPeripheralData(
                name: $0.name,
                uuid: $0.uuid,
                state: state
            )
        }
    }
    
    // MARK: - Internal
    private func updateSelectedPeripheral() {
        // Update selectedFileTransferClient
        let fileTransferClient = userSelectedTransferClient ?? fileTransferClients.values.first
        
        if fileTransferClient?.peripheral.address != currentFileTransferClient?.peripheral.address {
            currentFileTransferClient = fileTransferClient
            DLog("selectedPeripheral: \(currentFileTransferClient?.peripheral.nameOrAddress ?? "-")")
        }
    }
    
    // MARK: - Managed Peripherals
    private func addPeripheralToAutomaticallyManagedBleConnection(fileTransferPeripheral: BleFileTransferPeripheral) {
        // Check that doesn't already exists
        guard !managedBlePeripherals.contains(where: { $0.0.address == fileTransferPeripheral.address }) else {
            DLog("trying to add an already managed peripheral: \(fileTransferPeripheral.nameOrAddress)")
            return
        }
        
        let cancellable = fileTransferPeripheral.fileTransferState
            .sink(receiveCompletion: { completion in
                DLog("File transfer state error. Force disconnect")
                fileTransferPeripheral.peripheral.disconnect()
                self.removePeripheralFromAutomaticallyManagedConnection(bleFileTransferPeripheral: fileTransferPeripheral)
            }, receiveValue: { [weak self] fileTransferState in
                guard let self = self else { return }
                
                switch fileTransferState {
                case .connected:
                    DLog("peripheral connencted")
                    
                case .disconnected:
                    if self.isDisconnectingPeripheral[fileTransferPeripheral.address] == true {
                        DLog("peripheral disconnected \(fileTransferPeripheral.address)")
                        
                        self.removePeripheralFromAutomaticallyManagedConnection(address: fileTransferPeripheral.address)
                        self.fileTransferClients.removeValue(forKey: fileTransferPeripheral.address)     // Remove info from disconnected peripheral
                        self.updateSelectedPeripheral()
                    }
                    else if self.isReconnectingPeripheral[fileTransferPeripheral.address] == true {
                        DLog("recover failed for \(fileTransferPeripheral.address)")
                        self.setReconnectionFailed(address: fileTransferPeripheral.address)

                        self.removePeripheralFromAutomaticallyManagedConnection(address: fileTransferPeripheral.address)
                        self.fileTransferClients.removeValue(forKey: fileTransferPeripheral.address)     // Remove info from disconnected peripheral
                        
                        self.updateSelectedPeripheral()
                    }

                    // If it was the selected peripheral -> try to recover the connection because a peripheral can be disconnected momentarily when writing to the filesystem.
                    else if self.currentFileTransferClient?.peripheral.address == fileTransferPeripheral.address {
                        if let selectedFileTransferClient = self.currentFileTransferClient {
                            self.userSelectedTransferClient = nil
                            
                            // Wait for recovery before connecting to a different one
                            DLog("Try to recover disconnected peripheral: \(selectedFileTransferClient.peripheral.nameOrAddress)")
                                                    
                            self.isReconnectingToBondedPeripherals = true
                            
                            // Reconnect
                            self.isReconnectingPeripheral[fileTransferPeripheral.address] = true
                                                        
                            fileTransferPeripheral.connectAndSetup(connectionTimeout: Self.kReconnectTimeout) { [weak self] result in
                                guard let self = self else { return }
                                
                                DispatchQueue.main.async {
                                    self.isReconnectingPeripheral[fileTransferPeripheral.address] = false
                                    self.isReconnectingToBondedPeripherals = false
                                                                        
                                    switch result {
                                    case .success:
                                        break
      
                                    case .failure:
                                        DLog("recover failed. Auto-select another peripheral")
                                        self.removePeripheralFromAutomaticallyManagedConnection(address: fileTransferPeripheral.address)
                                        self.fileTransferClients.removeValue(forKey: fileTransferPeripheral.address)
                                        self.updateSelectedPeripheral()
                                    }
                                }
                            }
                        }
                    }
                
                case .error(_):
                    self.setReconnectionFailed(address: fileTransferPeripheral.address)
                    
                default:
                    break
                }
            })
               
        managedBlePeripherals.append((fileTransferPeripheral, cancellable))
    }
    
    private func setReconnectionFailed(address: String) {
        // If it the selectedPeripheral, then the reconnection failed
        if currentFileTransferClient?.peripheral.address == address {
            isReconnectingToBondedPeripherals = false
        }
        fileTransferClients.removeValue(forKey: address)     // Remove info from disconnected peripheral
    }
    
    func clean() {
        managedBlePeripherals.removeAll()
    }
    
    private func removePeripheralFromAutomaticallyManagedConnection(address: String) {
        managedBlePeripherals.removeAll { (fileTransferPeripheral, _) in
            fileTransferPeripheral.address == address
        }
    }
    
    private func removePeripheralFromAutomaticallyManagedConnection(bleFileTransferPeripheral: BleFileTransferPeripheral) {
        managedBlePeripherals.removeAll { (fileTransferPeripheral, _) in
            fileTransferPeripheral.address == bleFileTransferPeripheral.address
        }
    }
}
