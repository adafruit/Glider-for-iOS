//
//  PeripheralChooserView.swift
//  Glider
//
//  Created by Antonio García on 18/10/21.
//

import SwiftUI
import FileTransferClient

struct PeripheralChooserView: View {
    // Params
    @EnvironmentObject private var connectionManager: FileTransferConnectionManager
  
    // Data
    enum ActiveAlert: Identifiable {
        case confirmDisconnect(blePeripheral: BlePeripheral)
        
        var id: Int {
            switch self {
            case .confirmDisconnect: return 1
            }
        }
    }
    @State private var activeAlert: ActiveAlert?
    
    var body: some View {
        let connectedPeripherals = connectionManager.peripherals.filter{$0.state == .connected}
        
        List {
            Section(
                header:
                    HStack{
                        Spacer()
                        Text("Connected peripherals:")
                            .foregroundColor(.white)
                        Spacer()
                    },
                footer:
                    HStack {
                        Spacer()
                        Button(
                            action: {
                                FileTransferConnectionManager.shared.reconnect()
                            },
                            label: {
                                Label("Find paired peripherals", systemImage: "arrow.clockwise")
                            })
                            .buttonStyle(ListFooterButtonStyle())
                                                                
                    }) {
                        if connectedPeripherals.isEmpty {
                            Text("No peripherals found".uppercased())
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                        else {
                        let selectedPeripheral = FileTransferConnectionManager.shared.selectedPeripheral
                        ForEach(connectedPeripherals, id: \.identifier) { peripheral in
                            
                            HStack {
                                Button(action: {
                                    DLog("Select: \(peripheral.name ?? peripheral.identifier.uuidString)")
                                    FileTransferConnectionManager.shared.setSelectedClient(blePeripheral: peripheral)
                                }, label: {
                                    Text(verbatim: "\(peripheral.name ?? "<unknown>")")
                                        .if(selectedPeripheral?.identifier == peripheral.identifier) {
                                            $0.bold()
                                        }
                                })
                                
                                Spacer()
                                
                                Button(action: {
                                    activeAlert = .confirmDisconnect(blePeripheral: peripheral)
                                }, label: {
                                    Image(systemName: "xmark.circle")
                                })
                            }
                            .foregroundColor(.black)
                            
                        }
                        .buttonStyle(BorderlessButtonStyle())       // Allow multiple buttons inside
                        .listRowBackground(Color.white.opacity(0.7))
                        }
                    }
        }
        .modifier(Alerts(activeAlert: $activeAlert))
    }
    
    private struct Alerts: ViewModifier {
        @Binding var activeAlert: ActiveAlert?
        
        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .confirmDisconnect(let blePeripheral):
                        return Alert(
                            title: Text("Confirm disconnect \(blePeripheral.name ?? "")"),
                            message: nil,
                            primaryButton: .destructive(Text("Disconnect")) {
                                //BleAutoReconnect.clearAutoconnectPeripheral()
                                BleManager.shared.disconnect(from: blePeripheral)
                            },
                            secondaryButton: .cancel(Text("Cancel")) {})
                    }
                })
        }
    }
}

struct PeripheralChooserView_Previews: PreviewProvider {
    static var previews: some View {
        PeripheralChooserView()
            .environmentObject(FileTransferConnectionManager.shared)

    }
}
