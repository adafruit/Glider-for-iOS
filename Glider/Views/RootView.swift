//
//  RootView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

struct RootView: View {
    static let debugForceDestination = AppEnvironment.isDebug && false ? RootViewModel.Destination.debug : nil

    @StateObject private var model = RootViewModel()
    
    let didUpdateBleStatePublisher = NotificationCenter.default.publisher(for: .didUpdateBleState)
    let didDisconnectFromPeripheralPublisher = NotificationCenter.default.publisher(for: .didDisconnectFromPeripheral)

    var body: some View {
        Group {
            switch Self.debugForceDestination ?? model.destination {
            case .startup:
                StartupView()
            case .scan:
                ScanView()
            case .bluetoothStatus:
                BluetoothStatusView()
            case .connected:
                ConnectedTabView()
            case .debug:
                ScanView()
            default:
                TodoView()
            }
        }
        .onReceive(didUpdateBleStatePublisher) { notification in
            model.showWarningIfBluetoothStateIsNotReady()
        }
        .onReceive(didDisconnectFromPeripheralPublisher) { notification in
            if model.destination == .connected {
                model.destination = .scan
            }
        }
        .environmentObject(model)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

