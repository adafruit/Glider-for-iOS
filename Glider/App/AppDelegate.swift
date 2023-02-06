//
//  AppDelegate.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // UI
        setupAppearances()
        
        // Setup ConnectionManager userDefaults
        //ConnectionManager.shared.userDefaults = UserDefaults(suiteName: "group.2X94RM7457.com.adafruit.Glider")!
        
        /* Debug delete all domains*/
        NSFileProviderManager.getDomainsWithCompletionHandler() { (domains, error) in
            domains.forEach { domain in
                NSFileProviderManager.remove(domain) { error in
                    
                }
            }
        }
        
        
        return true
    }
    
    private func setupAppearances() {
        
        // Navigation bar title
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        
        /*
        // Navigation bar background
        UINavigationBar.appearance().barTintColor = .clear
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        */
        
        
        // List background
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().backgroundColor = .clear
        
        // Alerts
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .blue
    }
}
