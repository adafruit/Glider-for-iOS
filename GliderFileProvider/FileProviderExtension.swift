//
//  FileProviderExtension.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import FileProvider

class FileProviderExtension: NSFileProviderExtension {
    // Data
    private let gliderClient = GliderClient()
    private var fileManager = FileManager()
    private var backgroundQueue = DispatchQueue.global(qos: .utility)
    
    // MARK: -
    override init() {
        super.init()
        
        if AppEnvironment.isDebug && false {
            DLog("Debug: force resync")
            FileProviderUtils.signalFileProviderChanges()
        }
    }
    
    // MARK: - Mandatory
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        //DLog("item: \(identifier.rawValue)")
        guard let item = gliderClient.metadataCache.fileProviderItem(for: identifier) else {
            DLog("Error undefined item for identifier: \(identifier)")
            throw GliderClient.GliderError.undefinedFileProviderItem(identifier: identifier.rawValue)
        }
        return item
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        //DLog("urlForItem: \(identifier.rawValue)")

        // resolve the given identifier to a file on disk
        guard let item = try? item(for: identifier) as? FileProviderItem else {
            return nil
        }
    
        let manager = NSFileProviderManager.default
        let partialPath = item.fullPath.deletingPrefix(FileTransferPathUtils.pathSeparator)
        let url = manager.documentStorageURL.appendingPathComponent(partialPath, isDirectory: item.entry.isDirectory)
        //DLog("urlForItem at: \(identifier.rawValue) -> \(url.absoluteString)")
        return url
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {

        let pathComponents = url.pathComponents
        let fullPath = FileTransferPathUtils.pathSeparator + pathComponents[pathComponents.count - 1]
        let persistentIdentifier = NSFileProviderItemIdentifier(fullPath)
        //DLog("persistentIdentifierForItem at: \(url.absoluteString) -> \(persistentIdentifier.rawValue)")
        return persistentIdentifier
    }
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        DLog("providePlaceholder at: \(url.absoluteString)")
        
        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch let error {
            DLog("providePlaceholder error: \(error)")
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        DLog("startProvidingItem at: \(url.absoluteString)")
        
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
            DLog("startProvidingItem. Unknown identifier")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        guard let fileProviderItem = try? item(for: identifier) as? FileProviderItem else {
            DLog("startProvidingItem. Unknown fileProviderItem")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        let isFileOnDisk = fileManager.fileExists(atPath: url.path)
        if !isFileOnDisk {
            // If no file on disk, donwload from peripheral
            DLog("File \(fileProviderItem.fullPath) does not exists locally. Get from peripheral")
            gliderClient.readFileStartingFileTransferIfNeeded(path: fileProviderItem.fullPath) { [weak self]  result in
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    do {
                        // Write data locally
                        try self.writeReceivedFile(url: url, fileProviderItem: fileProviderItem ,receivedData: data)

                        // Finished sync
                        DLog("syncFile \(fileProviderItem.fullPath) success")
                        completionHandler(nil)
                    }
                    catch(let error) {
                        DLog("syncFile \(fileProviderItem.fullPath) write to disk error: \(error)")
                        completionHandler(error)
                    }
                    
                case .failure(let error):
                    DLog("syncFile \(fileProviderItem.fullPath) error: \(error)")
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
            }
            
        }
        else {
            // Warning: if the local file has changes, and the remote file chas changes too, there is no way to determine which ones are the last ones without the remote file modification date. So we always prioritize local changes over remote changes
            
            if hasLocalChanges(url: url) {
                // The local files has changes, so upload it to the peripheral
                DLog("File \(fileProviderItem.fullPath) has local changes. Send to peripheral")
                
                do {
                    let localData = try Data(contentsOf: url)
                    gliderClient.writeFileStartingFileTransferIfNeeded(path: fileProviderItem.fullPath, data: localData) { result in
                        switch result {
                        case .success:
                            // Save sync date
                            let localModificationDate = self.fileModificationDate(url: url)
                            fileProviderItem.lastUpdate = localModificationDate ?? Date()
                            self.gliderClient.metadataCache.setFileProviderItems(items: [fileProviderItem])
                            
                            // Finished
                            completionHandler(nil)
                            
                        case .failure:
                            completionHandler(NSFileProviderError(.serverUnreachable))
                        }
                    }
                }
                catch(let error) {
                    DLog("syncFile \(fileProviderItem.fullPath) load from disk error: \(error)")
                    completionHandler(NSFileProviderError(.noSuchItem))
                }
            }
            else {
                checkIfRemoteFileChangedAndDownload(url: url, fileProviderItem: fileProviderItem) { result in
                    
                    switch result {
                    case .success(let isRemoteFileChanged):
                        if isRemoteFileChanged {
                            DLog("File \(fileProviderItem.fullPath) has remote changes. Get from peripheral")
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
        DLog("itemChanged at: \(url.absoluteString)")
        
        // Called at some point after the file has changed; the provider may then trigger an upload
        
        /* TODO:
         - mark file at <url> as needing an update in the model
         - if there are existing NSURLSessionTasks uploading this file, cancel them
         - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
         - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
         */
    }
    
    override func stopProvidingItem(at url: URL) {
        DLog("stopProvidingItem at: \(url.absoluteString)")
        
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        // TODO: look up whether the file has local changes
        let fileHasLocalChanges = hasLocalChanges(url: url)
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try FileManager.default.removeItem(at: url)
            } catch(let error) {
                // Handle error
                DLog("error deleting local file: \(url.absoluteString). Error: \(error.localizedDescription)")
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // TODO: handle any error, do any necessary cleanup
                DLog("error providing placeholder for deleted file: \(url.absoluteString). Error: \(error?.localizedDescription ?? "nil")")
            })
        }
    }
    
    private func hasLocalChanges(url: URL) -> Bool {
        guard let identifier = persistentIdentifierForItem(at: url) else { return false }
        guard let fileProviderItem = try? item(for: identifier) as? FileProviderItem else { return false }
        
        let localModificationDate = self.fileModificationDate(url: url)
        let localFileHasChanges = localModificationDate != fileProviderItem.lastUpdate
        return localFileHasChanges
     
    }
    
    // MARK: - Actions
    
    /* implement the actions for items here
     each of the actions follows the same pattern:
     - make a note of the change in the local model
     - schedule a server request as a background task to inform the server of the change
     - call the completion block with the modified item in its post-modification state
     */
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        let maybeEnumerator: NSFileProviderEnumerator? = nil
        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            // instantiate an enumerator for the container root
            DLog("enumerator for rootContainer")
            return FileProviderEnumerator(gliderClient: gliderClient, path: FileTransferPathUtils.rootDirectory, filename: nil )
            
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
            // TODO: instantiate an enumerator for the working set
            DLog("TODO: enumerator for workingSet")
            
            
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            
            if let item = try item(for: containerItemIdentifier) as? FileProviderItem  {
                if item.entry.isDirectory {
                    DLog("enumerator for directory: \(containerItemIdentifier.rawValue)")
                    let path = item.path + item.entry.name + FileTransferPathUtils.pathSeparator
                    return FileProviderEnumerator(gliderClient: gliderClient, path: path, filename: nil )
                }
                else {
                    DLog("enumerator for file: \(containerItemIdentifier.rawValue)")
                    return FileProviderEnumerator(gliderClient: gliderClient, path: item.path, filename: item.filename )

                }
            }
        }
        guard let enumerator = maybeEnumerator else {
            DLog("TODO: enumerator")
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
        return enumerator
    }
 
    
    // MARK: - Optional
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        DLog("createDirectory: '\(directoryName)' at \(parentItemIdentifier.rawValue)")
  
        guard let parentFileProviderItem = try? item(for: parentItemIdentifier) as? FileProviderItem else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        // Create fileProviderItem
        let fileProviderItem = FileProviderItem(path: parentFileProviderItem.fullPath, entry: BlePeripheral.DirectoryEntry(name: directoryName, type: .directory))
        self.gliderClient.metadataCache.setFileProviderItems(items: [fileProviderItem])
        
        // Schedule create in background
        backgroundQueue.async {
            self.gliderClient.makeDirectory(path: fileProviderItem.fullPath) { result in
                switch result {
                case .success(let success):
                    DLog("createDirectory '\(fileProviderItem.fullPath)' result successful: \(success)")
                    
                case .failure(let error):
                    DLog("createDirectory error: \(error)")
                }
            }
        }

        // Return inmediately (before the directory is even created)
        completionHandler(fileProviderItem, nil)
    }
    
    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let fileProviderItem = try? item(for: itemIdentifier) as? FileProviderItem else {
            DLog("renameItem. Unknown fileProviderItem")
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        // Only renaming directories is supported at the moment
        guard fileProviderItem.entry.isDirectory else {
            completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError))
            return
        }
        
