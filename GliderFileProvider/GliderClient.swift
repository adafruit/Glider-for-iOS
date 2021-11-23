//
//  GliderClient.swift
//  GliderFileProvider
//
//  Created by Antonio García on 26/6/21.
//

import Foundation
import FileTransferClient

class GliderClient {
    // Config
    private static let maxTimeToWaitForBleSupport: TimeInterval = 1.0
    private static let willDeviceDisconnectAfterWrite = true    // If the device automatically disconnects after a write, don't signal on write. Wait for the disconnection to happen

    enum GliderError: LocalizedError {
        case bluetoothNotSupported
        case connectionFailed
        case invalidInternalState
        case undefinedFileProviderItem(identifier: String)
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
    private let identifier: UUID
    private let fileTransferSemaphore = DispatchSemaphore(value: 1)
    
    // MARK: -
    private init(identifier: UUID) {
        self.identifier = identifier
    }
    
    // MARK: - Commands (with semaphore to avoid concurrent requests)
    func readFile(path: String, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Data, Error>) -> Void)?) {
        fileTransferSemaphore.wait()
        setupFileTransferIfNeeded { result in
            switch result {
            case .success(let client):
                client.readFile(path: path, progress: progress) {
                    self.fileTransferSemaphore.signal()
                    completion?($0)
                }
            case .failure(let error):
                self.fileTransferSemaphore.signal()
                completion?(.failure(error))
            }
        }
    }
    
    func writeFile(path: String, data: Data, progress: FileTransferClient.ProgressHandler? = nil, completion: ((Result<Void, Error>) -> Void)?) {
        DLog("writeFile requested: \(path)")
        fileTransferSemaphore.wait()
        DLog("writeFile setup: \(path)")
        setupFileTransferIfNeeded { result in
            switch result {
            case .success(let client):
                client.writeFile(path: path, data: data, progress: progress) { result in
                    switch result {
                    case .success:
                        DLog("writeFile finished successfully. Waiting for disconnect")
                        if !Self.willDeviceDisconnectAfterWrite {
                            self.fileTransferSemaphore.signal()
                        }
                        completion?(.success(()))
                        
                    case .failure(let error):
                        DLog("writeFile finished with error")
                        self.fileTransferSemaphore.signal()
                        completion?(.failure(error))
                    }
                }
            case .failure(let error):
                DLog("writeFile setup finished with error")
                self.fileTransferSemaphore.signal()
                completion?(.failure(error))
            }
        }
    }
    
    func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        fileTransferSemaphore.wait()
        setupFileTransferIfNeeded { result in
            switch result {
            case .success(let client):
                client.deleteFile(path: path) { result in
                    self.fileTransferSemaphore.signal()
                    completion?(result)
                }
            case .failure(let error):
                self.fileTransferSemaphore.signal()
                completion?(.failure(error))
            }
        }
    }

    func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        fileTransferSemaphore.wait()
        setupFileTransferIfNeeded { result in
            switch result {
            case .success(let client):
                client.makeDirectory(path: path) {
                    self.fileTransferSemaphore.signal()
                    completion?($0)
                }
            case .failure(let error):
                self.fileTransferSemaphore.signal()
                completion?(.failure(error))
            }
        }
    }

    func listDirectory(path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        fileTransferSemaphore.wait()
        setupFileTransferIfNeeded { result in
            switch result {
            case .success(let client):
                client.listDirectory(path: path) {
                    self.fileTransferSemaphore.signal()
                    completion?($0)
                }
            case .failure(let error):
                self.fileTransferSemaphore.signal()
                completion?(.failure(error))
            }
        }
    }
    
    private func setupFileTransferIfNeeded(completion: @escaping (Result<FileTransferClient, Error>)->Void) {
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
