//
//  PeripheralsView.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import SwiftUI

struct PeripheralsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @EnvironmentObject private var savedBondedBlePeripherals: SavedBondedBlePeripherals
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var model: PeripheralsViewModel
    @State private var isVisible = false
         
    init(connectionManager: ConnectionManager, savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals) {
        // Inject viewmodel parameters
        _model = StateObject(wrappedValue: PeripheralsViewModel(connectionManager: connectionManager, savedSettingsWifiPeripherals: savedSettingsWifiPeripherals))
    }
    
    var body: some View {
        let scannedPeripherals = connectionManager.peripherals
        let bondedBlePeripheralsData = savedBondedBlePeripherals.peripheralsData
        let bondedBlePeripheralsDataWithState = connectionManager.bondedBlePeripheralDataWithState(peripheralsData: bondedBlePeripheralsData)
        let selectedPeripheral = connectionManager.currentFileTransferClient?.peripheral
        let peripheralAddressesBeingSetup = model.peripheralAddressesBeingSetup
        
        PeripheralsBody(
            scannedPeripherals: scannedPeripherals,
            bondedBlePeripheralsData: bondedBlePeripheralsDataWithState,
            selectedPeripheral: selectedPeripheral,
            peripheralAddressesBeingSetup: peripheralAddressesBeingSetup,
            onSelectPeripheral: { peripheral in
                connectionManager.setSelectedPeripheral(peripheral: peripheral)
            },
            onDisconnectPeripheral: { address in
                connectionManager.disconnectFileTransferClient(address: address)
            },
            onSelectBondedPeripheral: { uuid in
                connectionManager.reconnectToBondedBlePeripherals(knownUuids: [uuid], completion: nil)
            },
            onDeleteBondedPeripheral: { address in
                connectionManager.disconnectFileTransferClient(address: address)
                if let uuid = UUID(uuidString: address) {
                    savedBondedBlePeripherals.remove(uuid: uuid)
                }
                else {
                    DLog("Error: invalid uuid address: \(address)")
                }
            },
            wifiDialogSettings: model.wifiDialogSettings,
            onOpenWifiDialogSettings: { wifiPeripheral in
                model.openWifiDialogSettings(wifiPeripheral: wifiPeripheral)
            },
            onWifiPeripheralPasswordChanged: { wifiPeripheral, newPassword in
                if let newPassword = newPassword {
                    model.updateWifiPeripheralPassword(wifiPeripheral: wifiPeripheral, newPassword: newPassword)
                }
                model.closeWifiDialogSettings()
            },
            onCloseWifiPeripheralsSettings: {
                model.closeWifiDialogSettings()
            },
            activeAlert: $model.activeAlert
        )
        .onAppear {
            isVisible = true
            model.onAppear()
        }
        .onDisappear {
            model.onDissapear()
            isVisible = false
        }
        // Stop/Start when the app is inactive/active
        .onChange(of: scenePhase) { scenePhase in
            switch scenePhase {
            case .background:
                if isVisible {
                    model.onDissapear()
                }
            case .inactive:
                if isVisible {
                    model.onDissapear()
                }
            case .active:
                if isVisible {
                    model.onAppear()
                }
            @unknown default:
                break
            }
        }
    }
}

private struct PeripheralsBody: View {
    let scannedPeripherals: [Peripheral]
    let bondedBlePeripheralsData: [ConnectionManager.BondedPeripheralData]
    let selectedPeripheral: Peripheral?
    let peripheralAddressesBeingSetup: Set<String>
    var onSelectPeripheral: ((Peripheral)->Void)? = nil
    var onDisconnectPeripheral: ((String)->Void)? = nil
    var onSelectBondedPeripheral: ((UUID) -> Void)? = nil
    var onDeleteBondedPeripheral: ((String) -> Void)? = nil
    var wifiDialogSettings: (String, String)? = nil
    var onOpenWifiDialogSettings: ((WifiPeripheral) -> Void)? = nil
    var onWifiPeripheralPasswordChanged: ((_ wifiPeripheral: WifiPeripheral, _ newPassword: String?) -> Void)? = nil
    var onCloseWifiPeripheralsSettings: ()->Void
    @Binding var activeAlert: PeripheralsViewModel.ActiveAlert?
    
