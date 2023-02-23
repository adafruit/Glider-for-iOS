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
