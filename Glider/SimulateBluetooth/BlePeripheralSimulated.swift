//
//  BlePeripheralSimulated.swift
//  BluefruitPlayground
//
//  Created by Antonio García on 14/12/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth
import FileTransferClient

// Note: this is a fake replacement for BlePeripheral to make it work on the simulator which doesn't support bluetooth
// Important: dont add this file to the Glider target. Use it only for testing purposes
public class BlePeripheralSimulated: BlePeripheral {
    // Data
    private var simulatedIdentifier = UUID()
    override public var identifier: UUID {
        return simulatedIdentifier
    }

    override public var name: String? {
        return "CIRCUIT9999"
    }

    private var simulatedState: CBPeripheralState = .disconnected
    override public var state: CBPeripheralState {
        return simulatedState
    }

    init() {
        // Mocking CBPeripheral: https://forums.developer.apple.com/thread/29851
        guard let peripheral = ObjectBuilder.createInstance(ofClass: "CBPeripheral") as? CBPeripheral else {
            assertionFailure("Unable to mock CBPeripheral")
            let nilPeripheral: CBPeripheral! = nil          // Just to avoid a compiling error. This will never be executed
            super.init(peripheral: nilPeripheral, advertisementData: nil, rssi: nil)
            return
        }
        
        peripheral.addObserver(peripheral, forKeyPath: "delegate", options: .new, context: nil)

        super.init(peripheral: peripheral, advertisementData: nil, rssi: 20)
    }

    // MARK: - Connect
    func simulateConnect() {
        simulatedState = .connected
    }
}
