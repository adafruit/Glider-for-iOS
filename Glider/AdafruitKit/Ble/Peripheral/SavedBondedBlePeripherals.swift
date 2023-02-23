//
//  SavedBondedBlePeripherals.swift
//  Glider
//
//  Created by Antonio García on 4/10/22.
//

import Foundation

class SavedBondedBlePeripherals: ObservableObject {
    // Constants
    private static let dataKey = "data"
 
    // Parameters
    var userDefaults: UserDefaults        // Can be replaced if data saved needs to be shared

    struct PeripheralData: Codable {
        var name: String?
        let uuid: UUID
    }
    
    // Published
    @Published var peripheralsData = [PeripheralData]()
    

    // Internal data
    private var peripheralsDataLock = NSLock()
    
    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
        self.peripheralsData = getPeripheralsData()
    }
    
    // MARK: - Actions
    func add(name: String?, uuid: UUID) {
        peripheralsDataLock.lock(); defer { peripheralsDataLock.unlock() }
        
        // If already exist that address, remove it and add it to update the name
        let existingPeripheral = peripheralsData.first { $0.uuid == uuid }
        
        // Continue if not exist or the name has changed
        if existingPeripheral == nil || existingPeripheral!.name != name {
            // If the name has changed, remove it to add it with the new name
            if existingPeripheral != nil {
                peripheralsData.removeAll { $0.uuid == uuid }
            }
            
            peripheralsData.append(PeripheralData(name: name, uuid: uuid))
            setBondedPeripherals(peripheralsData)
        }
        
    }
    
    func remove(uuid: UUID) {
        peripheralsDataLock.lock(); defer { peripheralsDataLock.unlock() }
        
        peripheralsData.removeAll { $0.uuid == uuid }
        setBondedPeripherals(peripheralsData)
    }

    func clear() {
        peripheralsDataLock.lock(); defer { peripheralsDataLock.unlock() }
        
        setBondedPeripherals([])
    }

    private func getPeripheralsData() -> [PeripheralData] {
        guard let data = userDefaults.object(forKey: Self.dataKey) as? Data,
              let result = try? JSONDecoder().decode([PeripheralData].self, from: data) else {
            return []
        }
        
        return result
    }
    
    
    // MARK: - Utils
    private func setBondedPeripherals(_ peripherals: [PeripheralData]) {
            
        if let encoded = try? JSONEncoder().encode(peripheralsData) {
            userDefaults.set(encoded, forKey: Self.dataKey)
        }
        
        peripheralsData = peripherals
    }
    
}
