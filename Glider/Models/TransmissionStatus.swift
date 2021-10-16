//
//  TransmissionStatus.swift
//  Glider
//
//  Created by Antonio García on 15/10/21.
//

import Foundation

struct TransmissionProgress {
    var description: String
    var transmittedBytes: Int
    var totalBytes: Int?
    
    init (description: String) {
        self.description = description
        transmittedBytes = 0
    }
}

struct TransmissionLog: Equatable {
    enum TransmissionType: Equatable {
        case read(size: Int)
        case write(size: Int, date: Date?)
        case delete
        case listDirectory(numItems: Int?)
        case makeDirectory
        case error(message: String)
        
        var isError: Bool {
            switch self {
            case .error: return true
            default: return false
            }
        }
    }
    let type: TransmissionType
    
    var description: String {
        
        let modeText: String
        switch self.type {
        case .read(let size): modeText = "Received \(size) bytes"
        case let .write(size, date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            modeText = (size == 0 ? "Created empty file" : "Sent \(size) bytes") + (date == nil ? "" : ". Modification time: \(formatter.string(from: date!))")
        case .delete: modeText = "Deleted file"
        case .listDirectory(numItems: let numItems): modeText = numItems != nil ? "Listed directory: \(numItems!) items" : "Listed nonexistent directory"
        case .makeDirectory: modeText = "Created directory"
        case .error(let message): modeText = message
        }
        
        return modeText
    }
}
