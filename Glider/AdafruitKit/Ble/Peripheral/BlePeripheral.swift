//
//  BlePeripheral.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation
import CoreBluetooth
import Combine

class BlePeripheral: NSObject, Peripheral {
    // Constants
    static var kUndefinedRssiValue = 127

    // Notifications
    public enum NotificationUserInfoKey: String {
        case uuid = "uuid"
        case name = "name"
        case invalidatedServices = "invalidatedServices"
    }

    enum PeripheralError: Error {
        case timeout
        case disconnection
        case invalidState
    }
    
    // Data
    var peripheral: CBPeripheral
    var bleManager: BleManager
    
    var identifier: UUID {
        return peripheral.identifier
    }
    
    var name: String? {
        return peripheral.name
    }
    
    var address: String {
        return identifier.uuidString
    }
    var nameOrAddress: String { return name ?? address }
    
    let createdTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
   
    var lastSeenTime: CFAbsoluteTime
   
     /*
    var currentState: CBPeripheralState {
        return peripheral.state
    }*/
   
    var state: CurrentValueSubject<CBPeripheralState, Never>
    
    func maximumWriteValueLength(for: CBCharacteristicWriteType) -> Int {
        return peripheral.maximumWriteValueLength(for: .withoutResponse)
    }
    
    var rssi: Int?
    
    public var advertisement: BleAdvertisement

    typealias CapturedReadCompletionHandler = ((_ value: Any?, _ error: Error?) -> Void)
    private class CaptureReadHandler {

        var identifier: String
        var result: CapturedReadCompletionHandler
        var timeoutTimer: Timer?
        var timeoutAction: ((String) -> Void)?
        var isNotifyOmitted: Bool

        init(identifier: String, result: @escaping CapturedReadCompletionHandler, timeout: Double?, timeoutAction: ((String) -> Void)?, isNotifyOmitted: Bool = false) {
            self.identifier = identifier
            self.result = result
            self.isNotifyOmitted = isNotifyOmitted

            if let timeout = timeout {
                self.timeoutAction = timeoutAction
                DispatchQueue.global(qos: .background).async {
                    self.timeoutTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(self.timerFired), userInfo: nil, repeats: false)
                }
            }
        }

