//
//  HostNameResolver.swift
//  Glider
//
//  Created by Antonio García on 30/8/22.
//

import Foundation

// from: https://stackoverflow.com/questions/39857435/swift-getaddrinfo
enum SystemError: Swift.Error {
    case getaddrinfo(Int32, Int32?)
}

public func getaddrinfo(node: String, service: String, hints: addrinfo?) throws -> [sockaddr_storage] {
    var err: Int32
    var res: UnsafeMutablePointer<addrinfo>?
    if var hints = hints {
        err = getaddrinfo(node, service, &hints, &res)
    } else {
        err = getaddrinfo(node, service, nil, &res)
    }
    if err == EAI_SYSTEM {
        throw SystemError.getaddrinfo(err, errno)
    }
    if err != 0 {
        throw SystemError.getaddrinfo(err, nil)
    }
    defer {
        freeaddrinfo(res)
    }
    guard let firstAddr = res else {
        return []
    }

    var result = [sockaddr_storage]()
    for addr in sequence(first: firstAddr, next: { $0.pointee.ai_next }) {
        var sockAddr = sockaddr_storage()
        memcpy(&sockAddr, addr.pointee.ai_addr, Int(addr.pointee.ai_addrlen))
        result.append(sockAddr)
    }
    return result
}
