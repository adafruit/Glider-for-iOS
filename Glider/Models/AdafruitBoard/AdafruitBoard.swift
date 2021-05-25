//
//  AdafruitBoard.swift
//  BluefruitPlayground
//
//  Created by Antonio García on 26/10/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit


/**
 Manages the sensors for a connected Adafruit Board
 
 Use setupPeripheral to bind it to a connected BlePeripheral. setupPeripheral verifies the that sensor firmware version is supported, sets the period for receving data and starts sending the recevied data to the delegate and the NotificationCenter
 
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
    
    // Params - Delegates
 
    // Data
    private(set) weak var blePeripheral: BlePeripheral?
    var model: BlePeripheral.AdafruitManufacturerData.BoardModel? {
        return blePeripheral?.adafruitManufacturerData()?.boardModel
    }

    
    // MARK: - Setup
    
    /**
     Setup the singleton to use a BlePeripheral
     
     - parameters:
     - blePeripheral: a *connected* BlePeripheral
     - services: list of BoardServices that will be started. Use nil to select all the supported services
     - completion: completion handler
     */
    func setupPeripheral(blePeripheral: BlePeripheral, services: [BoardService]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        
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
            let selectedServices = /*Config.isDebugEnabled ? [.temperature] :*/ (services != nil ? services! : BoardService.allCases)   // If services is nil, select all services
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
    
    
    // MARK: - Receive Data
   
    
    // MARK: - Send Commands
 
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kNotificationsPrefix = Bundle.main.bundleIdentifier!
    static let willDiscoverServices = Notification.Name(kNotificationsPrefix+".willDiscoverServices")
    
//    static let didUpdateNeopixelLightSequence = Notification.Name(kNotificationsPrefix+".didUpdateNeopixelLightSequence")
 }
