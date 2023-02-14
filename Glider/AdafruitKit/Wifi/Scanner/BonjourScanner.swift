//
//  BonjourScanner.swift
//  Glider
//
//  Created by Antonio García on 30/8/22.
//

import Foundation

protocol BonjourScanner: ObservableObject {
    var knownWifiPeripherals: [WifiPeripheral] { get }
    var knownWifiPeripheralsPublisher: Published<[WifiPeripheral]>.Publisher { get }
    
    var bonjourLastErrorPublisher: Published<Error?>.Publisher { get }
    
    func start()
    func stop()
    
    func clearBonjourLastException()
}
