//
//  FileExplorerView.swift
//  Glider
//
//  Created by Antonio García on 14/10/21.
//

import SwiftUI
import FileTransferClient

struct FileExplorerView: View {
    
    @EnvironmentObject private var connectionManager: FileTransferConnectionManager
    @StateObject private var model = FileSystemViewModel()
    @State private var path = FileTransferPathUtils.rootDirectory
    @State private var isShowingPeripheralChooser = false

    var body: some View {
        let selectedClient = connectionManager.selectedClient
        let mainColor = Color.white.opacity(0.7)
        let isLoading = connectionManager.isSelectedPeripheralReconnecting

        NavigationView {
            
            VStack {
                
                // Top Bars
                VStack {
                    // Peripheral
                    VStack(alignment: .leading, spacing: 1) {
                        //HStack(alignment: .bottom) {
                            Text("Selected peripheral")
                        /*
                            Spacer()
                            Text("Reconnecting...")
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(8)
                                .opacity(connectionManager.isSelectedPeripheralReconnecting ? 1 : 0)
                                .animation(.default, value: connectionManager.isSelectedPeripheralReconnecting)
                            
                        }*/
                        .foregroundColor(.white)
                        .font(.caption2)
                        
                        Button(action: {
                            isShowingPeripheralChooser.toggle()
                        }, label: {
                            Text("\(selectedClient?.blePeripheral?.name ?? "<unknown>")")
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(mainColor)
                                )
                                .overlay(
                                    Image(systemName: "magnifyingglass")
                                        .padding()
                                        .foregroundColor(.black)
                                        .padding(.trailing, -8),
                                    alignment: .trailing
                                )
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
                            ActionButtonsView(mainColor: mainColor, isLoading: isLoading, selectedClient: selectedClient, model: model)
                        }
                    }
                    .foregroundColor(.white)
                }
                
                // FileSystem
                if let selectedClient = selectedClient {
                    
                    ZStack {
                        FileSystemView(model: model, path: $path, fileTransferClient: selectedClient, isLoading: isLoading)
                        
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
            .padding(.horizontal)
            .defaultGradientBackground(hidesKeyboardOnTap: true)
            .navigationBarTitle("File Explorer", displayMode: .large)
            .sheet(isPresented: $isShowingPeripheralChooser, onDismiss: nil) {
                ChooserView()
            }
            .id(connectionManager.selectedPeripheral?.identifier)       // Force reload when peripheral changes
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private struct ChooserView: View {
        @Environment(\.presentationMode) private var presentationMode
        
        var body: some View {
            VStack {
                PeripheralChooserView()
                Spacer()
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Close")
                        .padding(.horizontal)
               
                }
                .buttonStyle(MainButtonStyle())
            }
            .defaultGradientBackground()
        }
    }
    
    private struct ActionButtonsView: View {
        let mainColor: Color
        let isLoading: Bool
        let selectedClient: FileTransferClient?
        @ObservedObject var model: FileSystemViewModel
        
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
                            let path = model.path + directoryName
                            model.makeDirectory(path: path, fileTransferClient: selectedClient)
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
                        if let fileName = fileName {
                            let path = model.path + fileName
                            model.writeFile(filename: path, data: Data(), fileTransferClient: selectedClient)
                        }
                    })
            }
        }
    }
}

struct FileExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            FileExplorerView()
                .tabItem {
                    Label("Explorer", systemImage: "folder")
                }
                .environmentObject(FileTransferConnectionManager.shared)
        }
    }
}
