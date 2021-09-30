//
//  RootView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI
import FileTransferClient

struct RootView: View {
    static let debugForceDestination = AppEnvironment.isDebug && false ? RootViewModel.Destination.debug : nil
    @StateObject private var model = RootViewModel()
    @ObservedObject private var connectionManager = FileClientPeripheralConnectionManager.shared
    
    let didUpdateBleStatePublisher = NotificationCenter.default.publisher(for: .didUpdateBleState)
    
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
        .onChange(of: connectionManager.isConnectedOrReconnecting) { isConnectedOrReconnecting in
            //DLog("isConnectedOrReconnecting: \(isConnectedOrReconnecting)")
            
            if !isConnectedOrReconnecting, model.destination == .connected {
                model.destination = .scan
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DLog("App moving to the foreground. Force reconnect")
            FileClientPeripheralConnectionManager.shared.reconnect()
        }
        .environmentObject(model)
        .environmentObject(connectionManager)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

