//
//  WatchConnectivityManager.swift
//  SecondSight
//
//  Created by Jasper on 10/6/2025.
//

import Foundation
import WatchConnectivity

struct NotificationMessage: Identifiable {
    let id = UUID()
    let text: String
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var notificationMessage: NotificationMessage? = nil
    @Published var appState: AppState? = nil
    @Published var label: String? = nil
    @Published var desc: String? = nil
    @Published var display: String? = "on"
    
    enum MessageKey: String { // different state the app can be in
        case command = "command"
        case state = "state"
        case label = "label"
        case desc = "desc"
        case display = "display"
    }
    
    enum Command: String { // Declare raw value type
        case none = "none"
        case pause = "pauseDetection"
        case resume = "resumeDetection"
        case describe = "describeScene"
        case display = "displayToggle"
    }
    
    enum AppState: String { // different state the app can be in
        case error = "error"
        case ready = "ready"
        case progress = "progress"
        case speech = "speech"
        case paused = "paused"
    }
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func send(_ messageKey: String, _ message: String) {
        guard WCSession.default.activationState == .activated else {
          return
        }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else {
            return
        }
        #else
        guard WCSession.default.isCompanionAppInstalled else {
            return
        }
        #endif
        
        WCSession.default.sendMessage([messageKey : message], replyHandler: nil) { error in
            print("Cannot send message: \(String(describing: error))")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            if let notificationText = message[MessageKey.command.rawValue] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.notificationMessage = NotificationMessage(text: notificationText)
                }
            }
            
            if let stateText = message[MessageKey.state.rawValue] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.appState = AppState(rawValue: stateText)
                }
            }
        
            if let labelText = message[MessageKey.label.rawValue] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.label = labelText
                }
            }
        
            if let labelText = message[MessageKey.desc.rawValue] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.desc = labelText
                }
            }
        
            if let labelText = message[MessageKey.display.rawValue] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.display = labelText
                }
            }
        }
        
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