    private var isWifiDialogSettingsActive: Binding<Bool> { Binding (
        get: { wifiDialogSettings != nil },
        set: { if !$0 { onCloseWifiPeripheralsSettings() } }
    )}
    
    var body: some View {
        
        let address = wifiDialogSettings?.0
        let currentPassword = wifiDialogSettings?.1
        let peripheralForWifiSettings = scannedPeripherals
            .compactMap{ $0 as? WifiPeripheral }
            .first{ $0.address == address }
        
        NavigationView {
            
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    Text("Select peripheral".uppercased())
                        .font(.headline)
                        .padding(.top, 20)
                    //.padding(.bottom, 20)
                    
                    PeripheralsListByType(
                        peripherals: scannedPeripherals,
                        bondedPeripherals: bondedBlePeripheralsData,
                        selectedPeripheral: selectedPeripheral,
                        peripheralAddressesBeingSetup: peripheralAddressesBeingSetup,
                        onSelectPeripheral: onSelectPeripheral,
                        onSelectBondedPeripheral: onSelectBondedPeripheral,
                        onBondedBleStateAction: { (address, state) in
                            if state == .disconnect {
                                self.activeAlert = .disconnect(address: address)
                            }
                            else {
                                self.activeAlert = .deleteBondingInformation(address: address)
                            }
                        },
                        onOpenWifiDialogSettings: onOpenWifiDialogSettings
                    )
                }
                .padding()
                
            }
            
            .limitWidthOnRegularSizeClass()
            .foregroundColor(Color.white)
            .padding(.bottom)
            .defaultGradientBackground()
            .navigationBarTitle("Scanning...", displayMode: .inline)
            /*
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)*/
            .alert(isPresented: isWifiDialogSettingsActive, TextFieldAlert(title: "Settings", message: "Password:", defaultText: currentPassword ?? "", accept: "Set") { inputText in
                if let peripheralForWifiSettings = peripheralForWifiSettings {
                    onWifiPeripheralPasswordChanged?(peripheralForWifiSettings, inputText)
                }
                else {
                    DLog("Error: peripheralForWifiSettings is nil")
                }
            })
            .modifier(Alerts(
                activeAlert: $activeAlert,
                onDeleteBondedPeripheral: onDeleteBondedPeripheral,
                onDisconnectPeripheral: onDisconnectPeripheral)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private struct Alerts: ViewModifier {
        @Binding var activeAlert: PeripheralsViewModel.ActiveAlert?
        var onDeleteBondedPeripheral: ((String) -> Void)? = nil
        var onDisconnectPeripheral: ((String) -> Void)? = nil
        
        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .networkError(let error):
                        return Alert(
                            title: Text("Network Error"),
                            message: Text("\(error.localizedDescription)"))//,
                            //dismissButton: .cancel())
                        
                    case .bleBondedReconnectionError(let error):
                        return Alert(
                            title: Text("Bonded Peripheral Connection Error"),
                            message: Text("\(error.localizedDescription)"))
    
                    case .bleScanningError(let error):
                        return Alert(
                            title: Text("Bluetooth Scanning Error"),
                            message: Text("\(error.localizedDescription)"))
                        
                    case .wifiDiscoveryError(let error):
                        return Alert(
                            title: Text("Wifi Discovery Error"),
                            message: Text("\(error.localizedDescription)"))
                        
                    case .disconnect(let address):
                        return Alert(
                            title: Text("Disconnect"),
                            message: Text("Do you want to disconnect from this peripheral?"),
                            primaryButton: .destructive(Text("Disconnect")) {
                                onDisconnectPeripheral?(address)
                            },
                            secondaryButton: .cancel())
                        
                    case .deleteBondingInformation(let address):
                        return Alert(
                            title: Text("Delete bonding information"),
                            message: Text("Warning: You will not be able to connect to this peripheral until you reset the bonding information on the peripheral too."),
                            primaryButton: .destructive(Text("Delete")) {
                                onDeleteBondedPeripheral?(address)
                            },
                            secondaryButton: .cancel())
                    }

                })
        }
    }
}

private struct PeripheralsListByType: View {
    let peripherals: [Peripheral]
    let bondedPeripherals: [ConnectionManager.BondedPeripheralData]
    let selectedPeripheral: Peripheral?
    let peripheralAddressesBeingSetup: Set<String>
    let onSelectPeripheral: ((Peripheral)->Void)?
    let onSelectBondedPeripheral: ((UUID) -> Void)?
    let onBondedBleStateAction: (String, PeripheralButtonState)-> Void
    let onOpenWifiDialogSettings: ((WifiPeripheral) -> Void)?

