//
//  FileProviderItem.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import FileProvider
import UniformTypeIdentifiers

final class FileProviderItem: NSObject, NSFileProviderItem {
    static let peripheralSeparator: Character = "$"
    static let pathSeparator = "/"
  
    enum PeripheralType: Codable, Equatable, Hashable {
        case rootContainer       // i.e. rootContainer
        case wifi(address: String, name: String?)
        case ble(address: String, name: String?)
        case bleBondedData(address: String, name: String?)
        
        var address: String {
            switch self {
            case .rootContainer: return ""
            case let .wifi(address, _): return address
            case let .ble(address, _): return address
            case let .bleBondedData(address, _): return address
            }
        }
    }

    let peripheralType: PeripheralType
    private(set) var path: String                   // Always includes a trailing separator
    private(set) var entry: DirectoryEntry?         // nil for peripheral root routes (i.e: 37464$/)
    var lastUpdate: Date                            // Used to keep track of which files has been modified locally
    var creation: Date
    
    
    var peripheralRoute: String {
        switch peripheralType {
        case .rootContainer:
            return "\(Self.peripheralSeparator)\(Self.peripheralSeparator)"    // Nothing before the peripheralSeparator
        case let .wifi(address, _),
            let .ble(address, _),
            let .bleBondedData(address, _):
            return "\(address)\(Self.peripheralSeparator)"
        }
    }
    
    var isDirectory: Bool {
        return entry?.isDirectory ?? true      // true for the peripherals root (entry is nil for the peripheral sroot)
    }

    /**
            Full path including the peripheral route
     */
    var fullFilePath: String {
        if let entry = entry {
            return peripheralRoute + path + entry.name
        }
        else {
            return peripheralRoute + path
        }
    }
    
    /**
            Path used for FileTransferClient commands (excluding the peripheral route)
     */
    var fileTransferPath: String {
        if let entry = entry {
            return path + entry.name
        }
        else {
            return path
        }
    }
    
    init(peripheralType: PeripheralType) {
        self.peripheralType = peripheralType
        self.path = FileTransferPathUtils.rootDirectory
        self.entry = nil
        
        self.creation = Date()
        self.lastUpdate = self.creation
    }
    
    convenience init(peripheralType: PeripheralType, path: String, entry: DirectoryEntry) {
        self.init(peripheralType: peripheralType)
        
        let pathEndingWithSeparator = FileTransferPathUtils.pathWithTrailingSeparator(path: path)
        self.path = pathEndingWithSeparator
        self.entry = entry
    }
    
    // MARK: - Mandatory properties
    var itemIdentifier: NSFileProviderItemIdentifier {
        return itemIdentifier(fullPath: fullFilePath)
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        let result: NSFileProviderItemIdentifier
        
        if isRootContainer(fullPath: fullFilePath) {
            result = .rootContainer   // Parent of .rootContainer is .rootContainer
        }
        else if FileTransferPathUtils.isRootDirectory(path: path) && entry == nil {
            result = .rootContainer     // Parent of peripheral root is .rootContainer
        }
        else {
            let parentPath = FileTransferPathUtils.parentPath(from: path)
            let fullPath = peripheralRoute + parentPath
            result = itemIdentifier(fullPath: fullPath)
        }
        
        //DLog("parent for: '\(self.fullFilePath)' -> '\(result.rawValue)'")
        return result
    }
    
    var filename: String {
        let result: String
        if let entry = entry {
            result = entry.name
        }
        else {
            switch peripheralType {
            case .rootContainer:
                result = "Peripherals"
            case let .wifi(address, name),
                let .ble(address, name),
                let .bleBondedData(address, name):
                result = name ?? address
            }
        }

        
        //DLog("filename for: '\(self.fullFilePath)' -> \(result)")
        return result
    }

    var capabilities: NSFileProviderItemCapabilities {
        if let entry = entry {
            if entry.isDirectory {
                return [.allowsContentEnumerating, .allowsAddingSubItems, .allowsRenaming, .allowsDeleting]
            }
            else {
                return [.allowsReading, .allowsWriting, .allowsDeleting]
            }
        }
        else {
            switch peripheralType {
            case .rootContainer:     // Root
                return [.allowsContentEnumerating]
            default:                //  Peripheral root
                return [.allowsContentEnumerating, .allowsAddingSubItems]
            }
        }
        
        //return .allowsAll
        //return [.allowsReading, .allowsWriting, .allowsRenaming, .allowsReparenting, .allowsTrashing, .allowsDeleting]

    }
    
    var contentType: UTType {
        // Types defined here: https://developer.apple.com/documentation/uniformtypeidentifiers/system_declared_uniform_type_identifiers
        
        if let entry = entry {
            if entry.isDirectory {
                return .folder
            }
            else {
                let fileExtension = URL(fileURLWithPath: entry.name).pathExtension
                return UTType(filenameExtension: fileExtension) ?? .item
            }
        }
        else if case .rootContainer = peripheralType { // Root
            return .folder
        }
        else { // Peripheral root
            return .folder
        }
    }
    
    var documentSize: NSNumber? {
        if let entry = entry {
            guard case let .file(size) = entry.type else { return nil }
            return size as NSNumber
        }
        else {  // Peripheral root or Root
            return nil
        }
    }
    
    // MARK: - Optional properties
    var contentModificationDate: Date? {
        //  Note: the Bluetooth File protocol doesn't return the modification date, so we are using the last sync date as the modification date
        return lastUpdate
    }
    
    var isMostRecentVersionDownloaded: Bool {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: self.fullFilePath)
            let localModificationDate = attr[FileAttributeKey.modificationDate] as? Date
            return localModificationDate == self.lastUpdate
        } catch {
            return false
        }
    }
    
    var creationDate: Date? {
        return creation
    }
    
    /*
    var childItemCount: NSNumber? {
        DLog("childItemCount for: \(fullPath)")
        return 0
    }*/
    
    
    // MARK: - Utils
    /*
    var peripheralName: String? {
        guard let blePeripheralIdentifier = blePeripheralIdentifier else { return nil }
        return FileTransferConnectionManager.shared.peripheral(fromIdentifier: blePeripheralIdentifier)?.debugName
    }*/
    
    private func isRootContainer(fullPath: String) -> Bool {
        return peripheralIdentifier(fullPath: fullPath) == nil
    }
    
    private func peripheralIdentifier(fullPath: String) -> String? {
        guard let peripheralSeparatorIndex = fullPath.firstIndex(of: Self.peripheralSeparator) else {
            DLog("Error: unknown peripheralIdentifier: \(fullPath)")
            return nil
        }
        let peripheralIdentifier = fullPath.prefix(upTo: peripheralSeparatorIndex)
        return peripheralIdentifier.isEmpty ? nil : String(peripheralIdentifier)
    }
    
    private func itemIdentifier(fullPath: String) -> NSFileProviderItemIdentifier {
        if isRootContainer(fullPath: fullPath) {
            return .rootContainer
        }
        else {
            return NSFileProviderItemIdentifier(fullPath)
        }
    }
}

extension FileProviderItem: Codable {}
