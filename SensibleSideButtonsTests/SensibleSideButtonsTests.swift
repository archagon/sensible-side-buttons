//
//  SensibleSideButtonsTests.swift
//  SensibleSideButtonsTests
//
//  Created by Alexei Baboulevitch on 9/12/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import Testing

// These tests don't really do anything, but they can help debug event code more easily.
struct SensibleSideButtonsTests {
    
    @Test func testSwipeLeft() async throws {
        try await testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeLeft))
    }
    
    @Test func testSwipeRight() async throws {
        try await testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeRight))
    }
    
    func testSwipe(direction: TLInfoSwipeDirection) async throws {
        guard let kTLInfoKeyGestureSubtype: NSString = kTLInfoKeyGestureSubtype else {
            fatalError()
        }
        guard let kTLInfoKeySwipeDirection: NSString = kTLInfoKeySwipeDirection else {
            fatalError()
        }
        guard let kTLInfoKeyGesturePhase: NSString = kTLInfoKeyGesturePhase else {
            fatalError()
        }
        
        let swipeInfo1 = NSDictionary.init(objects: [
            kTLInfoSubtypeSwipe, 1
        ], forKeys: [
            kTLInfoKeyGestureSubtype, kTLInfoKeyGesturePhase
        ])
        
        let swipeInfo2 = NSDictionary.init(objects: [
            kTLInfoSubtypeSwipe, direction, 4
        ], forKeys: [
            kTLInfoKeyGestureSubtype, kTLInfoKeySwipeDirection, kTLInfoKeyGesturePhase
        ])
        
        let event1 = tl_CGEventCreateFromGesture(swipeInfo1, [] as CFArray)
        let event2 = tl_CGEventCreateFromGesture(swipeInfo2, [] as CFArray)
        
        event1?.takeRetainedValue().post(tap: .cghidEventTap)
        event2?.takeRetainedValue().post(tap: .cghidEventTap)
        
        print("sent event");
        
        // in order to complete, we have to wait
        //Task.sleep(nanoseconds: 1000000)
        try await Task.sleep(nanoseconds: 1000000/128)
        
        print("done");
    }

}
