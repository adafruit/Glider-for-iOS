//
//  BonjourResolver.swift
//  Glider
//
//  Created by Antonio García on 30/8/22.
//

import Foundation

// based on: https://developer.apple.com/forums/thread/673771?answerId=662482022#662482022
class BonjourResolver: NSObject {

    typealias CompletionHandler = (Result<(String, Int), Error>) -> Void
    
    // Data - Private
    private var service: NetService? = nil
    private var completionHandler: (CompletionHandler)? = nil
    //private var selfRetain: BonjourResolver? = nil

    // Data - Public
    var name: String? {
        return service?.name
    }
    
    // MARK: - Lifecycle
    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }
    
    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        //assert(self.service == nil)
        //assert(self.completionHandler == nil)
        //assert(self.selfRetain == nil)
    }
    
    // MARK: - Actions
    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }
    
    private func start() {
        precondition(Thread.isMainThread)
        guard let service = self.service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in `stop(with:)`.
        //selfRetain = self
    }
    

    
    func stop() {
        self.stop(with: .failure(CocoaError(.userCancelled)))
    }
    
    private func stop(with result: Result<(String, Int), Error>) {
        precondition(Thread.isMainThread)
        
        self.service?.delegate = nil
        self.service?.stop()
        self.service = nil
        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(result)
        
        //selfRetain = nil
    }
}

// MARK: - NetServiceDelegate
extension BonjourResolver: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        let port = sender.port
        self.stop(with: .success((hostName, port)))
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
            .flatMap { NetService.ErrorCode.init(rawValue: $0) }
        ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        self.stop(with: .failure(error))
    }
}


/*
 Usage:
 
    let service = NetService(domain: "local.", type: "_ssh._tcp", name: "Fluffy")
    print("will resolve, service: \(service)")
    BonjourResolver.resolve(service: service) { result in
        switch result {
        case .success(let hostName):
            print("did resolve, host: \(hostName)")
            exit(EXIT_SUCCESS)
        case .failure(let error):
            print("did not resolve, error: \(error)")
            exit(EXIT_FAILURE)
        }
    }
    RunLoop.current.run()
 
 */