        // Rename fileproviderItem
        let renamedEntry = BlePeripheral.DirectoryEntry(name: itemName, type: fileProviderItem.entry.type)
        let renamedItem = FileProviderItem(path: fileProviderItem.path, entry: renamedEntry)
        renamedItem.creation = fileProviderItem.creation        // Maintain creation date
        self.gliderClient.metadataCache.setFileProviderItems(items: [renamedItem])
        self.gliderClient.metadataCache.deleteFileProviderItem(identifier: itemIdentifier)
        
        // Schedule delete in background
        backgroundQueue.async {

            self.gliderClient.makeDirectory(path: renamedItem.fullPath) { result in
                switch result {
                case .success(let success):
                    DLog("rename step 1: createDirectory '\(renamedItem.fullPath)' result successful: \(success)")
                    
                    self.gliderClient.deleteFile(path: fileProviderItem.fullPath) { result in
                        switch result {
                        case .success(let success):
                            DLog("rename step 2: deleteFile \(fileProviderItem.fullPath) result successful: \(success)")
                            
                            
                        case .failure(let error):
                            DLog("rename step 2: deleteFile error: \(error)")
                        }
                    }
                    
                case .failure(let error):
                    DLog("rename step 1: createDirectory error: \(error)")
                }
            }
        }

