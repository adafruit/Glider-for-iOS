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
            Text("Restoring Connection...")
                .foregroundColor(Color.white)
                .if(!model.isRestoringConnection) {
                    $0.hidden()
                }
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
        }
        .defaultBackground()
        .modifier(StartupAlerts(model: model))
        .onAppear {
            model.setupBluetooth()
        }
        .onChange(of: model.isStartupFinished) { isStartupFinished in
            if isStartupFinished {
                rootViewModel.gotoMain()
            }
        }
    }
    
    private struct StartupAlerts: ViewModifier {
        @ObservedObject var model: StartupViewModel

        private var isAlertPresented: Binding<Bool> { Binding(
            get: { self.model.activeAlert.isActive },
            set: { if !$0 { self.model.activeAlert.setInactive() } }
        )
        }
        
        func body(content: Content) -> some View {
            content
                .alert(isPresented: isAlertPresented, content: {
                    switch model.activeAlert {
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
                        
                    case .none:
                        return Alert(title: Text("undefined"))
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
