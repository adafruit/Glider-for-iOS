//
//  FileMetadataCache.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import Foundation
import FileProvider
import FileTransferClient

class FileMetadataCache {
    
    // Singleton
    static let shared = FileMetadataCache()
    
    // Data
    private static let userDefaults = UserDefaults(suiteName: "group.com.adafruit.Glider")!        // Shared between the app and extensions
    private static let fileMetadataKey = "metadata_6"
    private static let buildNumberKey = "buildNumber"

    private var metadata = [NSFileProviderItemIdentifier: FileProviderItem]()
            
    // MARK: - Lifecycle
    private init() {
        // Load from userDefaults
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if UserDefaults.standard.string(forKey: Self.buildNumberKey) != buildNumber {           // Reset if build number changed
            DLog("build number changed. Reset metadata")
            clear()
            UserDefaults.standard.set(buildNumber, forKey: Self.buildNumberKey)
        }
        else {
            loadFromUserDefaults()
        }
        
        // If is the first time add root container
        if metadata[.rootContainer] == nil {
            metadata[.rootContainer] = FileProviderItem(blePeripheralIdentifier: nil)
            saveToUserDefaults()
        }
    }
    
    // MARK: - Actions
    /*
    mutating func setFileProviderItems(items: [FileProviderItem]) {
        for item in items {
            metadata[item.itemIdentifier] = item
        }
        
        // Update user Defaults
        saveToUserDefaults()
    }*/
    
    func setFileProviderItem(item: FileProviderItem) {
        metadata[item.itemIdentifier] = item
                
        // Update user Defaults
        saveToUserDefaults()
    }
    
    func setDirectoryItems(items: [FileProviderItem]) {
        guard let firstItem = items.first else { return }
        let commonPath = firstItem.path
        let commonPeripheral = firstItem.blePeripheralIdentifier
        let areAllDirectoriesEqual = items.map{$0.path}.allSatisfy{$0 == commonPath}
        guard areAllDirectoriesEqual else {
            DLog("setDirectoryItems error: all items should have the same directory ")
            return
        }
        
        // Sync: Delete any previous contents of the directory that is not present in the new items array
        let itemsIdentifiers = items.map {$0.itemIdentifier}
        let itemsToDelete = metadata.filter({(fileProviderItemIdentifier, fileProviderItem) in
            let alreadyExists = fileProviderItem.blePeripheralIdentifier == commonPeripheral && fileProviderItem.path == commonPath
            let isInNewSet = itemsIdentifiers.contains(fileProviderItem.itemIdentifier)    // This check could be elminated because we are going to add all new elements later. So we could just delete all of the current elements in the directory
            return alreadyExists && !isInNewSet && fileProviderItemIdentifier != .rootContainer && !FileTransferPathUtils.isRootDirectory(path: fileProviderItem.path)
        })
        let _ = itemsToDelete.map { metadata.removeValue(forKey: $0.key) }      // Delete items
        if itemsToDelete.count > 0 {
            DLog("Metadata: deleted \(itemsToDelete.count) items that are no longer present in directory: \(commonPath)")
        }
                
        // Insert updated items
        for item in items {
            metadata[item.itemIdentifier] = item
        }
        DLog("Metadata: added \(items.count) items in directory: \(commonPath)")
        
        // Update user Defaults
        saveToUserDefaults()
    }
    
    func deleteFileProviderItem(identifier: NSFileProviderItemIdentifier) {
        metadata.removeValue(forKey: identifier)
        //metadata[identifier] = nil
    }
    
    func fileProviderItem(for identifier: NSFileProviderItemIdentifier) -> FileProviderItem? {
        return metadata[identifier]
    }
    
    // MARK: - Save / Load from UserDefaults
    private func saveToUserDefaults() {
        guard let encodedData = try? JSONEncoder().encode(metadata) else { DLog("Error encoding metadata"); return }
            
        Self.userDefaults.set(encodedData, forKey: Self.fileMetadataKey)
    }
    
    private func loadFromUserDefaults() {
        guard let decodedData = Self.userDefaults.object(forKey: Self.fileMetadataKey) as? Data else { return }
        guard let decodedMetadata = try? JSONDecoder().decode([NSFileProviderItemIdentifier: FileProviderItem].self, from: decodedData) else {  DLog("Error decoding metadata"); return  }
        
        self.metadata = decodedMetadata
    }
    
    private func clear() {
        metadata = [:]
        saveToUserDefaults()
    }
}

extension NSFileProviderItemIdentifier: Codable {}
