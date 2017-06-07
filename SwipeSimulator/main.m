//
//  main.m
//  SwipeSimulator
//
//  Created by Alexei Baboulevitch on 2017-6-5.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
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
