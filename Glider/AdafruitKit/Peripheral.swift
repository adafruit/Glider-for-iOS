//
//  Peripheral.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation

protocol Peripheral {
    var name: String? { get }
    var address: String { get }
    var nameOrAddress: String { get }

    var createdTime: CFAbsoluteTime { get }
    
    func disconnect()
}

