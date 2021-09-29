//
//  RootViewModel.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import Foundation
import FileTransferClient

class RootViewModel: ObservableObject {
    
    // Published
    enum Destination {
        case startup
        case bluetoothStatus
        case scan
        case connected
        case debug
        case test
        case todo
    }
    
    @Published var destination: Destination = AppEnvironment.isRunningTests ? .test : .startup
    
    // MARK: - Actions
    func gotoMain() {
        // Check if we are reconnecting to a known Peripheral. If AppState.shared.fileTransferClient is not nil, no need to scan, just go to the connected screen
        if AppState.shared.fileTransferClient != nil {
            destination = .connected
        }
        else {
            destination = .scan
        }
    }
    
    func gotoStartup() {
        destination = .startup
    }
    
    func gotoConnected() {
        destination = .connected
    }
    
    func showWarningIfBluetoothStateIsNotReady() {
        let bluetoothState = BleManager.shared.state
        let shouldShowBluetoothDialog = bluetoothState == .poweredOff || bluetoothState == .unsupported || bluetoothState == .unauthorized
        
        if shouldShowBluetoothDialog {
            destination = .bluetoothStatus
        }
        else if destination == .bluetoothStatus {
            gotoStartup()
        }
    }
}
