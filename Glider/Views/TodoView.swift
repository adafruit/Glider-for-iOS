//
//  TodoView.swift
//  Glider
//
//  Created by Antonio García on 14/5/21.
//

import SwiftUI


struct TodoView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    
    var body: some View {
        VStack {
            Text("Not yet available")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text("🤷‍♂️")
                .font(.system(size: 128))
            
            
            Button("Restart") {
                rootViewModel.gotoMain()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        //.limitWidthOnRegularSizeClass()
        .padding()
        .defaultBackground()
        .navigationTitle("TODO")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TodoView_Previews: PreviewProvider {
    static var previews: some View {
        TodoView()
        
        NavigationView {
            TodoView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
    }
}
