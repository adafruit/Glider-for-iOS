//
//  FileTransferView.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import SwiftUI

struct FileTransferView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var model = FileTransferViewModel()
    @State private var filename = "/hello.txt"
    @State private var fileContents = FileTransferViewModel.defaultFileContentePlaceholder

    let blePeripheral: BlePeripheral?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            VStack(alignment: .leading, spacing: 1) {
                Text("File name:")
                    .foregroundColor(.white)
                    .font(.caption)
                HStack {
                TextField("", text: $filename, onCommit:  {
                    hideKeyboard()
                })
                .if(model.isTransmitting) {
                    $0.colorMultiply(.gray)
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                    let fileNamePlaceholders = model.fileNamePlaceholders
                    ForEach(0..<fileNamePlaceholders.count, id: \.self) { i in
                        Button("\(i+1)") {
                            filename = fileNamePlaceholders[i]
                        }
                        .buttonStyle(PrimaryButtonStyle(height: 32))
                    }
                }
            }
            
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
                    Button("Clear contents") {
                        fileContents = ""
                    }
                    
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Contents:")
                    .foregroundColor(.white)
                    .font(.caption)
                
                HStack(alignment: .top) {
                    VStack {
                        TextEditor(text: $fileContents)
                            .cornerRadius(4)
                            .if(model.isTransmitting) {
                                $0.colorMultiply(.gray)
                            }
                            .onChange(of: model.lastTransmit) { lastTransmit in
                                guard let lastTransmit = lastTransmit else { return }
                                if case .read(let data) = lastTransmit.type {
                                    fileContents = String(data: data, encoding: .utf8) ?? ""
                                }
                            }
                        
                        if let lastTransmit = model.lastTransmit {
                            Text(lastTransmit.description)
                                .foregroundColor(.white)
                                .font(.caption)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                        }
                        else {
                            Text("")
                        }
                    }
                    
                    VStack(spacing: 8) {
                        let fileContentPlaceholders = model.fileContentPlaceholders
                        ForEach(0..<fileContentPlaceholders.count, id: \.self) { i in
                            Button("\(i+1)") {
                                fileContents = fileContentPlaceholders[i]
                            }
                            .buttonStyle(PrimaryButtonStyle(height: 32))
                        }
                    }
                    
                }
                
             
            }
        }
        .accentColor(.gray)
        .disabled(model.isTransmitting)
        //.background(Color.black)
        .padding()
        .navigationTitle("File Transfer")
        //        .navigationBarTitleDisplayMode(.inline)
        .defaultBackground(hidesKeyboardOnTap: true)
        .onChange(of: model.blePeripheral) { blePeripheral in
            if blePeripheral == nil {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            model.onAppear(blePeripheral: blePeripheral)
        }
        .onDisappear {
            model.onDissapear()
        }
        
    }
}

struct FileTransferView_Previews: PreviewProvider {
    static var previews: some View {
        //let blePeripheral = BlePeripheralSimulated(model: .circuitPlaygroundBluefruit)
        
        NavigationView {
            ZStack {
                FileTransferView(blePeripheral: nil)
            }
            .defaultBackground()

        }
        
    }
}
