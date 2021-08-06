//
//  FileTransferViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import Foundation

class FileTransferViewModel: ObservableObject {

    // Published
    @Published var fileTransferClient: FileTransferClient?
    
    struct TransmissionProgress {
        var description: String
        var transmittedBytes: Int
        var totalBytes: Int?
        
        init (description: String) {
            self.description = description
            transmittedBytes = 0
        }
    }
    
    @Published var transmissionProgress: TransmissionProgress?
    
    struct TransmissionLog: Equatable {
        enum TransmissionType: Equatable {
            case read(data: Data)
            case write(size: Int)
            case delete(success: Bool)
            case listDirectory(numItems: Int?)
            case makeDirectory(success: Bool)
            case error(message: String)
        }
        let type: TransmissionType
        
        var description: String {
            let modeText: String
            switch self.type {
            case .read(let data): modeText = "Received \(data.count) bytes"
            case .write(let size): modeText = "Sent \(size) bytes"
            case .delete(let success): modeText = "Deleted file: \(success ? "success":"failed")"
            case .listDirectory(numItems: let numItems): modeText = numItems != nil ? "Listed directory: \(numItems!) items" : "Listed nonexistent directory"
            case .makeDirectory(let success): modeText = "Created directory: \(success ? "success":"failed")"
            case .error(let message): modeText = message
            }
            
            return modeText
        }
    }
    @Published var lastTransmit: TransmissionLog? =  TransmissionLog(type: .write(size: 334))
    
    
    // Data
    private let bleManager = BleManager.shared


    // MARK: - Placeholders
    var fileNamePlaceholders: [String] = ["/hello.txt"/*, "/bye.txt"*/, "/test.txt"]

    static let defaultFileContentePlaceholder = "This is some editable text 👻😎..."
    lazy var fileContentPlaceholders: [String] = {
        
        let longText =  "Far far away, behind the word mountains, far from the countries Vokalia and Consonantia, there live the blind texts. Separated they live in Bookmarksgrove right at the coast of the Semantics, a large language ocean. A small river named Duden flows by their place and supplies it with the necessary regelialia. It is a paradisematic country, in which roasted parts of sentences fly into your mouth. Even the all-powerful Pointing has no control about the blind texts it is an almost unorthographic life One day however a small line of blind text by the name of Lorem Ipsum decided to leave for the far World of Grammar. The Big Oxmox advised her not to do so, because there were thousands of bad Commas, wild Question Marks and devious Semikoli, but the Little Blind Text didn’t listen. She packed her seven versalia, put her initial into the belt and made herself on the way. When she reached the first hills of the Italic Mountains, she had a last view back on the skyline of her hometown Bookmarksgrove, the headline of Alphabet Village and the subline of her own road, the Line Lane. Pityful a rethoric question ran over her cheek"
        
        let sortedText = (1...500).map{"\($0)"}.joined(separator: ", ")
        
        return [Self.defaultFileContentePlaceholder, longText, sortedText]
    }()
    
    init() {
        /*
        if AppEnvironment.inXcodePreviewMode {
            transmissionProgress = TransmissionProgress(description: "test")
            transmissionProgress?.transmittedBytes = 33
            transmissionProgress?.totalBytes = 66
        }*/
    }
    
    // MARK: - Setup
    func onAppear(fileTransferClient: FileTransferClient?) {
        registerNotifications(enabled: true)
        setup(fileTransferClient: fileTransferClient)
    }
    
    func onDissapear() {
        registerNotifications(enabled: false)
    }
    
    private func setup(fileTransferClient: FileTransferClient?) {
        guard let fileTransferClient = fileTransferClient else {
            print("Error: undefined fileTransferClient")
            return
        }
        
        self.fileTransferClient = fileTransferClient
    }
    
    // MARK: - Actions
    func disconnectAndForgetPairing() {
        Settings.clearAutoconnectPeripheral()
        if let blePeripheral = fileTransferClient?.blePeripheral {
            bleManager.disconnect(from: blePeripheral)
        }
    }
    
