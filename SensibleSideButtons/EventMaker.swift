//
//  EventMaker.swift
//  SensibleSideButtons
//
//  Created by Alexei Baboulevitch on 9/15/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import AppKit

@objc class EventMaker : NSObject {
    
    enum EventMakerError: Error {
        case error(String)
    }
    
    // "TLInfoSwipeDirection" == IOHIDSwipeMask?
    @objc enum SwipeDirection: UInt8 {
        case up     = 0b0001
        case down   = 0b0010
        case left   = 0b0100
        case right  = 0b1000
    }
    
    // "TLInfoSubtype" == IOHIDEventType?
    @objc enum Subtype: UInt8 {
        case swipe  = 0x10
    }
    
    @objc class func createGestureEvent(withSwipeDirection swipeDirection: SwipeDirection, phase: CGGesturePhase) throws -> CGEvent {
        func addField(data: inout Data, type: UInt8, field: UInt8, value: UInt8) {
            data.append(contentsOf: [0x00, 0x01, type, field, 0, 0, 0, value])
        }
        
        guard let event = CGEvent(source: nil) else {
            throw EventMakerError.error("Could not create CGEvent")
        }
        
        guard let eventType = CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue)) else {
            throw EventMakerError.error("Could not create CGEventType")
        }
        
        event.type = eventType
        event.flags = CGEventFlags(rawValue: 256)
        event.timestamp =  DispatchTime.now().uptimeNanoseconds // not sure if this is even necessary
        
        guard var eventData = EventMaker_Compatibility.data(from: event) else {
            throw EventMakerError.error("Could not retrieve data from CGEvent")
        }
        
        // The base event data already contains this field. But adding it again seems to replace it.
        addField(data: &eventData, type: 0x40, field: 0x6e, value: Subtype.swipe.rawValue)
        
        addField(data: &eventData, type: 0x40, field: 0x84, value: UInt8(phase.rawValue))
        
        // Originally, this field was only filled in for CGGesturePhase.ended, but adding it every time seems to cause no harm.
        addField(data: &eventData, type: 0x40, field: 0x73, value: swipeDirection.rawValue)
        
        guard let newEvent = CGEvent(withDataAllocator: nil, data: eventData as CFData) else {
            throw EventMakerError.error("Could not create new CGEvent from modified data")
        }
        
        return newEvent
    }
}
