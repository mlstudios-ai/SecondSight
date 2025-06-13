//
//  SpeechManager.swift
//  SecondSight
//
//  Created by Jasper on 13/6/2025.
//


import AVFoundation
import SwiftUI

// MARK: - Speech Manager with Callbacks
@MainActor
class SpeechManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    // Callback closures
    private var onSpeechWillStart: (() -> Void)?
    private var onSpeechDidStart: (() -> Void)?
    private var onSpeechDidFinish: (() -> Void)?
    private var onSpeechDidPause: (() -> Void)?
    private var onSpeechDidResume: (() -> Void)?
    private var onSpeechDidCancel: (() -> Void)?
    private var onSpeechProgress: ((Float) -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(
        text: String,
        voice: AVSpeechSynthesisVoice? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        onWillStart: (() -> Void)? = nil,
        onDidStart: (() -> Void)? = nil,
        onDidFinish: (() -> Void)? = nil,
        onDidPause: (() -> Void)? = nil,
        onDidResume: (() -> Void)? = nil,
        onDidCancel: (() -> Void)? = nil,
        onProgress: ((Float) -> Void)? = nil
    ) {
        // Store the callbacks
        self.onSpeechWillStart = onWillStart
        self.onSpeechDidStart = onDidStart
        self.onSpeechDidFinish = onDidFinish
        self.onSpeechDidPause = onDidPause
        self.onSpeechDidResume = onDidResume
        self.onSpeechDidCancel = onDidCancel
        self.onSpeechProgress = onProgress
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "en-AU")
        utterance.rate = rate
        
        // Call the before callback
        onSpeechWillStart?()
        
        synthesizer.speak(utterance)
    }
    
    func pauseSpeech() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func resumeSpeech() {
        synthesizer.continueSpeaking()
    }
    
    func stopSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
    
    var isPaused: Bool {
        return synthesizer.isPaused
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpeechManager: AVSpeechSynthesizerDelegate {
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeechDidStart?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeechDidFinish?()
            self?.clearCallbacks()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeechDidPause?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeechDidResume?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeechDidCancel?()
            self?.clearCallbacks()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let progress = Float(characterRange.location) / Float(utterance.speechString.count)
        
        Task { @MainActor [weak self] in
            self?.onSpeechProgress?(progress)
        }
    }
    
    private func clearCallbacks() {
        onSpeechWillStart = nil
        onSpeechDidStart = nil
        onSpeechDidFinish = nil
        onSpeechDidPause = nil
        onSpeechDidResume = nil
        onSpeechDidCancel = nil
        onSpeechProgress = nil
    }
}

//// MARK: - SwiftUI Example Usage
//struct SpeechCallbackView: View {
//    @StateObject private var speechManager = SpeechManager()
//    @State private var buttonColor = Color.blue
//    @State private var isButtonDisabled = false
//    @State private var progressValue: Float = 0.0
//    
//    var body: some View {
//        VStack(spacing: 30) {
//            
//            Text("Speech with Callbacks")
//                .font(.title)
//                .fontWeight(.bold)
//            
//            ProgressView(value: progressValue)
//                .progressViewStyle(LinearProgressViewStyle())
//                .scaleEffect(y: 2.0)
//            
//            Button("Speak with UI Updates") {
//                speechManager.speak(
//                    text: "Hello, this is a test of speech with custom callback functions for UI updates.",
//                    onWillStart: {
//                        // Before speech starts
//                        print("About to start speaking...")
//                        isButtonDisabled = true
//                        buttonColor = .orange
//                        progressValue = 0.0
//                    },
//                    onDidStart: {
//                        // After speech starts
//                        print("Speech started!")
//                        buttonColor = .green
//                    },
//                    onDidFinish: {
//                        // After speech finishes
//                        print("Speech finished!")
//                        isButtonDisabled = false
//                        buttonColor = .blue
//                        progressValue = 1.0
//                        
//                        // Reset progress after a delay
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            progressValue = 0.0
//                        }
//                    },
//                    onProgress: { progress in
//                        progressValue = progress
//                    }
//                )
//            }
//            .padding()
//            .background(buttonColor)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//            .disabled(isButtonDisabled)
//            .animation(.easeInOut(duration: 0.3), value: buttonColor)
//            
//            Button("Speak with Different Callbacks") {
//                speechManager.speak(
//                    text: "This is another example with different callback behavior.",
//                    onWillStart: {
//                        // Different UI behavior for this speech
//                        print("Different callback - preparing...")
//                        buttonColor = .purple
//                    },
//                    onDidStart: {
//                        print("Different callback - started!")
//                    },
//                    onDidFinish: {
//                        print("Different callback - finished!")
//                        buttonColor = .blue
//                    }
//                )
//            }
//            .padding()
//            .background(Color.purple)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//            .disabled(speechManager.isSpeaking)
//            
//            HStack(spacing: 20) {
//                Button("Pause") {
//                    speechManager.pauseSpeech()
//                }
//                .disabled(!speechManager.isSpeaking || speechManager.isPaused)
//                
//                Button("Resume") {
//                    speechManager.resumeSpeech()
//                }
//                .disabled(!speechManager.isPaused)
//                
//                Button("Stop") {
//                    speechManager.stopSpeech()
//                }
//                .disabled(!speechManager.isSpeaking)
//            }
//            .buttonStyle(.bordered)
//            
//            Spacer()
//        }
//        .padding()
//    }
//}
//
//// MARK: - Preview
//struct SpeechCallbackView_Previews: PreviewProvider {
//    static var previews: some View {
//        SpeechCallbackView()
//    }
//}
