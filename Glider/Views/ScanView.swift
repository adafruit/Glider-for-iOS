//
//  ScanView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

struct ScanView: View {
    @StateObject private var model = ScanViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    var body: some View {
        NavigationView {
            VStack {

                // Navigate to TodoView
                NavigationLink(
                    destination: TodoView(),
                    tag: .troubleshootConnection,
                    selection: $model.destination) {
                    EmptyView()
                }
                
                // Scan animation views
                ScanningAnimationView()
                
                Spacer()
                
                VStack {
                    // Status
                    ZStack(alignment: .top) {
                        // When scanning
                        VStack(spacing: 16) {
                            Text("Hold a File-Transfer compatible peripheral close to your \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")").bold()
                            Text(fileTransferPeripheralsScannedText)
                                .foregroundColor(.gray)
                                .font(.caption)
                                .opacity(model.numAdafruitPeripheralsWithFileTransferServiceScanned == 0 ? 0 : 1)
                        }
                        .multilineTextAlignment(.center)
                        .opacity(isScanning ? 1 : 0)
                        
                        // When connecting, discovering, disconnecting, etc...
                        VStack {
                            Text("Status: ").bold()
                            Text(detailText)
                        }
                        .multilineTextAlignment(.center)
                        .opacity(isScanning ? 0 : 1)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Buttons
                    Button("Troubleshoot connection...") {
                        model.destination = .troubleshootConnection
                    }
                    .buttonStyle(MainButtonStyle())
                    .hidden()   // Hidden until throubleshoot guide is ready
                    
                }
                .padding(.top, 40)
            }
            .foregroundColor(Color.white)
            .padding(.bottom)
            .defaultGradientBackground()
            .navigationBarTitle("Searching...", displayMode: .large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            model.onAppear()
        }
        .onDisappear {
            model.onDissapear()
        }
        .onChange(of: model.destination) { destination in
            if destination == .connected {
                self.rootViewModel.gotoConnected()
            }
        }
    }
    
    private struct ScanningAnimationView: View {
        @State private var animationCurrentFactor: Double = 0

        var body: some View {
            ZStack {
                WaveView(color: .white.opacity(0.1), scale: 1.05)
                    .waveOpacity(index: 4, animatableData: animationCurrentFactor)
                WaveView(color: .white.opacity(0.3), scale: 0.90)
                    .waveOpacity(index: 3, animatableData: animationCurrentFactor)
                WaveView(color: .white.opacity(0.5), scale: 0.75)
                    .waveOpacity(index: 2, animatableData: animationCurrentFactor)
                WaveView(color: .white.opacity(0.7), scale: 0.60)
                    .waveOpacity(index: 1, animatableData: animationCurrentFactor)
                WaveView(color: .white.opacity(0.9), scale: 0.45)
                    .waveOpacity(index: 0, animatableData: animationCurrentFactor)
                
                ZStack {
                    Circle()
                        .foregroundColor(.white)
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(0.3)
                        .shadow(radius: 10)
                    Image("scan_bluetooth")
                }
            }
            .frame(width: min(400, UIScreen.main.bounds.width))
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: WaveOpacityModifier.waveAnimationDuration).delay(0.5).repeatForever(autoreverses: false)) {
                        animationCurrentFactor = 1
                    }
                }
            }
        }
    }
    
    // MARK: - UI
    private var isScanning: Bool {
        if case .scanning = model.connectionStatus { return true }
        else { return false }
    }
    
    private var fileTransferPeripheralsScannedText: String {
        let numPeripherals = model.numAdafruitPeripheralsWithFileTransferServiceScanned
        if numPeripherals == 1 {
            return "\(numPeripherals) peripheral detected nearby but not close enough to establish link"
        }
        else {
            return "\(numPeripherals) peripherals detected nearby but not close enough to establish link"
        }
    }

    private var detailText: String {
        let text: String
        switch model.connectionStatus {
        case .scanning:
            text = "Scanning..."
        case .restoringConnection:
            text = "Restoring connection..."
        case .connecting:
            text = "Connecting..."
        case .connected:
            text = "Connected..."
        case .discovering:
            text = "Discovering Services..."
        case .fileTransferError:
            text = "Error initializing FileTransfer"
        case .fileTransferReady:
            text = "FileTransfer service ready"
        case .disconnected(let error):
            if let error = error {
                text = "Disconnected: \(error.localizedDescription)"
            } else {
                text = "Disconnected"
            }
        }
        return text
    }
}

private struct WaveOpacityModifier: AnimatableModifier {
    // Config
    private static let numWaves = 5
    private static let fadeInDuration: TimeInterval = 1
    private static let fadeOutDuration: TimeInterval = 0.8
    
    // Data
    var index: Int
    var animatableData: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(currentOpacity)
    }
    
    static var waveAnimationDuration: TimeInterval {
        let totalFadeInAnimationDuration = Self.fadeInDuration * Double(Self.numWaves)
        let totalAnimationDuration = totalFadeInAnimationDuration + Self.fadeOutDuration
        return totalAnimationDuration
    }
    
    var currentOpacity: Double {
        let currentFactor = animatableData
        
        let totalFadeInAnimationDuration = Self.fadeInDuration * Double(Self.numWaves)
        let totalAnimationDuration = totalFadeInAnimationDuration + Self.fadeOutDuration
        let totalFadeInFactor = totalFadeInAnimationDuration / totalAnimationDuration
        
        let isFadingOut = currentFactor >= totalFadeInFactor
        
        let result: Double
        if isFadingOut {
            let totalFadeOutFactor = 1 - totalFadeInFactor
            let currentFadeOutFactor = ((currentFactor - totalFadeInFactor) / totalFadeOutFactor)
            result = 1 - currentFadeOutFactor
        }
        else {
            let waveFadeInFactor = totalFadeInFactor / Double(Self.numWaves)
            if currentFactor <= Double(index) * waveFadeInFactor {
                result = 0      // Waiting to start fadeIn
            }
            else if currentFactor > Double(index + 1) * waveFadeInFactor {
                result = 1      // Already visible
            }
            else {
                let currentWaveFactor = (currentFactor / waveFadeInFactor) - Double(index)
                result = currentWaveFactor
            }
        }
        
        //DLog("wave\(index): alpha: \(result), factor: \(currentFactor)")
        return result
    }
}

extension View {
    func waveOpacity(index: Int, animatableData: Double) -> some View {
        self.modifier(WaveOpacityModifier(index: index, animatableData: animatableData))
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
        //.previewDevice(PreviewDevice(rawValue: "iPad Air (4th generation)"))
        //.previewDevice(PreviewDevice(rawValue: "iPhone 12"))
        //.previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro Max"))
    }
}
