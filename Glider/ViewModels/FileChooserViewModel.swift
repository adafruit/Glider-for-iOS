//
//  FileChooserViewModel.swift
//  Glider
//
//  Created by Antonio García on 24/5/21.
//

import Foundation

class FileChooserViewModel: ObservableObject {
    @Published var isRootDirectory = false
    @Published var entries = [BlePeripheral.DirectoryEntry]()
    @Published var directory = ""
    @Published var isTransmiting = false

    private var blePeripheral: BlePeripheral?
    
    func setup(blePeripheral: BlePeripheral?, directory: String) {
        self.blePeripheral = blePeripheral
        
        // Clean directory name
        let directoryName = FileTransferUtils.pathRemovingFilename(path: directory)
        self.directory = directoryName
        
        // List directory
        listDirectory(directory: directoryName)
    }
    
    func listDirectory(directory: String) {
        isRootDirectory = directory == "/"
        entries.removeAll()
        isTransmiting = true
        
        blePeripheral?.listDirectory(directory) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmiting = false
                
                switch result {
                case .success(let entries):
                    if let entries = entries {
                        self.setEntries(entries)
                        self.directory = directory
                    }
                    else {
                        print("listDirectory: nonexistent directory")
                    }
                    
                case .failure(let error):
                    print("listDirectory \(directory) error: \(error)")
                }
            }
        }
    }
    
    func makeDirectory(path: String) {
        print("makeDirectory: \(path)")
        isTransmiting = true
        blePeripheral?.makeDirectory(path) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTransmiting = false
                
                switch result {
                case .success(let success):
                    print("makeDirectory \(path) success: \(success)")
                    self.listDirectory(directory: self.directory)      // Force list again directory
                    
                case .failure(let error):
                    print("makeDirectory \(path) error: \(error)")
                }
            }
        }
    }
    
    private func setEntries(_ entries: [BlePeripheral.DirectoryEntry]) {
        // Order by directory and as a second criteria order by name
        self.entries = entries.sorted(by: {
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
    
    func delete(at offsets: IndexSet) {
        for offset in offsets {
            let entry = entries[offset]
            let filename = directory + entry.name
            print("delete: \(offset) - \(filename)")

            isTransmiting = true
            blePeripheral?.deleteFile(filename: filename) { [weak self]  result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isTransmiting = false
                    
                    switch result {
                    case .success(let success):
                        print("deleteFile \(filename) success: \(success)")
                        self.listDirectory(directory: self.directory)      // Force list again directory
                        
                    case .failure(let error):
                        print("deleteFile \(filename) error: \(error)")
                    }
                }
            }
            
            
        }
    }
}
