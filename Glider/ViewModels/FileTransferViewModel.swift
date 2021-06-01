//
//  FileTransferViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import Foundation

class FileTransferViewModel: ObservableObject {

    // Published
    @Published var adafruitBoard: AdafruitBoard?
    @Published var isTransmitting = false
    
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
    @Published var lastTransmit: TransmissionLog? = nil
    
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
    
    // MARK: - Setup
    func onAppear(adafruitBoard: AdafruitBoard?) {
        registerNotifications(enabled: true)
        setup(adafruitBoard: adafruitBoard)
        
        // Debug
        // blePeripheral?.listDirectory("/") { result in}
    }
    
    func onDissapear() {
        registerNotifications(enabled: false)
    }
    
    private func setup(adafruitBoard: AdafruitBoard?) {
        guard let adafruitBoard = adafruitBoard else {
            print("Error: undefined adafruitBoard")
            return
        }
        
        self.adafruitBoard = adafruitBoard
    }
    
    // MARK: - Actions
    func readFile(filename: String) {
        startCommand()
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
        startCommand()
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
        let directory = FileTransferUtils.pathRemovingFilename(path: filename)
        
        startCommand()

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
        startCommand()
        
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
        startCommand()
        
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
    private func startCommand() {
        isTransmitting = true
        lastTransmit = nil
    }
    
    private func endCommand() {
        isTransmitting = false
    }
    
    private func readFileCommand(path: String, completion: ((Result<Data, Error>) -> Void)?) {
        print("start readFile \(path)")
        adafruitBoard?.readFile(path: path) { result in
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
        adafruitBoard?.writeFile(path: path, data: data) { result in
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
        adafruitBoard?.deleteFile(path: path) { result in
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
        adafruitBoard?.listDirectory(path: path) { result in
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
        adafruitBoard?.makeDirectory(path: path) { result in
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
        guard let selectedPeripheral = adafruitBoard?.blePeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there are no peripherals connected (after a failed dfu update)
            return
        }

        // Disconnect
        adafruitBoard = nil
    }
}
