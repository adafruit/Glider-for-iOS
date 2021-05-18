//
//  BlePeripheral+FileTransfer.swift
//  Glider
//
//  Created by Antonio García on 13/5/21.
//

import Foundation
import CoreBluetooth

extension BlePeripheral {
    // Config
    private static let kDebugLog = true
 
    // Constants
    static let kFileTransferServiceUUID = CBUUID(string: "FEBB")
    private static let kFileTransferVersionCharacteristicUUID = CBUUID(string: "ADAF0100-4669-6C65-5472-616E73666572")
    private static let kFileTransferDataCharacteristicUUID = CBUUID(string: "ADAF0200-4669-6C65-5472-616E73666572")
    private static let kAdafruitFileTransferVersion = 1

    // Data types
    struct FileTransferWriteStatus {
        var data: Data
        var completion: ((Result<Void, Error>) -> Void)?
    }

    struct FileTransferReadStatus {
        var data: Data
        var completion: ((Result<Data, Error>) -> Void)?
    }

    // MARK: - Errors
    enum FileTransferError: Error {
        case invalidData
        case unknownCommand
        case invalidInternalState
        case statusFailed
    }
    
        // MARK: - Custom properties
    private struct CustomPropertiesKeys {
        static var adafruitFileTransferDataCharacteristic: CBCharacteristic?
        static var adafruitFileTransferWriteStatus: FileTransferWriteStatus?
        static var adafruitFileTransferReadStatus: FileTransferReadStatus?
    }