    var body: some View {
        if peripherals.isEmpty, bondedPeripherals.isEmpty {
            Text("No peripherals found".uppercased())
                .padding(.top, 20)
                .foregroundColor(.gray)
        }
        else {
            // Wifi peripherals
            let wifiPeripherals: [WifiPeripheral] = peripherals.compactMap{$0 as? WifiPeripheral}
            if !wifiPeripherals.isEmpty {
                
                VStack(spacing: 12) {
                    Text("Wifi".uppercased())
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 16) {
                        WifiPeripheralsList(
                            wifiPeripherals: wifiPeripherals,
                            selectedPeripheral: selectedPeripheral,
                            peripheralAddressesBeingSetup: peripheralAddressesBeingSetup,
                            onSelectedPeripheral: { address in
                                if let peripheral = wifiPeripherals.first(where: { $0.address == address }) {
                                    onSelectPeripheral?(peripheral)
                                }
                            },
                            onStateAction: { address in
                                if let peripheral = wifiPeripherals.first(where: { $0.address == address }) {
                                    onOpenWifiDialogSettings?(peripheral)
                                }
                            }
                        )
                    }
                    
                }
            }
            
            // Bluetooth advertising peripherals
            let bondedUuids = bondedPeripherals.map { $0.uuid }
            let blePeripherals: [BlePeripheral] = peripherals
                .compactMap{$0 as? BlePeripheral}
                .filter { !bondedUuids.contains($0.identifier)      // Don't show bonded
            }
            if !blePeripherals.isEmpty {
                
                VStack(spacing: 12) {
                    Text("Bluetooth Discovered".uppercased())
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 16) {
                        BlePeripheralsList(
                            blePeripherals: blePeripherals,
                            selectedPeripheral: selectedPeripheral,
                            peripheralAddressesBeingSetup: peripheralAddressesBeingSetup,
                            onSelectedPeripheral: { address in
                                if let peripheral = blePeripherals.first(where: { $0.address == address }) {
                                    onSelectPeripheral?(peripheral)
                                }
                            }
                        )
                    }
                }
            }

            // Bluetooth bonded peripherals
            /*
            let notAdvertisingBondedPeripherals = bondedPeripherals
                .filter { peripheralData in
                    blePeripherals.first{$0.identifier == peripheralData.uuid } == nil
                }
            if !notAdvertisingBondedPeripherals.isEmpty {*/
            if !bondedPeripherals.isEmpty {
                VStack(spacing: 12) {
                    Text("Bluetooth Bonded".uppercased())
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 16) {
                        BondedBlePeripheralsList(
                            bondedBlePeripherals: bondedPeripherals,
                            selectedPeripheral: selectedPeripheral,
                            peripheralAddressesBeingSetup: peripheralAddressesBeingSetup,
                            onSelectPeripheral: onSelectBondedPeripheral,
                            onStateAction: onBondedBleStateAction
                        )
                    }
                }
            }
        }
    }
}

private struct BlePeripheralsList: View {
    let blePeripherals: [BlePeripheral]
    let selectedPeripheral: Peripheral?
    let peripheralAddressesBeingSetup: Set<String>
    let onSelectedPeripheral: ((String)->Void)

    var body: some View {
        ForEach(blePeripherals, id: \.address) { peripheral in
            let address = peripheral.address
            let isSelected = selectedPeripheral?.address == address
            let name = peripheral.nameOrAddress
            let isOperationInProgress = peripheralAddressesBeingSetup.contains(address)
            let state: PeripheralButtonState = isOperationInProgress ? .wait : .standard
            
            PeripheralButton(
                name: name,
                details: nil,
                address: address,
                isSelected: isSelected,
                state: state,
                onSelectedPeripheral: onSelectedPeripheral,
                onStateAction: nil
            )
        }
    }
}

private struct BondedBlePeripheralsList: View {
    let bondedBlePeripherals: [ConnectionManager.BondedPeripheralData]
    let selectedPeripheral: Peripheral?
    let peripheralAddressesBeingSetup: Set<String>
    let onSelectPeripheral: ((UUID)->Void)?
    let onStateAction: (String, PeripheralButtonState)-> Void

