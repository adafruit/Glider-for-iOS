//
//  FileTransferUtils.swift
//  Glider
//
//  Created by Antonio García on 24/5/21.
//

import Foundation

struct FileTransferUtils {
    static func fileDirectory(filename: String) -> String {
        guard let filenameIndex = filename.lastIndex(of: "/") else {
            return filename
        }
        
        return String(filename[filename.startIndex...filenameIndex])
    }
}
