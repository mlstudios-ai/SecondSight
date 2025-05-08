//
//  DetectionView.swift
//  SecondSight
//
//  Created by Anna Huang on 7 May 2025
//

import SwiftUI
import os.log
import AVFoundation
import UIKit
import Vision
import CoreML

struct DetectionView: View {
    @StateObject private var model = DetectionModel()
    @State private var description: String? = nil
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            ZStack {
                // Detection area
                GeometryReader { geometry in
                    if let previewImage = model.previewImage {
                        previewImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay {
                                GeometryReader { (geometry: GeometryProxy) in
                                    ForEach(model.recognizedObjects){ obj in
                                        BoundingBox(imageViewGeometry: geometry, label: obj.label, rect: obj.boundingBox, color: Color.red, hideLabel: false)
                                    }
                                }
                            }
                    }
                }
                .ignoresSafeArea()
                .background(.black)
                .onDisappear {
                    model.camera.stop()
                }
                .onAppear {
                    Task {
                        await model.camera.start()
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
                    Text(model.uniqueLabels.joined(separator: ", "))
                        .font(.title2).bold()
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    var statusImage: String {
                        switch model.status {
                        case .running:
                            return "StatusInProgress"
                        case .stopped:
                            return "StatusStopped"
                        case .error:
                            return "StatusError"
                        }
                    }
                    
                    Image(statusImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.75))
                .padding(.horizontal, 24)
                
                Spacer()
                // Description message
                if let message = description {
                   Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.75))
                        .padding(.bottom, 20)
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
                    Spacer()
                    
                    Button(action: {    // pause detection
                        pauseDetection()
                    }) {
                        HStack {
                            Image("GestureSwipeDown")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Pause")
                                .font(.headline)
                        }
                    }
                    Spacer()
                    
                    Button(action: {    // resume detection
                        resumeDetection()
                    }) {
                        HStack {
                            Image("GestureSwipeUp")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Resume")
                                .font(.headline)
                        }}
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
                }
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
            }
            
            // Settings popup
            if showSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                SettingsView()
            }
        }
        .onTapGesture { // describe scene
            describeScene()
        }
        .gesture( // pause/resume detection
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < 0 { // swipe up - pause
                        resumeDetection()
                    } else if value.translation.height > 0 { // swipe down - resume
                        pauseDetection()
                    }
                }
        )
        .onLongPressGesture {  // option popup
            showSettingsPopup()
        }
    }

    private func describeScene() {
        description = "Detection objects " + model.uniqueLabels.joined(separator: ", ")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            description = nil
        }
        // TODO: check internet connection and endpoint connection
        // TODO: pause to allow speech and reading time
        // TODO: make message disappear after a time interval
        // TODO: make message disappear when object is no longer detected
        // TODO: replease message when new objects are detected.
        // TODO: consider skip frame
    }
    
    private func pauseDetection() {
        model.stop()
    }
    
    private func resumeDetection() {
        model.start()
    }
    
    private func showSettingsPopup() {
//        showSettings = true
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
    
    // Detection Handler
    @MainActor class DetectionModel : ObservableObject {
        @Published var previewImage: Image?
        @Published var recognizedObjects: [RecognizedObject] = []
        @Published var uniqueLabels: Set<String> = []
        
        enum DetectionStatus {
                case running, stopped, error
            }
        
        @Published var status: DetectionStatus = .stopped
        
        private var YOLOv11Model: VNCoreMLModel?
        let camera = Camera()
        
        init() {
            if let model = try? YOLOv11s().model {
                if let vnModel = try? VNCoreMLModel(for: model) {
                    YOLOv11Model = vnModel
                }
            }
            if let _ = YOLOv11Model {
                logger.info("Loaded YOLOv11n model")
            } else {
                logger.error("Failed to load YOLOv11n model")
            }
            
            start() // start detecting by default
        }
        
        // start detection
        public func start() {
            Task {
                self.status = .running
                await camera.start()
                await consumePreviewStream()
            }
        }
        
        // stop detection
        public func stop() {
            camera.stop()
            status = .stopped
        }
        
        private func consumePreviewStream() async {
            for await ciImage in camera.previewStream.stream {
                Task { @MainActor in
                    let ciContext = CIContext()
                    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                    previewImage = Image(decorative: cgImage, scale: 1)

                    if let YOLOv11nModel = self.YOLOv11Model {
                        // Create a VNCoreMLRequest with the YOLOv11 model
                        let request = VNCoreMLRequest(model: YOLOv11nModel) { (request, error) in
                            if let error = error {
                                logger.error("Failed to process YOLOv11n model: \(error)")
                                self.status = .error
                                return
                            }
                            
                            // Process the results
                            if let results = request.results as? [VNRecognizedObjectObservation] {
                                // get results with confidence > 0.9
                                let results = results.filter { $0.labels[0].confidence > 0.9 }
                                // convert the results to RecognizedObject
                                self.recognizedObjects = results.map { $0.toRecognizedObject($0) }
                                self.uniqueLabels = Set(results.map{$0.labels[0].identifier})
                            }
                        }
                        // Create a VNImageRequestHandler with the previewImage
                        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                        // Perform the request
                        do {
                            try handler.perform([request])
                        } catch {
                            print("Failed to perform request: \(error)")
                            self.status = .error
                        }
                    }
                }
            }
        }
    }
}

struct RecognizedObject: Identifiable {
    var id: UUID = UUID()
    var label: String
    var boundingBox: CGRect
}

extension VNRecognizedObjectObservation {
    // Convert a VNRecognizedObjectObservation to a RecognizedObject
    func toRecognizedObject(_ observation: VNRecognizedObjectObservation) -> RecognizedObject {
        let firstLabel = observation.labels.first?.identifier ?? "unknown"
        // add label to display in top nav
        return RecognizedObject(label: firstLabel, boundingBox: observation.boundingBox)
    }
}

fileprivate let logger = Logger(subsystem: "com.enigmaai.SecondSight", category: "DetectionView")
