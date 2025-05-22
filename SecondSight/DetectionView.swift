//
//  DetectionView.swift
//  SecondSight
//
//  Created by Anna Huang on 7 May 2025
//

import SwiftUI
import AVFoundation
import UIKit

struct DetectionView: View {
    @StateObject private var detectionModel = DetectionModel()
    private let synthesizer = AVSpeechSynthesizer()
    @State private var showSettings = false
    @State private var description: String? = nil
    @State private var appState: AppState = AppState.ready
    private let errorMessage: String = "Error running detection!"
    private let pauseMessage: String = "Detection is paused"
    private let resumeMessage: String = "Detection is in progress"
    
    enum AppState { // different state the app can be in
        case error, ready, progress, speech, paused
    }
    
    var body: some View {
        ZStack {
            ZStack {
                // Detection area
                GeometryReader { geometry in
                    if let previewImage = detectionModel.previewImage {
                        previewImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay {
                                GeometryReader { (geometry: GeometryProxy) in
                                    ForEach(detectionModel.recognizedObjects){ obj in
                                        BoundingBox(imageViewGeometry: geometry, label: obj.label, rect: obj.boundingBox, color: Color.red, hideLabel: false)
                                    }
                                }
                            }
                    }
                }
                .ignoresSafeArea()
                .background(.black)
                .onDisappear {
                    pauseDetection()
                    Task {
                        await speakStatus(text: pauseMessage)
                    }
                }
                .onAppear {
                    resumeDetection()
                    Task {
                        await speakStatus(text: resumeMessage)
                    }
                }
            }
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Image("LogoWhite") // Placeholder logo
                        .resizable()
                        .frame(width: 36, height: 36)
                    Text("Potential Hazards:")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    Text(detectionModel.uniqueLabels.joined(separator: ", "))
                        .font(.title2).bold()
                        .foregroundColor(.red)
                    
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
                            return "StatusUnknown"
                        }
                    }
                    
