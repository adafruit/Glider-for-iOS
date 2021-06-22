//
//  AdafruitBoard.swift
//  BluefruitPlayground
//
//  Created by Antonio García on 26/10/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
 Manages the sensors for a connected Adafruit Board
 
 - Supported sensors:
 - FileTransfer
 
 */
class AdafruitBoard {
    // Data structs
    enum BoardError: Error {
        case errorBoardNotConnected
        case errorDiscoveringServices
    }
    
    enum BoardService: CaseIterable {
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
    private(set) weak var blePeripheral: BlePeripheral?
    /*
    var model: BlePeripheral.AdafruitManufacturerData.BoardModel? {
        return blePeripheral?.adafruitManufacturerData()?.boardModel
    }*/

    // MARK: - Init
    /**
     Init from CBPeripheral
     
     - parameters:
     - connectedCBPeripehral: a *connected* CBPeripheral
     - services: list of BoardServices that will be started. Use nil to select all the supported services
     - completion: completion handler
     */
    convenience init(connectedCBPeripheral peripheral: CBPeripheral, services: [BoardService]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
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
    init(connectedBlePeripheral blePeripheral: BlePeripheral, services: [BoardService]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        
        DLog("Discovering services")
        let peripheralIdentifier = blePeripheral.identifier
        NotificationCenter.default.post(name: .willDiscoverServices, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheralIdentifier])
        blePeripheral.discover(serviceUuids: nil) { error in
            // Check errors
            guard error == nil else {
                DLog("Error discovering services")
                DispatchQueue.main.async {
                    completion(.failure(BoardError.errorDiscoveringServices))
                }
                return
            }
            
            // Setup services
            let selectedServices = services != nil ? services! : BoardService.allCases   // If services is nil, select all services
            self.setupServices(blePeripheral: blePeripheral, services: selectedServices, completion: completion)
        }
    }
    
    private func setupServices(blePeripheral: BlePeripheral, services: [BoardService], completion: @escaping (Result<Void, Error>) -> Void) {
        
        // Set current peripheral
        self.blePeripheral = blePeripheral
        
        // Setup services
        let servicesGroup = DispatchGroup()
        
        // File Transfer
        if services.contains(.filetransfer) {
            servicesGroup.enter()
            blePeripheral.adafruitFileTransferEnable() { _ in
                servicesGroup.leave()
            }
        }
        
        // Wait for all finished
        servicesGroup.notify(queue: DispatchQueue.main) { [unowned self] in
            DLog("setupServices finished")
            
            if AppEnvironment.isDebug {
                for service in services {
                    DLog(self.isEnabled(service: service) ? "\(service.debugName) reading enabled":"\(service.debugName) service not available")
                }
            }
            
            completion(.success(()))
        }
    }

    // MARK: - Sensor availability
    var isFileTransferEnabled: Bool {
        return blePeripheral?.adafruitFileTransferIsEnabled() ?? false
    }
    
    func isEnabled(service: BoardService) -> Bool {
        switch service {
        case .filetransfer: return isFileTransferEnabled
        }
    }
    
    // MARK: - File Transfer Commands
    func readFile(path: String, completion: ((Result<Data, Error>) -> Void)?) {
        blePeripheral?.readFile(path: path, completion: completion)
    }

    func writeFile(path: String, data: Data, completion: ((Result<Void, Error>) -> Void)?) {
        blePeripheral?.writeFile(path: path, data: data, completion: completion)
    }
    
    func deleteFile(path: String, completion: ((Result<Bool, Error>) -> Void)?) {
        blePeripheral?.deleteFile(path: path, completion: completion)
    }

    func makeDirectory(path: String, completion: ((Result<Bool, Error>) -> Void)?) {
        blePeripheral?.makeDirectory(path: path, completion: completion)
    }

    func listDirectory(path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        blePeripheral?.listDirectory(path: path, completion: completion)
    }
    
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kNotificationsPrefix = Bundle.main.bundleIdentifier!
    static let willDiscoverServices = Notification.Name(kNotificationsPrefix+".willDiscoverServices")
 }

// MARK: - Equatable
extension AdafruitBoard: Equatable {
    static func ==(lhs: AdafruitBoard, rhs: AdafruitBoard) -> Bool {
        return lhs.blePeripheral == rhs.blePeripheral
    }
}
