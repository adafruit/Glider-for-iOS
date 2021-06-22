//
//  Settings.swift
//  BluefruitPlayground
//
//  Created by Antonio García on 10/10/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation

class Settings {
    // Constants
    private static let autoconnectPeripheralIdentifierKey = "autoconnectPeripheralIdentifier"
    //private static let autoconnectPeripheralAdvertisementDataKey = "autoconnectPeripheralAdvertisementData"

    // MARK: - AutoConnect
    static var autoconnectPeripheralUUID: UUID? {
        get {
            guard let uuidString = UserDefaults.standard.string(forKey: Self.autoconnectPeripheralIdentifierKey), let uuid = UUID(uuidString: uuidString) else { return nil}
            return uuid
        }
        
        set {
            let uuidString = newValue?.uuidString
            DLog("Set autoconnect peripheral: \(uuidString ?? "<nil>")")
            UserDefaults.standard.set(uuidString, forKey: Self.autoconnectPeripheralIdentifierKey)
        }
    }
    /*
    static var autoconnectPeripheral: (identifier: UUID, advertisementData: [String: Any])? {
        get {
            guard let uuidString = UserDefaults.standard.string(forKey: Self.autoconnectPeripheralIdentifierKey), let uuid = UUID(uuidString: uuidString), let advertisementData = UserDefaults.standard.dictionary(forKey: Self.autoconnectPeripheralAdvertisementDataKey) else { return nil}
                        
            return (uuid, advertisementData)
        }
        
        set {
            let uuidString = newValue?.identifier.uuidString
            DLog("Set autoconnect peripheral: \(uuidString ?? "<nil>")")

            UserDefaults.standard.set(uuidString, forKey: Self.autoconnectPeripheralIdentifierKey)
            UserDefaults.standard.set(newValue?.advertisementData, forKey: Self.autoconnectPeripheralAdvertisementDataKey)
        }
    }*/
    
    static func clearAutoconnectPeripheral() {
        autoconnectPeripheralUUID = nil
    }

    // Common load and save
    static func getBoolPreference(key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setBoolPreference(key: String, newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: key)
    }

    // MARK: - Defaults
    static func registerDefaults() {
        let path = Bundle.main.path(forResource: "DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String: AnyObject]

        UserDefaults.standard.register(defaults: defaultPrefs)
    }

    static func resetDefaults() {
        let appDomain = Bundle.main.bundleIdentifier!
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: appDomain)
    }
}
