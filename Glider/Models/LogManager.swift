//
//  LogManager.swift
//  Glider
//
//  Created by Antonio García on 8/9/21.
//

import Foundation
import FileTransferClient
import Combine

class LogManager: ObservableObject {
    private static let applicationGroupSharedDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.adafruit.Glider")!       // Shared between the app and extensions
    private static let logFilename = "log.json"
    private static let fileProviderFilename = "fileprovider_log.json"
    private static let maxEntries = 10000
    
    // Singleton
    static let shared = LogManager()

    // Data
    private var isFileProvider: Bool
    private var cancellable: Cancellable?
    
    init() {
        #if FILEPROVIDER
        self.isFileProvider = true
        #else
        self.isFileProvider = false
        #endif
        
        load()
        
        // Observe notification center
        cancellable = NotificationCenter.default.publisher(for: .didLogDebugMessage)
            .compactMap{ $0.userInfo?["message"] as? String }
            .sink() { message in self.log(Entry(level: .debug, text: message)) }
    }
    
    init(isFileProvider: Bool) {
        self.isFileProvider = isFileProvider

        // Load
        load()

        // Observe notification center
        cancellable = NotificationCenter.default.publisher(for: .didLogDebugMessage)
            .compactMap{ $0.userInfo?["message"] as? String }
            .sink() { message in self.log(Entry(level: .debug, text: message)) }
    }
    
    deinit {
        // Save
        save()
    }

    // Data
    struct Entry: Hashable, Codable {
        
        enum Category: Int, Codable {
            case unknown = -1
            case app = 0
            case bluetooth = 1
            case fileTransferProtocol = 2
            case fileProvider = 3
        }
        
        enum Level: Int, Codable {
            case debug = 0
            case error = 1
        }
        
        var category: Category
        var level: Level
        var text: String
        var timestamp: CFAbsoluteTime
        var date: Date {
            return Date(timeIntervalSinceReferenceDate: timestamp)
        }

        init(level: Level, text: String, category: Category = .app, timestamp: CFAbsoluteTime? = nil) {
            self.category = category
            self.level = level
            self.text = text
            self.timestamp = timestamp ?? CFAbsoluteTimeGetCurrent()
        }
        
        static func debug(text: String, category: Category, timestamp: CFAbsoluteTime? = nil) -> Self {
            return self.init(level: .debug, text: text, category: category, timestamp: timestamp)
        }

        static func error(text: String, category: Category, timestamp: CFAbsoluteTime? = nil) -> Self {
            return self.init(level: .error, text: text, category: category, timestamp: timestamp)
        }
    }
    
    // Published
    @Published var entries: [Entry] = []
    
    // MARK: - Actions
    private var defaultFileUrl: URL? {
        let filename = isFileProvider ? Self.fileProviderFilename :  Self.logFilename
        return Self.applicationGroupSharedDirectoryURL.appendingPathComponent(filename)
    }
    
    func load() {
        guard let fileUrl = defaultFileUrl else { return }
        guard FileManager.default.fileExists(atPath: fileUrl.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileUrl, options: [])
            entries = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            print("Log load error: \(error.localizedDescription)")      // don't use DLog to avoid recurve calls durint initilization
        }
    }
    
    func save() {
        guard let fileUrl = defaultFileUrl else { return }
        
        do {
            let json = try JSONEncoder().encode(entries)
            try json.write(to: fileUrl, options: [])
        } catch {
            DLog("Log save error: \(error.localizedDescription)")
        }
    }
    
    func log(_ entry: Entry) {
        let appendHandler = {
            self.entries.append(entry)
            
            // Limit entries count
            self.limitSizeIfNeeded()
        }
        
        // Make sure that we are publishing changes from the main thread
        if Thread.isMainThread {
            appendHandler()
        }
        else {
            DispatchQueue.main.async {
                appendHandler()
            }
        }
        //DLog(message)
    }

    func clear() {
        entries.removeAll()
        save()
    }
    
    private func limitSizeIfNeeded() {
        let currentSize = entries.count
        if currentSize > Self.maxEntries {
            entries.removeFirst(currentSize - Self.maxEntries)
        }
    }
}
