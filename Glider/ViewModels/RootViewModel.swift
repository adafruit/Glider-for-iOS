//
//  RootViewModel.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import Foundation

class RootViewModel: ObservableObject {
    
    // Published
    enum Destination {
        case startup
        case main
        case test
        case todo
    }
    
    @Published var destination: Destination = AppEnvironment.isRunningTests ? .test : .startup
    
    
    // MARK: - Actions
    func gotoMain() {
        destination = .main
    }
    
    func gotoStartup() {
        destination = .startup
    }
}
