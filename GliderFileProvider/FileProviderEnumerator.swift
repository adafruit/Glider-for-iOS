//
//  FileProviderEnumerator.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import FileProvider
import FileTransferClient

/// Enumerator for both directories and files
class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    // Data
    private var metadataCache: FileMetadataCache
    private let blePeripheral: BlePeripheral?
    private let path: String
    private let filename: String?       // If not nil the enumerator will only return information for a specific file
    
    private var fullPath: String { path + (filename ?? "") }
    private var lastUpdateDate: Date?
    
    // MARK: -
    
    /// Set the filename to nil to enumerate directories, or provide a filename to enumerate only that specific file
    init (metadataCache: FileMetadataCache, blePeripheral: BlePeripheral?, path: String = FileTransferPathUtils.rootDirectory, filename: String? = nil) {
        self.metadataCache = metadataCache
        self.blePeripheral = blePeripheral
        self.path = path
        self.filename = filename
        super.init()
    }
    
    /*
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }*/

    func invalidate() {
        DLog("FileProviderEnumerator for \(self.path) invalidate")
        // Perform invalidation of server connection if necessary
        //gliderClient.disconnect()
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        /*
         - inspect the page to determine whether this is an initial or a follow-up request
         
         If this is an enumerator for a directory, the root container or all directories:
         - perform a server request to fetch directory contents
         If this is an enumeratbor for the active set:
         - perform a server request to update your local database
         - fetch the active set from your local database
         
         - inform the observer about the items returned by the server (possibly multiple times)
         - inform the observer that you are finished with this page
         */
        
        
        DLog("Enumerate '\(blePeripheral?.debugName ?? "")\(FileProviderItem.peripheralSeparator)\(self.fullPath)' requested")
        if let blePeripheral = blePeripheral {
            enumeratePeripheralItems(blePeripheral: blePeripheral, for: observer, startingAt: page)
        }
        else {
            let peripherals = FileTransferConnectionManager.shared.peripherals
            let items = peripherals.map { FileProviderItem(blePeripheralIdentifier: $0.identifier) }
            
            self.metadataCache.setDirectoryItems(items: items)
            self.lastUpdateDate = Date()
            
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
            DLog("Enumerate '\(blePeripheral?.debugName ?? "")\(FileProviderItem.peripheralSeparator)\(self.fullPath)' finished. \(items.count) found")
        }
    }
    
    private func enumeratePeripheralItems(blePeripheral: BlePeripheral, for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let gliderClient = GliderClient.shared(peripheralIdentifier: blePeripheral.identifier)
        gliderClient.listDirectory(path: self.path) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let entries):
                if let entries = entries {
                    
                    // Always update all items returned, even if we are enumerating an specific file
                    let items = entries.map { FileProviderItem(blePeripheralIdentifier: blePeripheral.identifier, path: self.path, entry: $0) }
                    //DLog("listDirectory returned \(items.count) items")
                    self.metadataCache.setDirectoryItems(items: items)
                    self.lastUpdateDate = Date()
                    
                    if let filename = self.filename {   // If the enumerator only asked for a specific file, then return only that file
                        let item = entries.filter{$0.name == filename}.first.map { FileProviderItem(blePeripheralIdentifier: blePeripheral.identifier, path: self.path, entry: $0) }
                        if let item = item {
                            observer.didEnumerate([item])
                            observer.finishEnumerating(upTo: nil)
                        }
                        else {
                            DLog("Enumeration for a specific file failed to find that file: '\(self.fullPath)'")
                            observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                        }
                    }
                    else {  // Enumerate all items in the directory
                        observer.didEnumerate(items)
                        observer.finishEnumerating(upTo: nil)
                    }
                }
                else {
                    DLog("listDirectory: nonexistent directory")
                    observer.didEnumerate([])
                    observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                }
                
            case .failure(let error):
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                //observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
                if self.blePeripheral == nil {
                    DLog("Error: enumeratePeripheralItems with nil peripehral")
                }
                else {
                    DLog("listDirectory '\(self.path)' error: \(error)")
                }
            }
            
            DLog("Enumerate for '\(blePeripheral.debugName)\(FileProviderItem.peripheralSeparator)\(self.fullPath)' finished")
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        /* TODO:
         - query the server for updates since the passed-in sync anchor
         
         If this is an enumerator for the active set:
         - note the changes in your local database
         
         - inform the observer about item deletions and updates (modifications + insertions)
         - inform the observer when you have finished enumerating up to a subsequent sync anchor
         */
        
        DLog("enumerateChanges for anchor: \(anchor.rawValue)")
        guard let data = TimeInterval(data: anchor.rawValue) else { return }
        let anchorDate = Date(timeIntervalSince1970: data)
        DLog("enumerateChanges for anchor date: \(anchorDate)")
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        guard let lastUpdateDate = self.lastUpdateDate else { completionHandler(nil); return }
        
        let data = lastUpdateDate.timeIntervalSince1970.data
        let anchor = NSFileProviderSyncAnchor(data)
        completionHandler(anchor)
    }
}

