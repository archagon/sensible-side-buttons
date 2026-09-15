//
//  AppDelegate.swift
//  EventTapTest
//
//  Created by Alexei Baboulevitch on 9/15/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

import Cocoa

// The purpose of this barebones test app is to inspect swipe events more easily.
@main class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSEvent.addLocalMonitorForEvents(matching: .swipe) { event in
            print("Event: \(event)")
            
            if let data = event.cgEvent?.data as? Data {
                print("Data length: \(data.count)")
                let newEvent = CGEvent(withDataAllocator: nil, data: data as CFData)
                print("New data length: \((newEvent?.data as? Data)?.count ?? 0)")
                
                //if event.phase == .began {
                //    print("Began")
                //    NSPasteboard.general.clearContents()
                //    NSPasteboard.general.setData(data, forType: .string)
                //}
            }
            
            return event
        }
    }
}