                    Image(statusImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                .frame(height: 54)
                .background(Color.black.opacity(0.75))
                .padding(.horizontal, 24)
                .foregroundColor(.white)
                
                Spacer()
                
                // Display message
                if let message = appState == .progress || appState == .speech
                    ? description : appState == .paused
                    ? pauseMessage : errorMessage {
                   Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(5)
                        .frame(alignment: .center)
                        .background(Color.black.opacity(0.75))
                        .padding(.bottom, 20)
                    
                    if appState != .speech {
                        // display message at center
                        Spacer()
                    }
                }
                
                // Bottom Tab Bar
                HStack {
                    Button(action: {
                        describeScene()
                    }) {
                        HStack {
                            Image("GestureTap")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Describe")
                                .font(.headline)
                        }
                    }
                    .accessibilityLabel("Describe Scene")
                    
                    Spacer()
                    
                    Button(action: {    // pause detection
                        pauseDetection()
                        Task {
                            await speakStatus(text: pauseMessage)
                        }
                    }) {
                        HStack {
                            Image("GestureSwipeDown")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Pause")
                                .font(.headline)
                        }
                    }
                    .accessibilityLabel("Pause Detection")
                    
                    Spacer()
                    
                    Button(action: {    // resume detection
                        Task {
                            await speakStatus(text: resumeMessage)
                        }
                    }) {
                        HStack {
                            Image("GestureSwipeUp")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Resume")
                                .font(.headline)
                        }
                    }
                    .accessibilityLabel("Resume Detection")
                    
                    Spacer()
                    
                    Button(action: {    // show settings configs
                        showSettingsPopup()
                    }) {
                        HStack {
                            Image("GestureHold")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Settings")
                                .font(.headline)
                        }
                    }
                    .accessibilityLabel("Open Settings")
                }
                .frame(height: 54)
                .padding(.horizontal, 24)
                .background(Color.black.opacity(0.75))
                .foregroundColor(.white)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: {
                    showSettings = false
                    print("Settings view closed")
                })
                .presentationBackground(.clear)
                .padding(.vertical, 54)
                .padding(.horizontal, 24)
                .foregroundColor(.black)
                
            }
            .backgroundStyle(Color.black.opacity(0.85))
        }
        .gesture( // pause/resume detection
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < 0 { // swipe up - pause
                        resumeDetection()
                        Task {
                            await speakStatus(text: resumeMessage)
                        }
                    } else if value.translation.height > 0 { // swipe down - resume
                        pauseDetection()
                        Task {
                            await speakStatus(text: pauseMessage)
                        }
                    }
                }
        )
        .onLongPressGesture {  // option popup
            showSettingsPopup()
        }
        .onTapGesture { // describe scene
            describeScene()
        }
        .onChange(of: detectionModel.uniqueLabels) {
            alertHazards(newObjects:detectionModel.recognizedObjects)
        }
        .allowsHitTesting(appState != .speech)
    }

    private func alertHazards(newObjects: [RecognizedObject]) {
        Task {
            if !newObjects.isEmpty {
                var generator = UIImpactFeedbackGenerator(style: .light) // 1 hazard
                if newObjects.count > 1 { // two or more hazards
                    generator = UIImpactFeedbackGenerator(style: .medium)
                } else if newObjects.count > 3 { // 4 or more hazards
                    generator = UIImpactFeedbackGenerator(style: .heavy)
                }
                
                generator.prepare()
                generator.impactOccurred()
                
                let hazardMessage = "Detected " +  detectionModel.uniqueLabels.joined(separator: ", ")
                await speak(text: hazardMessage) // use delegate to timeout
            }
        }
    }
    
    /**
     Describe the detected object in the secene. If no objects, it descibes the scene normally.
     */
    private func describeScene() {//
//        if detectionModel.status == .running && description != nil {
//            Task {
//                // TODO: pause detection
////                sceneModel.infer()
//                await speak(text: description!)
//                description = nil
//            }
//        }
//            // TODO: check internet connection and endpoint connection
//            // TODO: pause to allow speech and reading time
//            // TODO: make message disappear after a time interval
//            // TODO: make message disappear when object is no longer detected
//            // TODO: replease message when new objects are detected.
//            // TODO: replease message when new objects are detected.
//            // TODO: consider skip frame
    }
    
    private func pauseDetection() {
        Task {
            detectionModel.stop()
            appState = .paused
        }
    }
    
    private func resumeDetection() {
        Task{
            detectionModel.start()
            appState = .progress
        }
    }
    
    private func showSettingsPopup() {
        showSettings = true
    }
    
    private func speak(text: String, duration: Int = 2) async {
        if (synthesizer.isSpeaking) {
            synthesizer.stopSpeaking(at: .immediate); // Or wait for `onend` event
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") // You can change the language
        
        appState = .speech
        detectionModel.stop()
        synthesizer.speak(utterance)
        description = text
        
        // hack to give it sometime to finish speaking, delegate is not compatible with UI
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
            synthesizer.stopSpeaking(at: .immediate);
            resumeDetection()
            description = nil
        }
    }
    
    private func speakStatus(text: String) async {
        if (synthesizer.isSpeaking) {
            synthesizer.stopSpeaking(at: .immediate); // Or wait for `onend` event
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") // You can change the language
        
        synthesizer.speak(utterance)
        description = text
        
        // hack to give it sometime to finish speaking, delegate is not compatible with UI
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            synthesizer.stopSpeaking(at: .immediate);
            if appState == .progress {
                description = nil
            }
        }
    }
    
    // Draw a bounding box around the recognized object
    private func BoundingBox(imageViewGeometry: GeometryProxy, label: String, rect: CGRect, color: Color, hideLabel: Bool) -> some View {
        let cgRect = self.denormalize(imageViewSize: imageViewGeometry.size, normalizedCGRect: rect)
            return Rectangle().path(in: cgRect)
                .stroke(color, lineWidth: 2.0)
                .overlay {
                    hideLabel ? nil : Text(label)
                        .foregroundColor(.white)
                        .background(Color.red)
                        .position(x: cgRect.minX, y: cgRect.minY)
                }
    }
    
    // Convert the normalized CGRect to a denormalized CGRect
    private func denormalize(imageViewSize: CGSize, normalizedCGRect: CGRect) -> CGRect {
        let imageViewWidth = imageViewSize.width
        let imageViewHeight = imageViewSize.height

        // Flip the Y coordinate, because the Vision framework uses a coordinate system with the origin in the bottom-left corner, while the SwiftUI uses a coordinate system with the origin in the top-left corner.
        let flippedY = 1.0 - normalizedCGRect.maxY
        return CGRect(x: normalizedCGRect.minX * imageViewWidth, y: flippedY * imageViewHeight, width: normalizedCGRect.width * imageViewWidth, height: normalizedCGRect.height * imageViewHeight)
    }
}
