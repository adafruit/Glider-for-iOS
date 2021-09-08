//
//  InfoView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI

struct InfoView: View {
    // Params
    let fileTransferClient: FileTransferClient?
  
    // Data
    enum ActiveAlert: Identifiable {
        case confirmUnpair
        
        var id: Int { hashValue }
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
                    Spacer()
                    Text("The peripheral is ready.\nYou can now use the Files app to create, move, rename, and delete files or directories.").bold()
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
                    
                    Button(action: {
                        activeAlert = .confirmUnpair
                    }, label: {
                        Text("Disconnect and unpair...")
                            .frame(maxWidth: .infinity)
                    })
                    .buttonStyle(MainButtonStyle(isDark: false, backgroundColor: Color("button_warning_background")))
                }
                .padding(.horizontal)

                Spacer()
            }
            .foregroundColor(Color.white)
            .padding(.bottom)
            .defaultGradientBackground()
            .navigationBarTitle("Connected", displayMode: .large)
            .modifier(Alerts(activeAlert: $activeAlert, fileTransferClient: fileTransferClient))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private struct Alerts: ViewModifier {
        @Binding var activeAlert: ActiveAlert?
        let fileTransferClient: FileTransferClient?
        
        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .confirmUnpair:
                        return Alert(
                            title: Text("Confirm unpairing"),
                            message: Text("You will need to reset the pairing information for the peripheral on Settings->Bluetooth to re-establish the connnection"),
                            primaryButton: .destructive(Text("Unpair")) {
                                Settings.clearAutoconnectPeripheral()
                                if let blePeripheral = fileTransferClient?.blePeripheral {
                                    BleManager.shared.disconnect(from: blePeripheral)
                                }
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
            InfoView(fileTransferClient: nil)
                .tabItem {
                    Label("Info", systemImage: "link")
                }
        }
    }
}