    private var adafruitFileTransferDataCharacteristic: CBCharacteristic? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferDataCharacteristic) as? CBCharacteristic
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferDataCharacteristic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var adafruitFileTransferWriteStatus: FileTransferWriteStatus? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferWriteStatus) as? FileTransferWriteStatus
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferWriteStatus, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
   
    private var adafruitFileTransferReadStatus: FileTransferReadStatus? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferReadStatus) as? FileTransferReadStatus
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.adafruitFileTransferReadStatus, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    

    // MARK: - Actions
    func adafruitFileTransferEnable(completion: ((Result<Void, Error>) -> Void)?) {
        
        // Note: don't check version because version characteristic is not available yet
        self.adafruitServiceEnable(serviceUuid: Self.kFileTransferServiceUUID, mainCharacteristicUuid: Self.kFileTransferDataCharacteristicUUID) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case let .success((_, characteristic)):
                self.adafruitFileTransferDataCharacteristic = characteristic
                
                self.adafruitServiceSetNotifyResponse(characteristic: characteristic, responseHandler: self.receiveFileTransferData, completion: completion)
                
            case let .failure(error):
                self.adafruitFileTransferDataCharacteristic = nil
                completion?(.failure(error))
            }
        }
            
        /*
        self.adafruitServiceEnableIfVersion(version: Self.kAdafruitFileTransferVersion, serviceUuid: Self.kFileTransferServiceUUID, versionCharacteristicUUID: Self.kFileTransferVersionCharacteristicUUID, mainCharacteristicUuid: Self.kFileTransferDataCharacteristicUUID) { result in
            switch result {
            case let .success(characteristic):
                self.adafruitFileTransferDataCharacteristic = characteristic
                completion?(.success(()))
                
            case let .failure(error):
                self.adafruitFileTransferDataCharacteristic = nil
                completion?(.failure(error))
            }
        }*/
    }
    
    func adafruitFileTransferIsEnabled() -> Bool {
        return adafruitFileTransferDataCharacteristic != nil
    }
    
    func adafruitFileTransferDisable() {
        // Clear all specific data
        adafruitFileTransferDataCharacteristic = nil
    }
    
    static let readDataHeaderLength = 16
    
    // MARK: - Commands
    func readFile(filename: String, completion: ((Result<Data, Error>) -> Void)?) {
        self.adafruitFileTransferReadStatus = FileTransferReadStatus(data: Data(), completion: completion)
        
        let mtu = self.maximumWriteValueLength(for: .withoutResponse)
        
        let offset = 0
        let chunkSize = mtu - Self.readDataHeaderLength //self.maximumWriteValueLength(for: .withoutResponse)
        let data = ([UInt8]([0x10, 0x00])).data
            + UInt16(filename.count).littleEndian.data
            + UInt32(offset).littleEndian.data
            + UInt32(chunkSize).littleEndian.data
            + Data(filename.utf8)
       
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
    
    func writeFile(data: Data, filename: String, completion: ((Result<Void, Error>) -> Void)?) {
        let fileStatus = FileTransferWriteStatus(data: data, completion: completion)
        self.adafruitFileTransferWriteStatus = fileStatus

        let offset = 0
        let totalSize = fileStatus.data.count
        
        let data = ([UInt8]([0x20, 0x00])).data
            + UInt16(filename.count).littleEndian.data
            + UInt32(offset).littleEndian.data
            + UInt32(totalSize).littleEndian.data
            + Data(filename.utf8)
       
        sendCommand(data: data) { result in
            if case .failure(let error) = result {
                completion?(.failure(error))
            }
        }
    }

    // Note: uses info stored in adafruitFileTransferFileStatus to resume writing data
    private func writeFileChunk(offset: UInt32, chunkSize: UInt32, completion: ((Result<Void, Error>) -> Void)?) {
        
        guard let adafruitFileTransferWriteStatus = adafruitFileTransferWriteStatus else {  completion?(.failure(FileTransferError.invalidInternalState)); return;}

        let chunkData = adafruitFileTransferWriteStatus.data.subdata(in: Int(offset)..<(Int(offset)+Int(chunkSize)))
    
        let data = ([UInt8]([0x22, 0x01, 0x00, 0x00])).data
            + UInt32(offset).littleEndian.data
            + UInt32(chunkSize).littleEndian.data
            + chunkData
       
        print("\twrite chunk at offset \(offset) chunkSize: \(chunkSize). message size: \(data.count) mtu: \(self.maximumWriteValueLength(for: .withoutResponse))")
        //print("\t\t\(String(data: chunkData, encoding: .utf8))")
        sendCommand(data: data, completion: completion)
    }
    
    func listDirectory(_ directory: String, completion: ((Result<Void, Error>) -> Void)?) {

        let data = ([UInt8]([0x50, 0x00])).data
            + UInt16(directory.count).littleEndian.data
            + Data(directory.utf8)
        
        sendCommand(data: data, completion: completion)
    }
    
    private func sendCommand(data: Data, completion: ((Result<Void, Error>) -> Void)?) {
        guard let adafruitFileTransferDataCharacteristic = adafruitFileTransferDataCharacteristic else {
            completion?(.failure(PeripheralAdafruitError.invalidCharacteristic))
            return
        }

        self.write(data: data, for: adafruitFileTransferDataCharacteristic, type: .withoutResponse) { error in
            guard error == nil else {
                completion?(.failure(error!))
                return
            }

            completion?(.success(()))
        }
    }
    
    // MARK: - Receive Data
    private func receiveFileTransferData(response: Result<(Data, UUID), Error>) {
        switch response {
        case .success(let (data, _)):
            decodeResponse(data: data)
                    
        case .failure(let error):
            print("receiveFileTransferData error: \(error)")
        }
    }
    
    private func decodeResponse(data: Data) {
        guard let command = data.first else { print("Error: response invalid data"); return }
        
        switch command {
        case 0x11:
            decodeReadFile(data: data)

        case 0x21:
            decodeWriteFile(data: data)
            
        case 0x51:
            print("List directory response")
            //decodeListDirectory(data: data)

        default:
            print("unknown command: \(command)")
            
        }
    }

    private func decodeWriteFile(data: Data) {
        guard let adafruitFileTransferWriteStatus = adafruitFileTransferWriteStatus else { print("Error: invalid internal status"); return }
        let completion = adafruitFileTransferWriteStatus.completion
        
        guard data.count >= 12 else { completion?(.failure(FileTransferError.invalidData)); return }
        
        let status = data[1]
        let isStatusOk = status == 0x01
        
        let offset: UInt32 = data.scanValue(start: 4, length: 4)
        let freeSpace: UInt32 = data.scanValue(start: 8, length: 4)

        print("\twrite \(isStatusOk ? "ok":"error") at offset: \(offset) free space: \(freeSpace)")
        guard isStatusOk else {
            completion?(.failure(FileTransferError.statusFailed))
            return
        }
        
        if offset >= adafruitFileTransferWriteStatus.data.count  {
            self.adafruitFileTransferWriteStatus = nil
            completion?(.success(()))
        }
        else {
            //let mtu = 100000 //self.maximumWriteValueLength(for: .withoutResponse)
            writeFileChunk(offset: offset, chunkSize: freeSpace/*min(UInt32(mtu), freeSpace)*/) { result in
                if case .failure(let error) = result {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    private func decodeReadFile(data: Data) {
        guard let adafruitFileTransferReadStatus = adafruitFileTransferReadStatus else { print("Error: invalid internal status"); return }
        let completion = adafruitFileTransferReadStatus.completion
        
        guard data.count > 3 else { completion?(.failure(FileTransferError.invalidData)); return }

        let status = data[1]
        let isStatusOk = status == 0x01
        
        let offset: UInt32 = data.scanValue(start: 4, length: 4)
        let totalLenght: UInt32 = data.scanValue(start: 8, length: 4)
        let chunkSize: UInt32 = data.scanValue(start: 12, length: 4)
        
        print("\tread \(isStatusOk ? "ok":"error") at offset \(offset) chunkSize: \(chunkSize) totalLength: \(totalLenght)")
        guard isStatusOk else {
            completion?(.failure(FileTransferError.statusFailed))
            return
        }

        let chunkData = data.subdata(in: Self.readDataHeaderLength..<Self.readDataHeaderLength + Int(chunkSize))
        //let chunkData = data.subdata(in: Self.readDataHeaderLength..<Int(chunkEndingOffset))
        self.adafruitFileTransferReadStatus!.data.append(chunkData)
        
        //if self.adafruitFileTransferReadStatus!.data.count < totalLenght {
        if offset + chunkSize < totalLenght {
            let mtu = self.maximumWriteValueLength(for: .withoutResponse)
            let maxChunkLength = mtu - Self.readDataHeaderLength
            readFileChunk(offset: offset + chunkSize, chunkSize: UInt32(maxChunkLength)) { result in
                if case .failure(let error) = result {
                    completion?(.failure(error))
                }
            }
        }
        else {
            let fileData = self.adafruitFileTransferReadStatus!.data
            self.adafruitFileTransferReadStatus = nil
            completion?(.success(fileData))
        }
    }
    
    private func decodeListDirectory(data: Data) -> Result<Void, Error> {
        guard data.count > 1 else { return  .failure(FileTransferError.invalidData)}
        let directoryExists = data[1] == 0x1
        if directoryExists, data.count >= 20 {
            let pathLength: UInt16 = data.scanValue(start: 2, length: 2)
            let entryIndex: UInt32 = data.scanValue(start: 4, length: 4)
            let entryCount: UInt32 = data.scanValue(start: 8, length: 4)
            let flags: UInt32 = data.scanValue(start: 12, length: 4)
            let isDirectory = flags == 0
            let fileSize: UInt32 = data.scanValue(start: 16, length: 4)
            
            var path: String?
            if pathLength > 0 {
                let pathBytes: [UInt8] = data.scanValue(start: 20, length: Int(pathLength))
                path = String(data: pathBytes.data, encoding: .utf8)
            }
            
            print("list: \(entryIndex)/\(entryCount) \(isDirectory ? "Directory":"File") \(fileSize) \(path ?? "<nil>")")
        }
        
        return .success(())
    }
}

