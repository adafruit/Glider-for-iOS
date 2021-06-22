//
//  FileTransferView.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//
 
import SwiftUI

struct FileTransferView: View {
    // Config
    private let helperButtonSize = CGSize(width: 40, height: 32)
    
    // Params
    private let fileTransferClient: FileTransferClient?
    
    // Data
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var model = FileTransferViewModel()
    @State private var filename = "/hello.txt"
    @State private var fileContents = FileTransferViewModel.defaultFileContentePlaceholder
    @State private var isShowingFileChooser = false
    @State private var topViewsHeight: CGFloat = .zero
    
    init(fileTransferClient: FileTransferClient?) {
        self.fileTransferClient = fileTransferClient
        //self.filename = model.fileNamePlaceholders.first!
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Filename
            FileNameView(model: model, filename: $filename, isShowingFileChooser: $isShowingFileChooser, helperButtonSize: helperButtonSize)
            
            // Actions
            VStack(alignment: .leading, spacing: 1) {
                Text("Actions:")
                    .foregroundColor(.white)
                    .font(.caption)
                
                HStack {
                    Button("Write File") {
                        if let data = fileContents.data(using: .utf8) {
                            model.writeFile(filename: filename, data: data)
                        }
                    }
                    Button("Read File") {
                        model.readFile(filename: filename)
                    }
                    Button("Delete File") {
                        model.deleteFile(filename: filename)
                    }
                    
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            // Contents Editor
            ContentsView(model: model, fileContents: $fileContents, filename: $filename, helperButtonSize: helperButtonSize)
        }
        .accentColor(.gray)
        .disabled(model.transmissionProgress != nil)
        .padding()
        .navigationTitle("File Transfer")
        //        .navigationBarTitleDisplayMode(.inline)
        .defaultBackground(hidesKeyboardOnTap: true)
        .sheet(isPresented: $isShowingFileChooser) {
            FileChooserView(directory: $filename, fileTransferClient: model.fileTransferClient)
        }
        .onChange(of: model.fileTransferClient) { fileTransferClient in
            if fileTransferClient == nil {
                isShowingFileChooser = false
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            model.onAppear(fileTransferClient: fileTransferClient)
        }
        .onDisappear {
            model.onDissapear()
        }
    }

    private struct ContentsView: View {
        @ObservedObject var model: FileTransferViewModel
        @Binding var fileContents: String
        @Binding var filename: String
        let helperButtonSize: CGSize
        
        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text("Contents:")
                    .foregroundColor(.white)
                    .font(.caption)
                
                HStack(alignment: .top) {
                    VStack {
                        TextEditor(text: $fileContents)
                            .cornerRadius(4)
                            .if(model.transmissionProgress != nil) {
                                $0.colorMultiply(.gray)
                            }
                            .frame(minHeight: 0, maxHeight: .infinity)
                            .onChange(of: model.lastTransmit) { lastTransmit in
                                guard let lastTransmit = lastTransmit else { return }
                                if case .read(let data) = lastTransmit.type {
                                    fileContents = String(data: data, encoding: .utf8) ?? ""
                                }
                            }
                                                
                        Group {
                            if let lastTransmit = model.lastTransmit {
                                Text(lastTransmit.description)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                            }
                            else if let progress = model.transmissionProgress, let totalBytes = progress.totalBytes {
                                ProgressView(progress.description, value: Float(progress.transmittedBytes), total: Float(totalBytes))
                                    .accentColor(Color.white)
                            }
                            else {
                                Text("")
                            }
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                    }
                    
                    VStack(spacing: 8) {
                        let fileContentPlaceholders = model.fileContentPlaceholders
                        
                        Button("X") {
                            fileContents = ""
                        }
                        .buttonStyle(PrimaryButtonStyle(width: helperButtonSize.width, height: helperButtonSize.height))
                        
                        ForEach(0..<fileContentPlaceholders.count, id: \.self) { i in
                            Button("\(i+1)") {
                                fileContents = fileContentPlaceholders[i]
                            }
                            .buttonStyle(PrimaryButtonStyle(width: helperButtonSize.width, height: helperButtonSize.height))
                        }
                    }
                }
            }
        }
    }
    
    private struct FileNameView: View {
        @ObservedObject var model: FileTransferViewModel
        @Binding var filename: String
        @Binding var isShowingFileChooser: Bool
        let helperButtonSize: CGSize
        
        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text("File name:")
                    .foregroundColor(.white)
                    .font(.caption)
                
                HStack {
                    TextField("", text: $filename, onCommit:  {
                        hideKeyboard()
                    })
                    .if(model.transmissionProgress != nil) {
                        $0.colorMultiply(.gray)
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .overlay(
                        Button(action: {
                            isShowingFileChooser.toggle()
                        }, label: {
                            Image(systemName: "folder.fill")
                                .padding()
                        })
                        //.border(Color.red)
                        .padding(.trailing, -8),
                        alignment: .trailing
                    )
                    
                    let fileNamePlaceholders = model.fileNamePlaceholders
                    ForEach(0..<fileNamePlaceholders.count, id: \.self) { i in
                        Button("\(i+1)") {
                            filename = fileNamePlaceholders[i]
                        }
                        .buttonStyle(PrimaryButtonStyle(height: helperButtonSize.height))
                    }
                }
            }
        }
    }
}

struct FileTransferView_Previews: PreviewProvider {
    static var previews: some View {
        
        NavigationView {
            ZStack {
                FileTransferView(fileTransferClient: nil)
            }
            .defaultBackground()
        }
    }
}
