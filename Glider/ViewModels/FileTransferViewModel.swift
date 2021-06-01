//
//  FileTransferViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import Foundation

class FileTransferViewModel: ObservableObject {

    // Published
    @Published var blePeripheral: BlePeripheral?
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
    func onAppear(blePeripheral: BlePeripheral?) {
        registerNotifications(enabled: true)
        setup(blePeripheral: blePeripheral)
        
        // Debug
        // blePeripheral?.listDirectory("/") { result in}
    }
    
    func onDissapear() {
        registerNotifications(enabled: false)
    }
    
    private func setup(blePeripheral: BlePeripheral?) {
        guard let blePeripheral = blePeripheral else {
            print("Error: undefined blePeripheral")
            return
        }
        
        self.blePeripheral = blePeripheral
    }
    
    // MARK: - Actions
    func readFile(filename: String) {
        startCommand()
        readFileCommand(filename: filename) { [weak self] result in
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
        writeFileCommand(filename: filename, data: data) { [weak self] result in
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

        listDirectoryCommand(directory: directory) { [weak self] result in
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
        
        deleteFileCommand(filename: filename) { [weak self]  result in
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
        
        makeDirectoryCommand(directory: filename) { [weak self]  result in
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
    
    private func readFileCommand(filename: String, completion: ((Result<Data, Error>) -> Void)?) {
        print("start readFile \(filename)")
        blePeripheral?.readFile(filename: filename) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success(let data):
                    print("readFile \(filename) success. Size: \(data.count)")
                    
                case .failure(let error):
                    print("readFile  \(filename) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func writeFileCommand(filename: String, data: Data, completion: ((Result<Void, Error>) -> Void)?) {
        print("start writeFile \(filename)")
        blePeripheral?.writeFile(data: data, filename: filename) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success:
                    print("writeFile \(filename) success. Size: \(data.count)")
                    
                case .failure(let error):
                    print("writeFile  \(filename) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func deleteFileCommand(filename: String, completion: ((Result<Bool, Error>) -> Void)?) {
        print("start deleteFile \(filename)")
        blePeripheral?.deleteFile(filename: filename) { result in
            if AppEnvironment.isDebug {
                switch result {
                case .success(let success):
                    print("deleteFile \(filename) \(success ? "success":"failed")")
                    
                case .failure(let error):
                    print("deleteFile  \(filename) error: \(error)")
                }
            }
            
            completion?(result)
        }
    }
    
    private func listDirectoryCommand(directory: String, completion: ((Result<[BlePeripheral.DirectoryEntry]?, Error>) -> Void)?) {
        print("start listDirectory \(directory)")
        blePeripheral?.listDirectory(directory) { result in
            switch result {
            case .success(let entries):
                print("listDirectory \(directory). \(entries != nil ? "Entries: \(entries!.count)" : "Directory does not exist")")
                
            case .failure(let error):
                print("listDirectory \(directory) error: \(error)")
            }
            
            completion?(result)
        }
    }
    
    private func makeDirectoryCommand(directory: String, completion: ((Result<Bool, Error>) -> Void)?) {
        print("start makeDirectory \(directory)")
        blePeripheral?.makeDirectory(directory) { result in
            switch result {
            case .success(let success):
                print("makeDirectory \(directory) \(success ? "success":"failed")")
                
            case .failure(let error):
                print("makeDirectory \(directory) error: \(error)")
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
        guard let selectedPeripheral = blePeripheral, selectedPeripheral.identifier == peripheral?.identifier || currentlyConnectedPeripheralsCount == 0 else {        // If selected peripheral is disconnected or if there are no peripherals connected (after a failed dfu update)
            return
        }

        // Disconnect
        blePeripheral = nil
    }
}
