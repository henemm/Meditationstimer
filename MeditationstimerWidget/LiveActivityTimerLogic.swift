//
//  LiveActivityTimerLogic.swift
//  MeditationstimerWidget
//
//  Autonomous timer logic for Live Activity to handle phase transitions
//  and automatic completion when app is force-quit.
//

import Foundation

struct LiveActivityTimerLogic {
    
    enum Phase {
        case meditation(remaining: Int)
        case reflection(remaining: Int) 
        case completed
    }
    
    static func calculateCurrentPhase(
        sessionStartDate: Date,
        phase1EndDate: Date,
        sessionEndDate: Date,
        currentTime: Date = Date()
    ) -> Phase {
        
        if currentTime < phase1EndDate {
            // Still in Phase 1 (Meditation)
            let remaining = Int(phase1EndDate.timeIntervalSince(currentTime).rounded(.up))
            return .meditation(remaining: max(0, remaining))
        } else if currentTime < sessionEndDate {
            // In Phase 2 (Reflection/Besinnung)
            let remaining = Int(sessionEndDate.timeIntervalSince(currentTime).rounded(.up))
            return .reflection(remaining: max(0, remaining))
        } else {
            // Session completed
            return .completed
        }
    }
    
    static func isSessionExpired(sessionEndDate: Date, currentTime: Date = Date()) -> Bool {
        return currentTime >= sessionEndDate
    }
}