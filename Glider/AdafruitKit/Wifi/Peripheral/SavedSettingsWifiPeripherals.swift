//
//  SavedSettingsWifiPeripherals.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

class SavedSettingsWifiPeripherals: ObservableObject {
    private static let kSettingsKey = "settings"
    
    struct Settings: Codable {
        var name: String
        var hostName: String?
        var password: String
    }
    
    @Published var peripheralSettings = [Settings]()
    
    init() {
        peripheralSettings = getPeripheralSettings()
    }
    
    func getPassword(hostName: String) -> String? {
        let existingPeripheral = peripheralSettings.first { $0.hostName == hostName }
        return existingPeripheral?.password
    }
    
    func add(name: String, hostName: String, password: String) {
        let existingPeripheral = peripheralSettings.first { $0.hostName == hostName }
        
        // Continue if not exist or the name has change
        if existingPeripheral == nil || existingPeripheral!.password != password {
            
            // If the name has changed, remove it to add it with the new name
            if let hostName = existingPeripheral?.hostName {
                remove(hostName: hostName)
            }
            
            peripheralSettings.append(Settings(name: name, hostName: hostName, password: password))
            setPeripheralsSettings(settings: peripheralSettings)
        }
    }
    
    func remove(hostName: String) {
        peripheralSettings.removeAll { $0.hostName == hostName }
    }
    
    func clear() {
        setPeripheralsSettings(settings: [])
    }
    
    // MARK: - User Defaults
    private func getPeripheralSettings() -> [Settings] {
        guard let savedSettings = UserDefaults.standard.object(forKey: Self.kSettingsKey) as? Data else {
            return []
        }
        
        guard let settings = try? JSONDecoder().decode([Settings].self, from: savedSettings) else {
            return[]
            
        }
        return settings    
    }
    
    private func setPeripheralsSettings(settings: [Settings]) {
        if let encodedSettings = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encodedSettings, forKey: Self.kSettingsKey)
        }
    }
}
