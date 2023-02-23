//
//  BleAdvertisement.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation
import CoreBluetooth

public struct BleAdvertisement {
    var advertisementData: [String: Any]

    init(advertisementData: [String: Any]?) {
        self.advertisementData = advertisementData ?? [String: Any]()
    }

    // Advertisement data formatted
    public var localName: String? {
        return advertisementData[CBAdvertisementDataLocalNameKey] as? String
    }

    public var manufacturerData: Data? {
        return advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    }

    public var manufacturerHexDescription: String? {
        guard let manufacturerData = manufacturerData else { return nil }
        return HexUtils.hexDescription(data: manufacturerData)
//            return String(data: manufacturerData, encoding: .utf8)
    }

    public var manufacturerIdentifier: Data? {
        guard let manufacturerData = manufacturerData, manufacturerData.count >= 2 else { return nil }
        let manufacturerIdentifierData = manufacturerData[0..<2]
        return manufacturerIdentifierData
    }

    public var services: [CBUUID]? {
        return advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }

    public var servicesOverflow: [CBUUID]? {
        return advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }

    public var servicesSolicited: [CBUUID]? {
        return advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }

    public var serviceData: [CBUUID: Data]? {
        return advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    }

    public var txPower: Int? {
        let number = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
        return number?.intValue
    }

    public var isConnectable: Bool? {
        let connectableNumber = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
        return connectableNumber?.boolValue
    }
}
