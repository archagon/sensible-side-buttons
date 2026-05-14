// GestureSynthesizer.swift — Swift wrapper for gesture event synthesis
// GPLv2

import Foundation
import CoreGraphics

enum SwipeDirection: UInt32 {
    case up = 1
    case down = 2
    case left = 4
    case right = 8
}

enum GestureSynthesizer {
    private static let swipeSubtype: Int32 = 0x10 // kTLInfoSubtypeSwipe

    /// Synthesize a 3-finger swipe gesture. Returns false if synthesis fails.
    static func fakeSwipe(_ direction: SwipeDirection) -> Bool {
        let phase1: NSDictionary = [
            kTLInfoKeyGestureSubtype!: NSNumber(value: swipeSubtype),
            kTLInfoKeyGesturePhase!: NSNumber(value: 1 as Int32)
        ]
        let phase2: NSDictionary = [
            kTLInfoKeyGestureSubtype!: NSNumber(value: swipeSubtype),
            kTLInfoKeySwipeDirection!: NSNumber(value: Int32(direction.rawValue)),
            kTLInfoKeyGesturePhase!: NSNumber(value: 4 as Int32)
        ]

        let emptyTouches = NSArray()

        guard let event1 = tl_CGEventCreateFromGesture(phase1, emptyTouches),
              let event2 = tl_CGEventCreateFromGesture(phase2, emptyTouches) else {
            return false
        }

        event1.post(tap: .cghidEventTap)
        event2.post(tap: .cghidEventTap)
        return true
    }
}
