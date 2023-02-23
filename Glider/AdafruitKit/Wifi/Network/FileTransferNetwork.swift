//
//  FileTransferNetwork.swift
//  Glider
//
//  Created by Antonio García on 3/10/22.
//

import Foundation


class FileTransferNetwork {
    static let shared = FileTransferNetwork()
    
    private let session: URLSession
    
    enum NetworkError: Error {
        case invalidRequest
        case invalidStatus(statusCode: Int?, response: Data?)
        case noData
        case notAvailable
        
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    
    func getVersion(baseUrlString: String, password: String, timeoutInterval: TimeInterval?, completion: @escaping (Result<FileTransferWebApiVersion, Error>)->Void) {
        
        // TODO: use timeoutInterval
        
        guard let request = Router.getVersion.request(baseUrlString: baseUrlString) else {
            completion(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success(let data):
                let version = self.decodeVersion(data: data)
                completion(.success(version))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    func listDirectory(baseUrlString: String, path: String, password: String, completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?) {
        
        guard let request = Router.list(path: path, password: password).request(baseUrlString: baseUrlString) else {
            completion?(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success(let data):
                let listDirectory = self.decodeListDirectory(data: data)
                completion?(.success(listDirectory))
                
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    func makeDirectory(baseUrlString: String, path: String, password: String, completion: ((Result<Date?, Error>) -> Void)?) {
        guard let request = Router.makeDirectory(path: path, password: password).request(baseUrlString: baseUrlString) else {
            completion?(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success: //(let data):
                let date: Date? = nil
                completion?(.success(date))
                
            case .failure(let error):
                // TODO: add better descriptions for error codes
                /*
                if case let NetworkError.invalidStatus(statusCode, response) = error {
                    if statusCode == 204 {
                        
                    }
                }
                  */
                completion?(.failure(error))
            }
        }
    }
    
    
    func readFile(baseUrlString: String, path: String, password: String, progress: FileTransferProgressHandler?,  completion: ((Result<Data, Error>) -> Void)?) {
        guard let request = Router.readFile(path: path, password: password).request(baseUrlString: baseUrlString) else {
            completion?(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success(let data):
                completion?(.success(data))
                
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    func writeFile(baseUrlString: String, path: String, password: String, data: Data, progress: FileTransferProgressHandler?,  completion: ((Result<Date?, Error>) -> Void)?) {
        guard let request = Router.writeFile(path: path, password: password, data: data).request(baseUrlString: baseUrlString) else {
            completion?(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success: //(let data):
                let date: Date? = nil
                completion?(.success(date))
                
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    func deleteFile(baseUrlString: String, path: String, password: String, completion: ((Result<Void, Error>) -> Void)?) {
        guard let request = Router.deleteFile(path: path, password: password).request(baseUrlString: baseUrlString) else {
            completion?(.failure(NetworkError.invalidRequest))
            return
        }
        
        requestData(request: request) { result in
            switch result {
            case .success:
                completion?(.success(()))
                
            case .failure(let error):
                // TODO: add better descriptions for error codes
                /*
                if case let NetworkError.invalidStatus(statusCode: statusCode) = error {
                    if statusCode >= 400 {
                        
                    }
                }*/
                            
                completion?(.failure(error))
            }
        }
    }

    
    
    
    private func requestData(request: URLRequest, completion: @escaping (Result<Data, Error>) -> ()) {
        let task = session.dataTask(with: request) { (data, urlResponse, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let statusCode = urlResponse?.getStatusCode()
                guard let statusCode = statusCode, (200...299).contains(statusCode) else {
                    completion(.failure(NetworkError.invalidStatus(
                        statusCode: urlResponse?.getStatusCode(),
                        response: data
                    )))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                completion(.success(data))
            }
        }
        task.resume()
    }
    
  
}

extension URLResponse {
    func getStatusCode() -> Int? {
        if let httpResponse = self as? HTTPURLResponse {
            return httpResponse.statusCode
        }
        return nil
    }
}