        @objc private func timerFired() {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            result(nil, PeripheralError.timeout)
            timeoutAction?(identifier)
        }
    }

    private func timeOutRemoveCaptureHandler(identifier: String) {   // Default behaviour for a capture handler timeout
        guard captureReadHandlers.count > 0, let index = captureReadHandlers.firstIndex(where: {$0.identifier == identifier}) else { return }
        // DLog("captureReadHandlers index: \(index) / \(captureReadHandlers.count)")

        // Remove capture handler
        captureReadHandlers.remove(at: index)
        finishedExecutingCommand(error: PeripheralError.timeout)
    }
    
    // Internal data
    private var connectionTimeoutTimer: Timer?
    private var connectionCompletion: ((Result<Void, Error>) -> Void)?
    private var stateObserverCancellable: Cancellable?

    private var notifyHandlers = [String: ((Error?) -> Void)]()                 // Nofify handlers for each service-characteristic
    private var captureReadHandlers = [CaptureReadHandler]()
    private var commandQueue: CommandQueue<BleCommand>?
    
    // MARK: - Init
    public init(peripheral: CBPeripheral, bleManager: BleManager, advertisementData: [String: Any]?, rssi: Int?) {
        self.peripheral = peripheral
        self.bleManager = bleManager
        self.advertisement = BleAdvertisement(advertisementData: advertisementData)
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
        self.state = CurrentValueSubject<CBPeripheralState, Never>(peripheral.state)

        super.init()
        self.rssi = rssi
        
        /*
        if AppEnvironment.isDebug, let name = peripheral.name, name.starts(with: "CIRCUIT") {
            DLog("create peripheral: \(peripheral.name ?? peripheral.identifier.uuidString)")
        }*/
        
        
        // State observer
        
    }
    
    deinit {
        DLog("blePeripheral deinit")
    }

    private func stateUpdatesEnabled(_ enabled: Bool) {
        if enabled {
            commandQueue = CommandQueue<BleCommand>(executeHandler: executeCommand)
            
            stateObserverCancellable = peripheral.publisher(for: \.state)
                //.removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] newState in
                    guard let self = self else { return }
                    guard newState != self.state.value else { return }
                    
                    DLog("blePeripheral: \(self.nameOrAddress) status: \(newState.rawValue)")
                    switch newState {
                    case .connected:
                        let completionHandler = self.connectionCompletion
                        self.reset()
                        completionHandler?(.success(()))
                        
                    case .disconnected:
                        let completionHandler = self.connectionCompletion
                        self.reset()
                        completionHandler?(.failure(PeripheralError.disconnection))
                    
                        if self.peripheral.delegate === self {
                            self.peripheral.delegate = nil
                        }
                        self.stateObserverCancellable?.cancel()
                        self.stateObserverCancellable = nil
                        
                    default:
                        break
                    }
                    
                    self.state.value = newState
                }
        }
        else {
            stateObserverCancellable?.cancel()
            stateObserverCancellable = nil

            commandQueue?.removeAll()
            commandQueue = nil

        }
    }
    
    func reset() {
        DLog("Command queue reset")
        self.connectionCompletion = nil
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        rssi = nil
        notifyHandlers.removeAll()
        captureReadHandlers.removeAll()
        commandQueue?.first()?.isCancelled = true        // Stop current command if is processing
        commandQueue?.removeAll()
    }

    // MARK: - Discover
    func discover(serviceUuids: [CBUUID]?, completion: ((Error?) -> Void)?) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .discoverService, parameters: serviceUuids, completion: completion)
        commandQueue.append(command)
    }

    func discover(characteristicUuids: [CBUUID]?, service: CBService, completion: ((Error?) -> Void)?) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .discoverCharacteristic, parameters: [characteristicUuids as Any, service], completion: completion)
        commandQueue.append(command)
    }

    func discover(characteristicUuids: [CBUUID]?, serviceUuid: CBUUID, completion: ((Error?) -> Void)?) {
        // Discover service
        discover(serviceUuids: [serviceUuid]) { [unowned self] error in
            guard error == nil else {
                completion?(error)
                return
            }

            guard let service = self.peripheral.services?.first(where: {$0.uuid == serviceUuid}) else {
                completion?(BleCommand.CommandError.invalidService)
                return
            }

            // Discover characteristic
            self.discover(characteristicUuids: characteristicUuids, service: service, completion: completion)
        }
    }

    func discoverDescriptors(characteristic: CBCharacteristic, completion: ((Error?) -> Void)?) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
       
        let command = BleCommand(type: .discoverDescriptor, parameters: [characteristic], completion: completion)
        commandQueue.append(command)
    }
    
    // MARK: - Connection
    func connect(connectionTimeout: TimeInterval?, shouldNotifyOnConnection: Bool = false, shouldNotifyOnDisconnection: Bool = false, shouldNotifyOnNotification: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {

        stateUpdatesEnabled(true)
        self.connectionCompletion = completion
        
        // Connect
        NotificationCenter.default.post(name: .willConnectToPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: identifier])

        var options: [String: Bool]?
        if shouldNotifyOnConnection || shouldNotifyOnDisconnection || shouldNotifyOnNotification {
            options = [CBConnectPeripheralOptionNotifyOnConnectionKey: shouldNotifyOnConnection, CBConnectPeripheralOptionNotifyOnDisconnectionKey: shouldNotifyOnDisconnection, CBConnectPeripheralOptionNotifyOnNotificationKey: shouldNotifyOnNotification]
        }

        
        if let timeout = connectionTimeout {
            self.connectionTimeoutTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(self.connectionTimeoutFired), userInfo: identifier, repeats: false)
        }
        
        bleManager.connect(peripheral: peripheral, options: options)
        // Wait for result via state changes
    }
    
    
    @objc private func connectionTimeoutFired(timer: Timer) {
        self.connectionTimeoutTimer = nil

        NotificationCenter.default.post(name: .willDisconnectFromPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: identifier])

        bleManager.cancelPeripheralConnection(peripheral: peripheral)
    }
    
    func disconnect() {
        guard let commandQueue = commandQueue else {  return }
       
        let command = BleCommand(type: .disconnect, parameters: [bleManager], completion: nil)
        commandQueue.append(command)
    }
    
    
    // MARK: - Service
    func discoveredService(uuid: CBUUID) -> CBService? {
        let service = peripheral.services?.first(where: {$0.uuid == uuid})
        return service
    }

    func service(uuid: CBUUID, completion: ((CBService?, Error?) -> Void)?) {

        if let discoveredService = discoveredService(uuid: uuid) {                      // Service was already discovered
            completion?(discoveredService, nil)
        } else {
            discover(serviceUuids: [uuid], completion: { [unowned self] error in      // Discover service
                var discoveredService: CBService?
                if error == nil {
                    discoveredService = self.discoveredService(uuid: uuid)
                }
                completion?(discoveredService, error)
            })
        }
    }

    // MARK: - Characteristic
    func discoveredCharacteristic(uuid: CBUUID, service: CBService) -> CBCharacteristic? {
        let characteristic = service.characteristics?.first(where: {$0.uuid == uuid})
        return characteristic
    }

    func characteristic(uuid: CBUUID, service: CBService, completion: ((CBCharacteristic?, Error?) -> Void)?) {

        if let discoveredCharacteristic = discoveredCharacteristic(uuid: uuid, service: service) {              // Characteristic was already discovered
            completion?(discoveredCharacteristic, nil)
        } else {
            discover(characteristicUuids: [uuid], service: service, completion: { [unowned self] (error) in     // Discover characteristic
                var discoveredCharacteristic: CBCharacteristic?
                if error == nil {
                    discoveredCharacteristic = self.discoveredCharacteristic(uuid: uuid, service: service)
                }
                completion?(discoveredCharacteristic, error)
            })
        }
    }

    func characteristic(uuid: CBUUID, serviceUuid: CBUUID, completion: ((CBCharacteristic?, Error?) -> Void)?) {
        if let discoveredService = discoveredService(uuid: serviceUuid) {                                              // Service was already discovered
            characteristic(uuid: uuid, service: discoveredService, completion: completion)
        } else {                                                                                                // Discover service
            service(uuid: serviceUuid) { (service, error) in
                if let service = service, error == nil {                                                        // Discover characteristic
                    self.characteristic(uuid: uuid, service: service, completion: completion)
                } else {
                    completion?(nil, error != nil ? error: BleCommand.CommandError.invalidService)
                }
            }
        }
    }

    func enableNotify(for characteristic: CBCharacteristic, handler: ((Error?) -> Void)?, completion: ((Error?) -> Void)? = nil) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .setNotify, parameters: [characteristic, true, handler as Any], completion: completion)
        commandQueue.append(command)
    }

    func disableNotify(for characteristic: CBCharacteristic, completion: ((Error?) -> Void)? = nil) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .setNotify, parameters: [characteristic, false], completion: completion)
        commandQueue.append(command)
    }

    func updateNotifyHandler(for characteristic: CBCharacteristic, handler: ((Error?) -> Void)? = nil) {
        let identifier = handlerIdentifier(from: characteristic)
        if notifyHandlers[identifier] == nil {
            DLog("Warning: trying to update non-existent notifyHandler")
        }
        notifyHandlers[identifier] = handler
    }

    func readCharacteristic(_ characteristic: CBCharacteristic, completion readCompletion: @escaping CapturedReadCompletionHandler) {
        guard let commandQueue = commandQueue else { readCompletion(nil, PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .readCharacteristic, parameters: [characteristic, readCompletion as Any], completion: nil)
        commandQueue.append(command)
    }

    func write(data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: ((Error?) -> Void)? = nil) {
        guard let commandQueue = commandQueue else { completion?(PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .writeCharacteristic, parameters: [characteristic, type, data], completion: completion)
        commandQueue.append(command)
    }

    func writeAndCaptureNotify(data: Data, for characteristic: CBCharacteristic, writeCompletion: ((Error?) -> Void)? = nil, readCharacteristic: CBCharacteristic, readTimeout: Double? = nil, readCompletion: CapturedReadCompletionHandler? = nil) {
        guard let commandQueue = commandQueue else { writeCompletion?(PeripheralError.invalidState); return }
        
        let type: CBCharacteristicWriteType = .withResponse     // Force write with response
        let command = BleCommand(type: .writeCharacteristicAndWaitNofity, parameters: [characteristic, type, data, readCharacteristic, readCompletion as Any, readTimeout as Any], timeout: readTimeout, completion: writeCompletion)
        commandQueue.append(command)
    }

    // MARK: - Descriptors
    func readDescriptor(_ descriptor: CBDescriptor, completion readCompletion: @escaping CapturedReadCompletionHandler) {
        guard let commandQueue = commandQueue else { readCompletion(nil, PeripheralError.invalidState); return }
        
        let command = BleCommand(type: .readDescriptor, parameters: [descriptor, readCompletion as Any], completion: nil)
        commandQueue.append(command)
    }

    // MARK: - Rssi
    func readRssi() {
        peripheral.readRSSI()
    }

    
    // MARK: - Command Queue
    internal class BleCommand: Equatable {
        enum CommandType {
            case discoverService
            case discoverCharacteristic
            case discoverDescriptor
            case setNotify
            case readCharacteristic
            case writeCharacteristic
            case writeCharacteristicAndWaitNofity
            case readDescriptor
            case disconnect
        }

        enum CommandError: Error {
            case invalidService
        }

        var type: CommandType
        var parameters: [Any]?
        var completion: ((Error?) -> Void)?
        var isCancelled = false

        init(type: CommandType, parameters: [Any]?, timeout: Double? = nil, completion: ((Error?) -> Void)?) {
            self.type = type
            self.parameters = parameters
            self.completion = completion
        }

        func completion(withError error: Error?) {
            completion?(error)
        }

        static func == (left: BleCommand, right: BleCommand) -> Bool {
            return left.type == right.type
        }
    }
    
    private func executeCommand(command: BleCommand) {
        // Force update peripheral delegate in case other BlePeripherals have been created with the same CBPeripheral
        self.peripheral.delegate = self

        switch command.type {
        case .discoverService:
            discoverService(with: command)
        case .discoverCharacteristic:
            discoverCharacteristic(with: command)
        case .discoverDescriptor:
            discoverDescriptor(with: command)
        case .setNotify:
            setNotify(with: command)
        case .readCharacteristic:
            readCharacteristic(with: command)
        case .writeCharacteristic, .writeCharacteristicAndWaitNofity:
            write(with: command)
        case .readDescriptor:
            readDescriptor(with: command)
        case .disconnect:
            disconnect(with: command)
        }
    }

    private func handlerIdentifier(from characteristic: CBCharacteristic) -> String {
        guard let service = characteristic.service else { DLog("Error: handleIdentifier with nil characteritic service"); return "" }
        return "\(service.uuid.uuidString)-\(characteristic.uuid.uuidString)"
    }

    private func handlerIdentifier(from descriptor: CBDescriptor) -> String {
        guard let characteristic = descriptor.characteristic, let service = characteristic.service else { DLog("Error: handleIdentifier with nil descriptor service"); return "" }
        return "\(service.uuid.uuidString)-\(characteristic.uuid.uuidString)-\(descriptor.uuid.uuidString)"
    }

    internal func finishedExecutingCommand(error: Error?) {
        //DLog("finishedExecutingCommand")
        guard let commandQueue = commandQueue else {  return }
       

        // Result Callback
        if let command = commandQueue.first(), !command.isCancelled {
            command.completion(withError: error)
        }
        commandQueue.executeNext()
    }
    
    // MARK: - Commands
    private func discoverService(with command: BleCommand) {
        var serviceUuids = command.parameters as? [CBUUID]
        let discoverAll = serviceUuids == nil

        // Remove services already discovered from the query
        if let services = peripheral.services, let serviceUuidsToDiscover = serviceUuids {
            for (i, serviceUuid) in serviceUuidsToDiscover.enumerated().reversed() {
                if services.contains(where: {$0.uuid == serviceUuid}) {
                    serviceUuids!.remove(at: i)
                }
            }
        }

        // Discover remaining uuids
        if discoverAll || (serviceUuids != nil && serviceUuids!.count > 0) {
            peripheral.discoverServices(serviceUuids)
        } else {
            // Everything was already discovered
            finishedExecutingCommand(error: nil)
        }
    }

    private func discoverCharacteristic(with command: BleCommand) {
        var characteristicUuids = command.parameters![0] as? [CBUUID]
        let discoverAll = characteristicUuids == nil
        let service = command.parameters![1] as! CBService

        // Remove services already discovered from the query
        if let characteristics = service.characteristics, let characteristicUuidsToDiscover = characteristicUuids {
            for (i, characteristicUuid) in characteristicUuidsToDiscover.enumerated().reversed() {
                if characteristics.contains(where: {$0.uuid == characteristicUuid}) {
                    characteristicUuids!.remove(at: i)
                }
            }
        }

        // Discover remaining uuids
        if discoverAll || (characteristicUuids != nil && characteristicUuids!.count > 0) {
            //DLog("discover \(characteristicUuids == nil ? "all": String(characteristicUuids!.count)) characteristics for \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(characteristicUuids, for: service)
        } else {
            // Everthing was already discovered
            finishedExecutingCommand(error: nil)
        }
    }

    private func discoverDescriptor(with command: BleCommand) {
        let characteristic = command.parameters![0] as! CBCharacteristic
        peripheral.discoverDescriptors(for: characteristic)
    }

    private func setNotify(with command: BleCommand) {
        let characteristic = command.parameters![0] as! CBCharacteristic
        let enabled = command.parameters![1] as! Bool
        let identifier = handlerIdentifier(from: characteristic)
        if enabled {
            let handler = command.parameters![2] as? ((Error?) -> Void)
            notifyHandlers[identifier] = handler
        } else {
            notifyHandlers.removeValue(forKey: identifier)
        }
        peripheral.setNotifyValue(enabled, for: characteristic)
    }

    private func readCharacteristic(with command: BleCommand) {
        let characteristic = command.parameters!.first as! CBCharacteristic
        let completion = command.parameters![1] as! CapturedReadCompletionHandler

        let identifier = handlerIdentifier(from: characteristic)
        let captureReadHandler = CaptureReadHandler(identifier: identifier, result: completion, timeout: nil, timeoutAction: timeOutRemoveCaptureHandler)
        captureReadHandlers.append(captureReadHandler)

        peripheral.readValue(for: characteristic)
    }

    private func write(with command: BleCommand) {
        let characteristic = command.parameters![0] as! CBCharacteristic
        let writeType = command.parameters![1] as! CBCharacteristicWriteType
        let data = command.parameters![2] as! Data

        
        if writeType == .withoutResponse {
            let mtu = maximumWriteValueLength(for: .withoutResponse)
            var offset = 0
            while offset < data.count {
                let chunkData = data.subdata(in: offset ..< min(offset + mtu, data.count))
                //DLog("blewrite offset: \(offset) / \(data.count), size: \(chunkData.count)")
                peripheral.writeValue(chunkData, for: characteristic, type: .withoutResponse)
                offset += chunkData.count
            }
            
            if !command.isCancelled, command.type == .writeCharacteristicAndWaitNofity {
                let readCharacteristic = command.parameters![3] as! CBCharacteristic
                let readCompletion = command.parameters![4] as! CapturedReadCompletionHandler
                let timeout = command.parameters![5] as? Double

                let identifier = handlerIdentifier(from: readCharacteristic)
                let captureReadHandler = CaptureReadHandler(identifier: identifier, result: readCompletion, timeout: timeout, timeoutAction: timeOutRemoveCaptureHandler)
                captureReadHandlers.append(captureReadHandler)
            }

            finishedExecutingCommand(error: nil)
        }
        else {
            peripheral.writeValue(data, for: characteristic, type: writeType)
        }
    }

    private func readDescriptor(with command: BleCommand) {
        let descriptor = command.parameters!.first as! CBDescriptor
        let completion = command.parameters![1] as! CapturedReadCompletionHandler

        let identifier = handlerIdentifier(from: descriptor)
        let captureReadHandler = CaptureReadHandler(identifier: identifier, result: completion, timeout: nil, timeoutAction: timeOutRemoveCaptureHandler)
        captureReadHandlers.append(captureReadHandler)

        peripheral.readValue(for: descriptor)
    }

    internal func disconnect(with command: BleCommand) {
        let bleManager = command.parameters!.first as! BleManager
        bleManager.cancelPeripheralConnection(peripheral: self.peripheral)
        finishedExecutingCommand(error: nil)
    }
}


// MARK: - CBPeripheralDelegate
extension BlePeripheral: CBPeripheralDelegate {
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        DLog("peripheralDidUpdateName: \(name ?? "{ No Name }")")
        NotificationCenter.default.post(name: .peripheralDidUpdateName, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier, NotificationUserInfoKey.name.rawValue: name as Any])
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("didModifyServices")
        NotificationCenter.default.post(name: .peripheralDidModifyServices, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier, NotificationUserInfoKey.invalidatedServices.rawValue: invalidatedServices])
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        //DLog("didDiscoverServices for: \(peripheral.name ?? peripheral.identifier.uuidString)")
        finishedExecutingCommand(error: error)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        ///DLog("didDiscoverCharacteristicsFor: \(service.uuid.uuidString)")
        finishedExecutingCommand(error: error)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        finishedExecutingCommand(error: error)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        let identifier = handlerIdentifier(from: characteristic)

        /*
        if (BlePeripheral.kProfileCharacteristicUpdates) {
            let currentTime = CACurrentMediaTime()
            let elapsedTime = currentTime - profileStartTime
            DLog("elapsed: \(String(format: "%.1f", elapsedTime * 1000))")
            profileStartTime = currentTime
        }
         */
        //DLog("didUpdateValueFor \(characteristic.uuid.uuidString): \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? "<invalid>")")

        // Check if waiting to capture this read
        var isNotifyOmitted = false
        var hasCaptureHandler = false
        if captureReadHandlers.count > 0, let index = captureReadHandlers.firstIndex(where: {$0.identifier == identifier}) {
            hasCaptureHandler = true
            // DLog("captureReadHandlers index: \(index) / \(captureReadHandlers.count)")

            // Remove capture handler
            let captureReadHandler = captureReadHandlers.remove(at: index)

            //  DLog("captureReadHandlers postRemove count: \(captureReadHandlers.count)")

            // Cancel timeout timer
            captureReadHandler.timeoutTimer?.invalidate()
            captureReadHandler.timeoutTimer = nil

            // Send result
            let value = characteristic.value
            //  DLog("updated value: \(String(data: value!, encoding: .utf8)!)")
            captureReadHandler.result(value, error)

            isNotifyOmitted = captureReadHandler.isNotifyOmitted
        }

        // Notify
        if !isNotifyOmitted {
            if let notifyHandler = notifyHandlers[identifier] {

                //let currentTime = CACurrentMediaTime()
                notifyHandler(error)
                //DLog("elapsed: \(String(format: "%.1f", (CACurrentMediaTime() - currentTime) * 1000))")
            }
        }

        if hasCaptureHandler {
            finishedExecutingCommand(error: error)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let commandQueue = commandQueue else {  return }
       
        if let command = commandQueue.first(), !command.isCancelled, command.type == .writeCharacteristicAndWaitNofity {
            let characteristic = command.parameters![3] as! CBCharacteristic
            let readCompletion = command.parameters![4] as! CapturedReadCompletionHandler
            let timeout = command.parameters![5] as? Double
            let identifier = handlerIdentifier(from: characteristic)

            //DLog("read timeout started")
            let captureReadHandler = CaptureReadHandler(identifier: identifier, result: readCompletion, timeout: timeout, timeoutAction: timeOutRemoveCaptureHandler)
            captureReadHandlers.append(captureReadHandler)
        } else {
            finishedExecutingCommand(error: error)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        finishedExecutingCommand(error: error)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        let identifier = handlerIdentifier(from: descriptor)

        if captureReadHandlers.count > 0, let index = captureReadHandlers.firstIndex(where: {$0.identifier == identifier}) {
            // Remove capture handler
            let captureReadHandler = captureReadHandlers.remove(at: index)

            // Send result
            let value = descriptor.value
            captureReadHandler.result(value, error)

            finishedExecutingCommand(error: error)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { DLog("didReadRSSI error: \(error!.localizedDescription)"); return }

        let rssi = RSSI.intValue
        if rssi != BlePeripheral.kUndefinedRssiValue {  // only update rssi value if is defined ( 127 means undefined )
            self.rssi = rssi
        }

        NotificationCenter.default.post(name: .peripheralDidUpdateRssi, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    public static let peripheralDidUpdateName = Notification.Name(kPrefix+".peripheralDidUpdateName")
    public static let peripheralDidModifyServices = Notification.Name(kPrefix+".peripheralDidModifyServices")
    public static let peripheralDidUpdateRssi = Notification.Name(kPrefix+".peripheralDidUpdateRssi")
}
