//
//  EventMaker_Compatibility.m
//  SensibleSideButtons
//
//  Created by Alexei Baboulevitch on 9/15/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

#import "EventMaker_Compatibility.h"

NS_ASSUME_NONNULL_BEGIN

@implementation EventMaker_Compatibility

+ (nullable NSData *)dataFromEvent:(CGEventRef)event {
    CFDataRef dataRef = CGEventCreateData(NULL, event);
    NSData *data = CFBridgingRelease(dataRef);
    return data;
}

@end

NS_ASSUME_NONNULL_END
