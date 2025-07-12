//
//  DetectionModel.swift
//  SecondSight
//
//  Created by Jasper on 13/5/2025.
//


import SwiftUI
import AVFoundation
import os.log
import UIKit
import Vision
import CoreML
import CoreMotion

// Detection Handler
@MainActor
class DetectionModel : ObservableObject {
    private var YOLOv11Model: VNCoreMLModel?
    let camera = Camera()
    private let motionManager = CMMotionManager()
    private var floorAngle: Double = 40    // Degrees from horizontal to consider "floor"
    @Published var stillLabels: Set<String> = []
    @Published var previewImage: Image?
    @Published var stillCgiImage: CGImage?
    @Published var previewCgiImage: CGImage?
    @Published var recognizedObjects: [RecognizedObject] = []
    @Published var uniqueLabels: Set<String> = []
    @Published var status: DetectionStatus = .ready
    
    // Event handlers
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onDetected: (([RecognizedObject]) -> Void)?
    
    enum DetectionStatus {
        case ready, running, stopped, error
    }
    
    init() {
        let config = MLModelConfiguration()
        if let model = try? DetectionV3(configuration: config).model {
//        if let model = try? yolo11m(configuration: config).model {
            if let vnModel = try? VNCoreMLModel(for: model) {
                YOLOv11Model = vnModel
            }
        }
        if let _ = YOLOv11Model {
            start()
            logger.info("Loaded YOLOv11n model")
        } else {
            self.status = .error
            logger.error("Failed to load YOLOv11n model")
        }
    }
    
    // start detection
    public func start() {
        if self.status != .error {
            Task {
                motionManager.startDeviceMotionUpdates()
                self.status = .running
                await camera.start()
                await consumePreviewStream()
            }
        }
        
        onStart?()
    }
    
    // stop detection
    public func stop() {
        if self.status != .error {
            motionManager.stopDeviceMotionUpdates()
            stillCgiImage = previewCgiImage
            stillLabels = uniqueLabels
            camera.stop()
            status = .stopped
        }
        
        onStop?()
    }
    
    private func consumePreviewStream() async {
        for await ciImage in camera.previewStream.stream {
            Task { @MainActor in
                let ciContext = CIContext()
                guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                previewCgiImage = cgImage
                previewImage = Image(decorative: cgImage, scale: 1)

                if let YOLOv11nModel = self.YOLOv11Model {
                    // Create a VNCoreMLRequest with the YOLOv11 model
                    let request = VNCoreMLRequest(model: YOLOv11nModel) { (request, error) in
                        if let error = error {
                            logger.error("Failed to process detection model: \(error)")
                            self.status = .error
                            return
                        }
                        
                        // Process the results
                        if let results = request.results as? [VNRecognizedObjectObservation] {
                            // get results with confidence > 0.9
                            
                            // only returns result if camera is pointing at the floor
                            let cameraAngle = self.getCurrentAngle()
                            print("camera angle=\(cameraAngle)")
                            if cameraAngle >= 0 && cameraAngle <= self.floorAngle {
                                let results = results.filter { $0.labels[0].confidence > 0.8 }
                                // convert the results to RecognizedObject
                                self.recognizedObjects = results.map { $0.toRecognizedObject($0) }
                                self.uniqueLabels = Set(results.map{$0.labels[0].identifier})
                            } else {
                                self.recognizedObjects = []
                                self.uniqueLabels = []
                            }
                        }
                    }
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
    
    func resizeImage(_ ciImage: CIImage, to size: CGSize) -> CIImage {
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        return ciImage.transformed(by: transform)
    }
    
    func getCurrentAngle() -> Double {
        guard let motion = motionManager.deviceMotion else { return 0 }
        
        let attitude = motion.attitude
        let orientation = camera.getOrientation()
        var radians: Double = 0
        
        switch orientation {
        case .up:
            radians = -attitude.roll
        case .down:
            radians = attitude.roll + 180
        default:
            radians = attitude.pitch    // portrait up
        }
        
        // Calculate pitch angle in degrees
        // Pitch: positive when device tilts up, negative when tilts down
        let rollDegrees = radians * 180 / .pi
        let currentAngle = rollDegrees
        
        return currentAngle
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 { normalized += 360 }
        while normalized >= 360 { normalized -= 360 }
        return normalized
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
