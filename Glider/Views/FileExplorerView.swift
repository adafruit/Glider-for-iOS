//
//  FileExplorerView.swift
//  Glider
//
//  Created by Antonio García on 14/10/21.
//

import SwiftUI
import FileTransferClient

struct FileExplorerView: View {
    
    @EnvironmentObject private var connectionManager: FileClientPeripheralConnectionManager
    @StateObject private var model = FileExplorerViewModel()
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
                        HStack(alignment: .bottom) {
                            Text("Selected peripheral")
                            Spacer()
                            Text("Reconnecting...")
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(8)
                                .opacity(connectionManager.isSelectedPeripheralReconnecting ? 1 : 0)
                                .animation(.default, value: connectionManager.isSelectedPeripheralReconnecting)
                            
                        }
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
                
                // Explorer
                if let selectedClient = selectedClient {
                    
                    ZStack {
                        ExplorerView(model: model, path: $path, fileTransferClient: selectedClient, isLoading: isLoading)
                        
                        // Bottom status bar
                        FileCommandsStatusBarView(model: model, backgroundColor: mainColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.6))
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
            .id(connectionManager.selectedPeripheral?.identifier)       // Force reload when peripehral changes
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
        @ObservedObject var model: FileExplorerViewModel
        
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
    
    private struct ExplorerView: View {
        @ObservedObject var model: FileExplorerViewModel
        @Binding var path: String
        
        let fileTransferClient: FileTransferClient
        let isLoading: Bool
        
        var body: some View {
            let isInteractionDisabled = model.isTransmiting || isLoading
            
            ZStack {
                List {
                    if !model.isRootDirectory {
                        Button(action: {
                            let newPath = FileTransferPathUtils.upPath(from: model.path)
                            let _ = DLog("Up directory: \(newPath)")
                            $path.wrappedValue = newPath
                            model.listDirectory(directory: newPath, fileTransferClient: fileTransferClient)
                            
                        }, label: {
                            ItemView(systemImageName: "arrow.up.doc", name: "..", size: nil)
                                .foregroundColor(.white)
                        })
                            .listRowBackground(Color.clear)
                    }
                    
                    
                    ForEach(model.entries, id:\.name) { entry in
                                                
                        HStack {
                            switch entry.type {
                            case .file(let size):
                                FileView(fileTransferClient: fileTransferClient, path: path, name: entry.name, size: size)
                                
                            case .directory:
                                Button(action: {
                                    //let _ = DLog("Directory: '\(entry.name)'")
                                    let path = model.path + entry.name + "/"
                                    $path.wrappedValue = path
                                    model.listDirectory(directory: path, fileTransferClient: fileTransferClient)
                                }, label: {
                                    ItemView(systemImageName: "folder", name: entry.name, size: nil)
                                })
                            }
                        }
                        .foregroundColor(entry.isHidden ? .gray : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(SwipeLeadingCompatibleModifier(model: model, entry: entry, fileTransferClient: fileTransferClient))

                    }
                    .onDelete { offsets in      // Note: this will only be executed on iOS14, because for iOS15 SwipeLeadingCompatibleModifier will take precedence
                        model.delete(at: offsets, fileTransferClient: fileTransferClient)
                    }
                    .listRowBackground(Color.clear)
                    
                }
                .listStyle(PlainListStyle())
                .padding(.vertical, 1)
                .padding(.bottom, 20)       // Add some margin because the status bar
                
                // Wait View
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                    .scaleEffect(1.5, anchor: .center)
                    .if(!isInteractionDisabled) {
                        $0.hidden()
                    }
                
                // Empty view
                Text("No files found")
                    .foregroundColor(.white)
                    .if(model.isTransmiting || model.entries.count > 0) {
                        $0.hidden()
                    }
            }
            .allowsHitTesting(!isInteractionDisabled)
            .onAppear {
                model.setup(directory: path, fileTransferClient: fileTransferClient)
            }
        }
        
        private struct SwipeLeadingCompatibleModifier: ViewModifier {
            @ObservedObject var model: FileExplorerViewModel
            let entry: BlePeripheral.DirectoryEntry
            let fileTransferClient: FileTransferClient
            
            @ViewBuilder
            func body(content: Content) -> some View {
                if #available(iOS 15.0, *) {
                    content
                    
                        .swipeActions(edge: .trailing) {
                          Button(role: .destructive) {
                              model.delete(entry: entry, fileTransferClient: fileTransferClient)
                          } label: {
                            Label("Delete", systemImage: "trash")
                          }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                print("TODO: move")
                            } label: {
                                Label("Move", systemImage: "rectangle.2.swap")
                            }
                            .tint(.indigo)
                        }
                } else {
                    content
                }
            }
        }
        
        private struct FileView: View {
            // Params
            let fileTransferClient: FileTransferClient
            let path: String
            let name: String
            let size: Int
            
            @State private var showFileEditor = false
            
            var body: some View {
                ZStack {
                    NavigationLink(
                        destination: FileEditView(fileTransferClient: fileTransferClient, path: path).environment(\.filename, name),
                        isActive: $showFileEditor, label: {
                            EmptyView()
                        })
                    
                    Button(action: {
                        let _ = DLog("File: \(name)")
                        showFileEditor = true
                    }, label: {
                        ItemView(systemImageName: "doc", name: name, size: size)
                    })
                }
            }
        }
        
        private struct ItemView: View {
            let systemImageName: String
            let name: String
            let size: Int?
            
            var body: some View {
                HStack {
                    Image(systemName: systemImageName)
                        .frame(width: 24)
                    Text(name)
                        .allowsTightening(true)
                        .lineLimit(1)
                    if let size = size {
                        Spacer()
                        Text(size > 1024 ? String(format: "%.0f KB", Float(size)/1024) : "\(size) B")
                            .font(.caption)
                    }
                }
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
                .environmentObject(FileClientPeripheralConnectionManager.shared)
        }
    }
}
