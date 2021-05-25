//
//  FileChooserView.swift
//  Glider
//
//  Created by Antonio García on 21/5/21.
//

import SwiftUI

struct FileChooserView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var model = FileChooserViewModel()
    @State private var showNewDirectoryDialog = false
    
    @Binding var directory: String
    var blePeripheral: BlePeripheral?
    
    var body: some View {
        VStack {
            Text("Select File:")
                .bold()
                .textCase(.uppercase)
                .foregroundColor(.white)                .padding(.top)
            
            HStack {
            Text("Path:")
                .font(.caption)
                .foregroundColor(.white)
            
                
                TextField("", text: $model.directory, onCommit:  {})
                    .disabled(true)
                    .colorMultiply(.gray)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            ZStack {
                List {
                    if !model.isRootDirectory {
                        Button(action: {
                            let _ = print("TODO: Up directory")
                        }, label: {
                            ItemView(systemImageName: "arrow.up.doc", name: "..", size: nil)
                                .listRowBackground(Color.clear)
                                .foregroundColor(.white)
                        })
                    }
                    
                    ForEach(model.entries, id:\.name) { entry in
                        HStack {
                            Button(action: {
                                let _ = print("Selected: \(entry.name)")
                                $directory.wrappedValue = FileTransferUtils.fileDirectory(filename: directory) + entry.name
                                presentationMode.wrappedValue.dismiss()
                                
                            }, label: {
                                switch entry.type {
                                case .directory:
                                    ItemView(systemImageName: "folder", name: entry.name, size: nil)
                                    
                                case .file(let size):
                                    ItemView(systemImageName: "doc", name: entry.name, size: size)
                                }
                            })
                        }
                    }
                    .onDelete(perform: model.delete)
                    .listRowBackground(Color.clear)
                    .foregroundColor(.white)
                }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                    .if(!model.isTransmiting) {
                        $0.hidden()
                    }
                
                Text("No files found")
                    .foregroundColor(.white)
                    .if(model.isTransmiting || model.entries.count > 0) {
                        $0.hidden()
                    }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    showNewDirectoryDialog.toggle()
                    
                }, label: {
                    Label("New Directory", systemImage: "folder.badge.plus")
                })
                .layoutPriority(1)
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.bottom)
        }
        .defaultBackground(hidesKeyboardOnTap: true)
        .onAppear {
            model.setup(blePeripheral: blePeripheral, directory: directory)
        }
        .alert(isPresented: $showNewDirectoryDialog, TextFieldAlert(title: "New Directory", message: "Enter name for the new directory") { directoryName in
            if let directoryName = directoryName {
                model.makeDirectory(directory: directoryName)
            }
        })
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
                if let size = size {
                    Spacer()
                    Text("\(size) bytes")
                }
            }
        }
        
    }
}

struct DirectoryChooserView_Previews: PreviewProvider {
    static var previews: some View {
        FileChooserView(directory: .constant("/"), blePeripheral: nil)
    }
}
