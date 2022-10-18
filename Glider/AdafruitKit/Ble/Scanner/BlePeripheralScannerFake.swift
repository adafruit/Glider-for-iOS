//
//  BlePeripheralScannerFake.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation

class BlePeripheralScannerFake: BlePeripheralScanner {
          
    @Published private(set) var blePeripherals = [BlePeripheral]()
    var blePeripheralsPublisher: Published<[BlePeripheral]>.Publisher { $blePeripherals }

    func start() {}
    func stop() {}
}
