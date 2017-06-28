//
//  main.m
//
// SensibleSideButtons, a utility that fixes the navigation buttons on third-party mice in macOS
// Copyright (C) 2017 Alexei Baboulevitch (ssb@archagon.net)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#import <Foundation/Foundation.h>
#import "TouchEvents.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
#ifdef LEFT
        TLInfoSwipeDirection dir = kTLInfoSwipeLeft;
#else
        TLInfoSwipeDirection dir = kTLInfoSwipeRight;
#endif
        
        NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    @(1), kTLInfoKeyGesturePhase,
                                    nil];
        
        NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    @(dir), kTLInfoKeySwipeDirection,
                                    @(4), kTLInfoKeyGesturePhase,
                                    nil];
        
        CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo1), (__bridge CFArrayRef)@[]);
        CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo2), (__bridge CFArrayRef)@[]);
        
        CFRetain(event1);
        CFRetain(event2);
        
        CGEventPost(kCGHIDEventTap, event1);
        CGEventPost(kCGHIDEventTap, event2);
        
        CFRelease(event1);
        CFRelease(event2);
        
        NSLog(@"sent event");
        
        // in order to complete, we have to wait
        //usleep(1000000);
        usleep(1000000/128);
        
        //NSLog(@"done");
    }
    return 0;
}
