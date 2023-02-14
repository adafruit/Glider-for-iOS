//
//  FileExplorerView.swift
//  Glider
//
//  Created by Antonio García on 14/10/21.
//

import SwiftUI

struct FileExplorerView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @StateObject private var model = FileSystemViewModel()

    var body: some View {
        let fileTransferClient = connectionManager.currentFileTransferClient
        let isLoading = connectionManager.isReconnectingToBondedPeripherals
        
        NavigationView {
            Group {
                if let fileTransferClient = fileTransferClient {
                    FileExplorerBody(
                        model: model,
                        fileTransferClient: fileTransferClient,
                        isLoading: isLoading
                    )
                }
                else {
                    // Empty State
                    VStack {
                        VStack(spacing: 12) {
                            Text("No peripheral selected".uppercased())
                            Text("Select a peripheral on the 'Peripherals' tab to start using the File Explorer")
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding(.top, 40)
                        
                        Spacer()
                    }
                }
                
            }
            .padding([.horizontal, .top])
            .defaultGradientBackground(hidesKeyboardOnTap: true)
            .navigationBarTitle("File Explorer", displayMode: .inline)
            .id(fileTransferClient?.peripheral.address)       // Force reload when peripheral changes
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


private struct FileExplorerBody: View {
    @ObservedObject var model: FileSystemViewModel
    let fileTransferClient: FileTransferClient
    let isLoading: Bool
    
    @State private var path = FileTransferPathUtils.rootDirectory

    
    var body: some View {
        let mainColor = Color.white.opacity(0.7)
        
        VStack {
            // Top Bars
            VStack {
                // Peripheral
                VStack(alignment: .leading, spacing: 1) {
                    Text("Selected peripheral")
                        .foregroundColor(.white)
                        .font(.caption2)
                    
                    Button(action: {
                        //isShowingPeripheralChooser.toggle()
                    }, label: {
                        Text(verbatim: "\(fileTransferClient.peripheral.nameOrAddress)")
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(mainColor)
                            )
                            /*.overlay(
                                Image(systemName: "magnifyingglass")
                                    .padding()
                                    .foregroundColor(.black)
                                    .padding(.trailing, -8),
                                alignment: .trailing
                            )*/
                    })
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                }
                
                // Path
                VStack(alignment: .leading, spacing: 1) {
                    // Title
                    Text("Path")
                        .font(.caption2)
                    
                    HStack {
                        // Current Path
                        Text("\(path)")
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(mainColor)
                            )
                        
                        // Action Buttons
                        ActionButtonsView(mainColor: mainColor, isLoading: isLoading, onMakeDirectory: { directoryName in
                            let path = model.path + directoryName
                            model.makeDirectory(path: path, fileTransferClient: fileTransferClient)
                            
                        }, onMakeFile: { filename in
                            let path = model.path + filename
                            model.makeFile(filename: path, fileTransferClient: fileTransferClient)
                            
                        })
                    }
                }
                .foregroundColor(.white)
            }
            
            
            // FileSystem
            if let selectedClient = fileTransferClient {
                
                ZStack {
                    FileSystemView(model: model, fileTransferClient: selectedClient, path: $path, isLoading: isLoading)
                    
                    // Bottom status bar
                    FileCommandsStatusBarView(model: model, backgroundColor: mainColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(mainColor)
                )
                .clipped()
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    private struct ActionButtonsView: View {
        let mainColor: Color
        let isLoading: Bool
        let onMakeDirectory: ((_ directoryName: String)->Void)
        let onMakeFile: ((_ fileName: String)->Void)

        @State private var showNewDirectoryDialog = false
        @State private var showNewFileDialog = false
        
        var body: some View {
            HStack {
                Button(action: {
                    showNewDirectoryDialog.toggle()
                    
                }, label: {
                    Image(systemName: "folder.badge.plus")
                        .padding(.horizontal, 2)
                })
                .layoutPriority(1)
                .buttonStyle(PrimaryButtonStyle(height: 36, foregroundColor: mainColor))
                .disabled(isLoading)
                .alert(isPresented: $showNewDirectoryDialog, TextFieldAlert(title: "New Directory", message: "Enter name for the new directory") { directoryName in
                    if let directoryName = directoryName {
                        onMakeDirectory(directoryName)
                    }
                })
                
                
                Button(action: {
                    showNewFileDialog.toggle()
                    
                }, label: {
                    Image(systemName: "doc.badge.plus")
                        .padding(.horizontal, 2)
                })
                    .layoutPriority(1)
                    .buttonStyle(PrimaryButtonStyle(height: 36, foregroundColor: mainColor))
                    .disabled(isLoading)
                    .alert(isPresented: $showNewFileDialog, TextFieldAlert(title: "New File", message: "Enter name for the new file") { fileName in
                        if  let fileName = fileName {
                            onMakeFile(fileName)
                        }
                    })
            }
        }
    }
}

struct FileExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            /*
             let connectionManager = ConnectionManager(
             wifiPeripheralScanner: BonjourScannerFake(),
             onWifiPeripheralGetPasswordForHostName: nil
             )
             
             FileExplorerView()
             .tabItem {
             Label("Explorer", systemImage: "folder")
             }
             .environmentObject(connectionManager)
             */
            
            let fileTransferClient = FileTransferClient(fileTransferPeripheral: WifiFileTransferPeripheral(wifiPeripheral: WifiPeripheral(name: "test", address: "127.0.0.1", port: 80), onGetPasswordForHostName: nil))
            
            NavigationView {
                FileExplorerBody(model: FileSystemViewModel(), fileTransferClient: fileTransferClient, isLoading: false)
                    .tabItem {
                        Label("Explorer", systemImage: "folder")
                    }
                    .padding(.horizontal)
                    .defaultGradientBackground(hidesKeyboardOnTap: true)
                    .navigationBarTitle("File Explorer", displayMode: .inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
