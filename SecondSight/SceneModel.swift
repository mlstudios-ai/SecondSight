//
//  SceneModel.swift
//  SecondSight
//
//  Created by Jasper on 23/5/2025.
//


//
//  SceneModel.swift
//  SecondSight
//
//  Created by Jasper on 23/5/2025.
//


import SwiftUI
import UIKit

@MainActor
class SceneModel : ObservableObject {
    
    init() {}
    
    func infer(_ endpoint: String = Endpoint.ENIGMAAI, image: UIImage, prompt: String, completion: @escaping (String) -> Void) {
        // Prepare the API endpoint URL
        let url = URL(string: endpoint)! // Replace with your VLM endpoint
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add prompt
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(prompt)\r\n".data(using: .utf8)!)
        
        guard let resizedImage = resizeImageAspect(image: image, targetWidth: 420) else {
            print("No image provided")
            return
        }
        
        let image_filename = UUID().uuidString
        // Add file
        if let imageData = resizedImage.jpegData(compressionQuality: 0.9) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(image_filename).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
            guard let data = data, error == nil else {
                completion("Network error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Parse response JSON (assuming {"text": "..."} in response)
            if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = result["detail"] as? String {
                print("result \(text)")
                completion(text)
            } else {
                completion("")
            }
        }
        task.resume()
    }
    
    func resizeImageAspect(image: UIImage, targetWidth: CGFloat) -> UIImage? {
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        return image.resize(to: CGSize(width: targetWidth, height: targetHeight))
    }
    
}

struct Endpoint {
    static let ENIGMAAI: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "EnigmaAIEndpoint") as? String else {
            fatalError("EndpointURL not set in Info.plist")
        }
        return value
    }()
    
    static let AYA: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AyaEndpoint") as? String else {
            fatalError("EndpointURL not set in Info.plist")
        }
        return value
    }()
    
    static let LLAVA: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "LlavaEndpoint") as? String else {
            fatalError("EndpointURL not set in Info.plist")
        }
        return value
    }()
}
    

extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
