//
//  ConnectedTabView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI
import FileTransferClient

struct ConnectedTabView: View {
    enum Tabs: Int {
        case connected = 0
        case log = 1
        case debug = 2
    }
    
    @EnvironmentObject private var connectionManager: FileClientPeripheralConnectionManager
    @State private var selectedTabIndex: Int = Tabs.connected.rawValue
    
     // MARK: - Lifecycle
    init() {
        let navigationBarLargeAppearance = UINavigationBarAppearance()
        navigationBarLargeAppearance.configureWithTransparentBackground()
        
        navigationBarLargeAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarLargeAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        let navigationBarDefaultAppearance = UINavigationBarAppearance()
        navigationBarDefaultAppearance.configureWithOpaqueBackground()
        navigationBarDefaultAppearance.backgroundColor = UIColor(Color("tab_background")) // UIColor(Color("background_gradient_start"))
        navigationBarDefaultAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarDefaultAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navigationBarDefaultAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarDefaultAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarLargeAppearance
        
        #if swift(>=5.5)
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarDefaultAppearance
        }
        #endif

        //
        /*
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.gray)
        UITabBar.appearance().barTintColor = UIColor(Color("tab_background"))
        */
        
        let tabbarAppearance = UITabBarAppearance()
        tabbarAppearance.configureWithOpaqueBackground()
        tabbarAppearance.backgroundColor = UIColor(named: "maintab_background")
        UITabBar.appearance().standardAppearance = tabbarAppearance
        #if swift(>=5.5)
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabbarAppearance
        }
        #endif
    }
    
    // MARK: - View
    var body: some View {
        
        // TabView
        TabView(selection: $selectedTabIndex) {
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "link")
                }
                .tag(Tabs.connected.rawValue)
            
            
            FileExplorerView()
                .tabItem {
                    Label("Explorer", systemImage: "folder")// "folder.badge.gearshape")
                }
                .tag(Tabs.debug.rawValue)
            
            LogView()
                .tabItem {
                    Label("Log", systemImage: "terminal")
                }
                .tag(Tabs.connected.rawValue)
        }
        .accentColor(Color("accent_main"))
    }
}

struct ConnectedView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedTabView()
            .environmentObject(FileClientPeripheralConnectionManager.shared)
    }
}
