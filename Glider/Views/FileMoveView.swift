//
//  FileMoveView.swift
//  Glider
//
//  Created by Antonio García on 18/10/21.
//

import SwiftUI
import FileTransferClient

struct FileMoveView: View {
    @EnvironmentObject private var connectionManager: FileTransferConnectionManager
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.safeAreaInsets) private var safeAreaInsets
 
    @StateObject private var model = FileSystemViewModel()
    let fromPath: String?
    let fileTransferClient: FileTransferClient?
    
    @State private var path = FileTransferPathUtils.rootDirectory
    
    var body: some View {
        let isLoading = connectionManager.isSelectedPeripheralReconnecting
        let mainColor = Color.white.opacity(0.7)
        
        NavigationView {
            VStack {
                // From
                VStack(alignment: .leading, spacing: 1) {
                    Text("From:")
                        .font(.caption2)
                    
                    Button(action: {
                        //isShowingPeripheralChooser.toggle()
                    }, label: {
                        Text("\(fromPath ?? "")")
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(mainColor)
                            )
                    })
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoading)
                }
                .foregroundColor(.white)

                
                VStack(alignment: .leading, spacing: 1) {
                    // Title
                    Text("To:")
                        .font(.caption2)
                    
                    // Current Path
                    Text("\(path)")
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(mainColor)
                        )
                }
                .foregroundColor(.white)
                
                // FileSystem
                if let fileTransferClient = fileTransferClient {
                    
                    ZStack {
                        FileSystemView(model: model, path: $path, fileTransferClient: fileTransferClient, isLoading: isLoading, showOnlyDirectories: true)
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
                
                // Action
                HStack {
                    // Cancel
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .padding(.horizontal)
                    }
                    .buttonStyle(MainButtonStyle())
                    
                    // Move
                    if let fromPath = fromPath {
                        let fileName = FileTransferPathUtils.filenameFromPath(path: fromPath)
                        let toPath = path + fileName
                        
                        Button(action: {
                            self.model.moveFile(fromPath: fromPath, toPath: toPath, fileTransferClient: fileTransferClient) { result in
                                
                                switch result {
                                case .success:
                                    // Dismiss
                                    DispatchQueue.main.async {  // needed for the dismiss
                                        self.presentationMode.wrappedValue.dismiss()
                                    }
                                    
                                case .failure:
                                    break
                                }
                            }
                        }) {
                            Text("Move")
                                .padding(.horizontal)
                        }
                        .buttonStyle(MainButtonStyle())
                        .disabled(fromPath == toPath)
                    }
                }
            }
            .padding(.horizontal)
            .if(safeAreaInsets.bottom == 0) {       // Add bottom margin for devices without bottom safe area
                $0.padding(.bottom)
            }
            .defaultGradientBackground()
            .navigationBarTitle("Move File", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct FileMoveView_Previews: PreviewProvider {
    static var previews: some View {
        FileMoveView(fromPath: FileTransferPathUtils.rootDirectory, fileTransferClient: nil)
            .environmentObject(FileTransferConnectionManager.shared)
    }
}
