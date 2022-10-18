//
//  WifiFileTransferPeripheral.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

class WifiFileTransferPeripheral: FileTransferPeripheral {
    static let defaultPassword = "passw0rd"
    private static let defaultConnectionTimeout: TimeInterval = 10
    
    var wifiPeripheral: WifiPeripheral
    var password = WifiFileTransferPeripheral.defaultPassword
    
    var peripheral: Peripheral { wifiPeripheral }
    var onGetPasswordForHostName: ((_ name: String, _ hostName: String) -> String?)?

    enum WifiFileTransferPeripheralError: Error {
        case requestFailed
    }
    
    init(wifiPeripheral: WifiPeripheral, onGetPasswordForHostName: ((_ name: String, _ hostName: String) -> String?)?) {
        self.wifiPeripheral = wifiPeripheral
        self.onGetPasswordForHostName = onGetPasswordForHostName
    }
    
    func connectAndSetup(connectionTimeout: TimeInterval?, completion: @escaping (Result<Void, Error>) -> Void) {
        getVersion(timeoutInterval: connectionTimeout ?? Self.defaultConnectionTimeout) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let version):
                if let savedPassword = self.onGetPasswordForHostName?(version.boardName, version.hostName) {
                    self.password = savedPassword
                    
                    DLog("hostName: \(version.hostName)} savedPassword: '\(savedPassword)'")
                }
                else {                    
                    DLog("hostName: \(version.hostName)} using default password: '\(self.password)'")
                }
                completion(.success(()))
                
            case .failure(let error):
                DLog("Error retrieving /version.json")
                completion(.failure(error))
            }
        }
    }
    
    func getVersion(timeoutInterval: TimeInterval? = nil, completion: @escaping (Result<FileTransferWebApiVersion, Error>)->Void) {
        let urlString = wifiPeripheral.baseUrl() + "/cp/version.json"
        guard let url = URL(string: urlString) else { return }
        
        DLog("GET \(url.absoluteString)")
        FileTransferNetwork.shared.getVersion(baseUrlString: wifiPeripheral.baseUrl(), password: password, timeoutInterval: timeoutInterval, completion: completion)
    }
    
    func listDirectory(path: String, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
        DLog("List directory \(path)")
        FileTransferNetwork.shared.listDirectory(baseUrlString: wifiPeripheral.baseUrl(), path: path, password: password, completion: completion)

    }
    
    func makeDirectory(path: String, completion: ((Result<Date?, Error>) -> Void)?) {
        DLog("Make directory \(path)")

        // Make sure it ends with '/'
        let directoryPath = FileTransferPathUtils.pathWithTrailingSeparator(path: path)
        
        FileTransferNetwork.shared.makeDirectory(baseUrlString: wifiPeripheral.baseUrl(), path: directoryPath, password: password, completion: completion)
    }
    
    func readFile(path: String, progress: FileTransferProgressHandler?, completion: ((Result<Data, Error>) -> Void)?) {
        FileTransferNetwork.shared.readFile(baseUrlString: wifiPeripheral.baseUrl(), path: path, password: password, progress: progress, completion: completion)
    }
    
    func writeFile(path: String, data: Data, progress: FileTransferProgressHandler?, completion: ((Result<Date?, Error>) -> Void)?) {
        FileTransferNetwork.shared.writeFile(baseUrlString: wifiPeripheral.baseUrl(), path: path, password: password, data: data, progress: progress, completion: completion)
    }
    
    func deleteFile(path: String, completion: ((Result<Void, Error>) -> Void)?) {
        FileTransferNetwork.shared.deleteFile(baseUrlString: wifiPeripheral.baseUrl(), path: path, password: password, completion: completion)
    }
    
    func moveFile(fromPath: String, toPath: String, completion: ((Result<Void, Error>) -> Void)?) {
        // TODO (REST API don't have a move command yet)
        completion?(Result.failure(FileTransferNetwork.NetworkError.notAvailable))
    }
    
    private func getAuthHeader() -> String {
        let userId = ""
        let authPayload = "\(userId):\(password)"
        guard let data = authPayload.data(using: .utf8) else {
            return ""
        }
        
        let base64 = data.base64EncodedString()
        return "Basic \(base64)"
    }
    
    
    
}
