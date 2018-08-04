//
//  MGThemingHelper.h
//  SensibleSideButtons
//
//  Created by Matteo Gaggiano on 10/06/2018.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

#ifndef MGThemingHelper_h
#define MGThemingHelper_h

typedef NS_ENUM(NSUInteger, ThemeType) {
    Dark,
    Light
};

@interface MGThemingHelper : NSObject

@property (readonly, nonatomic) ThemeType current;

- (ThemeType) getCurrent;
- (void) setCurrent:(ThemeType) type;

+ (MGThemingHelper*) fromString:(NSString *) typeString;
+ (ThemeType) valueOf:(NSString *) typeString;

@end

#endif /* MGThemingHelper_h */
