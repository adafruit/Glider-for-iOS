//
//  Config.swift
//  Glider
//
//  Created by Antonio García on 14/12/21.
//

import Foundation

struct Config {
    // MARK: - Screenshot Mode
    public static var isSimulatingBluetooth: Bool {
        #if SIMULATEBLUETOOTH
        return true
        #else
        return false
        #endif
    }
    
    public static let areFastlaneSnapshotsRunning = UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")
}