        // Return inmediately (before the file is deleted)
        completionHandler(renamedItem, nil)
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        guard let fileProviderItem = try? item(for: itemIdentifier) as? FileProviderItem else {
            DLog("deleteItem. Unknown fileProviderItem")
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        // Delete fileproviderItem
        self.gliderClient.metadataCache.deleteFileProviderItem(identifier: itemIdentifier)
        
        // Schedule delete in background
        backgroundQueue.async {
            self.gliderClient.deleteFile(path: fileProviderItem.fullPath) { result in
                switch result {
                case .success(let success):
                    DLog("deleteFile '\(fileProviderItem.fullPath)' result successful: \(success)")
                    
                case .failure(let error):
                    DLog("deleteFile error: \(error)")
                }
            }
        }

        // Return inmediately (before the file is deleted)
        completionHandler(nil)
    }
    
    /*
    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        DLog("setLastUsedDate: \(itemIdentifier.rawValue) to \(String(describing: lastUsedDate))")
        guard let fileProviderItem = try? item(for: itemIdentifier) as? FileProviderItem else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        // Save sync date
        fileProviderItem.syncDate = lastUsedDate
        self.gliderClient.metadataCache.updateMetadata(items: [fileProviderItem])

        
        NSFileProviderManager.default.signalEnumerator(for: itemIdentifier) { error in
            DLog("signalFileProviderChanges for \(itemIdentifier.rawValue) completed. Error?: \(String(describing: error))")
        }
        
        completionHandler(fileProviderItem, nil)
    }*/

    
    // MARK: - Utils
    func fileModificationDate(url: URL) -> Date? {
        do {
            let attr = try fileManager.attributesOfItem(atPath: url.path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func writeReceivedFile(url: URL, fileProviderItem: FileProviderItem, receivedData: Data) throws {
        try receivedData.write(to: url, options: .atomic)
        
        // Update metadata with the date used on the modification date on the written file. It will be used to keep track of the local changes. If the metadata stored data is older than the file's modification date, then the file has been changed locally and needs to be updated on the peripheral
        let modificationDate = self.fileModificationDate(url: url)
        fileProviderItem.lastUpdate = modificationDate ?? Date()
        self.gliderClient.metadataCache.setFileProviderItems(items: [fileProviderItem])
    }
    
    private func checkIfRemoteFileChangedAndDownload(url: URL, fileProviderItem: FileProviderItem, completion: @escaping((Result<Bool, Error>) -> Void) ) {
        // WARNING: major perfomance impact!!
        // TODO: this should only check the remote modification file, but the CircuitPython File Protocol used doesn't support it yet, so we have to download the whole file to check if it has changed
        
        do {
            let localData = try Data(contentsOf: url)
            
            // Retrieve remote file and compare with local data
            gliderClient.readFileStartingFileTransferIfNeeded(path: fileProviderItem.fullPath) { [weak self]  result in
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    let isRemoFileChanged = data != localData
                    
                    if isRemoFileChanged {
                        do {
                            try self.writeReceivedFile(url: url, fileProviderItem: fileProviderItem, receivedData: data)
                            completion(.success(true))
                        }
                        catch(let error) {
                            DLog("isRemoteFileChanged \(fileProviderItem.fullPath) error: \(error)")
                            completion(.failure(NSFileProviderError(.serverUnreachable)))
                        }
                    }
                    else {
                        completion(.success(false))
                    }
                    
                case .failure(let error):
                    DLog("isRemoteFileChanged \(fileProviderItem.fullPath) error: \(error)")
                    completion(.failure(error))
                }
            }
        }
        catch {
            completion(.failure(NSFileProviderError(.noSuchItem)))
        }
    }
}
