//
//  FileSystemViewModel.swift
//  Glider
//
//  Created by Antonio García on 24/5/21.
//

import Foundation

class FileSystemViewModel: FileCommandsViewModel {
    
    // MARK: - Lifecycle
    func setup(directory: String, fileTransferClient: FileTransferClient) {
        // Clean directory name
        let path = FileTransferPathUtils.pathRemovingFilename(path: directory)
        self.path = path
        
        // List directory
        listDirectory(directory: path, fileTransferClient: fileTransferClient)
        
        /*
        // Observe reconnect and list directory again
        if let blePeripheralFileTransferState = (fileTransferClient.peripheral as? BleFileTransferPeripheral)?.fileTransferState {
            blePeripheralFileTransferState
                .sink { <#Subscribers.Completion<Error>#> in
                    <#code#>
                } receiveValue: { <#BleFileTransferPeripheral.FileTransferState#> in
                    <#code#>
                }

            
        }*/
    }
}
