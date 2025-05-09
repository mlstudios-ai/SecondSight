//
//  SettingsView.swift
//  SecondSight
//
//  Created by Jasper on 8/5/2025.
//


import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode 
    @State var endpoint: String = ""
//    @State var remoteDetection: Bool
//    
    var onClose: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: geo.size.height * 0.06) {
                // Top bar
                HStack {
                    Spacer()
                    Text("Settings")
                        .font(.system(size: geo.size.width * 0.06, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                    Button(action: {
                        onClose?()
                    }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: geo.size.width * 0.04, height: geo.size.width * 0.04)
                            .foregroundColor(.black)
                            .padding(.trailing, geo.size.width * 0.03)
                    }
                }
                .padding(.top, geo.size.height * 0.04)

                Spacer()

                // Service Endpoint
                HStack {
                    Text("Service Endpoint:")
                        .font(.system(size: geo.size.width * 0.03, weight: .bold))
                    TextField("Endpoint", text: $endpoint)
                        .font(.system(size: geo.size.width * 0.03, weight: .bold))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))
                        .frame(width: geo.size.width * 0.35)
                }
                .padding(.horizontal, geo.size.width * 0.04)
                
                Spacer()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: Item.self, inMemory: true)
}
