//
//  LogView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI

struct LogView: View {
    private let dateFormatter: DateFormatter
    @ObservedObject var logManager = LogManager.shared
//    @State private var showAppLog = true
    @State private var showFileProviderLog = false
    
    @StateObject private var logManagerFileProvider = LogManager(isFileProvider: true)
    @State private var updateScroll: Int = 0
    
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
                .onChange(of: self.updateScroll) { _ in
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
                    
                    
                    Button(action: {
                        LogManager.shared.clear()
                    }, label: {
                        Image(systemName: "trash")
                    })
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {     // SwiftUI bug: onAppear does not work inside NavigationView, so use it here to trigger an update inside the NavigationView. More info: https://developer.apple.com/forums/thread/655338?page=3
            logManagerFileProvider.load()

            // Trigger scroll update
            DispatchQueue.main.async {
                self.updateScroll += 1
            }
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
