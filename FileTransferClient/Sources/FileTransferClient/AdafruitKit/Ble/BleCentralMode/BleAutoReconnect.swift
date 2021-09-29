//
//  BleAutoReconnect.swift
//  Glider
//
//  Created by Antonio García on 21/6/21.
//

import Foundation
import CoreBluetooth

public class BleAutoReconnect: ObservableObject {
    // Published
    var peripherals = [BlePeripheral]()

    var isReconnecting = false
    //var isPeripheralReconnecting = [UUID: Bool]()
    
    // Data
    private var servicesToReconnect: [CBUUID]
    private var reconnectHandler: ((_ peripheral: BlePeripheral, _ completion: @escaping (Result<Void, Error>) -> Void) -> ())?
    private let reconnectTimeout: TimeInterval
  
    //  MARK: - Lifecycle
    public init(servicesToReconnect: [CBUUID], reconnectTimeout: TimeInterval = 2, reconnectHandler: @escaping ( BlePeripheral, @escaping (Result<Void, Error>) -> Void) -> ()) {
        DLog("Init autoReconnect to known peripherals")
        self.servicesToReconnect = servicesToReconnect
        self.reconnectTimeout = reconnectTimeout
        self.reconnectHandler = reconnectHandler
        
        registerConnectionNotifications(enabled: true)
    }

    deinit {
        // Unregister notifications
        registerConnectionNotifications(enabled: false)
    }

    /// Returns if is trying to reconnect, or false if it is quickly decided that there is not possible
    @discardableResult
    public func reconnect() -> Bool {
        
        isReconnecting = true
        let isTryingToReconnect = BleManager.shared.reconnecToPeripheralsWithServices(servicesToReconnect, timeout: reconnectTimeout)
        if !isTryingToReconnect {
            DLog("isTryingToReconnect false. Go to next")
            connected(peripheral: nil, isDisconnected: true)
        }
        
        return isTryingToReconnect
    }

    // MARK: - Reconnect previously connnected Ble Peripheral
    private func didConnectToPeripheral(_ notification: Notification) {
        guard isReconnecting else {
            if let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID {
                DLog("AutoReconnect detected connection to identifier: \(identifier)");
            }
            return
        }

        guard let peripheral = BleManager.shared.peripheral(from: notification) else {
            DLog("Connected to an unknown peripheral")
            connected(peripheral: nil, isDisconnected: false)
            return
        }

        connected(peripheral: peripheral, isDisconnected: false)
    }

    private func didDisconnectFromPeripheral() {
        if isReconnecting {
            // Autoconnect failed
            connected(peripheral: nil, isDisconnected: true)
        }
    }

    // Note: added an extra parametrer isDisconnected to fix a problem with the FileProvider disconnections. Think how to improve the syntax
    private func connected(peripheral: BlePeripheral?, isDisconnected: Bool) {
        isReconnecting = false      // Finished reconnection process

        //
        if isDisconnected {
            NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil)
        }
        else if let peripheral = peripheral {
            // Show restoring connection label
            NotificationCenter.default.post(name: .willReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])

            reconnectHandler?(peripheral) { result in
                switch result {
                case .success:
                    DLog("Reconnected to peripheral successfully")
                    NotificationCenter.default.post(name: .didReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])

                case .failure(let error):
                    DLog("Failed to setup peripheral: \(error.localizedDescription)")
                    
                    NotificationCenter.default.post(name: .didFailToReconnectToKnownPeripheral, object: nil, userInfo: [BleManager.NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
                }
            }

        } else {
            // Don't assume that it failed. It could have restored the connection but the internal database in BleManager does not have the BlePeripheral
            NotificationCenter.default.post(name: .didReconnectToKnownPeripheral, object: nil, userInfo: nil)
        }
    }
    

    // MARK: - Notifications
    private var didConnectToPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerConnectionNotifications(enabled: Bool) {
        if enabled {
            didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: { [weak self] notification in self?.didConnectToPeripheral(notification)})
            didDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: { [weak self] _ in self?.didDisconnectFromPeripheral()})
        } else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {NotificationCenter.default.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {NotificationCenter.default.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    public static let willReconnectToKnownPeripheral = Notification.Name(kPrefix+".willReconnectToKnownPeripheral")
    public static let didReconnectToKnownPeripheral = Notification.Name(kPrefix+".didReconnectToKnownPeripheral")
    public static let didFailToReconnectToKnownPeripheral = Notification.Name(kPrefix+".didFailToReconnectToKnownPeripheral")
}
