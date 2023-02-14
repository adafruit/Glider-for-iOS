//
//  PeripheralsViewModel.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation
import Combine

class PeripheralsViewModel: ObservableObject {
    
    // Published
    @Published var wifiDialogSettings: (String, String)? = nil
    @Published var peripheralAddressesBeingSetup = Set<String>()    // Includes contents from both connectionManagerPeripheralAddressesBeingSetup and wifiPeripheralSettingsLoadingAddress
   
    enum ActiveAlert: Identifiable {
        case networkError(error: Error)
        case bleBondedReconnectionError(error: Error)
        case bleScanningError(error: Error)
        case wifiDiscoveryError(error: Error)
        case disconnect(address: String)
        case deleteBondingInformation(address: String)
        
        var id: Int {
            switch self {
            case .networkError: return 1
            case .bleBondedReconnectionError: return 2
            case .bleScanningError: return 3
            case .wifiDiscoveryError: return 4
            case .disconnect: return 5
            case .deleteBondingInformation: return 6
            }
        }
    }
    @Published var activeAlert: ActiveAlert? {
        // When an alert is diplayed, stop scanning to avoid refreshing the screen (it will make the alert button reappear constantly and the buttons will not be functional)
        didSet {
            if activeAlert == nil {
                self.startScan()
            }
            else {
                stopScan()
            }
        }
    }
    
    
    // Data
    private let connectionManager: ConnectionManager
    private let savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals
    private var disposables = Set<AnyCancellable>()
  
    private var connectionManagerPeripheralAddressesBeingSetup = Set<String>() {
        didSet {
            updatePeripheralAddressesBeingSetup()
        }
    }
    private var wifiPeripheralSettingsLoadingAddress: String? {
        didSet {
            updatePeripheralAddressesBeingSetup()
        }
    }
    
    
    init(connectionManager: ConnectionManager, /*savedBondedBlePeripherals: SavedBondedBlePeripherals,*/ savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals) {
        self.connectionManager = connectionManager
        self.savedSettingsWifiPeripherals = savedSettingsWifiPeripherals
        
        
        // This viewmodel add new operations, so intercept and include connectionManager.peripheralAddressesBeingSetup so the UI shows all the peripherals that have operations pending
        connectionManager.$peripheralAddressesBeingSetup
            .sink{ [weak self] peripherals in
                guard let self = self else { return }
                
                self.connectionManagerPeripheralAddressesBeingSetup = peripherals
            }
            .store(in: &disposables)
        
        
        // Intercept connectionManager.lastReconnectionError to show it as an alert
        connectionManager.$lastReconnectionError
            .receive(on: RunLoop.main)
            .compactMap{$0}     // discard nil values
            .sink {  lastReconnectionError in
                self.showAlert(.bleBondedReconnectionError(error: lastReconnectionError))
            }
            .store(in: &disposables)
        
        // Intercept connectionManager.bleScanningLastError to show it as an alert
        connectionManager.bleScanningLastErrorPublisher
            .receive(on: RunLoop.main)
            .compactMap{$0}     // discard nil values
            .sink { error in
                self.showAlert(.bleScanningError(error: error))
            }
            .store(in: &disposables)
        
        // Intercept connectionManager.bonjourLastErrorPublisher to show it as an alert
        connectionManager.bonjourLastErrorPublisher
            .receive(on: RunLoop.main)
            .compactMap{$0}      // discard nil values
            .sink { error in
                self.showAlert(.wifiDiscoveryError(error: error))
            }
            .store(in: &disposables)
    }
    
    private func showAlert(_ alert: ActiveAlert) {
        guard self.activeAlert == nil else {
            DLog("Connection error alert, but alert already being displayed. Skip...")
            return
        }
        self.activeAlert = alert
    }
    
    func onAppear() {
        startScan()
    }
    
    func onDissapear() {
        stopScan()
        disposables.removeAll()
    }
    
    private func startScan() {
        connectionManager.startScan()
    }
    
    private func stopScan() {
        connectionManager.stopScan()
    }
    
    
    private func updatePeripheralAddressesBeingSetup() {
        var allWaitingPeripherals = connectionManagerPeripheralAddressesBeingSetup
        if let wifiPeripheralSettingsLoadingAddress = self.wifiPeripheralSettingsLoadingAddress {
            allWaitingPeripherals.insert(wifiPeripheralSettingsLoadingAddress)
            
        }
        
        self.peripheralAddressesBeingSetup = allWaitingPeripherals
    }
    // MARK: - Actions
    func openWifiDialogSettings(wifiPeripheral: WifiPeripheral) {
        
        wifiPeripheralSettingsLoadingAddress = wifiPeripheral.address
        
        getWifiPeripheralCurrentPassword(wifiPeripheral: wifiPeripheral) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.wifiPeripheralSettingsLoadingAddress = nil
                
                switch result {
                case .success(let password):
                    if let password = password {
                        self.wifiDialogSettings = (wifiPeripheral.address, password)
                    }
                    else {
                        DLog("Warning: password is nil. Skip...")
                    }
                    
                case .failure(let error):
                    DLog("Error retrieving password: \(error)")
                    self.activeAlert = .networkError(error: error)
                }
            }
            
        }
    }
    
    func closeWifiDialogSettings() {
        wifiDialogSettings = nil
    }
    
    
    private func getWifiPeripheralCurrentPassword(wifiPeripheral: WifiPeripheral, completion: @escaping (Result<String?, Error>)->Void) {
        
        // Send request to get hostName
        let fileTransferPeripheral = WifiFileTransferPeripheral(wifiPeripheral: wifiPeripheral, onGetPasswordForHostName: nil)
        fileTransferPeripheral.getVersion() { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let version):
                // Get password
                let password = self.savedSettingsWifiPeripherals.getPassword(hostName: version.hostName) ?? WifiFileTransferPeripheral.defaultPassword
                completion(.success(password))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func updateWifiPeripheralPassword(wifiPeripheral: WifiPeripheral, newPassword: String) {
        // Send request to get hostName
        let fileTransferPeripheral = WifiFileTransferPeripheral(wifiPeripheral: wifiPeripheral, onGetPasswordForHostName: nil)
        fileTransferPeripheral.getVersion() { [weak self] result in
            guard let self = self else  { return }
            
            switch result {
            case .success(let version):
                // Save new password
                self.savedSettingsWifiPeripherals.add(name: version.boardName, hostName: version.hostName, password: newPassword)
                
                // Update password if the peripheral is already in connection manager
                let success = self.connectionManager.updateWifiPeripheralPassword(address: wifiPeripheral.address, newPassword: newPassword)
                if success {
                    DLog("Password update for connected wifi peripheral")
                }
                
            case .failure:
                DLog("Error retrieving hostName. Cannot update password")
            }
        }
    }
}
