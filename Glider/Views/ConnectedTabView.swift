//
//  ConnectedTabView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI

struct ConnectedTabView: View {

    // State
    enum Tabs: Int {
        case peripherals = 0
        case fileExplorer = 1
        case log = 2
    }
    @State private var selectedTabIndex: Int = Tabs.peripherals.rawValue

    // Data
    private let connectionManager: ConnectionManager
    private let savedBondedBlePeripherals: SavedBondedBlePeripherals
    private let savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals

     // MARK: - Lifecycle
    init(connectionManager: ConnectionManager,
         savedBondedBlePeripherals: SavedBondedBlePeripherals,
         savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals
    ) {
        self.connectionManager = connectionManager
        self.savedBondedBlePeripherals = savedBondedBlePeripherals
        self.savedSettingsWifiPeripherals = savedSettingsWifiPeripherals
        
        // UI
        setupUIAppearance()
    }

    // MARK: - View
    var body: some View {
        
        // TabView
        TabView(selection: $selectedTabIndex) {
            PeripheralsView(connectionManager: connectionManager, savedSettingsWifiPeripherals: savedSettingsWifiPeripherals)
                .navigationBarColor(backgroundColor: UIColor(named: "background_default"), titleColor: .white)
                .tabItem {
                    Label("Peripherals", systemImage: "link")
                }
                .tag(Tabs.peripherals.rawValue)
                .environmentObject(savedBondedBlePeripherals)
            
            
            FileExplorerView()
                .navigationBarColor(backgroundColor: UIColor(named: "background_default"), titleColor: .white)
                .tabItem {
                    Label("Explorer", systemImage: "folder")
                }
                .tag(Tabs.fileExplorer.rawValue)
        
            
            LogView()
                .navigationBarColor(backgroundColor: UIColor(named: "background_default"), titleColor: .white)
                .tabItem {
                    Label("Log", systemImage: "terminal")
                }
                .tag(Tabs.log.rawValue)
        }
        .accentColor(Color("accent_main"))
    }
    
    // MARK: - UI Appearance
    private func setupUIAppearance() {/*
        let navigationBarLargeAppearance = UINavigationBarAppearance()
        navigationBarLargeAppearance.configureWithTransparentBackground()
        
        navigationBarLargeAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarLargeAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        let navigationBarDefaultAppearance = UINavigationBarAppearance()
        navigationBarDefaultAppearance.configureWithOpaqueBackground()
        navigationBarDefaultAppearance.backgroundColor = UIColor(Color("tab_background"))
        navigationBarDefaultAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarDefaultAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navigationBarDefaultAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarDefaultAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarLargeAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarDefaultAppearance*/
        
        let tabbarAppearance = UITabBarAppearance()
        tabbarAppearance.configureWithOpaqueBackground()
        tabbarAppearance.backgroundColor = UIColor(named: "maintab_background")
        UITabBar.appearance().standardAppearance = tabbarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabbarAppearance
    }
}


// MARK: - Previews
struct ConnectedView_Previews: PreviewProvider {
    static var previews: some View {
        
        let connectionManager = ConnectionManager(
            bleManager: BleManagerFake(), blePeripheralScanner: BlePeripheralScannerFake(),
            wifiPeripheralScanner: BonjourScannerFake(),
            onBlePeripheralBonded: nil,
            onWifiPeripheralGetPasswordForHostName: nil
        )
        
        ConnectedTabView(
            connectionManager: connectionManager,
            savedBondedBlePeripherals: SavedBondedBlePeripherals(),
            savedSettingsWifiPeripherals: SavedSettingsWifiPeripherals()
        )
    }
}
