//
//  GliderClient.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import Foundation
import os.log
import Combine

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
    private static var sharedInstances = [FileProviderItem.PeripheralType: GliderClient]()
    static func shared(peripheralType: FileProviderItem.PeripheralType) -> GliderClient {
        guard let instance = sharedInstances[peripheralType] else {
            // Create new instance
            logger.info("Create GliderClient instance for \(peripheralType.address)")
            let client = GliderClient(peripheralType: peripheralType)
            sharedInstances[peripheralType] = client
            return client
        }
        return instance     // Return existing instance
    }

    // Data
    private static let logger = Logger.createLogger(category: "GliderClient")

    private lazy var operationsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Operations queue for \(peripheralType)"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    // MARK: - Lifecycle
    private let peripheralType: FileProviderItem.PeripheralType
    
    private init(peripheralType: FileProviderItem.PeripheralType) {
        self.peripheralType = peripheralType
    }
    
    /*
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
    
    */
    // MARK: - List Directory
    func listDirectory(path: String, connectionManager: ConnectionManager, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
        let operation = GliderListDirectoryFileOperation(peripheralType: peripheralType, path: path, connectionManager: connectionManager, completion: completion)
        Self.logger.info("GliderClient: add list directory operation \(path)")
        operationsQueue.addOperation(operation)
    }
    
    private class GliderOperation: Operation {
        // Config
        private static let kMaxTimeToWaitForBleSupport: TimeInterval = 5.0
        private static let kMaxTimeToWaitForPeripheralConnection: TimeInterval = 5.0
      
        // Data
        private static let logger = Logger.createLogger(category: "GliderOperation")

        private let bleSupportSemaphore = DispatchSemaphore(value: 0)
        private let connectionSemaphore = DispatchSemaphore(value: 0)
        private var cancellables = Set<AnyCancellable>()
              
        func setupFileTransferIfNeeded(peripheralType: FileProviderItem.PeripheralType, connectionManager: ConnectionManager, completion: @escaping (Result<FileTransferClient, Error>)->Void) {
            
            let peripheralAddress = peripheralType.address
            var fileTransferClient = connectionManager.fileTransferClient(address: peripheralAddress)
            let isBeingSetup = connectionManager.peripheralAddressesBeingSetup.contains(peripheralAddress)
            
            guard fileTransferClient == nil || /*!fileTransferClient!.isFileTransferEnabled || */isBeingSetup else {
                // It is already setup
                completion(.success(fileTransferClient!))
                return
            }
            
            // Check ble supported
            let bleManager = connectionManager.bleManager
            guard bleManager.bleState != .unsupported else {
                Self.logger.info("Bluetooth unsupported")
                completion(.failure(GliderError.bluetoothNotSupported))
                return
            }
            
            // Wait until ble status is known
            waitForKnownBleStatusSynchronously(bleManager: bleManager, maxTimeToWaitForBleSupport: Self.kMaxTimeToWaitForBleSupport)
            if isBeingSetup {     // Already reconnecting, just wait
                Self.logger.info("Reconnecting. Wait...")
                waitForStableConnectionsSynchronously(peripheralAddress: peripheralAddress, connectionManager: connectionManager)
            }
            
            fileTransferClient = connectionManager.fileTransferClient(address: peripheralAddress)
            guard fileTransferClient == nil /*|| !fileTransferClient!.isFileTransferEnabled  */ else {
                // It is already setup
                completion(.success(fileTransferClient!))
                return
            }
            
            // Connect
            switch peripheralType {
            case .rootContainer:
                Self.logger.error("invalid peripheral: .rootContainer")
                completion(.failure(GliderError.connectionFailed))
                
            case let .bleBondedData(address, _):
                if let uuid = UUID(uuidString: address) {
                    connectionManager.reconnectToBondedBlePeripherals(knownUuids: [uuid]) { fileTransferClients in
                        if let fileTransferClient = fileTransferClients.first {
                            Self.logger.info("reconnectToBondedBlePeripherals ready: \(fileTransferClients)")
                            completion(.success(fileTransferClient))
                        }
                        else {
                            Self.logger.info("reconnectToBondedBlePeripherals failed")
                            completion(.failure(GliderError.connectionFailed))
                        }
                    }
                }
                else {
                    Self.logger.error("invalid peripheral: .bleBondedData")
                    completion(.failure(GliderError.connectionFailed))
                }
                
            case let .ble(address, _),
                let .wifi(address, _):
                connectionManager.connect(knownAddress: address) { result in
                    switch result {
                    case let .success(fileTransferClient):
                        completion(.success(fileTransferClient))
                        
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
            
            /*
            let isTryingToReconnect = FileTransferConnectionManager.shared.reconnect()
            
            // Wait until connections are restored (if needed)
            if isTryingToReconnect {
                Self.logger.info("Forced reconnecting. Wait...")
                waitForStableConnectionsSynchronously(peripheralAddress: peripheralAddress, connectionManager: connectionManager)
            }

            // Result with fileTransferClient
            fileTransferClient = connectionManager.fileTransferClient(address: peripheralAddress)
            if let fileTransferClient = fileTransferClient {
                Self.logger.info("Connection ready")
                completion(.success(fileTransferClient))
            }
            else {
                Self.logger.info("Connection failed")
                completion(.failure(GliderError.connectionFailed))
            }*/
        }

        // MARK: - Utils
        private func waitForKnownBleStatusSynchronously(bleManager: BleManager, maxTimeToWaitForBleSupport: TimeInterval) {
            if bleManager.bleState == .unknown || bleManager.bleState == .resetting {
                bleManager.bleStatePublisher
                    .sink { [weak self] notification in
                        guard let self = self else { return }
                        DLog("waitForKnownBleStatusSynchronously status updated: \(bleManager.bleState.rawValue)")
                        self.bleSupportSemaphore.signal()
                        self.cancellables.removeAll()       // Notification observer no longer needed
                    }
                    .store(in: &cancellables)

                let semaphoreResult = self.bleSupportSemaphore.wait(timeout: .now() + maxTimeToWaitForBleSupport)
                if semaphoreResult == .timedOut {
                    DLog("waitForKnownBleStatusSynchronously time-out. status: \(bleManager.bleState.rawValue)")
                }
            }
        }

        private func waitForStableConnectionsSynchronously(peripheralAddress: String, connectionManager: ConnectionManager) {
            let isBeingSetup = connectionManager.peripheralAddressesBeingSetup.contains(peripheralAddress)
            
            guard isBeingSetup else  { return }
            DLog("Wait for connection started")
            
            connectionManager.peripheralAddressesBeingSetup.publisher.sink { peripheralAddressesBeingSetup in
                let isBeingSetup = connectionManager.peripheralAddressesBeingSetup.contains(peripheralAddress)
                            
                if !isBeingSetup {
                    DLog("Wait for connection finished")
                    self.connectionSemaphore.signal()
                    self.cancellables.removeAll()       // Notification observer no longer needed
                }
            }
            .store(in: &cancellables)
            
            let semaphoreResult = self.connectionSemaphore.wait(timeout: .now() + Self.kMaxTimeToWaitForPeripheralConnection)
            if semaphoreResult == .timedOut {
                DLog("Wait for connection check time-out")
            }
        }

    }
    
    private class GliderListDirectoryFileOperation: GliderOperation {
        private let peripheralType: FileProviderItem.PeripheralType
        
        private let path: String
        private let connectionManager: ConnectionManager
        private let completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?
        
        init(peripheralType: FileProviderItem.PeripheralType, path: String, connectionManager: ConnectionManager, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
            self.peripheralType = peripheralType
            self.path = path
            self.connectionManager = connectionManager
            self.completion = completion
            super.init()
        }
        
        override func main() {
            guard !isCancelled else { completion?(.failure(GliderError.cancelled)); return }
            
            //DLog("GliderClient: list directory start")
            let syncSemaphore = DispatchSemaphore(value: 0)     // Make the main() function synchronous
            setupFileTransferIfNeeded(peripheralType: peripheralType, connectionManager: connectionManager) { [weak self] result in
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

    
 
    
    
    
}
