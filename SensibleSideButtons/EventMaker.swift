//
//  EventMaker.swift
//  SensibleSideButtons
//
//  Created by Alexei Baboulevitch on 9/15/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import AppKit

@objc class EventMaker : NSObject {
    
    @objc enum SwipeDirection: UInt8 {
        case up = 1
        case down = 2
        case left = 4
        case right = 8
    }
    
    @objc enum Subtype: UInt8 {
        case rotate = 0x05
        case magnify = 0x08
        case gesture = 0x0B
        case swipe = 0x10
    }
    
    @objc class func createGestureEvent(withSwipeDirection swipeDirection: SwipeDirection, phase: CGGesturePhase) throws -> CGEvent {
        func addField(data: inout Data, type: UInt8, field: UInt8, value: (UInt8,UInt8,UInt8,UInt8)) {
            data.append(contentsOf: [0x00, 0x01, type, field, value.0, value.1, value.2, value.3])
        }
        
        let event = CGEvent(source: nil)!
        
        let gestureType = UInt32(NSEvent.EventType.gesture.rawValue)
        event.type = CGEventType(rawValue: gestureType)!
        event.flags = CGEventFlags(rawValue: 256)
        event.timestamp = 0
        
        var eventData: Data
        if #available(macOS 26.5, *) {
            eventData = event.data! as Data
        } else {
            fatalError("Wrong OS version")
        }
        
        addField(data: &eventData, type: 0x40, field: 0x6e, value: (0,0,0, Subtype.swipe.rawValue))
        addField(data: &eventData, type: 0x40, field: 0x84, value: (0,0,0, UInt8(phase.rawValue)))
        addField(data: &eventData, type: 0x40, field: 0x73, value: (0,0,0, swipeDirection.rawValue))
        
        let newEvent = CGEvent(withDataAllocator: nil, data: eventData as CFData)!
        
        return newEvent
    }
}
