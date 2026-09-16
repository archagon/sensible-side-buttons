//
//  EventMaker_Compatibility.h
//  SensibleSideButtons
//
//  Created by Alexei Baboulevitch on 9/15/26.
//  Copyright © 2026 Alexei Baboulevitch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface EventMaker_Compatibility : NSObject

// CGEvent.data is only available in macOS 12+, and we support versions earlier than that.
+ (nullable NSData *)dataFromEvent:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
