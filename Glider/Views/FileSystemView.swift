//
//  FileSystemView.swift
//  Glider
//
//  Created by Antonio García on 18/10/21.
//

import SwiftUI

struct FileSystemView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

     // Params
    @ObservedObject var model: FileSystemViewModel

    var fileTransferClient: FileTransferClient
    @Binding var path: String
    let isLoading: Bool
    
    var showOnlyDirectories = false
    
    var body: some View {
        let isInteractionDisabled = model.isTransmitting || isLoading
        
        ZStack {
            let isListEmpty = model.isRootDirectory && model.entries.isEmpty
            
            if !isListEmpty {       // Fix for iOS 16: Make the list dissapear because empty lists have white background
                List {
                    if !model.isRootDirectory {
                        Button(action: {
                            let newPath = FileTransferPathUtils.upPath(from: model.path)
                            $path.wrappedValue = newPath
                            DispatchQueue.main.async {
                                //let _ = DLog("Up directory: \(newPath)")
                                model.listDirectory(directory: newPath, fileTransferClient: fileTransferClient)
                            }
                            
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
                                    DispatchQueue.main.async {
                                        model.listDirectory(directory: path, fileTransferClient: fileTransferClient)
                                        
                                    }
                                }, label: {
                                    ItemView(systemImageName: "folder", name: entry.name, size: nil)
                                })
                            }
                        }
                        .foregroundColor(entry.isHidden ? .gray : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(SwipeLeadingCompatibleModifier(model: model, path: path, entry: entry, fileTransferClient: fileTransferClient, isLoading: isLoading))
                    }
                    .onDelete { offsets in      // Note: this will only be executed on iOS14, because for iOS15 SwipeLeadingCompatibleModifier will take precedence
                        model.delete(at: offsets, fileTransferClient: fileTransferClient)
                    }
                    .listRowBackground(Color.clear)
                    
                }
                .modifier(ListHiddenScrollBackgroundModifier())
                
                .listStyle(PlainListStyle())
                .padding(.vertical, 1)
                .padding(.bottom, 20)       // Add some margin because the status bar
            }
                        
            VStack(alignment: .center) {
                // Empty view
                VStack {
                            Text("No Folders Found")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding()

                    Text("Make sure you're using the latest CircuitPython version.")
                        .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding([.leading, .trailing, .bottom])
                        }
                        .background(Color("button_primary_accent"))
                        .cornerRadius(10)
                        .padding()
                    .foregroundColor(.white)
                    .if(showOnlyDirectories || model.isTransmitting || model.entries.count > 0) {
                        $0.hidden()
                    }
                
                // Wait View
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                    .scaleEffect(1.5, anchor: .center)
                    .if(!isInteractionDisabled) {
                        $0.hidden()
                    }
            }
        }
        .allowsHitTesting(!isInteractionDisabled)
        .onAppear {
            model.showOnlyDirectories = showOnlyDirectories
            model.setup(directory: path, fileTransferClient: fileTransferClient)
        }
        // listDirectory again if the peripheral reconnected
        .onChange(of: connectionManager.isReconnectingToBondedPeripherals) { isReconnectingToBondedPeripherals in
            if isReconnectingToBondedPeripherals == false {     // When reconnected
                model.listDirectory(directory: model.path, fileTransferClient: fileTransferClient)
            }
        }
    }
    
    
    private struct ListHiddenScrollBackgroundModifier: ViewModifier {

        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(iOS 16.0, *) {
                content
                    .scrollContentBackground(.hidden)
            } else {
                content
            }
        }
    }
    
    private struct SwipeLeadingCompatibleModifier: ViewModifier {
        @EnvironmentObject private var connectionManager: ConnectionManager
        
        @ObservedObject var model: FileSystemViewModel
        let path: String
        let entry: DirectoryEntry
        let fileTransferClient: FileTransferClient
        let isLoading: Bool
        
        @State private var isShowingMoveView = false
        @State private var isShowingRenameView = false

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
                        
                        if !(fileTransferClient.peripheral is WifiFileTransferPeripheral) {
                            Button {
                                isShowingMoveView.toggle()
                            } label: {
                                Label("Move", systemImage: "rectangle.2.swap")
                            }
                            .tint(.indigo)
                        }
                      
                        
                        Button {
                            isShowingRenameView.toggle()
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.cyan)
                        
                    }
                    .sheet(isPresented: $isShowingMoveView, onDismiss: {
                        // Reload directory after moving
                        DispatchQueue.main.async {
                            model.listDirectory(directory: path, fileTransferClient: fileTransferClient)
                        }
                    }) {
                        FileMoveView(fromPath: path + entry.name, fileTransferClient: fileTransferClient, isLoading: isLoading)
                    }
                    .alert(isPresented: $isShowingRenameView, TextFieldAlert(title: "Rename", message: "Enter new name for '\(entry.name)'") { fileName in
                        if let fileName = fileName, fileName != entry.name {
                            let fromPath = model.path + entry.name
                            let toPath = model.path + fileName
                            model.renameFile(fromPath: fromPath, toPath: toPath, fileTransferClient: fileTransferClient)
                        }
                    })
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
                    //let _ = DLog("File: \(name)")
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

struct FileSystemView_Previews: PreviewProvider {
    static var previews: some View {
        
        let fileTransferClient = FileTransferClient(fileTransferPeripheral: WifiFileTransferPeripheral(wifiPeripheral: WifiPeripheral(name: "test", address: "127.0.0.1", port: 80), onGetPasswordForHostName: nil))
        
        
        FileSystemView(
            model: FileSystemViewModel(),
            fileTransferClient: fileTransferClient,
            path: .constant(FileTransferPathUtils.rootDirectory),
            isLoading: false
        )
        .defaultGradientBackground()
    }
}
