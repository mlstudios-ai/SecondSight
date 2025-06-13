//
//  ContentView.swift
//  SecondSightWatch Watch App
//
//  Created by Jasper on 6/6/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var dragStartTime : Date? = nil
    @State private var appState: AppState = AppState.ready
    @State public var text: String = ""
    @State public var uniqueLabels: Set<String> = []
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    private let commandKey: String = WatchConnectivityManager.MessageKey.command.rawValue
    
    enum AppState { // different state the app can be in
        case error, ready, progress, speech, paused
    }
    
    var body: some View {
        VStack {
            HStack{
                Spacer()
                Image("LogoWhite") // Placeholder logo
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .padding(.top, 0)
                    .padding(.bottom, 10)
                Spacer()
            }
            
            Spacer()
            
            // case error, ready, progress, speech, paused, stopped
            var statusImage: String {
                switch appState {
                case .progress:
                    return "StatusInProgress"
                case .speech:
                    return "StatusSpeech"
                case .paused:
                    return "StatusStopped"
                case .error:
                    return "StatusError"
                default:
                    return "StatusError"
                }
            }
            
            Image(statusImage)
                .resizable()
                .frame(width: 60, height: 60)
            
            Spacer()
            
            Text(text)
            .font(.title3).bold()
            .foregroundColor(.red)
        }
        .foregroundColor(.white)
//        .allowsHitTesting(appState != .speech)
        .gesture( // pause/resume detection
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { _ in
                    dragStartTime = Date()
                }
                .onEnded { value in
                    let dragDuration = Date().timeIntervalSince(dragStartTime!)
                    if dragDuration > 0.4 { // long press
                        displayToggle()
                    } else if value.translation.height < -2 { // swipe up - resume
                        resumeDetection()
                    } else if value.translation.height > 2 { // swipe down - pause
                        pauseDetection()
                    } else { // tap - describe scene
                        describeScene()
                    }
                }
        )
        .onChange(of: uniqueLabels) {
            alertHazards(labels: uniqueLabels)
            WKInterfaceDevice.current().play(.notification)
            WKInterfaceDevice.current().play(.click)
        }
        .onAppear {
            WKInterfaceDevice.current().play(.click)
            alertHazards(labels: uniqueLabels)
        }
        .onReceive(connectivityManager.$appState) { message in
            guard let state = message else { return }
            
            switch state {
            case WatchConnectivityManager.AppState.ready:
                appState = .progress
                return
            case WatchConnectivityManager.AppState.progress:
                appState = .progress
                return
            case WatchConnectivityManager.AppState.speech:
                WKInterfaceDevice.current().play(.click)
                
                appState = .speech
                return
            case WatchConnectivityManager.AppState.paused:
                appState = .paused
                return
            default:
                return
            }
        }
        .onReceive(connectivityManager.$label) { label in
            guard let label else { return }
            
            WKInterfaceDevice.current().play(.click)
            
            uniqueLabels = Set(label
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            )
        }
    }
    
    private func alertHazards(labels: Set<String> = []) {
        let hazardText = uniqueLabels.joined(separator: ", ")
        let maxLength = 20 // or whatever limit you want

        if hazardText.count > maxLength {
            let index = hazardText.index(hazardText.startIndex, offsetBy: maxLength)
            text = String(hazardText[..<index]) + "..."
        } else {
            text = hazardText
        }
    }
    
    private func describeScene() {
        guard appState == .progress || appState == .speech else {
            return
        }
        
        let command: String = WatchConnectivityManager.Command.describe.rawValue
        WatchConnectivityManager.shared.send(commandKey, command)
    }
    
    private func pauseDetection() {
        appState = .paused
        let command: String = WatchConnectivityManager.Command.pause.rawValue
        WatchConnectivityManager.shared.send(commandKey, command)
    }
    
    private func resumeDetection() {
        appState = .progress
        let command: String = WatchConnectivityManager.Command.resume.rawValue
        WatchConnectivityManager.shared.send(commandKey, command)
    }
    
    private func displayToggle() {
        let command: String = WatchConnectivityManager.Command.display.rawValue
        WatchConnectivityManager.shared.send(commandKey, command)
    }
}

#Preview {
    ContentView()
}
