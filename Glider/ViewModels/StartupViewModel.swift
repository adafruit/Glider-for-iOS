//
//  StartupViewModel.swift
//  Glider
//
//  Created by Antonio García on 13/5/21.
//

import UIKit

class StartupViewModel: ObservableObject {

    // Published
    enum ActiveAlert {
        case none
        case bluetoothError(description: String)
        
        var isActive: Bool {
            switch self {
            case .none: return false
            default: return true
            }
        }
    }
    
    @Published var activeAlert: ActiveAlert = .none
    
    func setupBluetooth() {
        // TODO: check Bluetooth status
        // TODO: reconnect to known peripheral

        
        
    }
}
