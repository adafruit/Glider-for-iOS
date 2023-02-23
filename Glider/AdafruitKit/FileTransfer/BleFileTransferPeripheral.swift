//
//  BleFileTransferPeripheral.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation
import CoreBluetooth
import Combine

class BleFileTransferPeripheral: FileTransferPeripheral {
    // Constants
    public static let kFileTransferServiceUUID = CBUUID(string: "FEBB")
    private static let kFileTransferVersionCharacteristicUUID = CBUUID(string: "ADAF0100-4669-6C65-5472-616E73666572")
    private static let kFileTransferDataCharacteristicUUID = CBUUID(string: "ADAF0200-4669-6C65-5472-616E73666572")
    private static let kAdafruitDefaultVersion = 1
    private static let kDebugMessagesEnabled = AppEnvironment.isDebug && true
    
    // Data - Private
    private static let readFileResponseHeaderSize = 16      // (1+1+2+4+4+4+variable)
    private static let deleteFileResponseHeaderSize = 2     // (1+1)
    private static let moveFileResponseHeaderSize = 2       // (1+1)
    private static let writeFileResponseHeaderSize = 20     // (1+1+2+4+8+4)
    private static let makeDirectoryResponseHeaderSize = 16 // (1+1+6+8)
    private static let listDirectoryResponseHeaderSize = 28 // (1+1+2+4+4+4+8+4+variable)
    
    private var fileTransferVersion: Int? = nil
    private var dataCharacteristic: CBCharacteristic? = nil
    private var dataProcessingQueue: DataProcessingQueue? = nil
    private var readStatus: FileTransferReadStatus? = nil
    private var writeStatus: FileTransferWriteStatus? = nil
    private var deleteStatus: FileTransferDeleteStatus? = nil
    private var listDirectoryStatus: FileTransferListDirectoryStatus? = nil
    private var makeDirectoryStatus: FileTransferMakeDirectoryStatus? = nil
    private var moveStatus: FileTransferMoveStatus? = nil
    

    private var blePeripheral: BlePeripheral
    private var onBonded: ((_ name: String, _ uuid: UUID) -> Void)?

    enum BleFileTransferPeripheralError: Error {
        case invalidCharacteristic
        case enableNotifyFailed
        case disableNotifyFailed
        case unknownVersion
        case invalidResponseData
    }
    
    // Data
    var peripheral: Peripheral { blePeripheral }
    var address: String { blePeripheral.address }
    var nameOrAddress: String { blePeripheral.nameOrAddress }
    
    // States
    enum FileTransferState {
        case start      // Note: don't use disconnected as initial state to differentiate between a real disconnect and the initialization
        case connecting
        case connected
        case disconnecting(error: Error? = nil)
        case disconnected(error: Error? = nil)
        
        case discovering
        case checkingFileTransferVersion
        case enablingNotifications
        case enabled
        
        case error(_ error: Error? = nil)
    }
    
    var fileTransferState = CurrentValueSubject<FileTransferState, Error>(.start)
    private var stateObserverCancellable: Cancellable?

    private var setupCompletion: ((Result<Void, Error>) -> Void)? = nil
    
    // MARK: - Lifecycle
    init(blePeripheral: BlePeripheral, onBonded: ((_ name: String, _ uuid: UUID) -> Void)?) {
        self.blePeripheral = blePeripheral
        self.onBonded = onBonded
        
        self.stateUpdatesEnabled(true)
    }
    
    deinit {
        DLog("BleFileTransferPeripheral deinit")
    }

