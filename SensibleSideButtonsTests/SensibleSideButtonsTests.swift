//
//  SensibleSideButtonsTests.swift
//  SensibleSideButtonsTests
//
//  Created by Alexei Baboulevitch on 9/12/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import Testing
import AppKit

// These tests don't automatically validate the expected behavior.
// However, they can trigger navigation in the Xcode editor. (Sometimes?)
// They can also help debug event code more easily.
struct SensibleSideButtonsTests {
    
    enum EventReEncodeType {
        case none // this event works when posted
        case reData // this event still works when posted, but the data is smaller
        case reSource // this event does not work when posted, and the data is smallest of all
    }
    
    func reEncode(event: CGEvent, type: EventReEncodeType) throws -> CGEvent {
        let returnEvent: CGEvent
        
        switch type {
        case .none:
            returnEvent = event
        case .reData:
            let eventData = try #require(event.data) as Data
            returnEvent = try #require(CGEvent(withDataAllocator: nil, data: eventData as CFData))
        case .reSource:
            let eventSource = try #require(CGEventSource(event: event))
            returnEvent = try #require(CGEvent(source: eventSource))
        }
        
        return returnEvent
    }
    
    @Test func testSwipeLeft() throws {
        try testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeLeft), reEncodeType: .none)
    }
    
    @Test func testSwipeRight() throws {
        try testSwipe(direction: TLInfoSwipeDirection(kTLInfoSwipeRight))
    }
    
    func testSwipe(direction: TLInfoSwipeDirection, reEncodeType: EventReEncodeType = .none) throws {
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
        
        let event1Base = try #require(tl_CGEventCreateFromGesture(swipeInfo1, [] as CFArray))
        let event2Base = try #require(tl_CGEventCreateFromGesture(swipeInfo2, [] as CFArray))
        
        defer {
            event1Base.release()
            event2Base.release()
        }
        
        let event1 = try reEncode(event: event1Base.takeUnretainedValue(), type: reEncodeType)
        let event2 = try reEncode(event: event2Base.takeUnretainedValue(), type: reEncodeType)
        
        event1.post(tap: .cghidEventTap)
        event2.post(tap: .cghidEventTap)
        
        print("🧪 Done");
    }
    
    @Test func testEventData() throws {
        let kTLInfoKeyGestureSubtype: NSString = try #require(kTLInfoKeyGestureSubtype)
        let kTLInfoKeySwipeDirection: NSString = try #require(kTLInfoKeySwipeDirection)
        let kTLInfoKeyGesturePhase: NSString = try #require(kTLInfoKeyGesturePhase)
        
        let direction = TLInfoSwipeDirection(kTLInfoSwipeLeft)
        
        let swipeInfo = NSDictionary.init(objects: [
            kTLInfoSubtypeSwipe, direction, CGGesturePhase.ended.rawValue
        ], forKeys: [
            kTLInfoKeyGestureSubtype, kTLInfoKeySwipeDirection, kTLInfoKeyGesturePhase
        ])
        
        let eventDataBase = try #require(tl_CGEventDataCreateFromGesture(swipeInfo, [] as CFArray))
        
        defer {
            eventDataBase.release()
        }
        
        let eventData = eventDataBase.takeUnretainedValue() as Data
        
        let event = try #require(CGEvent(withDataAllocator: kCFAllocatorDefault, data: eventData as CFData))
        let eventReData = try reEncode(event: event, type: .reData)
        let eventReSource = try reEncode(event: event, type: .reSource)
        
        let eventReDataData = try #require(eventReData.data) as Data
        let eventReSourceData = try #require(eventReSource.data) as Data
        
        // This data can be accessed using Clipboard Viewer. Hacky... but simple.
        let debugPersist = true
        if debugPersist {
            NSPasteboard.general.clearContents()
            
            NSPasteboard.general.setData(eventData, forType: .string)
            NSPasteboard.general.setData(eventReDataData, forType: .string)
            NSPasteboard.general.setData(eventReSourceData, forType: .string)
            
            NSPasteboard.general.setData(eventData, forType: .init(rawValue: "net.archagon.test.eventData"))
            NSPasteboard.general.setData(eventReDataData, forType: .init(rawValue: "net.archagon.test.eventReDataData"))
            NSPasteboard.general.setData(eventReSourceData, forType: .init(rawValue: "net.archagon.test.eventReSourceData"))
            
            print("🧪 Pasteboard done");
        }
        
        print("🧪 Done");
    }

    @Test func testRandomEvent() throws {
        let bytes = (0..<128).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        let randomData = Data(bytes)
        
        let randomEvent = CGEvent(withDataAllocator: nil, data: randomData as CFData)
        #expect(randomEvent == nil)
        
        let randomEvent2 = CGEvent(withDataAllocator: kCFAllocatorDefault, data: randomData as CFData)
        #expect(randomEvent2 == nil)
    }
    
    @Test func testTweakedEvent() throws {
        func addField(data: inout Data, type: UInt8, field: UInt8, value: InlineArray<4, UInt8>) {
            data.append(contentsOf: [0x00, 0x01, type, field, value[0], value[1], value[2], value[3]])
        }
        
        let event1 = try #require(CGEvent(source: nil))
        let event2 = try #require(CGEvent(source: nil))
        
        for event in [event1, event2] {
            let gestureType = UInt32(NSEvent.EventType.gesture.rawValue)
            event.type = CGEventType(rawValue: gestureType)!
            event.flags = CGEventFlags(rawValue: 256)
            event.timestamp = 0
        }
        
        let subtypeSwipe: UInt8 = 0x10
        let swipeLeft: UInt8 = 4
        let swipeRight: UInt8 = 8
        
        var event1Data = try #require(event1.data) as Data
        addField(data: &event1Data, type: 0x40, field: 0x6e, value: [0,0,0, subtypeSwipe])
        addField(data: &event1Data, type: 0x40, field: 0x84, value: [0,0,0, UInt8(CGGesturePhase.began.rawValue)])
        addField(data: &event1Data, type: 0x40, field: 0x73, value: [0,0,0, 0])
        
        var event2Data = try #require(event2.data) as Data
        addField(data: &event2Data, type: 0x40, field: 0x6e, value: [0,0,0, subtypeSwipe])
        addField(data: &event2Data, type: 0x40, field: 0x84, value: [0,0,0, UInt8(CGGesturePhase.ended.rawValue)])
        addField(data: &event2Data, type: 0x40, field: 0x73, value: [0,0,0, swipeRight])
        
        let newEvent1 = try #require(CGEvent(withDataAllocator: nil, data: event1Data as CFData))
        let newEvent2 = try #require(CGEvent(withDataAllocator: nil, data: event2Data as CFData))
        
        newEvent1.post(tap: .cghidEventTap)
        newEvent2.post(tap: .cghidEventTap)
        
        print("🧪 Done");
    }
}
