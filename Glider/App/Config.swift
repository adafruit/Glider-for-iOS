//
//  Config.swift
//  Glider
//
//  Created by Antonio García on 14/12/21.
//

import Foundation

struct Config {

    public static let sharedUserDefaultsSuitName = "group.com.adafruit.Glider"

    // MARK: - Screenshot Mode
    public static let areFastlaneSnapshotsRunning = UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")
}
