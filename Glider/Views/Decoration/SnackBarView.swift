//
//  SnackBarView.swift
//  Glider
//
//  Created by Antonio García on 19/10/21.
//

import SwiftUI

struct SnackBarView: View {
    private static let duration: TimeInterval = 5

    @Binding var isShowing: Bool
    @State private var dissapearTask: DispatchWorkItem?
    
    let title: String
    let backgroundColor: Color
    
    var body: some View {
        ZStack {
            if isShowing {
                Text(title)
                    //.bold()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(backgroundColor)
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .onTapGesture {
                        withAnimation {
                            self.isShowing = false
                        }
                    }
                    .onAppear {
                        let task =  DispatchWorkItem {
                            withAnimation {
                                self.isShowing = false
                            }
                        }
                        dissapearTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: task)
                    }
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        //.animation(.easeInOut(duration: 0.3))
    }
}

struct SnackBarView_Previews: PreviewProvider {
    static var previews: some View {
        SnackBarView(isShowing: .constant(true), title: "Test", backgroundColor: .red)
    }
}
