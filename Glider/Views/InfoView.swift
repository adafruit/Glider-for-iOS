//
//  InfoView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI
import FileTransferClient

struct InfoView: View {
    // Params
    @EnvironmentObject var connectionManager: FileClientPeripheralConnectionManager
    
    // Data
    enum ActiveAlert: Identifiable {
        case confirmUnpair(blePeripheral: BlePeripheral)
        
        var id: Int {
            switch self {
            case .confirmUnpair: return 1
            }
        }
    }
    @State private var activeAlert: ActiveAlert?
    
    enum Destination {
        case todo
    }
    @State private var destination: Destination?
    
    var body: some View {
        NavigationView {
            VStack {
                
                // Navigate to TodoView
                NavigationLink(
                    destination: TodoView(),
                    tag: .todo,
                    selection: $destination) {
                        EmptyView()
                    }
                
                // Status
                VStack {
                    
                    VStack {
                        let connectedPeripherals = connectionManager.peripherals.filter{$0.state == .connected}
                        List {
                            Section(
                                header:
                                    HStack{
                                        Spacer()
                                        Text("Connected peripherals:")
                                        Spacer()
                                    },
                                footer:
                                    HStack {
                                        Spacer()
                                        Button(
                                            action: {
                                                FileClientPeripheralConnectionManager.shared.reconnect()
                                            },
                                            label: {
                                                Label("Find paired peripherals", systemImage: "arrow.clockwise")
                                            })
                                            .buttonStyle(ListFooterButtonStyle())
                                                                                
                                    }) {
                                        ForEach(connectedPeripherals, id: \.identifier) { peripheral in
                                            
                                            HStack {
                                                Text(verbatim: "\(peripheral.name ?? "<unknown>")")
                                                
                                                Spacer()

                                                Button(action: {
                                                    activeAlert = .confirmUnpair(blePeripheral: peripheral)
                                                }, label: {
                                                    Image(systemName: "xmark.circle")
                                                })
                                            }
                                            .foregroundColor(.black)

                                        }
                                        .listRowBackground(Color.white.opacity(0.7))
                                    }
                        }
                        .padding(.top, 1) // Don't go below the navigation bar
                    }
                
                    Spacer()
                        .frame(height: 20)
                    //Text("\(fileTransferClient?.blePeripheral?.name ?? "Peripheral") is ready.\n\nYou can now use the Files app to create, move, rename, and delete files or directories.").bold()
                    Text("You can now use the Files app to create, move, rename, and delete files or directories.").bold()
                    Spacer()
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 40)
                
                VStack {
                    // Buttons
                    Button(action: {
                        destination = .todo
                    }, label: {
                        Text("How to use the files app")
                            .frame(maxWidth: .infinity)
                    })
                        .buttonStyle(MainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .foregroundColor(Color.white)
            .padding(.bottom)
            .defaultGradientBackground()
            .navigationBarTitle("Info", displayMode: .large)
            .modifier(Alerts(activeAlert: $activeAlert))
            /*
             .toolbar {
             Button(action: {
             FileClientPeripheralConnectionManager.shared.reconnect()
             }, label: {
             //Text("Update connected peripherals").frame(maxWidth: .infinity)
             Image(systemName: "arrow.clockwise")
             })
             //.buttonStyle(MainButtonStyle())
             
             }*/
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private struct Alerts: ViewModifier {
        @Binding var activeAlert: ActiveAlert?
        
        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .confirmUnpair(let blePeripheral):
                        return Alert(
                            title: Text("Confirm disconnect \(blePeripheral.name ?? "")"),
                            message: nil /*Text("You will need to reset the pairing information for the peripheral on Settings->Bluetooth to re-establish the connnection")*/,
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

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "link")
                }
                .environmentObject(FileClientPeripheralConnectionManager.shared)
        }
    }
}
