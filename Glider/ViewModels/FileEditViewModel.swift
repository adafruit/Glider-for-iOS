//
//  FileEditViewModel.swift
//  Glider
//
//  Created by Antonio García on 17/5/21.
//

import Foundation
import FileTransferClient

class FileEditViewModel: FileCommandsViewModel {
    //@Published var data: Data? = nil                // Read data
    @Published var text: String? = nil              // Read converted to text (ut8)
    
    // MARK: - Placeholders
    static let defaultFileContentePlaceholder = "This is some editable text 👻😎..."
    lazy var fileContentSnippets: [String] = {
        
        let longText = "Far far away, behind the word mountains, far from the countries Vokalia and Consonantia, there live the blind texts. Separated they live in Bookmarksgrove right at the coast of the Semantics, a large language ocean. A small river named Duden flows by their place and supplies it with the necessary regelialia. It is a paradisematic country, in which roasted parts of sentences fly into your mouth. Even the all-powerful Pointing has no control about the blind texts it is an almost unorthographic life One day however a small line of blind text by the name of Lorem Ipsum decided to leave for the far World of Grammar. The Big Oxmox advised her not to do so, because there were thousands of bad Commas, wild Question Marks and devious Semikoli, but the Little Blind Text didn’t listen. She packed her seven versalia, put her initial into the belt and made herself on the way. When she reached the first hills of the Italic Mountains, she had a last view back on the skyline of her hometown Bookmarksgrove, the headline of Alphabet Village and the subline of her own road, the Line Lane. Pityful a rethoric question ran over her cheek"
        
        let sortedText = (1...500).map{"\($0)"}.joined(separator: ", ")
        
        return [Self.defaultFileContentePlaceholder, longText, sortedText]
    }()
    
    /*
    init() {
        if AppEnvironment.inXcodePreviewMode {
            transmissionProgress = TransmissionProgress(description: "test")
            transmissionProgress?.transmittedBytes = 33
            transmissionProgress?.totalBytes = 66
        }
    }*/
    
    // MARK: - Setup
    func setup(filePath: String, fileTransferClient: FileTransferClient?) {
        self.path = filePath
        
        // Initial read
        if let fileTransferClient = fileTransferClient {
            readFile(filePath: filePath, fileTransferClient: fileTransferClient) { result in
                switch result {
                case .success(let data):
                    self.setData(data)
                case .failure:
                    break
                }
            }
        }
    }
    
 
    override func writeFile(filename: String, data: Data, fileTransferClient: FileTransferClient, completion: ((Result<Date?, Error>) -> Void)? = nil) {
        super.writeFile(filename: filename, data: data, fileTransferClient: fileTransferClient) { result in
            switch result {
            case .success:
                self.setData(data)
            case .failure:
                break
            }
        }
    }
    
    private func setData(_ data: Data) {
        //self.data = data
        self.text = String(data: data, encoding: .utf8)
    }
    
}
