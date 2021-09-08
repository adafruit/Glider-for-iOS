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
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // Manage logging persistence
                .onChange(of: scenePhase) { scenePhase in
                    switch scenePhase {
                    case .background:
                        LogManager.shared.save()
                    case .inactive:
                        LogManager.shared.save()
                    case .active:
                        LogManager.shared.load()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
