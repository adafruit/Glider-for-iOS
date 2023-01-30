//
//  Logger+Subsystems.swift
//  QuantumPainter
//
//  Created by Antonio García on 13/4/21.
//

import Foundation
import os

extension Logger {

    static func createLogger(categoryClass: Any) -> Logger {
        return createLogger(category: String(describing: categoryClass))
    }

    static func createLogger(category: String) -> Logger {
        return Logger(subsystem: Bundle.main.bundleIdentifier!, category: category)
    }
    
    public func dumpDebug(title: String? = nil, message: Any) {
        guard AppEnvironment.isDebug else { return }
        let string = (title ?? String()) + toString(message)
        debug("\(string)")
    }

    public func dumpError(title: String? = nil, message: Any) {
        guard AppEnvironment.isDebug else { return }
        let string = (title ?? String()) + toString(message)
        error("\(string)")
    }
    
    private func toString(_ content: Any) -> String {
        var string = String()
        Swift.dump(content, to: &string)
        return string
    }

}
