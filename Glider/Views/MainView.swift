//
//  MainView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

struct MainView: View {
    @State private var isAutoConnectVisible = false
//    @Environment(\.isKeyboardVisible) var isKeyboardVisible
    
    var body: some View {
        NavigationView {
            ZStack {
                AutoConnectView(isVisible: $isAutoConnectVisible)
            }
            //.defaultBackground()
            .onAppear {
                // onAppear doesnt work on navigationItem so pass the onAppear/onDissapear via a binding variable: https://developer.apple.com/forums/thread/655338
                DispatchQueue.main.async {
                    isAutoConnectVisible = true
                }
            }
            .onDisappear() {
                DispatchQueue.main.async {
                    isAutoConnectVisible = false
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())        // Use a single view also on iPad
//        .gesture(TapGesture().onEnded{
//            hideKeyboard()
//        }, including: .none)

    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

