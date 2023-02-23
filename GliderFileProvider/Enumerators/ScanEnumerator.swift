//
//  ScanEnumerator.swift
//  Glider
//
//  Created by Antonio García on 21/1/23.
//

import FileProvider
import os.log

class ScanEnumerator: NSObject, NSFileProviderEnumerator {
    private static let kSecondsToWaitForScan: TimeInterval = 3.0
    
    private let logger = Logger.createLogger(category: "ScanEnumerator")
    private var metadataCache: FileMetadataCache
    private var lastUpdateDate = Date.distantPast
    
    private var model: PeripheralsViewModel
    
    private var connectionManager: ConnectionManager
    private var savedBondedBlePeripherals: SavedBondedBlePeripherals
    
    private var lastAnchor: NSFileProviderSyncAnchor {
        let data = lastUpdateDate.timeIntervalSince1970.data
        return NSFileProviderSyncAnchor(data)
    }
    
    private let modelAppearDate: Date
    
    init(metadataCache: FileMetadataCache, connectionManager: ConnectionManager, savedBondedBlePeripherals: SavedBondedBlePeripherals, savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals) {
        logger.info("init")
        
        self.metadataCache = metadataCache
        self.connectionManager = connectionManager
        self.savedBondedBlePeripherals = savedBondedBlePeripherals
        
        model = PeripheralsViewModel(connectionManager: connectionManager, savedSettingsWifiPeripherals: savedSettingsWifiPeripherals)
       
        model.onAppear()
        modelAppearDate = Date()
    }
    
    func invalidate() {
        logger.info("invalidate")
    }
   
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        logger.info("enumerateItems: \(observer.description) startingAt: \(page.rawValue)")
        
        let items = items()
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
        
        logger.info("enumerateItems: \(observer.description) finished. \(items.count) found")
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        /* TODO:
         - query the server for updates since the passed-in sync anchor
         
         If this is an enumerator for the active set:
         - note the changes in your local database
         
         - inform the observer about item deletions and updates (modifications + insertions)
         - inform the observer when you have finished enumerating up to a subsequent sync anchor
         */
        
        DLog("enumerateChanges for anchor: \(anchor.rawValue)")
        guard let data = TimeInterval(data: anchor.rawValue) else { return }
        let anchorDate = Date(timeIntervalSince1970: data)
        
        if anchorDate > lastUpdateDate {
            DLog("enumerateChanges needs update")

            observer.didUpdate([FileProviderItem(peripheralType: .rootContainer)])
        }
        
        DLog("enumerateChanges for anchor date: \(anchorDate)")
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        logger.info("currentSyncAnchor date: \(self.lastUpdateDate)")
        completionHandler(self.lastAnchor)
    }
    
    deinit {
        logger.info("deinit")
        model.onDissapear()
    }

    private func items() -> [FileProviderItem] {
        
        let secondsElapsedSinceInit = Date().timeIntervalSince(modelAppearDate)
        if secondsElapsedSinceInit < Self.kSecondsToWaitForScan {
            let remaining = Self.kSecondsToWaitForScan - secondsElapsedSinceInit
            sleep(UInt32(ceil(remaining)))
        }
        
        
        let peripherals = connectionManager.peripherals
        let bondedPeripherals = savedBondedBlePeripherals.peripheralsData
        //let peripheralAddressesBeingSetup = model.peripheralAddressesBeingSetup
        
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
        
        let bleItems = blePeripherals.map { blePeripheral in
            FileProviderItem(peripheralType: .ble(address: blePeripheral.address, name: blePeripheral.name))
        }
        
        let bondedItems = bondedPeripherals.map { bondedBlePeripheral in
            FileProviderItem(peripheralType:
                    .bleBondedData(address: bondedBlePeripheral.uuid.uuidString, name: bondedBlePeripheral.name))
        }
        
        let testItems: [FileProviderItem] = []
        /*
        if AppEnvironment.isDebug, false {
            let dateString = Date().formatted()
            testItems = [FileProviderItem(peripheralType: .wifi(address: dateString, name: "zzzTest \(dateString)"))]
        }*/
        
        let items = wifiItems + bleItems + bondedItems + testItems

        self.metadataCache.setDirectoryItems(items: items)
        self.lastUpdateDate = Date()
        
        return items
    }
    
}
