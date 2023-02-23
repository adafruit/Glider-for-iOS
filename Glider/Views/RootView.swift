//
//  RootView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI
//import FileTransferClient

struct RootView: View {
    // Debug
    private static let debugForceDestination = AppEnvironment.isDebug && false ? RootViewModel.Destination.debug : nil
    
    // Params
    let appContainer: AppContainer
    
    //
    @StateObject private var model = RootViewModel()
    
    // Snackbar
    @State private var snackBarIsShowing = false
    @State private var snackBarTitle = "Test"
    @State private var snacBarBackgroundColor = Color.gray
    

    // MARK: - View
    var body: some View {
        // Main screen
        ZStack {
            switch Self.debugForceDestination ?? model.destination {
                /*
            case .startup:
                StartupView()
            case .scan:
                ScanView()*/
            //case .bluetoothStatus:
            //    BluetoothStatusView()
            case .connected:
                ConnectedTabView(
                    connectionManager: appContainer.connectionManager,
                    savedBondedBlePeripherals: appContainer.savedBondedBlePeripherals,
                    savedSettingsWifiPeripherals: appContainer.savedSettingsWifiPeripherals
                )
            case .debug:
                EmptyView()
            default:
                TodoView()
            }
            
            // SnackBar
            SnackBarView(
                isShowing: $snackBarIsShowing,
                title: snackBarTitle,
                backgroundColor: snacBarBackgroundColor)
            .padding(.bottom, 80)
            /*
                .onReceive(NotificationCenter.default.publisher(for: .didSelectPeripheralForFileTransfer)) { notification in
                    
                    if let peripheral = BleManager.shared.peripheral(from: notification) {
                        showSnackBar(title: "Connected to: \(peripheral.debugName)", backgroundColor: .gray)
                    }
                }
                .onChange(of: connectionManager.isSelectedPeripheralReconnecting) { isSelectedPeripheralReconnecting in
                    if isSelectedPeripheralReconnecting {
                        showSnackBar(title: "Reconnecting...", backgroundColor: .orange)
                    }
                }*/
        }
        /*
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateBleState)) { notification in
            if !Config.isSimulatingBluetooth {
                model.showWarningIfBluetoothStateIsNotReady()
            }
        }
        .onChange(of: connectionManager.isConnectedOrReconnecting) { isConnectedOrReconnecting in
            //DLog("isConnectedOrReconnecting: \(isConnectedOrReconnecting)")
            
            if !isConnectedOrReconnecting, model.destination == .connected {
                model.destination = .scan
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DLog("App moving to the foreground. Force reconnect")
            FileTransferConnectionManager.shared.reconnect()
        }*/
        .environmentObject(model)
        .environmentObject(appContainer.connectionManager)
    }
    
    // MARK: - SnackBar
    private func showSnackBar(title: String, backgroundColor: Color? = nil) {
        self.snackBarTitle = title
        self.snacBarBackgroundColor = backgroundColor ?? Color.gray
        
        let showHandler = {
            withAnimation {
                snackBarIsShowing = true
            }
        }
        
        if snackBarIsShowing {
            snackBarIsShowing = false
            DispatchQueue.main.async {
                showHandler()
            }
        }
        else {
            showHandler()
        }
    }
}

// MARK: - Previews
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let appContainer = AppContainerImpl.shared

        RootView(appContainer: appContainer)
    }
}

