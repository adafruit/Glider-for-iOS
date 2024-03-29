//
//  FileCommandsViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/10/21.
//

import Foundation

class FileCommandsViewModel: ObservableObject {
    // Params
    var showOnlyDirectories = false

    // Published
    @Published var isRootDirectory = false
    @Published var entries = [DirectoryEntry]()
    @Published var path = ""
    
    @Published var isTransmitting = false
    @Published var transmissionProgress: TransmissionProgress?
    @Published var lastTransmit: TransmissionLog? = TransmissionLog(type: .write(size: 334, date: nil))

    // MARK: - Actions
    func listDirectory(directory: String, fileTransferClient: FileTransferClient) {
        startCommand(description: "List directory")

        isRootDirectory = FileTransferPathUtils.isRootDirectory(path: directory)
        entries.removeAll()
        isTransmitting = true
        
        fileTransferClient.listDirectory(path: directory) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmitting = false
                
                switch result {
                case .success(let entries):
                    if let entries = entries {
                        self.setEntries(entries)
                    }
                    else {
                        DLog("listDirectory: nonexistent directory")
                    }
                    self.path = directory
                    self.lastTransmit = TransmissionLog(type: .listDirectory(numItems: entries?.count))
                   
                case .failure(let error):
                    DLog("listDirectory \(directory) error: \(error)")
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func makeDirectory(path: String, fileTransferClient: FileTransferClient) {
        // Make sure that the path ends with the separator
        //DLog("makeDirectory: \(path)")
        startCommand(description: "Creating \(path)")
        isTransmitting = true
        fileTransferClient.makeDirectory(path: path) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmitting = false
                
                switch result {
                case .success(_ /*let date*/):
                    //DLog("makeDirectory \(path) success")
                    self.listDirectory(directory: self.path, fileTransferClient: fileTransferClient)      // Force list again directory
                    self.lastTransmit = TransmissionLog(type: .makeDirectory)

                case .failure(let error):
                    DLog("makeDirectory \(path) error: \(error)")
                    
                    var message = error.localizedDescription
                    if case let FileTransferNetwork.NetworkError.invalidStatus(statusCode, _) = error, let statusCode = statusCode {
                        message = "Network Error. Status Code: \(statusCode)"
                    }
                    
                    self.lastTransmit = TransmissionLog(type: .error(message: message))
                }
                
                self.endCommand()
            }
        }
    }
    
    func makeFile(filename: String, data: Data, fileTransferClient: FileTransferClient) {
        writeFile(filename: filename, data: data, fileTransferClient: fileTransferClient) { result in
            if case .success = result {
                self.listDirectory(directory: self.path, fileTransferClient: fileTransferClient)      // Force list again directory
            }
        }
    }
    
    func renameFile(fromPath: String, toPath: String, fileTransferClient: FileTransferClient) {
        moveFile(fromPath: fromPath, toPath: toPath, fileTransferClient: fileTransferClient)  { result in
            if case .success = result {
                self.listDirectory(directory: self.path, fileTransferClient: fileTransferClient)      // Force list again directory
            }
        }
    }
    
    private func setEntries(_ entries: [DirectoryEntry]) {
        // Filter if needed
        let filteredEntries: [DirectoryEntry]
        if showOnlyDirectories {
            filteredEntries = entries.filter{$0.isDirectory}
        }
        else {
            filteredEntries = entries
        }
                
        // Sort by directory and as a second criteria order by name
        self.entries = filteredEntries.sorted(by: {
            if case .directory = $0.type, case .directory = $1.type  {    // Both directories: order alphabetically
                return $0.name < $1.name
            }
            else if case .file = $0.type, case .file = $1.type {          // Both files: order alphabetically
                return $0.name < $1.name
            }
            else {      // Compare directory and file
                if case .directory = $0.type { return true } else { return false }
            }
        })
    }
    
    func delete(at offsets: IndexSet, fileTransferClient: FileTransferClient) {
        for offset in offsets {
            let entry = entries[offset]
            DLog("delete: \(offset) - \(path + entry.name)")
            delete(entry: entry, fileTransferClient: fileTransferClient)
        }
    }
    
    func delete(entry: DirectoryEntry, fileTransferClient: FileTransferClient) {
        let filename = path + entry.name
        startCommand(description: "Deleting \(filename)")
        isTransmitting = true
        fileTransferClient.deleteFile(path: filename) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmitting = false
                
                switch result {
                case .success:
                    DLog("deleteFile \(filename)")
                    self.listDirectory(directory: self.path, fileTransferClient: fileTransferClient)      // Force list again directory
                    self.lastTransmit = TransmissionLog(type: .delete)
                    
                case .failure(let error):
                    DLog("deleteFile \(filename) error: \(error)")
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func readFile(filePath: String, fileTransferClient: FileTransferClient, completion: ((Result<Data, Error>) -> Void)? = nil) {
        startCommand(description: "Reading \(filePath)")
        isTransmitting = true
        
        fileTransferClient.readFile(path: filePath, progress: { [weak self] read, total in
            //DLog("reading progress: \( String(format: "%.1f%%", Float(read) * 100 / Float(total)) )")
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.transmissionProgress?.transmittedBytes = read
                self.transmissionProgress?.totalBytes = total
            }
        }) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmitting = false
                
                switch result {
                case .success(let data):
                    self.lastTransmit = TransmissionLog(type: .read(size: data.count))
                    completion?(.success(data))
                    
                case .failure(let error):
                    DLog("readFile \(filePath) error: \(error)")
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                    completion?(.failure(error))
                }
                
                self.endCommand()
            }
        }
    }
    
    func writeFile(filename: String, data: Data, fileTransferClient: FileTransferClient, completion: ((Result<Date?, Error>) -> Void)? = nil) {
        startCommand(description: "Writing \(filename)")
        
        isTransmitting = true
        fileTransferClient.writeFile(path: filename, data: data, progress: { [weak self] written, total in
            //DLog("writing progress: \( String(format: "%.1f%%", Float(written) * 100 / Float(total)) )")
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.transmissionProgress?.transmittedBytes = written
                self.transmissionProgress?.totalBytes = total
            }
        }) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isTransmitting = false
                
                switch result {
                case .success(let date):
                    self.lastTransmit = TransmissionLog(type: .write(size: data.count, date: date))
                    completion?(.success(date))

                case .failure(let error):
                    DLog("writeFile \(filename) error: \(error)")
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                    completion?(.failure(error))
                }
                
                self.endCommand()
            }
        }
    }
    
    func moveFile(fromPath: String, toPath: String, fileTransferClient: FileTransferClient?, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let fileTransferClient = fileTransferClient else { return }
        startCommand(description: "Moving from \(fromPath) to \(toPath)")
        
        isTransmitting = true
        
        fileTransferClient.moveFile(fromPath: fromPath, toPath: toPath) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmitting = false

                switch result {
                case .success:
                    DLog("moveFile from \(fromPath) to \(toPath)")
                   // self.listDirectory(directory: self.path, fileTransferClient: fileTransferClient)      // Force list again directory
                    self.lastTransmit = TransmissionLog(type: .move)
                    completion?(.success(()))

                case .failure(let error):
                    DLog("moveFile  from \(fromPath) to \(toPath). error: \(error)")
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                    completion?(.failure(error))
                }

                self.endCommand()
            }
        }
    }
    
    // MARK: - Transmission Status
    private func startCommand(description: String) {
        transmissionProgress = TransmissionProgress(description: description)    // Start description with no progress 0 and undefined Total
        lastTransmit = nil
    }
    
    private func endCommand() {
        transmissionProgress = nil
    }
}
