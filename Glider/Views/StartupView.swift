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
        ZStack {
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
        }
        .defaultBackground()
        .onAppear() {
            model.setupBluetooth()
        }
    }
}

struct StartupView_Previews: PreviewProvider {
    static var previews: some View {
        StartupView()
            .environmentObject(RootViewModel())
    }
    
}
