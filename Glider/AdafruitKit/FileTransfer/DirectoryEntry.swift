//
//  DirectoryEntry.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

public struct DirectoryEntry: Codable {
    public enum EntryType: Codable {
        case file(size: Int)
        case directory
    }

    public let name: String
    public let type: EntryType
    public let modificationDate: Date?

    public init(name: String, type: EntryType, modificationDate: Date?) {
        self.name = name
        self.type = type
        self.modificationDate = modificationDate
    }
    
    public var isDirectory: Bool {
        switch type {
        case .directory: return true
        default: return false
        }
    }
    
    public var isHidden: Bool {
        return name.starts(with: ".")
    }
}
