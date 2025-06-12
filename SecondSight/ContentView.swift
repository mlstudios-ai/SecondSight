//
//  ContentView.swift
//  SecondSight
//
//  Created by Jasper on 24/3/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isLaunching = true
    private let splashView = SplashScreenView()
    private let detectionView = DetectionView()
    
//    @Environment(\.modelContext) private var modelContext
    var body: some View {
        ZStack {
            if isLaunching {
                splashView
            } else {
                detectionView
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isLaunching = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
