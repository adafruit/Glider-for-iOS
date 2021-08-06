//
//  FileMetadataCache.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import Foundation
import FileProvider


struct FileMetadataCache {
    private static let userDefaults = UserDefaults(suiteName: "group.com.adafruit.Glider")!        // Shared between the app and extensions
    private static let fileMetadataKey = "metadataKey"
    
    private var metadata = [NSFileProviderItemIdentifier: FileProviderItem]()
            
    init() {
        // Load from userDefaults
        loadFromUserDefaults()
        
        // If is the first time add root container
        if metadata.isEmpty {
            metadata[.rootContainer] = FileProviderItem(path: FileTransferPathUtils.rootDirectory, entry: BlePeripheral.DirectoryEntry(name: "", type: .directory))
            saveToUserDefaults()
        }
    }
    
    mutating func setFileProviderItems(items: [FileProviderItem]) {
        for item in items {
            metadata[item.itemIdentifier] = item
        }
        
        // Update user Defaults
        saveToUserDefaults()
    }
    
    mutating func deleteFileProviderItem(identifier: NSFileProviderItemIdentifier) {
        metadata[identifier] = nil
    }
    
    func fileProviderItem(for identifier: NSFileProviderItemIdentifier) -> FileProviderItem? {
        return metadata[identifier]
    }
    
    // MARK: - Save / Load from UserDefaults
    private func saveToUserDefaults() {
        guard let encodedData = try? JSONEncoder().encode(metadata) else { DLog("Error encoding metadata"); return }
            
        Self.userDefaults.set(encodedData, forKey: Self.fileMetadataKey)
    }
    
    private mutating func loadFromUserDefaults() {
        guard let decodedData = Self.userDefaults.object(forKey: Self.fileMetadataKey) as? Data else { return }
        guard let decodedMetadata = try? JSONDecoder().decode([NSFileProviderItemIdentifier: FileProviderItem].self, from: decodedData) else {  DLog("Error decoding metadata"); return  }
        
        self.metadata = decodedMetadata
    }
}

extension NSFileProviderItemIdentifier: Codable {}
