//
//  AppDelegate.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Settings
        Settings.registerDefaults()
        
        // UI
        setupAppearances()
        
        return true
    }
    
    private func setupAppearances() {
        // Navigation bar title
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        
        // List background
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().backgroundColor = .clear
        
        // Alerts
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .blue
    }
}
