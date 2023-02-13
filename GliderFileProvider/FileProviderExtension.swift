//
//  FileProviderExtension.swift
//  GliderFileProvider
//
//  Created by Antonio García on 30/1/23.
//

import FileProvider
import os.log

class FileProviderExtension: NSFileProviderExtension {

    // Data
    private let logger = Logger.createLogger(category: "FileProviderExtension")
    private var metadataCache = FileMetadataCache.shared
    private var fileManager = FileManager()
     
    private let appContainer = AppContainerImpl.shared
 
    
    override init() {
        logger.info("init")

        super.init()
    }
    
    deinit {
        logger.info("deinit")
    }

    // MARK: - Mandatory methods
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        guard let item = metadataCache.fileProviderItem(for: identifier) else {
            logger.error("Error: undefined item for identifier: \(identifier.rawValue)")
            throw GliderClient.GliderError.undefinedFileProviderItem(identifier: identifier.rawValue)
        }
        //DLog("item: \(identifier.rawValue) -> \(item.itemIdentifier.rawValue)")
        if AppEnvironment.isDebug, identifier != item.itemIdentifier {
            logger.error("Error: item(for:) wrong result")
        }
        return item
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        
        // resolve the given identifier to a file on disk
        guard let item = try? item(for: identifier) as? FileProviderItem else {
            logger.error("urlForItem: \(identifier.rawValue) -> nil")
            return nil
        }

        let partialPath = item.fullFilePath.deletingPrefix(FileTransferPathUtils.pathSeparator)
        let url = NSFileProviderManager.default.documentStorageURL.appendingPathComponent(partialPath, isDirectory: item.isDirectory)
        //DLog("urlForItem at: \(identifier.rawValue) -> \(url.absoluteString) isDirectory: \(item.isDirectory)")
        return url
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        
        var pathComponents = url.pathComponents
        
        // Remove all common elements with the FileProvider documents storage to get the specific components used as identifier
        let documentsStorageComponents = NSFileProviderManager.default.documentStorageURL.pathComponents
        for component in documentsStorageComponents {
            if component == pathComponents.first {
                pathComponents.removeFirst()
            }
        }
        
