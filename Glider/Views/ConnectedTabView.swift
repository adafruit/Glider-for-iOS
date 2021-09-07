//
//  ConnectedTabView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI

struct ConnectedTabView: View {
    enum Tabs: Int {
        case connected = 0
        case log = 1
        case debug = 2
    }
    
    @State private var selectedTabIndex: Int = Tabs.connected.rawValue
    
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

        //
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.gray)
        UITabBar.appearance().barTintColor = UIColor(Color("tab_background"))
    }
    
    var body: some View {
        TabView(selection: $selectedTabIndex) {
            InfoView(fileTransferClient: AppState.shared.fileTransferClient)
                .tabItem {
                    Label("Info", systemImage: "link")
                }
                .tag(Tabs.connected.rawValue)

    
            FileTransferView(fileTransferClient: AppState.shared.fileTransferClient)
                .tabItem {
                    Label("Tests", systemImage: "folder")// "folder.badge.gearshape")
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
    }
}