    func readFile(filename: String) {
        startCommand(description: "Reading \(filename)")
        readFileCommand(path: filename) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.lastTransmit = TransmissionLog(type: .read(data: data))
                    
                case .failure(let error):
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func writeFile(filename: String, data: Data) {
        startCommand(description: "Writing \(filename)")
        writeFileCommand(path: filename, data: data) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.lastTransmit = TransmissionLog(type: .write(size: data.count))
                    
                case .failure(let error):
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func listDirectory(filename: String) {
        let directory = FileTransferPathUtils.pathRemovingFilename(path: filename)
        
        startCommand(description: "List directory")

        listDirectoryCommand(path: directory) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let entries):
                    self.lastTransmit = TransmissionLog(type: .listDirectory(numItems: entries?.count))
                    
                case .failure(let error):
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func deleteFile(filename: String) {
        startCommand(description: "Deleting \(filename)")
        
        deleteFileCommand(path: filename) { [weak self]  result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    self.lastTransmit = TransmissionLog(type: .delete(success: success))
                    
                case .failure(let error):
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    func makeDirectory(filename: String) {
        startCommand(description: "Creating \(filename)")
        
        makeDirectoryCommand(path: filename) { [weak self]  result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    self.lastTransmit = TransmissionLog(type: .makeDirectory(success: success))
                    
                case .failure(let error):
                    self.lastTransmit = TransmissionLog(type: .error(message: error.localizedDescription))
                }
                
                self.endCommand()
            }
        }
    }
    
    // MARK: - Command Status
    private func startCommand(description: String) {
        transmissionProgress = TransmissionProgress(description: description)    // Start description with no progress 0 and undefined Total
        lastTransmit = nil
    }
    
    private func endCommand() {
        transmissionProgress = nil
    }
    
    private func readFileCommand(path: String, completion: ((Result<Data, Error>) -> Void)?) {
        print("start readFile \(path)")
        fileTransferClient?.readFile(path: path, progress: { [weak self] read, total in
            print("reading progress: \( String(format: "%.1f%%", Float(read) * 100 / Float(total)) )")
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.transmissionProgress?.transmittedBytes = read
                self.transmissionProgress?.totalBytes = total
            }
        }) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success(let data):
                    print("readFile \(path) success. Size: \(data.count)")
                    
                case .failure(let error):
                    print("readFile  \(path) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func writeFileCommand(path: String, data: Data, completion: ((Result<Void, Error>) -> Void)?) {
        print("start writeFile \(path)")
        fileTransferClient?.writeFile(path: path, data: data, progress: { [weak self] written, total in
            print("writing progress: \( String(format: "%.1f%%", Float(written) * 100 / Float(total)) )")
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.transmissionProgress?.transmittedBytes = written
                self.transmissionProgress?.totalBytes = total
            }
        }) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success:
                    print("writeFile \(path) success. Size: \(data.count)")
                    
                case .failure(let error):
                    print("writeFile  \(path) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func deleteFileCommand(path: String, completion: ((Result<Bool, Error>) -> Void)?) {
        print("start deleteFile \(path)")
        fileTransferClient?.deleteFile(path: path) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success(let success):
                    print("deleteFile \(path) \(success ? "success":"failed")")
                    
                case .failure(let error):
                    print("deleteFile  \(path) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func listDirectoryCommand(path: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        print("start listDirectory \(path)")
        fileTransferClient?.listDirectory(path: path) { result in
            switch result {
            case .success(let entries):
                print("listDirectory \(path). \(entries != nil ? "Entries: \(entries!.count)" : "Directory does not exist")")
                
            case .failure(let error):
                print("listDirectory \(path) error: \(error)")
            }
            
            completion?(result)
        }
    }
    
    private func makeDirectoryCommand(path: String, completion: ((Result<Bool, Error>) -> Void)?) {
        print("start makeDirectory \(path)")
        fileTransferClient?.makeDirectory(path: path) { result in
            switch result {
            case .success(let success):
                print("makeDirectory \(path) \(success ? "success":"failed")")
                
            case .failure(let error):
                print("makeDirectory \(path) error: \(error)")
            }
            
            completion?(result)
        }
    }
    
    // MARK: - BLE Notifications
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
          didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.didDisconnectFromPeripheral(notification: notification)})
 
        } else {
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
    
    private func didDisconnectFromPeripheral(notification: Notification) {
        let peripheral = bleManager.peripheral(from: notification)

        let currentlyConnectedPeripheralsCount = bleManager.connectedPeripherals().count
        guard let selectedPeripheral = fileTransferClient?.blePeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there are no peripherals connected (after a failed dfu update)
            return
        }

        // Disconnect
        fileTransferClient = nil
    }
}
