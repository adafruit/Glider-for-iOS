//
//  FileTransferClient.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

class FileTransferClient {
    
    let fileTransferPeripheral: FileTransferPeripheral
    var peripheral: Peripheral { fileTransferPeripheral.peripheral }
    
    init(fileTransferPeripheral: FileTransferPeripheral) {
        self.fileTransferPeripheral = fileTransferPeripheral
    }
    
    // MARK: - File Transfer Commands
    /// Given a full path, returns the full contents of the file
    public func readFile(path: String, progress: FileTransferProgressHandler? = nil, completion: ((Result<Data, Error>) -> Void)?) {
        fileTransferPeripheral.readFile(path: path, progress: progress, completion: completion)
    }

    ///  Writes the content to the given full path. If the file exists, it will be overwritten
    public func writeFile(path: String, data: Data, progress: FileTransferProgressHandler? = nil, completion: ((Result<Date?, Error>) -> Void)?) {
        fileTransferPeripheral.writeFile(path: path, data: data, progress: progress, completion: completion)
    }
    
    /// Deletes the file or directory at the given full path. Directories must be empty to be deleted
    public func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        fileTransferPeripheral.deleteFile(path: path, completion: completion)
    }

    /**
     Creates a new directory at the given full path. If a parent directory does not exist, then it will also be created. If any name conflicts with an existing file, an error will be returned
        - Parameter path: Full path
    */
    public func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        fileTransferPeripheral.makeDirectory(path: FileTransferPathUtils.pathWithTrailingSeparator(path: path), completion: completion)
    }

    /// Lists all of the contents in a directory given a full path. Returned paths are relative to the given path to reduce duplication
    public func listDirectory(path: String, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
        fileTransferPeripheral.listDirectory(path: path, completion: completion)
    }
    
    /// Moves a single file from fromPath to toPath
    public func moveFile(fromPath: String, toPath: String, completion: ((Result<Void, Error>) -> Void)?) {
        fileTransferPeripheral.moveFile(fromPath: fromPath, toPath: toPath, completion: completion)
    }
}
