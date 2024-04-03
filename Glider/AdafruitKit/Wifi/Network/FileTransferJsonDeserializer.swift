//
//  FileTransferJsonDeserializer.swift
//  Glider
//
//  Created by Antonio García on 20/9/22.
//

import Foundation
import SwiftyJSON

extension FileTransferNetwork {
        
    internal func decodeVersion(data: Data) -> FileTransferWebApiVersion {
        let json = JSON(data)
    
        let dateFormatter: DateFormatter =  {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
        
        let apiVersion = json["web_api_version"].intValue
        let version = json["version"].stringValue
        let buildDate = dateFormatter.date(from: json["build_date"].stringValue)
        let boardName = json["board_name"].stringValue
        let mcuName = json["mcu_name"].stringValue
        let boardId = json["board_id"].stringValue
        let creatorId = json["creator_id"].intValue
        let creationId = json["creation_id"].intValue
        let hostName = json["hostname"].stringValue
        let port = json["port"].intValue
        let ip = json["ip"].stringValue
                       
        return FileTransferWebApiVersion(apiVersion: apiVersion, version: version, buildDate: buildDate, boardName: boardName, mcuName: mcuName, boardId: boardId, creatorId: creatorId, creationId: creationId, hostName: hostName, port: port, ip: ip)
        
    }
    
    internal func decodeListDirectory(data: Data) -> [DirectoryEntry] {
        let json = JSON(data)
            var entries = [DirectoryEntry]()
            

            if let filesArray = json["files"].array {
                for entryJson in filesArray {
                    let name = entryJson["name"].stringValue
                    let isDirectory = entryJson["directory"].boolValue
                    let fileSize = entryJson["file_size"].intValue
                    let modifiedNs = entryJson["modified_ns"].int64Value
                    let date = Date(timeIntervalSince1970: TimeInterval(modifiedNs / 1_000_000_000)) 
                    
                    let entry = DirectoryEntry(name: name, type: isDirectory ? .directory : .file(size: fileSize), modificationDate: date)
                    
                    entries.append(entry)
                }
            }
            
            return entries
    }

}
