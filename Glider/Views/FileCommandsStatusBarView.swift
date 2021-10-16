//
//  FileCommandsStatusBarView.swift
//  Glider
//
//  Created by Antonio García on 17/10/21.
//

import SwiftUI

struct FileCommandsStatusBarView: View {
    @ObservedObject var model: FileCommandsViewModel
    let backgroundColor: Color

    var body: some View {
        
        VStack(spacing: 0) {
            // Status log
            if let lastTransmit = model.lastTransmit {
                
                Text(lastTransmit.description.capitalized)
                    .bold()
                    .font(.caption2)
                    .allowsTightening(true)
                    .foregroundColor(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Progress
            ZStack {
                if let progress = model.transmissionProgress, let totalBytes = progress.totalBytes {
                    ProgressView(""/*progress.description*/, value: Float(progress.transmittedBytes), total: Float(totalBytes))
                        .accentColor(Color("accent_main"))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 4)
        }
        .background((model.lastTransmit?.type.isError ?? false) ? .red : backgroundColor)
        
    }
}

struct FileCommandsStatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        FileCommandsStatusBarView(model: FileCommandsViewModel(), backgroundColor: .gray.opacity(0.7))
            .previewLayout(.sizeThatFits)
    }
}
