//
//  GliderClient.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import Foundation
import FileTransferClient

/// Helper class to serialize FileTransfer operations
/// It will check that the peripheral is connected and properly initialized before executing each operation
class GliderClient {
    // Enums
    enum GliderError: LocalizedError {
        case bluetoothNotSupported
        case connectionFailed
        case invalidInternalState
        case undefinedFileProviderItem(identifier: String)
        case cancelled
    }

    // Singleton (used to manage concurrency)
    private static var sharedInstances = [UUID: GliderClient]()
    static func shared(peripheralIdentifier: UUID) -> GliderClient {
        guard let instance = sharedInstances[peripheralIdentifier] else {
            // Create new instance
            DLog("Create GliderClient instance for \(peripheralIdentifier)")
            let client = GliderClient(identifier: peripheralIdentifier)
            sharedInstances[peripheralIdentifier] = client
            return client
        }
        return instance     // Return existing instance
    }

    // Data
    private lazy var operationsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Operations queue for \(identifier)"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    // MARK: - Lifecycle
    private let identifier: UUID
    
    private init(identifier: UUID) {
        self.identifier = identifier
    }
    
    // MARK: - Read
    func readFile(path: String, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Data, Error>) -> Void)?) {
        
        let operation = GliderReadFileOperation(identifier: identifier, path: path, progress: progress, completion: completion)
        DLog("GliderClient: add read operation \(path)")
        operationsQueue.addOperation(operation)
    }
    
    private class GliderReadFileOperation: Operation {
        private let identifier: UUID
        
        private let path: String
        private let progress: FileTransferClient.ProgressHandler?
        private let completion: ((Result<Data, Error>) -> Void)?
        
        init(identifier: UUID, path: String, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Data, Error>) -> Void)?) {
            self.identifier = identifier
            self.path = path
            self.progress = progress
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
            
            //DLog("GliderClient: read start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            GliderClient.setupFileTransferIfNeeded(identifier: identifier) { [weak self] result in
                guard let self = self else { syncSemaphore.signal(); return }

                switch result {
                case .success(let client):
                    guard !self.isCancelled else { self.completion?(.failure(GliderError.cancelled)); syncSemaphore.signal(); return }
                    //DLog("GliderClient: read prepared: \(result.isSuccess)")
                    client.readFile(path: self.path, progress: self.progress) { [weak self] result in
                        //DLog("GliderClient: read finished: \(result.isSuccess)")
                        self?.completion?(result)
                        syncSemaphore.signal()
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                    syncSemaphore.signal()
                }
            }
            
            syncSemaphore.wait()        // Operation main() should return when completed
        }
    }
    
    // MARK: - Write
    func writeFile(path: String, data: Data, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Void, Error>) -> Void)?) {
        let operation = GliderWriteFileOperation(identifier: identifier, path: path, data: data, progress: progress, completion: completion)
        DLog("GliderClient: add write operation \(path)")
        operationsQueue.addOperation(operation)
    }
    
    private class GliderWriteFileOperation: Operation {
        private let identifier: UUID
        
        private let path: String
        private let data: Data
        private let progress: FileTransferClient.ProgressHandler?
        private let completion: ((Result<Void, Error>) -> Void)?
        
        init(identifier: UUID, path: String, data: Data, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Void, Error>) -> Void)?) {
            self.identifier = identifier
            self.path = path
            self.data = data
            self.progress = progress
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
            
            //DLog("GliderClient: write start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            GliderClient.setupFileTransferIfNeeded(identifier: identifier) { [weak self] result in
                guard let self = self else { syncSemaphore.signal(); return }
                switch result {
                case .success(let client):
                    guard !self.isCancelled else { self.completion?(.failure(GliderError.cancelled)); syncSemaphore.signal(); return }
                    //DLog("GliderClient: write prepared: \(result.isSuccess)")
                    client.writeFile(path: self.path, data: self.data, progress: self.progress) { [weak self] result in
                        guard let self = self else { syncSemaphore.signal(); return }
                        //DLog("GliderClient: write finished: \(result.isSuccess)")
                        switch result {
                        case .success:
                            self.completion?(.success(()))

                        case .failure(let error):
                            self.completion?(.failure(error))
                        }
                        syncSemaphore.signal()
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                    syncSemaphore.signal()
                }
            }
            
            syncSemaphore.wait()        // Operation main() should return when completed
        }
    }
    
    // MARK: - Delete
    func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        let operation = GliderDeleteFileOperation(identifier: identifier, path: path, completion: completion)
        DLog("GliderClient: add delete operation \(path)")
        operationsQueue.addOperation(operation)
    }

    private class GliderDeleteFileOperation: Operation {
        private let identifier: UUID
        
        private let path: String
        private let completion: ((Result<Void, Error>) -> Void)?
        
        init(identifier: UUID, path: String, completion: ((Result<Void, Error>) -> Void)?) {
            self.identifier = identifier
            self.path = path
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
            
            //DLog("GliderClient: delete start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            GliderClient.setupFileTransferIfNeeded(identifier: identifier) { [weak self] result in
                guard let self = self else { syncSemaphore.signal(); return }
                //DLog("GliderClient: delete prepared: \(result.isSuccess)")
                switch result {
                case .success(let client):
                    guard !self.isCancelled else { self.completion?(.failure(GliderError.cancelled)); syncSemaphore.signal(); return }
                    
                    client.deleteFile(path: self.path) { [weak self] result in
                        //DLog("GliderClient: delete finished: \(result.isSuccess)")
                        self?.completion?(result)
                        syncSemaphore.signal()
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                    syncSemaphore.signal()
                }
            }
            
            syncSemaphore.wait()        // Operation main() should return when completed
        }
    }
    
    // MARK: - Make Directory
    func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        let operation = GliderMakeDirectoryFileOperation(identifier: identifier, path: path, completion: completion)
        DLog("GliderClient: add make directory operation \(path)")
        operationsQueue.addOperation(operation)
    }

    private class GliderMakeDirectoryFileOperation: Operation {
        private let identifier: UUID
        
        private let path: String
        private let completion: ((Result<Date?, Error>) -> Void)?
        
        init(identifier: UUID, path: String, completion: ((Result<Date?, Error>) -> Void)?) {
            self.identifier = identifier
            self.path = path
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
                        
            //DLog("GliderClient: make directory start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            GliderClient.setupFileTransferIfNeeded(identifier: identifier) { [weak self] result in
                guard let self = self else { syncSemaphore.signal(); return }
                //DLog("GliderClient: make directory prepared: \(result.isSuccess)")
                switch result {
                case .success(let client):
                    guard !self.isCancelled else { self.completion?(.failure(GliderError.cancelled)); syncSemaphore.signal(); return }
                    
                    client.makeDirectory(path: self.path) { [weak self] result in
                        //DLog("GliderClient: make directory finished: \(result.isSuccess)")
                        self?.completion?(result)
                        syncSemaphore.signal()
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                    syncSemaphore.signal()
                }
            }
            
            syncSemaphore.wait()        // Operation main() should return when completed
        }
    }
    
    
    // MARK: - List Directory
    func listDirectory(path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        let operation = GliderListDirectoryFileOperation(identifier: identifier, path: path, completion: completion)
        DLog("GliderClient: add list directory operation \(path)")
        operationsQueue.addOperation(operation)
    }

    private class GliderListDirectoryFileOperation: Operation {
        private let identifier: UUID
        
        private let path: String
        private let completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?
        
        init(identifier: UUID, path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
            self.identifier = identifier
            self.path = path
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
            
            //DLog("GliderClient: list directory start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            GliderClient.setupFileTransferIfNeeded(identifier: identifier) { [weak self] result in
                guard let self = self else { syncSemaphore.signal(); return }
                //DLog("GliderClient: list directory prepared: \(result.isSuccess)")
                switch result {
                case .success(let client):
                    guard !self.isCancelled else { self.completion?(.failure(GliderError.cancelled)); syncSemaphore.signal(); return }
                    
                    client.listDirectory(path: self.path) { [weak self] result in
                        //DLog("GliderClient: list directory finished: \(result.isSuccess)")
                        self?.completion?(result)
                        syncSemaphore.signal()
                    }
                case .failure(let error):
                    self.completion?(.failure(error))
                    syncSemaphore.signal()
                }
            }
            
            syncSemaphore.wait()        // Operation main() should return when completed
        }
    }

    
    // MARK: - Common
    private static func setupFileTransferIfNeeded(identifier: UUID, completion: @escaping (Result<FileTransferClient, Error>)->Void) {
        let fileTransferClient = FileTransferConnectionManager.shared.fileTransferClient(fromIdentifier: identifier)
        let isReconnecting = FileTransferConnectionManager.shared.isReconnectingPeripheral(withIdentifier: identifier)
        guard fileTransferClient == nil || !fileTransferClient!.isFileTransferEnabled || isReconnecting else {
            // It is already setup
            completion(.success(fileTransferClient!))
            return
        }
        
        // Check ble supported
        guard BleManager.shared.state != .unsupported else {
            DLog("Bluetooth unsupported")
            completion(.failure(GliderError.bluetoothNotSupported))
            return
        }

        // Wait until ble status is known
        FileTransferConnectionManager.shared.waitForKnownBleStatusSynchronously()
        if isReconnecting {     // Already reconnecting, just wait
            DLog("Reconnecting. Wait...")
            FileTransferConnectionManager.shared.waitForStableConnectionsSynchronously()
        }
        else {
            let isTryingToReconnect = FileTransferConnectionManager.shared.reconnect()
            
            // Wait until connections are restored (if needed)
            if isTryingToReconnect {
                DLog("Forced reconnecting. Wait...")
                FileTransferConnectionManager.shared.waitForStableConnectionsSynchronously()
            }
        }

        // Result with fileTransferClient
        if let fileTransferClient = FileTransferConnectionManager.shared.fileTransferClient(fromIdentifier: identifier) {
            DLog("Connection ready")
            completion(.success(fileTransferClient))
        }
        else {
            DLog("Connection failed")
            completion(.failure(GliderError.connectionFailed))
        }
    }

}
