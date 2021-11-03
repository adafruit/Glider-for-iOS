//
//  FileSystemViewModel.swift
//  Glider
//
//  Created by Antonio García on 24/5/21.
//

import Foundation
import FileTransferClient

class FileSystemViewModel: FileCommandsViewModel {
    
    
    // MARK: - Lifecycle
    func setup(directory: String, fileTransferClient: FileTransferClient) {
        // Clean directory name
        let path = FileTransferPathUtils.pathRemovingFilename(path: directory)
        self.path = path
        
        // List directory
        listDirectory(directory: path, fileTransferClient: fileTransferClient)
    }
}
