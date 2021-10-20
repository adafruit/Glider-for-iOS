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
    @EnvironmentObject private var connectionManager: FileTransferConnectionManager
    
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
                    
                    PeripheralChooserView()
                        .padding(.top, 1) // Don't go below the navigation bar
                    
                    Spacer()
                        .frame(height: 20)
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "link")
                }
                .environmentObject(FileTransferConnectionManager.shared)
        }
    }
}
