//
//  SplashScreenView.swift
//  SecondSight
//
//  Created by Jasper on 7/5/2025.
//


import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack {
            Image("LaunchImage") // Replace with your image asset name
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    SplashScreenView()
        .modelContainer(for: Item.self, inMemory: true)
}
