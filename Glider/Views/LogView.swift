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
                        ForEach(entries, id: \.id) { entry in
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
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    
                }
             
                .onDidAppear {      // Warning: there is a SwiftUI bug and onAppear is called when the view dissapears. More info: https://developer.apple.com/forums/thread/655338?page=3
                    logManagerFileProvider.load()
                    if let id = entries.last?.id {
                        scroll.scrollTo(id, anchor: .bottom)
                    }
                }
                .onChange(of: entries.count) { count in
                    if let id = entries.last?.id {
                        scroll.scrollTo(id, anchor: .bottom)
                    }
                }
                .padding(.vertical, 1)      // Fix scroll shown below navigation and tabbar
            }
            
            /*
             HStack(spacing: 30) {
             Toggle(isOn: $showAppLog) {
             Text("Glider App")
             .foregroundColor(.white)
             }
             .toggleStyle(SwitchToggleStyle(tint: Color("accent_main")))
             
             Toggle(isOn: $showFileProviderLog) {
             Text("File-Provider")
             .foregroundColor(.orange)
             // .frame(maxWidth: .infinity, alignment: .trailing)
             }
             .toggleStyle(SwitchToggleStyle(tint: Color("accent_main")))
             
             }
             .padding()
             .frame(maxWidth: .infinity)
             .background(Color.white.opacity(0.5))
             
             }*/
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
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
