//
//  WifiPeripheral.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation

struct WifiPeripheral: Peripheral {
    let name: String?
    let address: String
    var nameOrAddress: String { return name ?? address }
    
    let port: Int

    let createdTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    
    func baseUrl() -> String {
        var baseUrlString = "http://\(address)"
        if port != 80 {
            baseUrlString += ":\(port)"
        }
        return baseUrlString
    }
    
     func disconnect() {
        DLog("TODO: disconnect")
    }
    
    
}
