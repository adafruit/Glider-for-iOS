//
//  BlePeripheralScanner.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation

protocol BlePeripheralScanner: ObservableObject {
    var blePeripherals: [BlePeripheral] { get }
    var blePeripheralsPublisher: Published<[BlePeripheral]>.Publisher { get }
    
    //var bleLastError: Error? { get }
    var bleLastErrorPublisher: Published<Error?>.Publisher { get }
    
    func start()
    func stop()
    
    func clearBleLastException()
}
