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
    @StateObject private var sceneModel = SceneModel()
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var endpoint: String = Endpoint.enigmaAI
    @State private var dragStartTime : Date? = nil
//    private let synthesizer = AVSpeechSynthesizer()
    @StateObject private var speechManager = SpeechManager()
    @State private var showSettings = false
    @State private var description: String? = nil
    @State private var appState: AppState = AppState.ready
    @State private var displayVideo: Bool = true
    private let errorMessage: String = "Error!"
    private let pauseMessage: String = "Detection paused"
    private let resumeMessage: String = "Detection in progress"
    
    enum AppState { // different state the app can be in
        case error, ready, progress, speech, paused
    }
    
    var body: some View {
        ZStack {
            ZStack {
                // Detection area
                GeometryReader { geometry in
                    if displayVideo, let previewImage = detectionModel.previewImage {
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
                    } else {
                        // case error, ready, progress, speech, paused, stopped
                        var statusMessage: String {
                            switch appState {
                            case .progress:
                                return "Detection in progress"
                            case .speech:
                                return "Speaking..."
                            case .paused:
                                return "Detection paused"
                            case .error:
                                return "Error"
                            default:
                                return ""
                            }
                        }
                        
                        Text(statusMessage)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .ignoresSafeArea()
                .background(.black)
                .onDisappear {
                    pauseDetection()
                    speakStatus(pauseMessage)
                }
                .onAppear {
                    resumeDetection()
                    speakStatus(resumeMessage)
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
                    
                    if displayVideo || (!displayVideo && appState == .speech) {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(5)
                            .frame(alignment: .center)
                            .background(Color.black.opacity(0.75))
                            .padding(.bottom, 20)
                    }
                    if appState != .speech {
                        // display message at center
                        Spacer()
                    }
                }
                
                // Bottom Tab Bar
                HStack {
                    Button(action: describeAction) {
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
                    
                    Button(action:pauseDetectionAction) {
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
                    
                    Button(action: resumeDetectionAction) {
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
                    
                    Button(action: displayAction) {
                        HStack {
                            Image("GestureHold")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Display")
                                .font(.headline)
                        }
                    }
                    .accessibilityLabel("Toggle Display")
                }
                .frame(height: 54)
                .padding(.horizontal, 24)
                .background(Color.black.opacity(0.75))
                .foregroundColor(.white)
            }
            .backgroundStyle(Color.black.opacity(0.85))
        }
        .gesture( // pause/resume detection
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { _ in
                    dragStartTime = Date()
                }
                .onEnded { value in
                    let dragDuration = Date().timeIntervalSince(dragStartTime!)
                    if dragDuration > 0.4 { // long press
                        displayAction()
                    } else if value.translation.height < -2 { // swipe up - resume
                        resumeDetection()
                        speakStatus(resumeMessage)
                    } else if value.translation.height > 2 { // swipe down - pause
                        pauseDetection()
                        speakStatus(pauseMessage)
                    } else { // tap - describe scene
                        describeScene()
                    }
                }
        )
        .onChange(of: detectionModel.uniqueLabels) {
            if !speechManager.isSpeaking {
                alertHazards(newObjects:detectionModel.recognizedObjects)
            }
            updateWatchLabel()
        }
        .onChange(of: appState) {
            updateWatchState()
        }
        .onReceive(connectivityManager.$notificationMessage) { message in
            guard let command = message else { return }
            
            switch command.text {
            case WatchConnectivityManager.Command.describe.rawValue:
                describeAction()
                return
            case WatchConnectivityManager.Command.pause.rawValue:
                pauseDetectionAction()
                return
            case WatchConnectivityManager.Command.resume.rawValue:
                resumeDetectionAction()
                return
            case WatchConnectivityManager.Command.display.rawValue:
                displayAction()
                return
            default:
                return
            }
        }
//        .allowsHitTesting(appState != .speech)
    }

    private func describeAction() {
        describeScene()
    }
    
    private func pauseDetectionAction() {
        pauseDetection()
        speakStatus(pauseMessage)
    }
    
    private func resumeDetectionAction() {
        resumeDetection()
        speakStatus(resumeMessage)
    }
    
    private func displayAction() {
        toggleDisplay()
    }
    
    private func alertHazards(newObjects: [RecognizedObject]) {
        if !newObjects.isEmpty {
            var generator = UIImpactFeedbackGenerator(style: .medium)
            if newObjects.count > 2 { // 3 or more hazards
                generator = UIImpactFeedbackGenerator(style: .heavy)
            }
            
            generator.prepare()
            generator.impactOccurred()
            
            let hazardMessage = detectionModel.uniqueLabels.joined(separator: ", ")
            speak(hazardMessage)
        }
    }
    
    /**
     Describe the detected object in the secene. If no objects, it descibes the scene normally.
     */
    private func describeScene() {
        guard appState == .progress || appState == .speech else {
            return
        }
        
        guard NetworkMonitor.shared.isConnected else {
            print("❌ No internet connection.")
            speak("No internet connection. Please try again later.")
            return
        }
        
        detectionModel.stop()
        
        var focus = detectionModel.stillLabels.joined(separator: ", ")
        var prompt: String = "Describe the image."
        
        if !detectionModel.stillLabels.isEmpty {
            prompt = "Describe the picture focus on \(focus)."
        }
        
        var image = UIImage(cgImage: detectionModel.previewCgiImage!)
        
        if appState != .speech {
            focus = detectionModel.uniqueLabels.joined(separator: ", ")
            prompt = "Describe the image."
            
            if !detectionModel.uniqueLabels.isEmpty {
                prompt = "Describe the picture focus on \(focus)."
            }
        }
        else {
            image = UIImage(cgImage: detectionModel.stillCgiImage!)
        }
                                                       
        sceneModel.infer(image: image, prompt: prompt) { generatedText in
            guard !generatedText.isEmpty else {
                print("❌ Failed to generate text.")
                speak("Description not available.")
                return
            }
            
            speak(generatedText)
        }
    }
    
    private func pauseDetection() {
        guard appState != .paused else {
            return
        }
        
        Task {
            detectionModel.stop()
            appState = .paused
        }
    }
    
    private func resumeDetection() {
        guard detectionModel.status != .running else {
            return
        }
        
        Task{
            detectionModel.start()
            appState = .progress
        }
    }
    
    private func toggleDisplay() {
        displayVideo.toggle()
        let message = displayVideo ? "Video is displayed" : "Video is hidden"
        speak(message)
    }
    
    private func speak(_ text: String) {
        let oldState = appState
        
        if (speechManager.isSpeaking) {
            speechManager.stopSpeech() // Or wait for `onend` event
        }
        
        speechManager.speak(
            text: text,
            onWillStart: {
                appState = .speech
//                detectionModel.stop()
                description = text
            },
            onDidFinish: {
                appState = oldState
                if oldState != .paused {
                    resumeDetection()
                }
                description = nil
            }
        )
    }
    
    private func speakStatus(_ text: String) {
        if (speechManager.isSpeaking) {
            speechManager.stopSpeech() // Or wait for `onend` event
        }
        
        speechManager.speak(
            text: text,
            onWillStart: {
                description = text
            },
            onDidFinish: {
                if appState == .progress {
                    description = nil
                }
            }
        )
    }
    
    private func updateWatchLabel() {
        let labelKey = WatchConnectivityManager.MessageKey.label.rawValue
        let labelText = detectionModel.uniqueLabels.joined(separator: ", ")
        WatchConnectivityManager.shared.send(labelKey, labelText)
    }
    
    private func updateWatchState() {
        let stateKey = WatchConnectivityManager.MessageKey.state.rawValue
        var stateText = WatchConnectivityManager.AppState.ready.rawValue
        
        switch appState {
        case .progress:
            stateText = WatchConnectivityManager.AppState.progress.rawValue
        case .paused:
            stateText = WatchConnectivityManager.AppState.paused.rawValue
        case .speech:
            stateText = WatchConnectivityManager.AppState.speech.rawValue
        case .error:
            stateText = WatchConnectivityManager.AppState.error.rawValue
        default:
            break
        }
        
        WatchConnectivityManager.shared.send(stateKey, stateText)
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

struct TwoFingerTapGesture: UIGestureRecognizerRepresentable {
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> some UIGestureRecognizer {
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleGesture))
        gesture.numberOfTouchesRequired = 2
        return gesture
    }

    func updateUIGestureRecognizer(_ uiGestureRecognizer: UIGestureRecognizer, context: Context) {}

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func handleGesture() { action() }
    }
}