    private func stateUpdatesEnabled(_ enabled: Bool) {
        if enabled {
            
            stateObserverCancellable = blePeripheral.state
                .sink { [weak self] state in
                    guard let self = self else { return }
                    
                    switch state {
                    case .connecting:
                        self.fileTransferState.value = .connecting
                    case .connected:
                        
                        if let completion = self.setupCompletion {
                            self.fileTransferState.value = .discovering
                            
                            // Discover
                            self.fileTransferEnable() { [weak self] result in
                                DLog("File Transfer Enable success: \(result.isSuccess)")
                                guard let self = self else { return }
                                
                                self.setupCompletion = nil
                                
                                switch result {
                                case .success:
                                    self.fileTransferState.value = .enabled
                                    completion(.success(()))
                                    
                                case .failure(let error):
                                    self.fileTransferState.value = .error(error)
                                    completion(.failure(error))
                                }
                            }
                        }
                        else {
                            self.fileTransferState.value = .connected
                        }
                        
                    case .disconnecting:
                        self.fileTransferState.value = .disconnecting()
                        
                    case .disconnected:
                        self.setupCompletion?(.failure(FileTransferError.disconnected))
                        self.disable()
                        self.fileTransferState.value = .disconnected()
                        
                    @unknown default:
                        break
                    }
                }
        }
        else {
            stateObserverCancellable?.cancel()
            stateObserverCancellable = nil
        }
    }
    
