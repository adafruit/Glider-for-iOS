//
//  FileTransferClient.swift
//  Glider
//
//  Created by Antonio García on 26/10/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth
import FileTransferClient

// Note: this is a fake replacement for FileTransferClient to make it work on the simulator which doesn't support bluetooth
// Important: dont add this file to the Glider target. Use it only for testing purposes
public class FileTransferClient {
    // Data structs
    public typealias ProgressHandler = ((_ transmittedBytes: Int, _ totalBytes: Int) -> Void)
    
    public enum ClientError: Error {
        case errorDiscoveringServices
        case serviceNotEnabled
    }
    
    public enum Service: CaseIterable {
        case filetransfer
        
        var debugName: String {
            switch self {
            case .filetransfer: return "File Transfer"
            }
        }
    }
    
    // Notifications
    enum NotificationUserInfoKey: String {
        case uuid = "uuid"
        case value = "value"
    }
 
    // Data
    private(set) public weak var blePeripheral: BlePeripheral?

    // MARK: - Init
    /**
     Don't use this init.
     It is provided to help testing views in Xcode
     */
    public init() {
        guard AppEnvironment.inXcodePreviewMode else {
            assert(false)
            return
        }
    }
    
    /**
     Init from CBPeripheral
     
     - parameters:
     - connectedCBPeripehral: a *connected* CBPeripheral
     - services: list of BoardServices that will be started. Use nil to select all the supported services
     - completion: completion handler
     */
    convenience init(connectedCBPeripheral peripheral: CBPeripheral, services: [Service]? = nil, completion: @escaping (Result<FileTransferClient, Error>) -> Void) {
        let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: nil, rssi: nil)
        self.init(connectedBlePeripheral: blePeripheral, services: services, completion: completion)
    }
        
    /**
     Init from BlePeripheral
     
     - parameters:
     - connectedBlePeripheral: a *connected* BlePeripheral
     - services: list of BoardServices that will be started. Use nil to select all the supported services
     - completion: completion handler
     */
    public init(connectedBlePeripheral blePeripheral: BlePeripheral, services: [Service]? = nil, completion: @escaping (Result<FileTransferClient, Error>) -> Void) {
        
        let selectedServices = services != nil ? services! : Service.allCases   // If services is nil, select all services
        self.setupServices(blePeripheral: blePeripheral, services: selectedServices, completion: completion)
    }
    
    private func setupServices(blePeripheral: BlePeripheral, services: [Service], completion: @escaping (Result<FileTransferClient, Error>) -> Void) {
        
        // Set current peripheral
        self.blePeripheral = blePeripheral
        
        completion(.success((self)))
    }

    // MARK: - Sensor availability
    public var isFileTransferEnabled: Bool {
        return true
    }
    
    func isEnabled(service: Service) -> Bool {
        switch service {
        case .filetransfer: return isFileTransferEnabled
        }
    }
    
    // MARK: - File Transfer Commands
    
    /// Given a full path, returns the full contents of the file
    public func readFile(path: String, progress: ProgressHandler? = nil, completion: ((Result<Data, Error>) -> Void)?) {
        // Fake file contnets
        
        let text = """
        import time
        import board
        import neopixel


        pixels = neopixel.NeoPixel(board.NEOPIXEL, 10, brightness=0.2, auto_write=False)
        PURPLE = (10, 0, 25)
        PINK = (25, 0, 10)
        OFF = (0,0,0)

        while True:
            pixels.fill(PURPLE)
            pixels.show()
            time.sleep(0.5)
            pixels.fill(OFF)
            pixels.show()
            time.sleep(0.5)
            pixels.fill(PINK)
            pixels.show()
            time.sleep(0.5)
            pixels.fill(OFF)
            pixels.show()
            time.sleep(0.5)
        """
                
        completion?(.success(text.data(using: .utf8)!))
    }

    ///  Writes the content to the given full path. If the file exists, it will be overwritten
    public func writeFile(path: String, data: Data, progress: ProgressHandler? = nil, completion: ((Result<Date?, Error>) -> Void)?) {
        completion?(.success(Date()))
    }
    
    /// Deletes the file or directory at the given full path. Directories must be empty to be deleted
    public func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        completion?(.success((())))
    }

    /**
     Creates a new directory at the given full path. If a parent directory does not exist, then it will also be created. If any name conflicts with an existing file, an error will be returned
        - Parameter path: Full path
    */
    public func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        completion?(.success(Date()))
    }

    /// Lists all of the contents in a directory given a full path. Returned paths are relative to the given path to reduce duplication
    public func listDirectory(path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        // Fake directory
        var entries = [BlePeripheral.DirectoryEntry]()
        entries.append(.init(name: "adafruit", type: .directory, modificationDate: Date()))
        entries.append(.init(name: "code.py", type: .file(size: 1575), modificationDate: Date()))
        entries.append(.init(name: "boot_out.txt", type: .file(size: 149), modificationDate: Date()))
        entries.append(.init(name: "lib", type: .directory, modificationDate: Date()))
        entries.append(.init(name: "docs", type: .directory, modificationDate: Date()))
        entries.append(.init(name: "readme.txt", type: .file(size: 223), modificationDate: Date()))
        entries.append(.init(name: ".Trashes", type: .file(size: 0), modificationDate: Date()))
        completion?(.success(entries))
    }
    
    /// Moves a single file from fromPath to toPath
    public func moveFile(fromPath: String, toPath: String, completion: ((Result<Void, Error>) -> Void)?) {
        blePeripheral?.moveFile(fromPath: fromPath, toPath: toPath, completion: completion)
    }
}

