//
//  ButtonStyles.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI


// MARK: - PrimaryButtonStyle
struct PrimaryButtonStyle: ButtonStyle {
    let paddingHorizontal: CGFloat = 8
    var width: CGFloat? = nil
    var height: CGFloat = 40
    var foregroundColor: Color = Color("button_primary_text")
    
    // To access the isEnabled property: https://stackoverflow.com/questions/59169436/swiftui-buttonstyle-how-to-check-if-button-is-disabled-or-enabled
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        PrimaryButton(configuration: configuration, paddingHorizontal: paddingHorizontal, forcedWidth: width, height: height, color: foregroundColor)
    }

    struct PrimaryButton: View {
        let configuration: ButtonStyle.Configuration
        let paddingHorizontal: CGFloat
        let forcedWidth: CGFloat?
        let height: CGFloat
        let color: Color
       
        @Environment(\.isEnabled) private var isEnabled: Bool
        var body: some View {
            configuration.label
                .font(.caption)
                .foregroundColor(Color.white)       // Animate foregroundColor: https://stackoverflow.com/questions/57832439/swiftui-animate-text-color-foregroundcolor
                .colorMultiply(isEnabled ? color : Color.black)
                .padding(.horizontal, paddingHorizontal)
                .ifelse(forcedWidth != nil, ifContent: {
                    $0.frame(width: forcedWidth!, height: height)
                }, elseContent: {
                    $0.frame(height: height)
                })
                .contentShape(Rectangle())          // Add this to make the empty background clickable
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isEnabled ? color : Color.clear, lineWidth: 1)
                        .background((isEnabled ? (configuration.isPressed ? Color("button_primary_accent") :  Color.clear) : Color.gray).cornerRadius(8))
                )
                //.animation(.easeOut(duration: 0.1))
        }
    }
}

struct MainButtonStyle: ButtonStyle {
    var isDark = true
    var backgroundColor = Color("accent_main")
    
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        let backgroundPressed = isDark ? backgroundColor.darker() : backgroundColor.lighter()
        
        configuration.label
            .font(.subheadline.bold())
            .textCase(.uppercase)
            .foregroundColor(isDark ? Color("button_main_text") : Color(.white))
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? backgroundPressed : backgroundColor)
            )
    }
}

struct ListFooterButtonStyle: ButtonStyle {
    var isDark = true
    var backgroundColor = Color("accent_main")
    
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        let backgroundPressed = isDark ? backgroundColor.darker() : backgroundColor.lighter()
        
        configuration.label
            .foregroundColor(configuration.isPressed ? backgroundPressed : backgroundColor)
           // .font(.caption.bold())
            //.textCase(.uppercase)
        
            //.foregroundColor(isDark ? Color("button_main_text") : Color(.white))
            //.padding(.horizontal)
            //.padding(.vertical, 2)
            //.contentShape(Rectangle())
        /*
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? backgroundPressed : backgroundColor)
            )*/
    }
}
