//
//  BonjourScannerImpl.swift
//  Glider
//
//  Created by Antonio García on 19/9/22.
//

import Foundation
import Network

class BonjourScannerImpl: BonjourScanner {
    // Data
    private var browser: NWBrowser?
    private var bonjourTCP: NWBrowser.Descriptor
    
    // Published
    @Published private(set) var knownWifiPeripherals = [WifiPeripheral]()
    var knownWifiPeripheralsPublisher: Published<[WifiPeripheral]>.Publisher { $knownWifiPeripherals }

    @Published private(set) var bonjourLastError: Error? = nil
    var bonjourLastErrorPublisher: Published<Error?>.Publisher { $bonjourLastError }
    
    // Data
    private var bonjourResolvers = [BonjourResolver]()
    
    // MARK: - Lifecycle
    init(serviceType: String, serviceDomain: String?) {
        bonjourTCP = NWBrowser.Descriptor.bonjour(type: serviceType, domain: serviceDomain)
    }
    
    // MARK: - Actions
    func start() {
        let bonjourParms = NWParameters.init()
        /*
            bonjourParms.allowLocalEndpointReuse = true
            bonjourParms.acceptLocalOnly = true
            bonjourParms.allowFastOpen = true
        */

        // Recreate browswer because calling .start doesn't seem to work after calling .cancel
        let browser = NWBrowser(for: bonjourTCP, using: bonjourParms)

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                DLog("BonjourScanner error state: \(error)")
                self.browser?.cancel()
            case .ready:
                DLog("BonjourScanner ready")
            case .setup:
                DLog("BonjourScanner setup")
            case .cancelled:
                DLog("BonjourScanner cancelled")
            case .waiting(_):
                DLog("BonjourScanner waiting")
            @unknown default:
                DLog("BonjourScanner unknown state")
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] ( updatedResults, changes ) in
            guard let self = self else { return }
            
            DLog("BonjourScanner changes:")
            for updatedResult in updatedResults {
                DLog("\tendpoint updated: \(updatedResult.endpoint.debugDescription)")
            }
            
            for change in changes {
                switch change {
                    
                case .identical:
                    break
                case let .added(result):
                    DLog("\tadded: \(result)")
                    self.addResult(result)
                case let .removed(result):
                    DLog("\tremoved: \(result)")
                    self.removeResult(endpoint: result.endpoint)
                case let .changed(old: old, new: new, flags: flags):
                    DLog("\tchanged from \(old) to \(new) with flags \(flags)")
                    // Remove existing and add changed
                    self.removeResult(endpoint: old.endpoint)
                    self.addResult(new)
                @unknown default:
                    DLog("\tunknown change")
                }
            }
        }
        
        self.browser = browser
        browser.start(queue: DispatchQueue.main)
        
    }
    
    func stop() {
        browser?.cancel()
        browser = nil
    }
    
    func clearBonjourLastException() {
        bonjourLastError = nil
    }
    
    // MARK: - Utils
    private func addResult(_ result: NWBrowser.Result) {
        if case let(.service(name, type, domain, _)) = result.endpoint {
            
            // Resolve IP
            let service = NetService(domain: domain, type: type, name: name)
            DLog("Resolve service: \(service)")
            let resolver = BonjourResolver.resolve(service: service) { [weak self] result in
                guard let self = self else { return }
                
                // Remove from cached array
                self.bonjourResolvers.removeAll { resolver in
                    resolver.name == name
                }
                
                // Check result from resolver
                switch result {
                case let .success((hostName, port)):
                    DLog("Resolved address: \(hostName):\(port)")
                    self.addResolvedBonjour(name: name, hostName: hostName, port: port)
                    
                case .failure(let error):
                    DLog("Error resolving: \(error)")
                    self.bonjourLastError = error
                }
            }
            
            // Add to cached array (to be able to remove it while resolving)
            bonjourResolvers.append(resolver)

        }
        else {
            DLog("\twarning: result is not a bonjour service")
        }
    }
    
    private func removeResult(endpoint: NWEndpoint) {
        // Check if resolver is executing and remove
        let _ = bonjourResolvers.map { resolver in
            if resolver.name == endpoint.bonjourName() {
                resolver.stop()
            }
        }
        
        // Check if is in the results and remove
        self.knownWifiPeripherals.removeAll { existing in
            return existing.name == endpoint.bonjourName()
        }
    }
    
    private func addResolvedBonjour(name: String, hostName: String, port: Int) {
        // Remove if already exists
        self.knownWifiPeripherals.removeAll { wifiPeripheral in
            wifiPeripheral.name == name
        }
        
        // Add new
        let wifiPeripheral = WifiPeripheral(name: name, address: hostName, port: port)
        self.knownWifiPeripherals.append(wifiPeripheral)
    }
}
