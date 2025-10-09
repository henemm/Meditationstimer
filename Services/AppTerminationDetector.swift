//
//  AppTerminationDetector.swift
//  Meditationstimer
//
//  Created by AI on 09.10.25.
//

// MARK: - AI ORIENTATION
// Purpose:
//   AppTerminationDetector is a testable component that detects app termination events.
//   Provides callbacks when the app is about to be terminated normally.
//   Does NOT detect force-quit (iOS limitation).
//
// Usage:
//   let detector = AppTerminationDetector()
//   detector.onAppWillTerminate = { /* handle termination */ }
//   detector.startMonitoring()
//
// Limitations:
//   • Only detects normal app termination (UIApplication.willTerminateNotification)
//   • Force-quit cannot be detected (iOS kills process immediately)
//   • Only works on iOS (conditional compilation for watchOS)

import Foundation
import Combine

#if os(iOS)
import UIKit
#endif

/// Detects app termination events and provides callbacks
final class AppTerminationDetector: ObservableObject {
    
    /// Called when app will terminate normally (not force-quit)
    var onAppWillTerminate: (() -> Void)?
    
    /// Debug callback for testing
    var onDebugEvent: ((String) -> Void)?
    
    private var terminationSubscription: AnyCancellable?
    private var isMonitoring = false
    
    init() {
        logDebug("AppTerminationDetector initialized")
    }
    
    deinit {
        stopMonitoring()
        logDebug("AppTerminationDetector deinitialized")
    }
    
    /// Start monitoring for app termination
    func startMonitoring() {
        guard !isMonitoring else {
            logDebug("Already monitoring")
            return
        }
        
        #if os(iOS)
        terminationSubscription = NotificationCenter.default
            .publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
        
        isMonitoring = true
        logDebug("Started monitoring app termination")
        #else
        logDebug("App termination monitoring not available on this platform")
        #endif
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        terminationSubscription?.cancel()
        terminationSubscription = nil
        isMonitoring = false
        logDebug("Stopped monitoring app termination")
    }
    
    // MARK: - Private
    
    private func handleAppWillTerminate() {
        logDebug("App will terminate - calling callback")
        onAppWillTerminate?()
    }
    
    private func logDebug(_ message: String) {
        onDebugEvent?("[AppTerminationDetector] \(message)")
        print("🔔 AppTerminationDetector: \(message)")
    }
}