    var body: some View {
        ForEach(bondedBlePeripherals, id: \.uuid) { data in
            let address = data.uuid.uuidString
            let isSelected = selectedPeripheral?.address == address
            let name = data.name ?? data.uuid.uuidString

            let isOperationInProgress = peripheralAddressesBeingSetup.contains(address)
            let state: PeripheralButtonState = isOperationInProgress ? .wait : data.state == .connected ? .disconnect : .delete
            
            PeripheralButton(
                name: name,
                details: nil,
                address: address,
                isSelected: isSelected,
                state: state,
                onSelectedPeripheral: { _ in
                    onSelectPeripheral?(data.uuid)
                },
                onStateAction: { address in
                    onStateAction(address, state)
                }
            )
        }
    }
}

private struct WifiPeripheralsList: View {
    let wifiPeripherals: [WifiPeripheral]
    let selectedPeripheral: Peripheral?
    let peripheralAddressesBeingSetup: Set<String>
    let onSelectedPeripheral: ((String)->Void)
    let onStateAction: ((String)->Void)

    var body: some View {
        ForEach(wifiPeripherals, id: \.address) { peripheral in
            let address = peripheral.address
            let isSelected = selectedPeripheral?.address == address
            let name = peripheral.nameOrAddress
            let isOperationInProgress = peripheralAddressesBeingSetup.contains(address)
            let state: PeripheralButtonState = isOperationInProgress ? .wait : .settings
            
            PeripheralButton(name: name, details: "Address: \(address)", address: address, isSelected: isSelected, state: state, onSelectedPeripheral: onSelectedPeripheral, onStateAction: onStateAction)
        }
    }
}

private enum PeripheralButtonState {
    case standard
    case wait
    case disconnect
    case delete
    case settings
}

private struct PeripheralButton: View {
    let name: String
    let details: String?
    let address: String
    let isSelected: Bool
    let state: PeripheralButtonState
    let onSelectedPeripheral: ((String)->Void)
    let onStateAction: ((String)->Void)?

    var body: some View {
        let mainColor = Color.white.opacity(0.7)
        let buttonHeight: CGFloat = 44
        

        HStack(spacing: 8) {
            Button(action: {
                if !isSelected {
                    onSelectedPeripheral(address)
                }
                
            }, label: {
                PeripheralName(name: name, details: details, isSelected: isSelected, state: state)
            })
            .buttonStyle(PrimaryButtonStyle(height: buttonHeight, foregroundColor: mainColor, isSelected: isSelected))
            
            
            // State button
            if state == .delete || state == .settings || state == .disconnect {
                Button(action: {
                    onStateAction?(address)
                }, label: {
                    Image(systemName: state == .disconnect ? "eject" : (state == .delete ? "trash" : "gearshape"))
                        .font(.headline)
                        .padding(.horizontal, 6)
                })
                .buttonStyle(PrimaryButtonStyle(height: buttonHeight, foregroundColor: mainColor))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private struct PeripheralName: View {
        let name: String
        let details: String?
        let isSelected: Bool
        let state: PeripheralButtonState

        var body: some View {
            HStack() {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: name)
                        .font(.callout)
                        .if(isSelected) { $0.bold() }
                    
                    if let details = details {
                        Text(verbatim: details)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

                if state == .wait {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                }
            }
            
        }
    }
}

// MARK: - Previews
struct PeripheralsView_Previews: PreviewProvider {
    static var previews: some View {

        let peripheral = WifiPeripheral(name: "Adafruit Feather ESP32-S2 TFT", address: "127.0.0.1", port: 80)
        let peripheral2 = WifiPeripheral(name: "Adafruit Test Device", address: "127.0.0.2", port: 80)
        let peripherals = [peripheral, peripheral2]
        
        TabView {
            PeripheralsBody(
                scannedPeripherals: peripherals,
                bondedBlePeripheralsData: [],
                selectedPeripheral: nil,
                peripheralAddressesBeingSetup: [],
                onSelectPeripheral: {_ in },
                onCloseWifiPeripheralsSettings: {},
                activeAlert: .constant(nil))
            .tabItem {
                Label("Peripherals", systemImage: "link")
            }
        }
    }
}
