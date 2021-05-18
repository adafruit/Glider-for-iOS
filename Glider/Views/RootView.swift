//
//  RootView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

struct RootView: View {
    @StateObject private var model = RootViewModel()
    
    var body: some View {
        Group {
            switch model.destination {
            case .startup:
                StartupView()
            case .main:
                MainView()
            default:
                TodoView()
            }
        }
   
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

