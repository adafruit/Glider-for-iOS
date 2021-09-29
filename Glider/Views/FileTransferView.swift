//
//  FileTransferView.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import SwiftUI
import FileTransferClient

struct FileTransferView: View {
    // Config
    private let helperButtonSize = CGSize(width: 40, height: 32)
    
    // Params
    let fileTransferClient: FileTransferClient?
    
    // Data
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var model = FileTransferViewModel()
    @State private var filename = "/hello.txt"
    @State private var fileContents = FileTransferViewModel.defaultFileContentePlaceholder
    @State private var isShowingFileChooser = false
    @State private var topViewsHeight: CGFloat = .zero
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 8) {
                
                // Filename
                FileNameView(model: model, filename: $filename, isShowingFileChooser: $isShowingFileChooser, helperButtonSize: helperButtonSize)
                
                // Actions
                VStack(alignment: .leading, spacing: 1) {
                    Text("Actions:")
                        .foregroundColor(.white)
                        .font(.caption2)
                    
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
            //.navigationTitle("File Transfer")
            .defaultGradientBackground(hidesKeyboardOnTap: true)
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
            .navigationBarTitle("File Transfer Tests", displayMode: .large)
            //.navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .modifier(Alerts(activeAlert: $model.activeAlert))
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                    .font(.caption2)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
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
                            if let progress = model.transmissionProgress, let totalBytes = progress.totalBytes {
                                ProgressView(progress.description, value: Float(progress.transmittedBytes), total: Float(totalBytes))
                                    .accentColor(Color.white)
                                    .font(.callout)
                            }
                            else {
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    // Last transmit info
                                    HStack {
                                        if let lastTransmit = model.lastTransmit {
                                            Spacer()
                                            Text(lastTransmit.description)
                                                .font(.caption2)
                                        }
                                    }
                                    
                                    /*
                                     HStack() {
                                     Button(action: {
                                     model.disconnectAndForgetPairing()
                                     }, label: {
                                     Text("Forget Pairing")
                                     .bold()
                                     })
                                     .buttonStyle(PrimaryButtonStyle(foregroundColor: Color("button_warning_text")))
                                     
                                     
                                     Button("FileProvider Resync") {
                                     FileProviderUtils.signalFileProviderChanges()
                                     }
                                     .buttonStyle(PrimaryButtonStyle(foregroundColor: Color("button_warning_text")))
                                     }*/
                                }
                                
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundColor(.white)
                        
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
    
    private struct Alerts: ViewModifier {
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Binding var activeAlert: FileTransferViewModel.ActiveAlert?
        
        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .error(let error):
                        return Alert(
                            title: Text("Error"),
                            message: Text(error.localizedDescription),
                            dismissButton: .default(Text("ok")) {
                            })
                    }
                })
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
                    .font(.caption2)
                
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
        
        FileTransferView(fileTransferClient: nil)
        /*
         NavigationView {
         ZStack {
         FileTransferView(fileTransferClient: nil)
         }
         .navigationViewStyle(StackNavigationViewStyle())
         }*/
    }
}