    // MARK: - Actions
    func connectAndSetup(connectionTimeout: TimeInterval?, completion: @escaping (Result<Void, Error>) -> Void) {
        
        disable()
        
        fileTransferState.value = .start
        blePeripheral.connect(connectionTimeout: connectionTimeout) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                self.onBonded?(self.blePeripheral.nameOrAddress, self.blePeripheral.identifier)
                self.setupCompletion = completion
                
            case .failure:
                completion(result)
            }
            
        }
    }
    
    // MARK: - Commands
    func listDirectory(path: String, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
        if self.listDirectoryStatus != nil { DLog("Warning: concurrent listDirectory") }
        self.listDirectoryStatus = FileTransferListDirectoryStatus(completion: completion)
                
        let data = ([UInt8]([0x50, 0x00])).data
            + UInt16(path.utf8.count).littleEndian.data
            + Data(path.utf8)
        
        sendCommand(data: data)  { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
    
    func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        self.makeDirectoryStatus = FileTransferMakeDirectoryStatus(completion: completion)
        
        var data = ([UInt8]([0x40, 0x00])).data
            + UInt16(path.utf8.count).littleEndian.data
        
        // Version 3 adds currentTime
        let currentTime = UInt64(Date().timeIntervalSince1970 * 1000*1000*1000)
        data += ([UInt8]([0x00, 0x00, 0x00, 0x00])).data        // 4 bytes padding
        + UInt64(currentTime).littleEndian.data
        
        data += Data(path.utf8)
        
        sendCommand(data: data)  { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
    
    func readFile(path: String, progress: FileTransferProgressHandler?, completion: ((Result<Data, Error>) -> Void)?) {
        self.readStatus = FileTransferReadStatus(progress: progress, completion: completion)
        
        let mtu = blePeripheral.maximumWriteValueLength(for: .withoutResponse)
        
        let offset = 0
        let chunkSize = mtu - Self.readFileResponseHeaderSize
        let data = ([UInt8]([0x10, 0x00])).data
            + UInt16(path.utf8.count).littleEndian.data
            + UInt32(offset).littleEndian.data
            + UInt32(chunkSize).littleEndian.data
            + Data(path.utf8)
       
        sendCommand(data: data) { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
    
    func readFileChunk(offset: UInt32, chunkSize: UInt32, completion: ((Result<Void, Error>) -> Void)?) {
        let data = ([UInt8]([0x12, 0x01, 0x00, 0x00])).data
            + UInt32(offset).littleEndian.data
            + UInt32(chunkSize).littleEndian.data
       
        sendCommand(data: data, completion: completion)
    }
    
    func writeFile(path: String, data fileData: Data, progress: FileTransferProgressHandler?, completion: ((Result<Date?, Error>) -> Void)?) {
        let fileStatus = FileTransferWriteStatus(data: fileData, progress: progress, completion: completion)
        self.writeStatus = fileStatus
        
        let offset = 0
        let totalSize = fileStatus.data.count
        
        var data = ([UInt8]([0x20, 0x00])).data
            + UInt16(path.utf8.count).littleEndian.data
            + UInt32(offset).littleEndian.data
        
        let currentTime = UInt64(Date().timeIntervalSince1970 * 1000*1000*1000)
        data += UInt64(currentTime).littleEndian.data
        
        data += UInt32(totalSize).littleEndian.data
            + Data(path.utf8)
        
        sendCommand(data: data) { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
    
    // Note: uses info stored in adafruitFileTransferFileStatus to resume writing data
    private func writeFileChunk(offset: UInt32, chunkSize: UInt32, completion: ((Result<Void, Error>) -> Void)?) {
        guard let adafruitFileTransferWriteStatus = writeStatus else { completion?(.failure(FileTransferError.invalidInternalState)); return; }

        let chunkData = adafruitFileTransferWriteStatus.data.subdata(in: Int(offset)..<(Int(offset)+Int(chunkSize)))
    
        let data = ([UInt8]([0x22, 0x01, 0x00, 0x00])).data
            + UInt32(offset).littleEndian.data
            + UInt32(chunkSize).littleEndian.data
            + chunkData
       
        if Self.kDebugMessagesEnabled {
            DLog("write chunk at offset \(offset) chunkSize: \(chunkSize). message size: \(data.count). mtu: \(blePeripheral.maximumWriteValueLength(for: .withoutResponse))")
        }
        //DLog("\t\(String(data: chunkData, encoding: .utf8))")
        sendCommand(data: data, completion: completion)
    }
    
    func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        self.deleteStatus = FileTransferDeleteStatus(completion: completion)
        
        let data = ([UInt8]([0x30, 0x00])).data
            + UInt16(path.utf8.count).littleEndian.data
            + Data(path.utf8)
       
        sendCommand(data: data) { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
    
    func moveFile(fromPath: String, toPath: String, completion: ((Result<Void, Error>) -> Void)?) {
        self.moveStatus = FileTransferMoveStatus(completion: completion)
      
        let data = ([UInt8]([0x60, 0x00])).data
            + UInt16(fromPath.utf8.count).littleEndian.data
            + UInt16(toPath.utf8.count).littleEndian.data
            + Data(fromPath.utf8)
            + UInt8(0x00).data           // Padding byte
            + Data(toPath.utf8)
        
        sendCommand(data: data)  { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }
        
    private func sendCommand(data: Data, completion: ((Result<Void, Error>) -> Void)?) {
        guard blePeripheral.state.value == .connected else {
            completion?(.failure(FileTransferError.disconnected))
            return
        }
        
        guard let adafruitFileTransferDataCharacteristic = dataCharacteristic else {
            completion?(.failure(BleFileTransferPeripheralError.invalidCharacteristic))
            return
        }

        blePeripheral.write(data: data, for: adafruitFileTransferDataCharacteristic, type: .withoutResponse) { error in
            guard error == nil else {
                completion?(.failure(error!))
                return
            }

            completion?(.success(()))
        }
    }
    
    // MARK: - File Transfer Management
    
    private func fileTransferEnable(completion: ((Result<Void, Error>) -> Void)?) {
        DLog("Discovering services...")
        
        let serviceUuid = Self.kFileTransferServiceUUID
        blePeripheral.characteristic(uuid: Self.kFileTransferDataCharacteristicUUID, serviceUuid: serviceUuid) { [weak self] (characteristic, error) in
            guard let self = self else { return }
            guard let characteristic = characteristic, error == nil else {
                completion?(.failure(error ?? BleFileTransferPeripheralError.invalidCharacteristic))
                return
            }

            // Check version
            self.fileTransferState.value = .checkingFileTransferVersion
            
            self.adafruitVersion(serviceUuid: serviceUuid, versionCharacteristicUUID: Self.kFileTransferVersionCharacteristicUUID) { [weak self] version in
                guard let self = self else { return }
                DLog("\(self.blePeripheral.nameOrAddress) FileTransfer Protocol v\(version) detected")
                
                self.fileTransferVersion = version
                self.dataCharacteristic = characteristic
                
                // Set notify
                self.fileTransferState.value = .enablingNotifications
                self.adafruitServiceSetNotifyResponse(characteristic: characteristic, responseHandler: self.receiveFileTransferData, completion: completion)
         
            }
        }
    }
    
    func adafruitFileTransferIsEnabled() -> Bool {
        return dataCharacteristic != nil && dataCharacteristic!.isNotifying
    }
    
    func disable() {
        //statusUpdatesEnabled(false)
        setupCompletion = nil
        
        // Clear all internal data
        fileTransferVersion = nil
        dataCharacteristic = nil
        dataProcessingQueue?.reset(forceReleaseLock: true)
        dataProcessingQueue = nil
        
        // Clear all internal variables for commands, sending an error to the completion handler if it was still executing
        readStatus?.completion?(.failure(FileTransferError.disconnected))
        readStatus = nil

        writeStatus?.completion?(.failure(FileTransferError.disconnected))
        writeStatus = nil

        deleteStatus?.completion?(.failure(FileTransferError.disconnected))
        deleteStatus = nil
        
        listDirectoryStatus?.completion?(.failure(FileTransferError.disconnected))
        listDirectoryStatus = nil
        
        makeDirectoryStatus?.completion?(.failure(FileTransferError.disconnected))
        makeDirectoryStatus = nil
        
        moveStatus?.completion?(.failure(FileTransferError.disconnected))
        moveStatus = nil
    }
    
    
    // MARK: - Receive Data
    private func receiveFileTransferData(response: Result<(Data, UUID), Error>) {
        switch response {
        case .success(let (receivedData, peripheralIdentifier)):

            // Init received data
            if dataProcessingQueue == nil {
                dataProcessingQueue = DataProcessingQueue(uuid: peripheralIdentifier)
            }
            
            processDataQueue(receivedData: receivedData)
            
        case .failure(let error):
            DLog("receiveFileTransferData error: \(error)")
        }
    }
    
    private func processDataQueue(receivedData: Data) {
        guard let adafruitFileTransferDataProcessingQueue = dataProcessingQueue else { return }
        
        adafruitFileTransferDataProcessingQueue.processQueue(receivedData: receivedData) { remainingData in
            return decodeResponseChunk(data: remainingData)
        }
    }
    
    /// Returns number of bytes processed (they will need to be discarded from the queue)
    // Note: Take into account that data can be a Data-slice
    private func decodeResponseChunk(data: Data) -> Int {
        var bytesProcessed =  0
        guard let command = data.first else { DLog("Error: response invalid data"); return bytesProcessed }
        
        //DLog("received command: \(command)")
        switch command {
        case 0x11:
            bytesProcessed = decodeReadFile(data: data)

        case 0x21:
            bytesProcessed = decodeWriteFile(data: data)

        case 0x31:
            bytesProcessed = decodeDeleteFile(data: data)

        case 0x41:
            bytesProcessed = decodeMakeDirectory(data: data)

        case 0x51:
            bytesProcessed = decodeListDirectory(data: data)

        case 0x61:
            bytesProcessed = decodeMoveFile(data: data)

        default:
            DLog("Error: unknown command: \(HexUtils.hexDescription(bytes: [command], prefix: "0x")). Invalidating all received data...")
         
            bytesProcessed = Int.max        // Invalidate all received data
        }

        return bytesProcessed
    }

    private func decodeMoveFile(data: Data) -> Int {
        guard let adafruitFileTransferMoveStatus = moveStatus else { DLog("Error: write invalid internal status. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferMoveStatus.completion

        guard data.count >= Self.moveFileResponseHeaderSize else { return 0 }      // Header has not been fully received yet

        let status = data[1]
        let isMoved = status == 0x01
        
        self.writeStatus = nil
        if isMoved {
            completion?(.success(()))
        }
        else {
            completion?(.failure(FileTransferError.statusFailed(code: Int(status))))
        }
        
        return Self.moveFileResponseHeaderSize        // Return processed bytes
    }
    
    private func decodeWriteFile(data: Data) -> Int {
        guard let adafruitFileTransferWriteStatus = writeStatus else { DLog("Error: write invalid internal status. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferWriteStatus.completion
        
        guard data.count >= Self.writeFileResponseHeaderSize else { return 0 }     // Header has not been fully received yet

        var decodingOffset = 1
        let status = data[decodingOffset]
        let isStatusOk = status == 0x01
        
        decodingOffset = 4  // Skip padding
        let offset: UInt32 = data.scanValue(start: decodingOffset, length: 4)
        decodingOffset += 4
        var writeDate: Date? = nil
        if fileTransferVersion ?? Self.kAdafruitDefaultVersion >= 3 {
            let truncatedTime: UInt64 = data.scanValue(start: decodingOffset, length: 8)
            writeDate = Date(timeIntervalSince1970: TimeInterval(truncatedTime)/(1000*1000*1000))
            decodingOffset += 8
        }
        let freeSpace: UInt32 = data.scanValue(start: decodingOffset, length: 4)

        if Self.kDebugMessagesEnabled {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd-HH:mm:ss"
            DLog("write \(isStatusOk ? "ok":"error(\(status))") at offset: \(offset). \(writeDate == nil ? "" : "date: \(dateFormatter.string(from: writeDate!))") freespace: \(freeSpace)")
        }

        guard isStatusOk else {
            self.writeStatus = nil
            completion?(.failure(FileTransferError.statusFailed(code: Int(status))))
            return Int.max      // invalidate all received data on error
        }
        
        adafruitFileTransferWriteStatus.progress?(Int(offset), Int(adafruitFileTransferWriteStatus.data.count))

        if offset >= adafruitFileTransferWriteStatus.data.count  {
            self.writeStatus = nil
            completion?(.success((writeDate)))
        }
        else {
            writeFileChunk(offset: offset, chunkSize: freeSpace) { result in
                if case .failure(let error) = result {
                    self.writeStatus = nil
                    completion?(.failure(error))
                }
            }
        }
        
        return Self.writeFileResponseHeaderSize      // Return processed bytes
    }
    
    /// Returns number of bytes processed
    private func decodeReadFile(data: Data) -> Int {
        guard let adafruitFileTransferReadStatus = readStatus else { DLog("Error: read invalid internal status. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferReadStatus.completion
        
        guard data.count >= Self.readFileResponseHeaderSize else { return 0 }        // Header has not been fully received yet

        let status = data[1]
        let isStatusOk = status == 0x01
        
        let offset: UInt32 = data.scanValue(start: 4, length: 4)
        let totalLength: UInt32 = data.scanValue(start: 8, length: 4)
        let chunkSize: UInt32 = data.scanValue(start: 12, length: 4)
        
        if Self.kDebugMessagesEnabled { DLog("read \(isStatusOk ? "ok":"error") at offset \(offset) chunkSize: \(chunkSize) totalLength: \(totalLength)") }

        guard isStatusOk else {
            self.readStatus = nil
            completion?(.failure(FileTransferError.statusFailed(code: Int(status))))
            return Int.max      // invalidate all received data on error
        }

        let packetSize = Self.readFileResponseHeaderSize + Int(chunkSize)
        guard data.count >= packetSize else { return 0 }        // The first chunk is still no available wait for it

        let chunkData = data.subdata(in: Self.readFileResponseHeaderSize..<packetSize)
        self.readStatus!.data.append(chunkData)
        
        adafruitFileTransferReadStatus.progress?(Int(offset + chunkSize), Int(totalLength))

        if offset + chunkSize < totalLength {
            let mtu = blePeripheral.maximumWriteValueLength(for: .withoutResponse)
            let maxChunkLength = mtu - Self.readFileResponseHeaderSize
            readFileChunk(offset: offset + chunkSize, chunkSize: UInt32(maxChunkLength)) { result in
                if case .failure(let error) = result {
                    self.readStatus = nil
                    completion?(.failure(error))
                }
            }
        }
        else {
            let fileData = self.readStatus!.data
            self.readStatus = nil
            completion?(.success(fileData))
        }
        
        return packetSize       // Return processed bytes
    }

    private func decodeDeleteFile(data: Data) -> Int {
        guard let adafruitFileTransferDeleteStatus = deleteStatus else {
            DLog("Warning: unexpected delete result received. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferDeleteStatus.completion

        guard data.count >= Self.deleteFileResponseHeaderSize else { return 0 }      // Header has not been fully received yet

        let status = data[1]
        let isDeleted = status == 0x01
        
        self.deleteStatus = nil
        if isDeleted {
            completion?(.success(()))
        }
        else {
            completion?(.failure(FileTransferError.statusFailed(code: Int(status))))
        }
        
        return Self.deleteFileResponseHeaderSize        // Return processed bytes
    }
    
    private func decodeMakeDirectory(data: Data) -> Int {
        guard let adafruitFileTransferMakeDirectoryStatus = makeDirectoryStatus else { DLog("Warning: unexpected makeDirectory result received. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferMakeDirectoryStatus.completion

        guard data.count >= Self.makeDirectoryResponseHeaderSize else { return 0 }      // Header has not been fully received yet

        let status = data[1]
        let isCreated = status == 0x01
        
        self.makeDirectoryStatus = nil
        if isCreated {
            var modificationDate: Date? = nil
            let truncatedTime: UInt64 = data.scanValue(start: 8, length: 8)
            modificationDate = Date(timeIntervalSince1970: TimeInterval(truncatedTime)/(1000*1000*1000))
            
            completion?(.success(modificationDate))
        }
        else {
            completion?(.failure(FileTransferError.statusFailed(code: Int(status))))
        }
        
        return Self.makeDirectoryResponseHeaderSize  // Return processed bytes
    }
    
    private func decodeListDirectory(data: Data) -> Int {
        guard let adafruitFileTransferListDirectoryStatus = listDirectoryStatus else {
            DLog("Warning: unexpected list result received. Invalidating all received data..."); return Int.max }
        let completion = adafruitFileTransferListDirectoryStatus.completion
        
        let headerSize = Self.listDirectoryResponseHeaderSize
        guard data.count >= headerSize else { return 0 }       // Header has not been fully received yet
        var packetSize = headerSize      // Chunk size processed (can be less that data.count if several chunks are included in the data)
        
        let directoryExists = data[data.startIndex + 1] == 0x1
        if directoryExists, data.count >= headerSize {
            let entryCount: UInt32 = data.scanValue(start: 8, length: 4)
            if entryCount == 0  {             // Empty directory
                self.listDirectoryStatus = nil
                completion?(.success([]))
            }
            else {
                let pathLength: UInt16 = data.scanValue(start: 2, length: 2)
                let entryIndex: UInt32 = data.scanValue(start: 4, length: 4)
                
                if entryIndex >= entryCount  {     // Finished. Return entries
                    let entries = self.listDirectoryStatus!.entries
                    self.listDirectoryStatus = nil
                    if Self.kDebugMessagesEnabled { DLog("list: finished") }
                    completion?(.success(entries))
                }
                else {
                    let flags: UInt32 = data.scanValue(start: 12, length: 4)
                    let isDirectory = flags & 0x1 == 1
                    
                    var decodingOffset = 16
                    var modificationDate: Date? = nil
                    let truncatedTime: UInt64 = data.scanValue(start: decodingOffset, length: 8)
                    modificationDate = Date(timeIntervalSince1970: TimeInterval(truncatedTime)/(1000*1000*1000))
                    decodingOffset += 8
                    
                    let fileSize: UInt32 = data.scanValue(start: decodingOffset, length: 4)        // Ignore for directories
                    
                    guard data.count >= headerSize + Int(pathLength) else { return 0 } // Path is still no available wait for it
                    
                    if pathLength > 0, let path = String(data: data[(data.startIndex + headerSize)..<(data.startIndex + headerSize + Int(pathLength))], encoding: .utf8) {
                        packetSize += Int(pathLength)        // chunk includes the variable length path, so add it
                        
                        if Self.kDebugMessagesEnabled {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy/MM/dd-HH:mm:ss"
                            DLog("list: \(entryIndex+1)/\(entryCount) \(isDirectory ? "directory":"file size: \(fileSize) bytes") \(modificationDate == nil ? "" : "date: \(dateFormatter.string(from: modificationDate!))"), path: '/\(path)'")
                        }
                        let entry = DirectoryEntry(name: path, type: isDirectory ? .directory : .file(size: Int(fileSize)), modificationDate: modificationDate)
                        
                        // Add entry
                        self.listDirectoryStatus?.entries.append(entry)
                    }
                    else {
                        self.listDirectoryStatus = nil
                        completion?(.failure(FileTransferError.invalidData))
                    }
                }
            }
        }
        else {
            self.listDirectoryStatus = nil
            completion?(.success(nil))      // nil means directory does not exist
        }
        
        return packetSize
    }
    
    // MARK: - Service Utils
    private func adafruitVersion(serviceUuid: CBUUID, versionCharacteristicUUID: CBUUID,  completion: @escaping(Int) -> Void) {
        blePeripheral.characteristic(uuid: versionCharacteristicUUID, serviceUuid: serviceUuid) { [weak self] (characteristic, error) in
            guard let self = self else { return }

            // Check if version characteristic exists or return default value
            guard error == nil, let characteristic = characteristic  else {
                completion(Self.kAdafruitDefaultVersion)
                return
            }
            
            // Read the version
            self.blePeripheral.readCharacteristic(characteristic) { (result, error) in
                guard error == nil, let data = result as? Data, data.count >= 4 else {
                    completion(Self.kAdafruitDefaultVersion)
                    return
                }
                
                let version = data.toIntFrom32Bits()
                completion(version)
            }
        }
    }

    func adafruitServiceSetNotifyResponse(characteristic: CBCharacteristic, responseHandler: @escaping(Result<(Data, UUID), Error>) -> Void, completion: ((Result<Void, Error>) -> Void)?) {

        // Prepare notification handler
        let notifyHandler: ((Error?) -> Void)? = { [unowned self] error in
            guard error == nil else {
                responseHandler(.failure(error!))
                return
            }
            
            if let data = characteristic.value {
                responseHandler(.success((data, blePeripheral.identifier)))
            }
        }
        
        // Enable notifications
        if !characteristic.isNotifying {
            blePeripheral.enableNotify(for: characteristic, handler: notifyHandler, completion: { error in
                guard error == nil else {
                    completion?(.failure(error!))
                    return
                }
                guard characteristic.isNotifying else {
                    completion?(.failure(BleFileTransferPeripheralError.enableNotifyFailed))
                    return
                }
                
                completion?(.success(()))
                
            })
        } else {
            blePeripheral.updateNotifyHandler(for: characteristic, handler: notifyHandler)
            completion?(.success(()))
        }
    }
    
    
    // MARK: - Data structures
    private struct FileTransferReadStatus {
        var data = Data()
        var progress: FileTransferProgressHandler?
        var completion: ((Result<Data, Error>) -> Void)?
    }
    
    private struct FileTransferWriteStatus {
        var data: Data
        var progress: FileTransferProgressHandler?
        var completion: ((Result<Date?, Error>) -> Void)?
    }

    private struct FileTransferDeleteStatus {
        var completion: ((Result<Void, Error>) -> Void)?
    }

    private struct FileTransferListDirectoryStatus {
        var entries = [DirectoryEntry]()
        var completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?
    }

    private struct FileTransferMakeDirectoryStatus {
        var completion: ((Result<Date?, Error>) -> Void)?
    }
    
    private struct FileTransferMoveStatus {
        var completion: ((Result<Void, Error>) -> Void)?
    }
    
    // MARK: - Errors
    public enum FileTransferError: LocalizedError {
        case invalidData
        case unknownCommand
        case invalidInternalState
        case statusFailed(code: Int)
        case disconnected
        
        public var errorDescription: String? {
            switch self {
            case .invalidData: return "invalid data"
            case .unknownCommand: return "unknown command"
            case .invalidInternalState: return "invalid internal state"
            case .statusFailed(let code):
                if code == 5 {
                    return "status error: \(code). Filesystem in read-only mode"
                } else {
                    return "status error: \(code)"
                }
            case .disconnected: return "disconnected"
            }
        }
    }
}
