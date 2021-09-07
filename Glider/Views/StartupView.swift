//
//  StartupView.swift
//  Glider
//
//  Created by Antonio García on 13/5/21.
//

import SwiftUI

struct StartupView: View {
    @StateObject private var model = StartupViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    var body: some View {
        VStack {
            Image("glider_logo")
            
            Text("Restoring Connection...")
                .foregroundColor(Color.white)
                .opacity(model.isRestoringConnection ? 1 : 0)
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
        }
        .defaultPlainBackground()
        .modifier(Alerts(activeAlert: $model.activeAlert, model: model))
        .onAppear {
            model.setupBluetooth()
        }
        .onChange(of: model.isStartupFinished) { isStartupFinished in
            if isStartupFinished {
                rootViewModel.gotoMain()
            }
        }
    }
    
    private struct Alerts: ViewModifier {
        @Binding var activeAlert: StartupViewModel.ActiveAlert?
        @ObservedObject var model: StartupViewModel

        func body(content: Content) -> some View {
            content
                .alert(item: $activeAlert, content:  { alert in
                    switch alert {
                    case .bluetoothUnsupported:
                        return Alert(
                            title: Text("Error"),
                            message: Text("This device doesn't support Bluetooth Low Energy which is needed to connect to Bluefruit devices"),
                            dismissButton: .cancel(Text("Ok")) {
                                model.setupBluetooth()
                            })
                        
                    case .fileTransferErrorOnReconnect:
                        return Alert(
                            title: Text("Error"),
                            message: Text("Error initializing FileTransfer service"),
                            dismissButton: .cancel(Text("Ok")) {
                                model.setupBluetooth()
                            })
                    }
                })
        }
    }
}

struct StartupView_Previews: PreviewProvider {
    static var previews: some View {
        StartupView()
            .environmentObject(RootViewModel())
    }
}
