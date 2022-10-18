//
//  BonjourScannerFake.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation

class BonjourScannerFake: BonjourScanner {
          
    @Published private(set) var knownWifiPeripherals = [WifiPeripheral]()
    var knownWifiPeripheralsPublisher: Published<[WifiPeripheral]>.Publisher { $knownWifiPeripherals }

    func start() {}
    func stop() {}
}
