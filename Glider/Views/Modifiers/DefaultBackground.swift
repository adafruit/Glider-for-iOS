//
//  DefaultBackground.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI

// MARK: - Background
struct DefaultPlainBackgrondView: View {
    var body: some View {
        Color("background_default")
            .ignoresSafeArea()
    }
}

struct DefaultGradientBackgroundView: View {
    var body: some View {
       
        LinearGradient(
            gradient: Gradient(colors: [Color("background_gradient_start"), Color("background_gradient_end")]),
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .ignoresSafeArea()
    }
}

// MARK: - Background as modifier
private struct DefaultPlainBackgroundViewModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        ZStack() {
            DefaultPlainBackgrondView()
            content
        }
    }
}

private struct DefaultGradientBackgroundViewModifier: ViewModifier {
    var hidesKeyboardOnTap: Bool
    
    func body(content: Content) -> some View {
        ZStack() {
            DefaultGradientBackgroundView()
                .if(hidesKeyboardOnTap) {
                    $0.onTapGesture {
                        self.hideKeyboard()
                    }
                }
            content
        }
    }
}

extension View {
    func defaultPlainBackground(hidesKeyboardOnTap: Bool = false) -> some View {
        self.modifier(DefaultPlainBackgroundViewModifier())
    }
    
    func defaultGradientBackground(hidesKeyboardOnTap: Bool = false) -> some View {
        self.modifier(DefaultGradientBackgroundViewModifier(hidesKeyboardOnTap: hidesKeyboardOnTap))
    }
}
