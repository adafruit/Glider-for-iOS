//
//  FileSystemView.swift
//  Glider
//
//  Created by Antonio García on 18/10/21.
//

import SwiftUI
import FileTransferClient

struct FileSystemView: View {
    // Params
    @ObservedObject var model: FileSystemViewModel
    @Binding var path: String
    let fileTransferClient: FileTransferClient
    let isLoading: Bool
    
    var showOnlyDirectories = false
    
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
                    .modifier(SwipeLeadingCompatibleModifier(model: model, path: path, entry: entry, fileTransferClient: fileTransferClient))
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
                .if(showOnlyDirectories || model.isTransmiting || model.entries.count > 0) {
                    $0.hidden()
                }
        }
        .allowsHitTesting(!isInteractionDisabled)
        .onAppear {
            model.showOnlyDirectories = showOnlyDirectories
            model.setup(directory: path, fileTransferClient: fileTransferClient)
        }
    }
    
    private struct SwipeLeadingCompatibleModifier: ViewModifier {
        @ObservedObject var model: FileSystemViewModel
        let path: String
        let entry: BlePeripheral.DirectoryEntry
        let fileTransferClient: FileTransferClient
        @State private var isShowingMoveView = false

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
                            isShowingMoveView.toggle()
                        } label: {
                            Label("Move", systemImage: "rectangle.2.swap")
                        }
                        .tint(.indigo)
                    }
                    .sheet(isPresented: $isShowingMoveView, onDismiss: {
                        // Reload directory after moving
                        DispatchQueue.main.async {
                            model.listDirectory(directory: path, fileTransferClient: fileTransferClient)
                        }
                    }) {
                        FileMoveView(fromPath: path + entry.name, fileTransferClient: fileTransferClient)
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

struct FileSystemView_Previews: PreviewProvider {
    static var previews: some View {
        FileSystemView(model: FileSystemViewModel(), path: .constant(FileTransferPathUtils.rootDirectory), fileTransferClient: FileTransferClient(), isLoading: false)
            .defaultGradientBackground()
    }
}
