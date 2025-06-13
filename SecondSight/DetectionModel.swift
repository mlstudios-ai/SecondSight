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

// Detection Handler
@MainActor
class DetectionModel : ObservableObject {
    private var YOLOv11Model: VNCoreMLModel?
    let camera = Camera()
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
        if let model = try? YOLO11nDetectionModel(configuration: config).model {
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
//                            let results = results.filter { $0.labels[0].confidence > 0.9 }
                            let results = results.filter { observation in
                                observation.labels.first?.confidence ?? 0 > 0.8
//                                && observation.confidence > 0.75
                            }
                            
//                            for observation in results {
//                                if let topLabel = observation.labels.first {
//                                    print("\(topLabel.identifier) detected with confidence \(topLabel.confidence)")
//                                    print("BBOX confidence \(observation.confidence)")
//                                }
//                            }
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
