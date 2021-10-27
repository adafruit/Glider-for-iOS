//
//  LimitWidthOnRegularSizeClassModifier.swift
// 
//
//  Created by Antonio García on 7/5/21.
//

import SwiftUI

private struct LimitWidthOnRegularSizeClass: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var width: CGFloat
    
    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(width: width)
        }
        else {
            content
        }
    }
}

extension View {
    func limitWidthOnRegularSizeClass(_ width: CGFloat = 500) -> some View {
        modifier(LimitWidthOnRegularSizeClass(width: width))
  }
}
