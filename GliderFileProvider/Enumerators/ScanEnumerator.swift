//
//  ScanEnumerator.swift
//  Glider
//
//  Created by Antonio García on 21/1/23.
//

import FileProvider
import os.log

class ScanEnumerator: NSObject, NSFileProviderEnumerator {
    private let logger = Logger.createLogger(category: "ScanEnumerator")
    private var lastUpdateDate: Date?
    private var model: PeripheralsViewModel
    
    private var connectionManager: ConnectionManager
    private var savedBondedBlePeripherals: SavedBondedBlePeripherals
    
    init(connectionManager: ConnectionManager, savedBondedBlePeripherals: SavedBondedBlePeripherals, savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals) {
        logger.info("init")
        
        self.connectionManager = connectionManager
        self.savedBondedBlePeripherals = savedBondedBlePeripherals

        
        model = PeripheralsViewModel(connectionManager: connectionManager, savedSettingsWifiPeripherals: savedSettingsWifiPeripherals)
       
        model.onAppear()
    }
   
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        logger.info("enumerateItems: \(observer.description) startingAt: \(page.rawValue)")
        
        
        let peripherals = connectionManager.peripherals
        let bondedPeripherals = savedBondedBlePeripherals.peripheralsData
        let peripheralAddressesBeingSetup = model.peripheralAddressesBeingSetup
        
        
        let wifiPeripherals: [WifiPeripheral] = peripherals.compactMap{$0 as? WifiPeripheral}         // Wifi peripherals
        
        
        let bondedUuids = bondedPeripherals.map { $0.uuid }     // Bluetooth bonded peripherals
        let blePeripherals: [BlePeripheral] = peripherals       // Bluetooth advertising peripherals
            .compactMap{$0 as? BlePeripheral}
            .filter { !bondedUuids.contains($0.identifier)      // Don't show bonded
            }
        
           
        let wifiItems = wifiPeripherals.map { wifiPeripheral in
            FileProviderItem(peripheralType:
                    .wifi(address: wifiPeripheral.address, name: wifiPeripheral.name))
        }
        
        let items = wifiItems// + blePeripherals + bondedPeripherals
         
        //let items: [FileProviderItem] = []

        self.lastUpdateDate = Date()
        
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
        logger.info("enumerateItems: \(observer.description) finished. \(items.count) found")
    }
    
    func invalidate() {
        logger.info("invalidate")
    }
    
    deinit {
        logger.info("deinit")
        model.onDissapear()
    }

    
    
}
