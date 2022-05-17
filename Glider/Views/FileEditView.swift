//
//  FileEditView.swift
//  Glider
//
//  Created by Antonio García on 15/10/21.
//

import SwiftUI
import FileTransferClient

struct FileEditView: View {
    // Params
    let fileTransferClient: FileTransferClient?
    let path: String
    @Environment(\.filename) private var filename
    
    //
    @EnvironmentObject private var connectionManager: FileTransferConnectionManager
    @Environment(\.safeAreaInsets) private var safeAreaInsets
   
    // Data
    @StateObject private var model = FileEditViewModel()
    @State private var editedContents = "" //FileEditViewModel.defaultFileContentePlaceholder
    
    var body: some View {
        let isLoading = connectionManager.isSelectedPeripheralReconnecting
        let isInteractionDisabled = model.isTransmitting || isLoading
        let filePath = path + filename
        
        VStack(spacing: 0) {
            ZStack {
                TextEditor(text: $editedContents)
                    .autocapitalization(UITextAutocapitalizationType.none)
                    .if(isInteractionDisabled) {
                        $0.colorMultiply(.gray)
                    }
                    .overlay (
                        
                        // Bottom status bar
                        FileCommandsStatusBarView(model: model, backgroundColor: .gray.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    )
                    .cornerRadius(4)
                    .padding()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .onChange(of: model.text ?? "") { text in
                        editedContents = text
                    }
                
                // Wait View
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.gray))
                    .scaleEffect(1.5, anchor: .center)
                    .if(!isInteractionDisabled) {
                        $0.hidden()
                    }
                
                // Empty view
                VStack(spacing: 8) {
                    Text("This file is empty")
                    Text("You can add content using the keyboard or press the numbered buttons to insert a predefined snippet.")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.gray)
                .shadow(radius: 16)
                .if(isInteractionDisabled || !(model.text?.isEmpty ?? true) || !editedContents.isEmpty) {
                    $0.hidden()
                }
                .padding(24)
            }
            
            HStack {
                let mainColor = Color.white.opacity(0.7)
                let hasChanged = (model.text ?? "") != editedContents
                
                Button(action: {
                    if let fileTransferClient = fileTransferClient, let data = editedContents.data(using: .utf8) {
                        model.writeFile(filename: filePath, data: data, fileTransferClient: fileTransferClient)
                    }
                    
                }, label: {
                    Label("Save", systemImage: hasChanged ? "square.and.pencil" : "checkmark.circle")
                        .padding(.horizontal, 2)
                    
                })
                    .buttonStyle(PrimaryButtonStyle(height: 36, foregroundColor: mainColor))
                
                Spacer()
                
                HStack(spacing: 8) {
                    let width: CGFloat = 40
                    
                    let fileContentPlaceholders = model.fileContentSnippets
                    
                    // Snippets
                    ForEach(0..<fileContentPlaceholders.count, id: \.self) { i in
                        Button("\(i+1)") {
                            editedContents = fileContentPlaceholders[i]
                        }
                        .buttonStyle(PrimaryButtonStyle(width: width, foregroundColor: mainColor))
                    }
                    
                    // Delete
                    Button {
                        editedContents = ""
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(PrimaryButtonStyle(width: width, foregroundColor: mainColor))
                }
            }
            .padding(.horizontal)
            .if(safeAreaInsets.bottom == 0) {       // Add bottom margin for devices without bottom safe area
                $0.padding(.bottom)
            }
        }
        .padding(.bottom)
        .defaultGradientBackground(hidesKeyboardOnTap: true)
        .navigationBarTitle(filename, displayMode: .inline)
        .allowsHitTesting(!isInteractionDisabled)
        .onAppear {
            model.setup(filePath: filePath, fileTransferClient: fileTransferClient)
        }
    }
}

// MARK: - Environment Keys
private struct FilenameEnvironmentKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var filename: String {
        get { self[FilenameEnvironmentKey.self] }
        set { self[FilenameEnvironmentKey.self] = newValue }
    }
}

// MARK: - Preview
struct FileEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FileEditView(fileTransferClient: nil, path: "/")
                .environmentObject(FileTransferConnectionManager.shared)
                .environment(\.filename, "test.txt")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        //.previewDevice(PreviewDevice(rawValue: "iPhone SE (2nd generation)"))
    }
}
