//
//  AutoConnectView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

struct AutoConnectView: View {
    @StateObject private var model = AutoConnectViewModel()
    @Binding var isVisible: Bool
    
    var body: some View {
        
        NavigationLink(destination: FileTransferView(adafruitBoard: model.adafruitBoard), tag: .fileTransfer, selection: $model.destination) { EmptyView() }
        
        VStack {
            Spacer()
            
            Text("Status: ").bold()
            Text(model.detailText)
            
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("Found peripherals: \(model.numPeripheralsScanned)")
                Text("Adafruit peripherals: \(model.numAdafruitPeripheralsScanned)")
                Text("FileTransfer peripherals: \(model.numAdafruitPeripheralsWithFileTranferServiceScanned)")
                Text("FileTransfer peripherals nearby: \(model.numAdafruitPeripheralsWithFileTranferServiceNearby)")
           
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.1))
            
        }
        .defaultBackground()
        .foregroundColor(Color.white)
        .navigationTitle("Auto-Connect")
        .onChange(of: isVisible) { isVisible in
            // onAppear doesn't work on navigationItem so pass the onAppear/onDissapear via binding variable: https://developer.apple.com/forums/thread/655338

            if isVisible {
                model.onAppear()
            }
            else {
                model.onDissapear()
            }
        }

    }
}

struct AutoConnectView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack {
                AutoConnectView(isVisible: .constant(true))
            }
            .defaultBackground()
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
