//
//  SensibleSideButtonsTests.swift
//  SensibleSideButtonsTests
//
//  Created by Alexei Baboulevitch on 9/12/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import Testing

// These tests don't automatically validate the expected behavior.
// However, they can trigger navigation in the Xcode editor.
// They can also help debug event code more easily.
struct SensibleSideButtonsTests {
    
    @Test func testSwipeLeft() async throws {
        try await testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeLeft))
    }
    
    @Test func testSwipeRight() async throws {
        try await testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeRight))
    }
    
    func testSwipe(direction: TLInfoSwipeDirection) async throws {
        let kTLInfoKeyGestureSubtype: NSString = try #require(kTLInfoKeyGestureSubtype)
        let kTLInfoKeySwipeDirection: NSString = try #require(kTLInfoKeySwipeDirection)
        let kTLInfoKeyGesturePhase: NSString = try #require(kTLInfoKeyGesturePhase)
        
        let swipeInfo1 = NSDictionary.init(objects: [
            kTLInfoSubtypeSwipe, CGGesturePhase.began.rawValue
        ], forKeys: [
            kTLInfoKeyGestureSubtype, kTLInfoKeyGesturePhase
        ])
        
        let swipeInfo2 = NSDictionary.init(objects: [
            kTLInfoSubtypeSwipe, direction, CGGesturePhase.ended.rawValue
        ], forKeys: [
            kTLInfoKeyGestureSubtype, kTLInfoKeySwipeDirection, kTLInfoKeyGesturePhase
        ])
        
        let event1 = try #require(tl_CGEventCreateFromGesture(swipeInfo1, [] as CFArray))
        let event2 = try #require(tl_CGEventCreateFromGesture(swipeInfo2, [] as CFArray))
        
        event1.takeUnretainedValue().post(tap: .cghidEventTap)
        event2.takeUnretainedValue().post(tap: .cghidEventTap)
        
        event1.release()
        event2.release()
        
        print("🧪 Sent event");
    }

}
