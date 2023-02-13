//
//  ItemEnumerator.swift
//  Glider
//
//  Created by Antonio García on 21/1/23.
//

import FileProvider
import os.log

class ItemEnumerator: NSObject, NSFileProviderEnumerator
{
    private let logger = Logger.createLogger(category: "ItemEnumerator")
    private let metadataCache: FileMetadataCache
    private let enumeratedItem: FileProviderItem
    private var lastUpdateDate = Date.distantPast

    private var connectionManager: ConnectionManager
    
    private let path: String
    
    init(enumeratedItem: FileProviderItem, metadataCache: FileMetadataCache, connectionManager: ConnectionManager) {
        logger.info("init \(enumeratedItem.fullFilePath)")
        
        self.metadataCache = metadataCache
        self.enumeratedItem = enumeratedItem
        self.connectionManager = connectionManager
        
        self.path = enumeratedItem.path + (enumeratedItem.entry == nil ? "" : enumeratedItem.entry!.name + FileTransferPathUtils.pathSeparator)
        
        super.init()
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        logger.info("enumerateItems: \(observer.description) startingAt: \(page.rawValue)")
        
        let gliderClient = GliderClient.shared(peripheralType: enumeratedItem.peripheralType)
        gliderClient.listDirectory(path: self.path, connectionManager: connectionManager) { [weak self] result in
            guard let self = self else { return }
            
            
            switch result {
            case .success(let entries):
                if let entries = entries {
                    
                    // Always update all items returned, even if we are enumerating an specific file
                    let items = entries.map { FileProviderItem(peripheralType: self.enumeratedItem.peripheralType, path: self.path, entry: $0) }
                    //logger.info("listDirectory returned \(items.count) items")
                    self.metadataCache.setDirectoryItems(items: items)
                    self.lastUpdateDate = Date()
                    
                    if self.enumeratedItem.isDirectory {  // Enumerate all items in the directory
                        observer.didEnumerate(items)
                        observer.finishEnumerating(upTo: nil)
                    }
                    else {   // If the enumerator only asked for a specific file, then return only that file
                        let item = entries.filter{$0.name == self.enumeratedItem.filename}.first.map { FileProviderItem(peripheralType: self.enumeratedItem.peripheralType, path: self.path, entry: $0) }
                        if let item = item {
                            observer.didEnumerate([item])
                            observer.finishEnumerating(upTo: nil)
                        }
                        else {
                            self.logger.error("Enumeration for a specific file failed to find that file: '\(self.enumeratedItem.fullFilePath)'")
                            observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                        }
                    }
                    
                }
                else {
                    self.logger.error("listDirectory: nonexistent directory")
                    observer.didEnumerate([])
                    observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                }
                
            case .failure(let error):
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                //observer.finishEnumeratingWithError(NSFileProviderError(.notAuthenticated))
                self.logger.error("listDirectory '\(self.enumeratedItem.fullFilePath)' error: \(error)")
            }
            
            self.logger.info("Enumerate for '\(self.enumeratedItem.fullFilePath)' finished")
        }
        
    }
    
    func invalidate() {
        logger.info("invalidate \(self.enumeratedItem.fullFilePath)")
    }
}