        let fullPath = pathComponents.joined(separator: FileTransferPathUtils.pathSeparator)
        let persistentIdentifier = NSFileProviderItemIdentifier(fullPath)
        logger.info("persistentIdentifierForItem at: \(url.absoluteString) -> \(persistentIdentifier.rawValue)")
        return persistentIdentifier
    }
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        logger.info("providePlaceholder at: \(url.absoluteString)")
        
        guard let identifier = persistentIdentifierForItem(at: url) else {
            logger.error("providePlaceholder error .noSuchItem")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        do {
            let fileProviderItem = try item(for: identifier)

            createLocalIntermediateDirectoriesIfNeeded(url: url)
            
            // Write placeholder
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch let error {
            logger.error("providePlaceholder error: \(error)")
            completionHandler(error)
        }
    }
    
    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        logger.info("startProvidingItem at: \(url.absoluteString)")
        
        /*
         Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
         
         This is one of the main entry points of the file provider. We need to check whether the file already exists on disk,
         whether we know of a more recent version of the file, and implement a policy for these cases. Pseudocode:
         
         if !fileOnDisk {
         downloadRemoteFile()
         callCompletion(downloadErrorOrNil)
         } else if fileIsCurrent {
         callCompletion(nil)
         } else {
         if localFileHasChanges {
         // in this case, a version of the file is on disk, but we know of a more recent version
         // we need to implement a strategy to resolve this conflict
         moveLocalFileAside()
         scheduleUploadOfLocalFile()
         downloadRemoteFile()
         callCompletion(downloadErrorOrNil)
         } else {
         downloadRemoteFile()
         callCompletion(downloadErrorOrNil)
         }
         }
         */

        guard let identifier = persistentIdentifierForItem(at: url) else {
            logger.error("startProvidingItem. Unknown identifier")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        guard let fileProviderItem = try? item(for: identifier) as? FileProviderItem else {
            logger.error("startProvidingItem. Unknown fileProviderItem")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        let isFileOnDisk = fileManager.fileExists(atPath: url.path)
        if !isFileOnDisk {
            // If no file on disk, donwload from peripheral
            logger.info("File \(fileProviderItem.fullFilePath) does not exists locally. Get from peripheral")
            let gliderClient = GliderClient.shared(peripheralType: fileProviderItem.peripheralType)
            gliderClient.readFile(path: fileProviderItem.fileTransferPath, connectionManager: appContainer.connectionManager) { [weak self]  result in
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    do {
                        // Write data locally
                        try self.writeReceivedFileLocally(url: url, fileProviderItem: fileProviderItem, receivedData: data)
                        
                        // Finished sync
                        self.logger.info("syncFile \(fileProviderItem.fullFilePath) success")
                        completionHandler(nil)
                    }
                    catch(let error) {
                        self.logger.error("syncFile \(fileProviderItem.fullFilePath) write to disk error: \(error)")
                        completionHandler(error)
                    }
                    
                case .failure(let error):
                    self.logger.error("syncFile \(fileProviderItem.fullFilePath) error: \(error)")
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
            }
            
        }
        else {
            // Warning: if the local file has changes, and the remote file chas changes too, there is no way to determine which ones are the last ones without the remote file modification date. So we always prioritize local changes over remote changes
            
            if hasLocalChanges(url: url) {
                // The local files has changes, so upload it to the peripheral
                DLog("File \(fileProviderItem.fullFilePath) has local changes. Send to peripheral")
                
                uploadFile(localURL: url, item: fileProviderItem, completionHandler: completionHandler)
            }
            else {
                checkIfRemoteFileChangedAndDownload(url: url, fileProviderItem: fileProviderItem) { result in
                    
                    switch result {
                    case .success(let isRemoteFileChanged):
                        if isRemoteFileChanged {
                            self.logger.info("File \(fileProviderItem.fullFilePath) has remote changes. Get from peripheral")
                        }
                        completionHandler(nil)
                        
                    case .failure(let fileProviderError):
                        completionHandler(fileProviderError)
                    }
                }
            }
        }
        
        //completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
    }
    
    
    override func itemChanged(at url: URL) {
        logger.info("itemChanged at: \(url.absoluteString)")
        
        // Called at some point after the file has changed; the provider may then trigger an upload
        
        /*
         - mark file at <url> as needing an update in the model
         - if there are existing NSURLSessionTasks uploading this file, cancel them
         - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
         - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
         */
        
        guard let identifier = persistentIdentifierForItem(at: url) else {
            logger.error("itemChanged. Unknown identifier")
            return
        }
        
        guard let fileProviderItem = try? item(for: identifier) as? FileProviderItem else {
            logger.error("itemChanged. Unknown fileProviderItem")
            return
        }
        
        /*
        // TODO: check if the file was already being uploaded in the queue and cancel it
        // Schedule upload in background
        self.uploadFile(localURL: url, item: fileProviderItem) { error in
            if let error = error {
                DLog("itemChanged upload \(fileProviderItem.fullFilePath) error: \(error.localizedDescription)")
            }
            else {
                DLog("itemChanged uploaded \(fileProviderItem.fullFilePath)")
            }
        }*/
        
        logger.error("TODO")
    }
    
    override func stopProvidingItem(at url: URL) {
        logger.info("stopProvidingItem at: \(url.absoluteString)")
        
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        /*
        // TODO: look up whether the file has local changes
        let fileHasLocalChanges = hasLocalChanges(url: url)
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try FileManager.default.removeItem(at: url)
            } catch(let error) {
                // Handle error
                logger.error("error deleting local file: \(url.absoluteString). Error: \(error.localizedDescription)")
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // TODO: handle any error, do any necessary cleanup
                logger.error("error providing placeholder for deleted file: \(url.absoluteString). Error: \(error?.localizedDescription ?? "nil")")
            })
        }*/
        
        logger.error("TODO")
    }
    
    // MARK: - Enumeration
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        let enumerator: NSFileProviderEnumerator? = nil
        if containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer {
            // instantiate an enumerator for the container root
            logger.info("enumerator for rootContainer")
            return ScanEnumerator(metadataCache: metadataCache, connectionManager: appContainer.connectionManager, savedBondedBlePeripherals: appContainer.savedBondedBlePeripherals, savedSettingsWifiPeripherals: appContainer.savedSettingsWifiPeripherals)
            
        } else if containerItemIdentifier == NSFileProviderItemIdentifier.workingSet {
            // TODO: instantiate an enumerator for the working set
            logger.info("TODO: enumerator for workingSet")
            
            
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            
            if let item = try item(for: containerItemIdentifier) as? FileProviderItem {
                
                if item.isDirectory {
                    logger.info("enumerator for directory: \(containerItemIdentifier.rawValue)")
                    return ItemEnumerator(enumeratedItem: item, metadataCache: metadataCache, connectionManager: appContainer.connectionManager)
                }
                else {
                    logger.info("enumerator for file: \(containerItemIdentifier.rawValue)")
                    //return FileProviderEnumerator(metadataCache: metadataCache, blePeripheral: blePeripheral, path: item.path, filename: item.filename )
                }
            }
        }
        guard let enumerator = enumerator else {
            DLog("TODO: enumerator")
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
        return enumerator
    }
    
    
    // MARK: - Thumbnails
    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        
        for itemIdentifier in itemIdentifiers {
            perThumbnailCompletionHandler(itemIdentifier, nil, nil)
            progress.completedUnitCount += 1
            
            //DispatchQueue.main.async {
                if progress.isFinished {
                    // All thumbnails are complete
                    completionHandler(nil)
                }
            //}
        }
        
        return progress
    }
    
    // MARK: - Utils
    
    /**
        Creates the intermediate directories for the url passed. It does not create the final element in the path
     */
    private func createLocalIntermediateDirectoriesIfNeeded(url: URL) {
        let intermediateUrl = url.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: intermediateUrl.path) else { return }
        try? fileManager.createDirectory(at: intermediateUrl, withIntermediateDirectories: true, attributes: [:])
    }
    
    private func fileModificationDate(url: URL) -> Date? {
        do {
            let attr = try fileManager.attributesOfItem(atPath: url.path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func writeReceivedFileLocally(url: URL, fileProviderItem: FileProviderItem, receivedData: Data) throws {
        try receivedData.write(to: url, options: .atomic)
        
        // Update metadata with the date used on the modification date on the written file. It will be used to keep track of the local changes. If the metadata stored data is older than the file's modification date, then the file has been changed locally and needs to be updated on the peripheral
        let modificationDate = self.fileModificationDate(url: url)
        fileProviderItem.lastUpdate = modificationDate ?? Date()
        self.metadataCache.setFileProviderItem(item: fileProviderItem)
    }
    
    private func checkIfRemoteFileChangedAndDownload(url: URL, fileProviderItem: FileProviderItem, completion: @escaping((Result<Bool, Error>) -> Void) ) {
        // WARNING: major perfomance impact!!
        // TODO: this should only check the remote modification file, but the CircuitPython File Protocol used doesn't support it yet, so we have to download the whole file to check if it has changed
        
        do {
            let localData = try Data(contentsOf: url)
            
            // Retrieve remote file and compare with local data
            let gliderClient = GliderClient.shared(peripheralType: fileProviderItem.peripheralType)
            gliderClient.readFile(path: fileProviderItem.fileTransferPath, connectionManager: appContainer.connectionManager) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    let isRemoFileChanged = data != localData
                    
                    if isRemoFileChanged {
                        do {
                            try self.writeReceivedFileLocally(url: url, fileProviderItem: fileProviderItem, receivedData: data)
                            completion(.success(true))
                        }
                        catch(let error) {
                            self.logger.error("isRemoteFileChanged \(fileProviderItem.fullFilePath) error: \(error)")
                            completion(.failure(NSFileProviderError(.serverUnreachable)))
                        }
                    }
                    else {
                        completion(.success(false))
                    }
                    
                case .failure(let error):
                    self.logger.error("isRemoteFileChanged \(fileProviderItem.fullFilePath) error: \(error)")
                    completion(.failure(error))
                }
            }
        }
        catch {
            completion(.failure(NSFileProviderError(.noSuchItem)))
        }
    }
    
    private func createDirectoryLocally(fileProviderItem: FileProviderItem, completion: (Result<Void, Error>)->Void) {
        // Update metadata
        self.metadataCache.setFileProviderItem(item: fileProviderItem)
        
        guard let localUrl = self.urlForItem(withPersistentIdentifier: fileProviderItem.itemIdentifier) else {
            self.logger.error("Error obtaining local url for createDirectory: \(fileProviderItem.fullFilePath)")
            completion(.failure(GliderClient.GliderError.invalidInternalState))
            return
        }
        
        guard !fileManager.fileExists(atPath: localUrl.path) else {
            completion(.success(()))
            return
        }
        
        do {
            try fileManager.createDirectory(at: localUrl, withIntermediateDirectories: true, attributes: [:])
            completion(.success(()))
        } catch(let error) {
            self.metadataCache.deleteFileProviderItem(identifier: fileProviderItem.itemIdentifier)     // Undo creation
            self.logger.error("Error creating local directory: \(fileProviderItem.fullFilePath). Error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    private func deleteItemLocally(itemIdentifier: NSFileProviderItemIdentifier, completion: (Result<Void, Error>)->Void) {
        guard let localUrl = self.urlForItem(withPersistentIdentifier: itemIdentifier) else {
            self.logger.error("Error obtaining local url for deleteItem: \(itemIdentifier.rawValue)")
            completion(.failure(GliderClient.GliderError.invalidInternalState))
            return
        }
        
        // Update metadata (before real delete)
        self.metadataCache.deleteFileProviderItem(identifier: itemIdentifier)
        
        // Delete local directory
        try? fileManager.removeItem(at: localUrl)
        completion(.success(()))
        
        /* Note: commented to always return delete successful in case we are in an inconsistent state
         let isLocalItemDeleted: Bool
         do {
         try fileManager.removeItem(atPath: fileProviderItem.fullPath)
         isLocalItemDeleted = true
         } catch(let error) {
         DLog("Error deleting local item: \(fileProviderItem.fullPath). Error: \(error.localizedDescription)")
         isLocalItemDeleted = false
         completionHandler(error)
         }
         */
    }
    
    private func uploadFile(localURL url: URL, item fileProviderItem: FileProviderItem, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        do {
            let localData = try Data(contentsOf: url)
            
            let gliderClient = GliderClient.shared(peripheralType: fileProviderItem.peripheralType)
            gliderClient.writeFile(path: fileProviderItem.fileTransferPath, data: localData, connectionManager: appContainer.connectionManager) { result in
                switch result {
                case .success:
                    // Save sync date
                    let localModificationDate = self.fileModificationDate(url: url)
                    fileProviderItem.lastUpdate = localModificationDate ?? Date()
                    self.metadataCache.setFileProviderItem(item: fileProviderItem)
                    
                    // Finished
                    completionHandler(nil)
                    
                case .failure:
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
            }
        }
        catch(let error) {
            self.logger.error("syncFile \(fileProviderItem.fullFilePath) load from disk error: \(error)")
            completionHandler(NSFileProviderError(.noSuchItem))
        }
    }
    
    private func hasLocalChanges(url: URL) -> Bool {
        guard let identifier = persistentIdentifierForItem(at: url) else { return false }
        guard let fileProviderItem = try? item(for: identifier) as? FileProviderItem else { return false }
        
        let localModificationDate = self.fileModificationDate(url: url)
        let localFileHasChanges = (localModificationDate ?? Date.distantPast) > fileProviderItem.lastUpdate
        return localFileHasChanges
    }
}
