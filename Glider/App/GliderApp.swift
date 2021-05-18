//
//  GliderApp.swift
//  Glider
//
//  Created by Antonio García on 13/5/21.
//

import SwiftUI

@main
struct GliderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
