//
//  FileTransferPeripheral.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

public typealias FileTransferProgressHandler = ((_ transmittedBytes: Int, _ totalBytes: Int) -> Void)

protocol FileTransferPeripheral {
    var peripheral: Peripheral { get }
    
    func connectAndSetup(
        connectionTimeout: TimeInterval?,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    func listDirectory(
          path: String,
          completion: ((Result<[DirectoryEntry]?, Error>) -> Void)?
      )

    func makeDirectory(
          path: String,
          completion: ((Result<Date?, Error>) -> Void)?
      )

    func readFile(
          path: String,
          progress: FileTransferProgressHandler?,
          completion: ((Result<Data, Error>) -> Void)?
      )

    func writeFile(
          path: String,
          data: Data,
          progress: FileTransferProgressHandler?,
          completion: ((Result<Date?, Error>) -> Void)?
      )

    func deleteFile(
          path: String,
          completion: ((Result<Void, Error>) -> Void)?
      )

      func moveFile(
          fromPath: String,
          toPath: String,
          completion: ((Result<Void, Error>) -> Void)?
      )
}
