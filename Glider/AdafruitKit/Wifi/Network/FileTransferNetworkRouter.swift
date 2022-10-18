//
//  FileTransferNetworkRouter.swift
//  Glider
//
//  Created by Antonio García on 3/10/22.
//

import Foundation

extension FileTransferNetwork {
    enum Router {
        static let defaultConnectionTimeout: TimeInterval = 10
        
        // Routes
        case getVersion
        case list(path: String, password: String)
        case makeDirectory(path: String, password: String)
        case readFile(path: String, password: String)
        case writeFile(path: String, password: String, data: Data)
        case deleteFile(path: String, password: String)

        // Method
        private var method: HTTPMethod {
            switch self {
            case .makeDirectory: return .put
            case .writeFile: return .put
            case .deleteFile: return .delete
            default: return .get
            }
        }
        
        // Path
        private var path: String {
            switch self {
            case .getVersion: return "/cp/version.json"
            case let .list(path, _): return "/fs/\(path)"
            case let .makeDirectory(path, _): return "/fs/\(path)"
            case let .readFile(path, _): return "/fs/\(path)"
            case let .writeFile(path, _, _): return "/fs/\(path)"
            case let .deleteFile(path, _): return "/fs/\(path)"
            }
        }
        
        func request(baseUrlString: String) -> URLRequest? {
            let urlString = baseUrlString + path
            guard let url = URL(string:urlString) else { return nil }
            
            var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy/*.reloadIgnoringCacheData*/, timeoutInterval: Self.defaultConnectionTimeout)
            request.httpMethod = method.value
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Set password if needed
            var authorizationPassword: String?
            switch self {
            case .list(_, let password):
                authorizationPassword = password
                
            case .makeDirectory(_, let password):
                authorizationPassword = password
                
            case .readFile(_, let password):
                authorizationPassword = password
                
            case let .writeFile(_, password, data):
                authorizationPassword = password
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                request.httpBody = data

            case .deleteFile(_, let password):
                authorizationPassword = password


            default: break
            }

            // Add authorization is password is set
            if let authorizationPassword = authorizationPassword {
                request.setValue(getAuthHeader(password: authorizationPassword), forHTTPHeaderField: "Authorization")
            }

            return request
        }
        
        
        // MARK: - Utils
        private func getAuthHeader(password: String) -> String {
            let userId = ""
            let authPayload = "\(userId):\(password)"
            guard let data = authPayload.data(using: .utf8) else {
                return ""
            }
            
            let base64 = data.base64EncodedString()
            return "Basic \(base64)"
        }
        
        private enum HTTPMethod {
            case get
            case post
            case put
            case delete
            
            var value: String {
                switch self {
                case .get: return "GET"
                case .post: return "POST"
                case .put: return "PUT"
                case .delete: return "DELETE"
                }
            }
        }
    }
}
