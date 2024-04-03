//
//  FileTransferWebApiVersion.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation

struct FileTransferWebApiVersion {
    let apiVersion: Int
    let version: String
    let buildDate: Date?
    let boardName: String
    let mcuName: String
    let boardId: String
    let creatorId: Int
    let creationId: Int
    let hostName: String
    let port: Int
    let ip: String
}

struct FileInfo: Codable {
    let name: String
    let directory: Bool
    let modifiedNs: Int
    let fileSize: Int

    enum CodingKeys: String, CodingKey {
        case name
        case directory
        case modifiedNs = "modified_ns"
        case fileSize = "file_size"
    }
}

struct FolderInfo: Codable {
    let files: [FileInfo]
    let version: Int
}

struct StorageInfo: Codable {
    let root: String
    let free: Int
    let total: Int
    let blockSize: Int
    let writable: Bool
    let disks: [FolderInfo]

    enum CodingKeys: String, CodingKey {
        case root
        case free
        case total
        case blockSize = "block_size"
        case writable
        case disks = "files"
    }
}
