//
//  LogView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI
import FileTransferClient

struct LogView: View {
    private let dateFormatter: DateFormatter
    @ObservedObject var logManager = LogManager.shared
    @State private var showFileProviderLog = false
    
    @StateObject private var logManagerFileProvider = LogManager(isFileProvider: true)
    @State private var updateScrollId: Int = 0      // Scroll position is updated when this variable is changed
    @State private var isShareSheetPresented = false
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
    }
    
    var body: some View {
        let entries = showFileProviderLog ? logManagerFileProvider.entries : logManager.entries
        
        NavigationView {
            //VStack {
            ScrollViewReader { scroll in
                ScrollView(.vertical) {
                    
                    LazyVStack {
                        
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(entry.date, formatter: dateFormatter)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 56, alignment: .leading)
                                Text("\(entry.text)")
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(showFileProviderLog ? .orange : .white)
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .onChange(of: self.updateScrollId) { _ in
                    // Update scroll
                    scroll.scrollTo(entries.count - 1, anchor: .bottom)
                }
                .padding(.vertical, 1)      // Fix scroll shown below navigation and tabbar
            }
            .foregroundColor(.white)
            .defaultGradientBackground()
            .navigationBarTitle(showFileProviderLog ? "FileProvider Log" : "App Log", displayMode: .large)
            .toolbar {
                HStack {
                    // Export
                    Button(action: {
                        isShareSheetPresented = true
                    }, label: {
                        Image(systemName: "square.and.arrow.up")
                    })
                    
                    // Change between AppLog and FileProviderLog
                    Button(action: {
                        showFileProviderLog.toggle()
                    }, label: {
                        if showFileProviderLog {
                            Image(systemName: "folder")
                        }
                        else {
                            Image("glider_toolbar")
                        }
                    })
                    
                    // Clear log
                    Button(action: {
                        LogManager.shared.clear()
                    }, label: {
                        Image(systemName: "trash")
                    })
                }
            }
            .sheet(isPresented: $isShareSheetPresented, onDismiss: nil) {
                let entries = showFileProviderLog ? logManagerFileProvider.entries : logManager.entries
                let text = shareText(entries: entries)
                let filename = "\(showFileProviderLog ? "AppLog":"FileProvider")_b\(AppEnvironment.buildNumber ?? "-")"
                if let data = text.data(using: .utf8), let textUrl = saveToTemporaryDirectory(data: data, resourceName: filename, fileExtension: "txt") {
                    ActivityViewController(activityItems: [textUrl])
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {     // SwiftUI bug: onAppear does not work inside NavigationView, so use it here to trigger an update inside the NavigationView. More info: https://developer.apple.com/forums/thread/655338?page=3
            logManagerFileProvider.load()

            // Trigger scroll update
            DispatchQueue.main.async {
                self.updateScrollId += 1
            }
        }
    }
    
    private func shareText(entries: [LogManager.Entry]) -> String {
        var text = ""
        for entry in entries {
            let dateString = dateFormatter.string(from: entry.date)
            text.append("\(dateString): \(entry.text)\n")
        }
        return text
    }
    
    private func saveToTemporaryDirectory(data: Data, resourceName: String, fileExtension: String) -> URL? {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let targetURL = tempDirectoryURL.appendingPathComponent(resourceName).appendingPathExtension(fileExtension)
        
        do {
            try data.write(to: targetURL, options: .atomic)
            return targetURL
        } catch let error {
            DLog("Unable to create file: \(resourceName).\(fileExtension): \(error)")
        }
        
        return nil
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
