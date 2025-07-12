//
//  CameraAngleDetector 2.swift
//  SecondSight
//
//  Created by Jasper on 23/6/2025.
//


import UIKit
import AVFoundation
import CoreMotion

class CameraAngleDetector: NSObject {
    
    // MARK: - Properties
    private let motionManager = CMMotionManager()
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // Angle detection properties
    private var currentDeviceOrientation: UIDeviceOrientation = .unknown
    private var currentCameraAngle: Double = 0.0
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMotionManager()
        setupNotifications()
    }
    
    // MARK: - Setup Methods
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let motion = motion, error == nil else { return }
            self?.processDeviceMotion(motion)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Camera Setup
    func setupCamera() -> AVCaptureVideoPreviewLayer? {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return nil }
        
        // Configure session
        captureSession.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to create camera input")
            return nil
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Create preview layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        
        return videoPreviewLayer
    }
    
    // MARK: - Orientation Detection
    @objc private func orientationDidChange() {
        currentDeviceOrientation = UIDevice.current.orientation
        updateCameraOrientation()
    }
    
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        
        // Calculate roll angle (rotation around z-axis)
        let roll = attitude.roll * 180.0 / .pi
        
        // Calculate pitch angle (rotation around x-axis)  
        let pitch = attitude.pitch * 180.0 / .pi
        
        // Determine if device is in landscape and calculate angle
        if isLandscapeMode() {
            currentCameraAngle = calculateLandscapeAngle(roll: roll, pitch: pitch)
            
            // Notify about angle change
            DispatchQueue.main.async {
                self.onAngleChanged?(self.currentCameraAngle, self.getLandscapeOrientation())
            }
        }
    }
    
    private func isLandscapeMode() -> Bool {
        return currentDeviceOrientation.isLandscape || 
               UIApplication.shared.statusBarOrientation.isLandscape
    }
    
    private func calculateLandscapeAngle(roll: Double, pitch: Double) -> Double {
        // Adjust angle calculation based on landscape orientation
        switch currentDeviceOrientation {
        case .landscapeLeft:
            return normalizeAngle(-roll)
        case .landscapeRight:
            return normalizeAngle(roll + 180)
        default:
            // Fallback to interface orientation
            if UIApplication.shared.statusBarOrientation == .landscapeLeft {
                return normalizeAngle(-roll)
            } else if UIApplication.shared.statusBarOrientation == .landscapeRight {
                return normalizeAngle(roll + 180)
            }
            return normalizeAngle(roll)
        }
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 { normalized += 360 }
        while normalized >= 360 { normalized -= 360 }
        return normalized
    }
    
    private func getLandscapeOrientation() -> String {
        switch currentDeviceOrientation {
        case .landscapeLeft:
            return "Landscape Left"
        case .landscapeRight:
            return "Landscape Right"
        default:
            if UIApplication.shared.statusBarOrientation == .landscapeLeft {
                return "Landscape Left"
            } else if UIApplication.shared.statusBarOrientation == .landscapeRight {
                return "Landscape Right"
            }
            return "Unknown Landscape"
        }
    }
    
    // MARK: - Camera Orientation Update
    private func updateCameraOrientation() {
        guard let videoPreviewLayer = videoPreviewLayer else { return }
        
        let orientation: AVCaptureVideoOrientation
        
        switch currentDeviceOrientation {
        case .landscapeLeft:
            orientation = .landscapeRight
        case .landscapeRight:
            orientation = .landscapeLeft
        default:
            // Use interface orientation as fallback
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                orientation = .landscapeRight
            case .landscapeRight:
                orientation = .landscapeLeft
            default:
                orientation = .portrait
            }
        }
        
        videoPreviewLayer.connection?.videoOrientation = orientation
    }
    
    // MARK: - Public Methods
    func startDetection() {
        captureSession?.startRunning()
    }
    
    func stopDetection() {
        captureSession?.stopRunning()
        motionManager.stopDeviceMotionUpdates()
    }
    
    func getCurrentAngle() -> Double {
        return currentCameraAngle
    }
    
    func getCurrentOrientation() -> String {
        return getLandscapeOrientation()
    }
    
    // MARK: - Callback
    var onAngleChanged: ((Double, String) -> Void)?
    
    // MARK: - Cleanup
    deinit {
        stopDetection()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Usage Example
class CameraViewController: UIViewController {
    
    private let angleDetector = CameraAngleDetector()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    @IBOutlet weak var angleLabel: UILabel!
    @IBOutlet weak var orientationLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupAngleDetection()
    }
    
    private func setupCamera() {
        previewLayer = angleDetector.setupCamera()
        
        guard let previewLayer = previewLayer else {
            print("Failed to setup camera")
            return
        }
        
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    private func setupAngleDetection() {
        angleDetector.onAngleChanged = { [weak self] angle, orientation in
            self?.angleLabel.text = String(format: "Angle: %.1f°", angle)
            self?.orientationLabel.text = "Orientation: \(orientation)"
        }
        
        angleDetector.startDetection()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        angleDetector.stopDetection()
    }
}

// MARK: - Helper Extensions
extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        default:
            return .portrait
        }
    }
}
