//
//  FileEditViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import Foundation

class FileEditViewModel: FileCommandsViewModel {
    @Published var text: String? = nil              // Read converted to text (ut8)
    
    // MARK: - Setup
    func setup(filePath: String, fileTransferClient: FileTransferClient?) {
        self.path = filePath
        
        // Initial read
        if let fileTransferClient = fileTransferClient {
            readFile(filePath: filePath, fileTransferClient: fileTransferClient) { result in
                switch result {
                case .success(let data):
                    self.setData(data)
                case .failure:
                    break
                }
            }
        }
    }
 
    override func writeFile(filename: String, data: Data, fileTransferClient: FileTransferClient, completion: ((Result<Date?, Error>) -> Void)? = nil) {
        super.writeFile(filename: filename, data: data, fileTransferClient: fileTransferClient) { result in
            switch result {
            case .success:
                self.setData(data)
            case .failure:
                break
            }
        }
    }
    
    private func setData(_ data: Data) {
        self.text = String(data: data, encoding: .utf8)
    }
    
}
