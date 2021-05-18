//
//  AppEnvironment.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import Foundation

public struct AppEnvironment {
    
    static var isDebug: Bool {
        return _isDebugAssertConfiguration()
    }
    
    static var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    static var inSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    static var appVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
