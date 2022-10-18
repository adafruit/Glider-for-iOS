//
//  Scanner.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation
import Combine

class Scanner: ObservableObject {
    private let blePeripheralScanner: any BlePeripheralScanner
    private let wifiPeripheralScanner: any BonjourScanner
 
    private var scannedWifiPeripherals = [WifiPeripheral]()
    private var scannedBlePeripherals = [BlePeripheral]()
    private var disposables = Set<AnyCancellable>()
    
    enum ScanningState {
        case idle
        case scanning(peripherals: [Peripheral])
        case scanningError(error: Error)
        
        var isScanning: Bool {
            switch self {
            case .scanning: return true
            default: return false
            }
        }
    }
    
    @Published var scanningState: ScanningState = .idle
    
    init(blePeripheralScanner: any BlePeripheralScanner, wifiPeripheralScanner: any BonjourScanner) {
        self.blePeripheralScanner = blePeripheralScanner
        self.wifiPeripheralScanner = wifiPeripheralScanner
    }
    
    func start() {
        // Start Wifi Scan
        wifiPeripheralScanner.start()
        
        wifiPeripheralScanner.knownWifiPeripheralsPublisher
            //.receive(on: RunLoop.main)
            .sink { wifiPeripherals in
                self.scannedWifiPeripherals = wifiPeripherals.sorted(by: { $0.createdTime < $1.createdTime })
                self.updateScanningState()
            }
            .store(in: &disposables)

        
        // Start Bluetooth Scan
        blePeripheralScanner.start()
        
        blePeripheralScanner.blePeripheralsPublisher
            //.receive(on: RunLoop.main)
            .sink { blePeripherals in
                let filteredPeripherals = blePeripherals.sorted(by: { $0.createdTime < $1.createdTime })
                    .filter({$0.advertisement.isManufacturerAdafruit() && $0.advertisement.services?.contains(BleFileTransferPeripheral.kFileTransferServiceUUID) ?? false})
                
                self.scannedBlePeripherals = filteredPeripherals
                self.updateScanningState()
            }
            .store(in: &disposables)
        
        // TODO: map scanning errors to state
    }
    
    
    func stop() {
        blePeripheralScanner.stop()
        wifiPeripheralScanner.stop()
        disposables.removeAll()
    }
    
    private func updateScanningState() {
        let allPeripherals: [Peripheral] = scannedWifiPeripherals + scannedBlePeripherals
        scanningState = .scanning(peripherals: allPeripherals)
    }
}
