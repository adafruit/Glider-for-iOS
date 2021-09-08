//
//  WaveView.swift
//  Glider
//
//  Created by Antonio García on 7/9/21.
//

import SwiftUI

struct WaveView: View {
    var color = Color.black
    var scale: CGFloat = 1
    var lineWidth: CGFloat = 20
    
    var animationFactor: Double = 0
    
    var animatableData: Double {
           get { return animationFactor }
           set { animationFactor = newValue }
       }
    
    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth / scale)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(scale)
    }
}

struct WaveView_Previews: PreviewProvider {
    static var previews: some View {
        WaveView()
            .previewLayout(.sizeThatFits)
    }
}
