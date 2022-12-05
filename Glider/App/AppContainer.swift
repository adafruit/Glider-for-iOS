//
//  AppContainer.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation

protocol AppContainer {
    var bleManager: any BleManager { get }
    var blePeripheralScanner: any BlePeripheralScanner { get }
    var wifiPeripheralScanner: any BonjourScanner { get }
    var connectionManager: ConnectionManager { get }
    var savedBondedBlePeripherals: SavedBondedBlePeripherals { get }
    var savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals { get }
    
    var userDefaults: UserDefaults { get set }      // Can be replaced if data saved needs to be shared
}

class AppContainerImpl: AppContainer {
    
    // Singleton
    public static let shared = AppContainerImpl()
    
    var bleManager: any BleManager
    var blePeripheralScanner: any BlePeripheralScanner
    var wifiPeripheralScanner: any BonjourScanner
    var connectionManager: ConnectionManager
    var savedBondedBlePeripherals: SavedBondedBlePeripherals
    var savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals
   
    var userDefaults: UserDefaults = UserDefaults(suiteName: Config.sharedUserDefaultsSuitName)! {
        didSet {
            savedBondedBlePeripherals.userDefaults = userDefaults
        }
    }
    
    init() {
        bleManager = BleManagerImpl()
        blePeripheralScanner = BlePeripheralScannerImpl(bleManager: bleManager)
        
        wifiPeripheralScanner = BonjourScannerImpl(serviceType: "_circuitpython._tcp", serviceDomain: "local.")
        
        savedSettingsWifiPeripherals = SavedSettingsWifiPeripherals()
        savedBondedBlePeripherals = SavedBondedBlePeripherals(userDefaults: userDefaults)
        
        connectionManager = ConnectionManager(
            bleManager: bleManager,
            blePeripheralScanner: blePeripheralScanner,
            wifiPeripheralScanner: wifiPeripheralScanner,
            onBlePeripheralBonded: {[unowned savedBondedBlePeripherals] (name, uuid) in
                // Bluetooth peripheral -> Save bluetooth address when bonded to be able to reconnect later
                savedBondedBlePeripherals.add(name: name, uuid: uuid)
            },
            onWifiPeripheralGetPasswordForHostName: { [unowned savedSettingsWifiPeripherals] _, hostName in
                
                // Wifi peripheral -> Get saved password
                return savedSettingsWifiPeripherals.getPassword(hostName: hostName)
            }
        )
    }
}
