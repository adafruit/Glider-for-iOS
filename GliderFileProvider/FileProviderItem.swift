//
//  FileProviderItem.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import FileProvider
import UniformTypeIdentifiers

final class FileProviderItem: NSObject, NSFileProviderItem {

    private(set) var path: String
    private(set) var entry: BlePeripheral.DirectoryEntry
    var lastUpdate: Date            // Used to keep track of which files has been modified locally
    var creation: Date
    
    var fullPath: String { path + entry.name }
    
    init(path: String, entry: BlePeripheral.DirectoryEntry) {
        let pathEndingWithSeparator = path.hasSuffix("/") ? path : path.appending("/")      // Force a trailing separator
        self.path = pathEndingWithSeparator
        self.entry = entry
        self.creation = Date()
        self.lastUpdate = self.creation
    }
    
    // MARK: - Mandatory properties
    var itemIdentifier: NSFileProviderItemIdentifier {
        return itemIdentifier(from: fullPath)
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        let parentPath: String
        
        // Remove leading '/' and find the next one. Keep anything after the one found
        let pathWithoutLeadingSlash = path.deletingPrefix("/")
        if let indexOfFirstSlash = (pathWithoutLeadingSlash.range(of: "/")?.lowerBound) {
            let parentPathWithoutLeadingSlash = String(pathWithoutLeadingSlash.prefix(upTo: indexOfFirstSlash))
            parentPath = "/"+parentPathWithoutLeadingSlash
        }
        else {      // Is root (only the leading '/' found)
            parentPath = path       // The parent for root is root
        }
        
        //DLog("parent for: '\(fullPath)' -> '\(parentPath)'")
        return itemIdentifier(from: parentPath)
        
    }
    
    var filename: String {
        if fullPath == "/" {
            return "root"
        }
        else {
            return entry.name
        }
    }

    var capabilities: NSFileProviderItemCapabilities {
        if entry.isDirectory {
            return [.allowsContentEnumerating, .allowsAddingSubItems, .allowsRenaming, .allowsDeleting]
        }
        else {
            return [.allowsReading, .allowsWriting, .allowsDeleting]
        }
//        return .allowsAll
    }
    
    var contentType: UTType {
        // Types defined here: https://developer.apple.com/documentation/uniformtypeidentifiers/system_declared_uniform_type_identifiers
        if entry.isDirectory {
            return .folder
        }
        else {
            let fileExtension = URL(fileURLWithPath: entry.name).pathExtension
            return UTType(filenameExtension: fileExtension) ?? .item
        }
    }
    
    var documentSize: NSNumber? {
        guard case let .file(size) = entry.type else { return nil }
        return size as NSNumber
    }
    
    // MARK: - Optional properties
    var contentModificationDate: Date? {
        //  Note: the Bluetooth File protocol doesn't return the modification date, so we are using the last sync date as the modification date
        return lastUpdate
    }
    
    var isMostRecentVersionDownloaded: Bool {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: self.fullPath)
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
    private func itemIdentifier(from path: String) -> NSFileProviderItemIdentifier {
        let isRootDirectory = path == "/"
        if isRootDirectory {
            return .rootContainer
        }
        else {
            return NSFileProviderItemIdentifier(path)
        }
    }
}

extension FileProviderItem: Codable {}