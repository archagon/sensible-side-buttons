//
//  ThemingHelper.m
//  SensibleSideButtons
//
//  Created by Matteo Gaggiano on 10/06/2018.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MGThemingHelper.h"

@implementation MGThemingHelper: NSObject

- (ThemeType) getCurrent {
    return _current;
}

- (void) setCurrent:(ThemeType) type {
    _current = type;
}

+ (MGThemingHelper *) fromString:(NSString *) typeString {
    MGThemingHelper *th = [MGThemingHelper new];
    if (typeString == NULL) {
        [th setCurrent: [MGThemingHelper defaultType]];
    } else {
        [th setCurrent: [MGThemingHelper valueOf:typeString]];
    }
    
    return th;
}

+ (ThemeType) valueOf:(NSString *) typeString {
    ThemeType type = Light;
    if ([[typeString lowercaseString] isEqualToString:@"dark"]) {
        type = Dark;
    }
    return type;
}

+ (ThemeType) defaultType {
    return Light;
}

@end
