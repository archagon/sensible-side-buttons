//
//  AppDelegate.m
//
// SensibleSideButtons, a utility that fixes the navigation buttons on third-party mice in macOS
// Copyright (C) 2018 Alexei Baboulevitch (ssb@archagon.net)
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

#import "AppDelegate.h"
#import "TouchEvents.h"

#define SIGN(x) (((x) > 0) - ((x) < 0))
#define SCROLL_LINES 3

static NSMutableDictionary<NSNumber*, NSArray<NSDictionary*>*>* swipeInfo = nil;
static NSArray* nullArray = nil;

static void SBFFakeSwipe(TLInfoSwipeDirection dir) {
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
}

// This logic comes from discrete-scroll (https://github.com/emreyolcu/discrete-scroll),
// which is MIT-licensed by Emre Yolcu. See LICENSE-discrete-scroll.
static CGEventRef SBFScrollCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (!CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)) {
        int64_t delta = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
        
        CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, SIGN(delta) * SCROLL_LINES);
    }
    
    return event;
}

static CGEventRef SBFMouseCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    int64_t number = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    BOOL down = (CGEventGetType(event) == kCGEventOtherMouseDown);
    
    BOOL mouseDown = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"];
    BOOL swapButtons = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFSwapButtons"];
    
    if (number == (swapButtons ? 4 : 3)) {
        if ((mouseDown && down) || (!mouseDown && !down)) {
            SBFFakeSwipe(kTLInfoSwipeLeft);
        }
        
        return NULL;
    }
    else if (number == (swapButtons ? 3 : 4)) {
        if ((mouseDown && down) || (!mouseDown && !down)) {
            SBFFakeSwipe(kTLInfoSwipeRight);
        }
        
        return NULL;
    }
    else {
        return event;
    }
}

typedef NS_ENUM(NSInteger, MenuMode) {
    MenuModeAccessibility,
    MenuModeDonation,
    MenuModeNormal
};

typedef NS_ENUM(NSInteger, MenuItem) {
    MenuItemEnabled = 0,
    MenuItemAccelDisabled,
    MenuItemEnabledSeparator,
    MenuItemTriggerOnMouseDown,
    MenuItemSwapButtons,
    MenuItemOptionsSeparator,
    MenuItemStartupHide,
    MenuItemStartupHideInfo,
    MenuItemStartupSeparator,
    MenuItemAboutText,
    MenuItemAboutSeparator,
    MenuItemDonate,
    MenuItemWebsite,
    MenuItemAccessibility,
    MenuItemLinkSeparator,
    MenuItemQuit
};

@interface AppDelegate () <NSMenuDelegate>
@property (nonatomic, retain) NSStatusItem* statusItem;
@property (nonatomic, assign) CFMachPortRef tap;
@property (nonatomic, assign) CFMachPortRef scrollTap;
@property (nonatomic, assign) MenuMode menuMode;
@end

@interface AboutView: NSView
@property (nonatomic, retain) NSTextView* text;
@property (nonatomic, assign) MenuMode menuMode;
-(CGFloat) margin;
@end

@implementation AppDelegate

-(void) dealloc {
    [self startTap:NO];
    [self startScrollTap:NO];
    
    swipeInfo = nil;
    nullArray = nil;
}

-(void) setMenuMode:(MenuMode)menuMode {
    _menuMode = menuMode;
    AboutView* view = (AboutView*)self.statusItem.menu.itemArray[MenuItemAboutText].view;
    view.menuMode = menuMode;
    [self refreshSettings];
}

// if the application is launched when it's already running, show the icon in the menu bar again
-(BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (@available(macOS 10.12, *)) {
        [self.statusItem setVisible:YES];
    }
    return NO;
}

-(void) applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
                                                              @"SBFWasEnabled": @YES,
                                                              @"SBFAccelWasDisabled": @NO,
                                                              @"SBFMouseDown": @YES,
                                                              @"SBFDonated": @NO,
                                                              @"SBFSwapButtons": @NO
                                                              }];
    
    // setup globals
    {
        swipeInfo = [NSMutableDictionary dictionary];
        
        for (NSNumber* direction in @[ @(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight) ]) {
            NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                        @(1), kTLInfoKeyGesturePhase,
                                        nil];
            
            NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                        direction, kTLInfoKeySwipeDirection,
                                        @(4), kTLInfoKeyGesturePhase,
                                        nil];
            
            swipeInfo[direction] = @[ swipeInfo1, swipeInfo2 ];
        }
        
        nullArray = @[];
    }
    
    // create status bar item
    {
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    }
    
    // create menu
    {
        NSMenu* menu = [NSMenu new];
        
        menu.autoenablesItems = NO;
        menu.delegate = self;
        
        NSMenuItem* enabledItem = [[NSMenuItem alloc] initWithTitle:@"Enabled" action:@selector(enabledToggle:) keyEquivalent:@"e"];
        [menu addItem:enabledItem];
        assert(menu.itemArray.count - 1 == MenuItemEnabled);
        
        NSMenuItem* accelDisabledItem = [[NSMenuItem alloc] initWithTitle:@"Disable Scroll Wheel Acceleration" action:@selector(accelDisabledToggle:) keyEquivalent:@"a"];
        [menu addItem:accelDisabledItem];
        assert(menu.itemArray.count - 1 == MenuItemAccelDisabled);
        
        [menu addItem:[NSMenuItem separatorItem]];
        assert(menu.itemArray.count - 1 == MenuItemEnabledSeparator);
        
        NSMenuItem* modeItem = [[NSMenuItem alloc] initWithTitle:@"Trigger on Mouse Down" action:@selector(mouseDownToggle:) keyEquivalent:@""];
        modeItem.state = NSControlStateValueOn;
        [menu addItem:modeItem];
        assert(menu.itemArray.count - 1 == MenuItemTriggerOnMouseDown);
        
        NSMenuItem* swapItem = [[NSMenuItem alloc] initWithTitle:@"Swap Buttons" action:@selector(swapToggle:) keyEquivalent:@""];
        swapItem.state = NSControlStateValueOff;
        [menu addItem:swapItem];
        assert(menu.itemArray.count - 1 == MenuItemSwapButtons);
        
        [menu addItem:[NSMenuItem separatorItem]];
        assert(menu.itemArray.count - 1 == MenuItemOptionsSeparator);
        
        
        NSMenuItem* hideItem = [[NSMenuItem alloc] initWithTitle:@"Hide Menu Bar Icon" action:@selector(hideMenubarItem:) keyEquivalent:@""];
        [menu addItem:hideItem];
        assert(menu.itemArray.count - 1 == MenuItemStartupHide);
        
        NSMenuItem* hideInfoItem = [[NSMenuItem alloc] initWithTitle:@"Relaunch application to show again" action:NULL keyEquivalent:@""];
        [hideInfoItem setEnabled:NO];
        [menu addItem:hideInfoItem];
        assert(menu.itemArray.count - 1 == MenuItemStartupHideInfo);
        
        [menu addItem:[NSMenuItem separatorItem]];
        assert(menu.itemArray.count - 1 == MenuItemStartupSeparator);
        
        AboutView* text = [[AboutView alloc] initWithFrame:NSMakeRect(0, 0, 320, 100)]; //arbitrary height
        NSMenuItem* aboutText = [[NSMenuItem alloc] initWithTitle:@"Text" action:NULL keyEquivalent:@""];
        aboutText.view = text;
        [menu addItem:aboutText];
        assert(menu.itemArray.count - 1 == MenuItemAboutText);
        
        [menu addItem:[NSMenuItem separatorItem]];
        assert(menu.itemArray.count - 1 == MenuItemAboutSeparator);
        
        NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        [menu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ Website", appName] action:@selector(donate:) keyEquivalent:@""]];
        assert(menu.itemArray.count - 1 == MenuItemDonate);
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ Website", appName] action:@selector(website:) keyEquivalent:@""]];
        assert(menu.itemArray.count - 1 == MenuItemWebsite);
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Open Accessibility Whitelist" action:@selector(accessibility:) keyEquivalent:@""]];
        assert(menu.itemArray.count - 1 == MenuItemAccessibility);
        
        [menu addItem:[NSMenuItem separatorItem]];
        assert(menu.itemArray.count - 1 == MenuItemLinkSeparator);

        NSMenuItem* quit = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
        quit.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        [menu addItem:quit];
        assert(menu.itemArray.count - 1 == MenuItemQuit);
        
        self.statusItem.menu = menu;
    }
    
    [self startTap:[[NSUserDefaults standardUserDefaults] boolForKey:@"SBFWasEnabled"]];
    [self startScrollTap:[[NSUserDefaults standardUserDefaults] boolForKey:@"SBFAccelWasDisabled"]];
    
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) updateMenuMode {
    [self updateMenuMode:YES];
}

-(void) updateMenuMode:(BOOL)active {
    // TODO: this actually returns YES if SSB is deleted (not disabled) from Accessibility
    NSDictionary* options = @{ (__bridge id)kAXTrustedCheckOptionPrompt: @(active ? YES : NO) };
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
    //BOOL accessibilityEnabled = YES; //is accessibility even required? seems to work fine without it
    
    if (accessibilityEnabled) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SBFDonated"]) {
            self.menuMode = MenuModeNormal;
        }
        else {
            self.menuMode = MenuModeDonation;
        }
    }
    else {
        self.menuMode = MenuModeAccessibility;
    }
    
    // QQQ: for testing
    //self.menuMode = arc4random_uniform(3);
}

-(void) refreshSettings {
    self.statusItem.menu.itemArray[MenuItemEnabled].state = self.tap != NULL && CGEventTapIsEnabled(self.tap);
    self.statusItem.menu.itemArray[MenuItemAccelDisabled].state = self.scrollTap != NULL && CGEventTapIsEnabled(self.scrollTap);
    self.statusItem.menu.itemArray[MenuItemTriggerOnMouseDown].state = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"];
    self.statusItem.menu.itemArray[MenuItemSwapButtons].state = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFSwapButtons"];
    
    switch (self.menuMode) {
        case MenuModeAccessibility:
            self.statusItem.menu.itemArray[MenuItemEnabled].enabled = NO;
            self.statusItem.menu.itemArray[MenuItemAccelDisabled].enabled = NO;
            self.statusItem.menu.itemArray[MenuItemTriggerOnMouseDown].enabled = NO;
            self.statusItem.menu.itemArray[MenuItemSwapButtons].enabled = NO;
            self.statusItem.menu.itemArray[MenuItemDonate].hidden = YES;
            self.statusItem.menu.itemArray[MenuItemWebsite].hidden = NO;
            self.statusItem.menu.itemArray[MenuItemAccessibility].hidden = NO;
            break;
        case MenuModeDonation:
            self.statusItem.menu.itemArray[MenuItemEnabled].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemAccelDisabled].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemTriggerOnMouseDown].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemSwapButtons].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemDonate].hidden = NO;
            self.statusItem.menu.itemArray[MenuItemWebsite].hidden = YES;
            self.statusItem.menu.itemArray[MenuItemAccessibility].hidden = YES;
            break;
        case MenuModeNormal:
            self.statusItem.menu.itemArray[MenuItemEnabled].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemAccelDisabled].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemTriggerOnMouseDown].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemSwapButtons].enabled = YES;
            self.statusItem.menu.itemArray[MenuItemDonate].hidden = YES;
            self.statusItem.menu.itemArray[MenuItemWebsite].hidden = NO;
            self.statusItem.menu.itemArray[MenuItemAccessibility].hidden = YES;
            break;
    }
    
    AboutView* view = (AboutView*)self.statusItem.menu.itemArray[MenuItemAboutText].view;
    [view layoutSubtreeIfNeeded]; //used to auto-calculate the text view size
    view.frame = NSMakeRect(0, 0, view.bounds.size.width, view.text.frame.size.height);
    
    // only show the menu item to hide the icon if the API is available
    if (@available(macOS 10.12, *)) {
        self.statusItem.menu.itemArray[MenuItemStartupHide].hidden = NO;
        self.statusItem.menu.itemArray[MenuItemStartupHideInfo].hidden = NO;
    }
    else {
        self.statusItem.menu.itemArray[MenuItemStartupHide].hidden = YES;
        self.statusItem.menu.itemArray[MenuItemStartupHideInfo].hidden = YES;
    }
    
    if (self.statusItem.button != nil) {
        if (self.tap != NULL && CGEventTapIsEnabled(self.tap)) {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuIcon"];
        }
        else {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuIconDisabled"];
        }
    }
}

// This logic comes from discrete-scroll (https://github.com/emreyolcu/discrete-scroll),
// which is MIT-licensed by Emre Yolcu. See LICENSE-discrete-scroll.
-(void) startScrollTap:(BOOL)start {
    if (start) {
        if (self.scrollTap == NULL) {
            self.scrollTap = CGEventTapCreate(kCGSessionEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              CGEventMaskBit(kCGEventScrollWheel),
                                              &SBFScrollCallback,
                                              NULL);
            if (self.scrollTap != NULL) {
                CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, self.scrollTap, 0);
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
                CFRelease(runLoopSource);
                
                CGEventTapEnable(self.scrollTap, true);
            }
        }
    }
    else {
        if (self.scrollTap != NULL) {
            CGEventTapEnable(self.tap, NO);
            CFRelease(self.scrollTap);
            
            self.scrollTap = NULL;
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:self.scrollTap != NULL && CGEventTapIsEnabled(self.scrollTap) forKey:@"SBFAccelWasDisabled"];
}

-(void) startTap:(BOOL)start {
    if (start) {
        if (self.tap == NULL) {
            self.tap = CGEventTapCreate(kCGHIDEventTap,
                                        kCGHeadInsertEventTap,
                                        kCGEventTapOptionDefault,
                                        CGEventMaskBit(kCGEventOtherMouseUp)|CGEventMaskBit(kCGEventOtherMouseDown),
                                        &SBFMouseCallback,
                                        NULL);
            
            if (self.tap != NULL) {
                CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, self.tap, 0);
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
                CFRelease(runLoopSource);
                
                CGEventTapEnable(self.tap, true);
            }
        }
    }
    else {
        if (self.tap != NULL) {
            CGEventTapEnable(self.tap, NO);
            CFRelease(self.tap);
            
            self.tap = NULL;
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:self.tap != NULL && CGEventTapIsEnabled(self.tap) forKey:@"SBFWasEnabled"];
}

-(void) accelDisabledToggle:(id)sender {
    [self startScrollTap:self.scrollTap == NULL];
    [self refreshSettings];
}

-(void) enabledToggle:(id)sender {
    [self startTap:self.tap == NULL];
    [self refreshSettings];
}

-(void) mouseDownToggle:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"] forKey:@"SBFMouseDown"];
    [self refreshSettings];
}

-(void) swapToggle:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:@"SBFSwapButtons"] forKey:@"SBFSwapButtons"];
    [self refreshSettings];
}

-(void) donate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://sensible-side-buttons.archagon.net#donations"]];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SBFDonated"];
    
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) website:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://sensible-side-buttons.archagon.net"]];
}

-(void) accessibility:(id)sender {
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) hideMenubarItem:(id)sender {
    if (@available(macOS 10.12, *)) {
        [self.statusItem setVisible:NO];
    }
}

-(void) quit:(id)sender {
    [NSApp terminate:self];
}

- (void) menuWillOpen:(NSMenu*)menu {
    // TODO: theoretically, accessibility can be disabled while the menu is opened, but this is unlikely
    [self updateMenuMode:NO];
    [self refreshSettings];
}

@end

@implementation AboutView

-(CGFloat) margin {
    return 17;
}

-(void) setMenuMode:(MenuMode)menuMode {
    _menuMode = menuMode;
    
    NSFont* font = [NSFont menuFontOfSize:13];
    
    NSFontDescriptor* boldFontDesc = [NSFontDescriptor fontDescriptorWithFontAttributes:@{
                                                                                          NSFontFamilyAttribute: font.familyName,
                                                                                          NSFontFaceAttribute: @"Bold"
                                                                                          }];
    NSFont* boldFont = [NSFont fontWithDescriptor:boldFontDesc size:font.pointSize];
    if (!boldFont) { boldFont = font; }
    
    // AB: dynamic color component extraction experiments
    //CGFloat h1, s1, b1, a1, h2, s2, b2, a2;
    //NSColorSpace* space;
    //if (@available(macOS 10.13, *)) {
    //    space = [[NSColor redColor] colorUsingType:NSColorTypeComponentBased].colorSpace;
    //} else {
    //    space = [NSColorSpace deviceRGBColorSpace];
    //}
    //NSColor* color = [[NSColor systemBlueColor] colorUsingColorSpace:space];
    //[color getHue:&h1 saturation:&s1 brightness:&b1 alpha:&a1];
    //color = [[NSColor systemRedColor] colorUsingColorSpace:space];
    //[color getHue:&h2 saturation:&s2 brightness:&b2 alpha:&a2];
    
    //NSColor* regularColor = [NSColor colorWithRed:120/255.0 green:120/255.0 blue:160/255.0 alpha:1];
    //NSColor* regularColor = [NSColor colorWithHue:h1 saturation:s1 brightness:b1 alpha:a1];
    NSColor* regularColor = [NSColor secondaryLabelColor];
    NSColor* alertColor = [NSColor systemRedColor];
    
    NSDictionary* regularAttributes = @{
                                 NSFontAttributeName: font,
                                 NSForegroundColorAttributeName: regularColor
                                 };
    NSDictionary* alertAttributes = @{
                                      NSFontAttributeName: font,
                                      NSForegroundColorAttributeName: alertColor
                                      };
    NSDictionary* smallReturnAttributes = @{
                                            NSFontAttributeName: [NSFont menuFontOfSize:3],
                                            };
    
    NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString* appDescription = [NSString stringWithFormat:@"%@ %@", appName, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    NSString* copyright = @"Copyright © 2018 Alexei Baboulevitch.";
    
    switch (menuMode) {
        case MenuModeAccessibility: {
            NSString* text = [NSString stringWithFormat:@"Uh-oh! It looks like %@ is not whitelisted in the Accessibility panel of your Security & Privacy System Preferences. This app needs to be on the Accessibility whitelist in order to process global mouse events. Please open the Accessibility panel below and add the app to the whitelist.", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:alertAttributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:regularAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:smallReturnAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:copyright attributes:regularAttributes]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
        case MenuModeDonation: {
            NSString* text = [NSString stringWithFormat:@"Thanks for using %@!\nIf you find this utility useful, please consider making a purchase through the Amazon affiliate link on the website below. It won't cost you an extra cent! 😊", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:regularAttributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:regularAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:smallReturnAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:copyright attributes:regularAttributes]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
        case MenuModeNormal: {
            NSString* text = [NSString stringWithFormat:@"Thanks for using %@!", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:regularAttributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:regularAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:smallReturnAttributes]];
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:copyright attributes:regularAttributes]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
    }
    
    [self setNeedsLayout:YES];
}

-(instancetype) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    
    if (self) {
        //NSTextView* testColor = [NSTextView new];
        //testColor.backgroundColor = NSColor.greenColor;
        //[self addSubview:testColor];
        
        self.text = [NSTextView new];
        self.text.backgroundColor = NSColor.clearColor;
        [self.text setEditable:NO];
        [self.text setSelectable:NO];
        [self addSubview:self.text];
        
        self.menuMode = MenuModeNormal;
    }
    
    return self;
}

-(void) layout {
    [super layout];
    
    CGFloat margin = [self margin];
    
    // text view sizing
    {
        // first, set the correct width
        CGFloat arbitraryHeight = 100;
        self.text.frame = NSMakeRect(margin, 0, self.bounds.size.width - margin, arbitraryHeight);
        
        // next, autosize to get the height
        [self.text sizeToFit];
        
        // finally, position the view correctly
        self.text.frame = NSMakeRect(self.text.frame.origin.x, self.bounds.size.height - self.text.frame.size.height, self.text.frame.size.width, self.text.frame.size.height);
    }
    
    //NSView* testView = [self subviews][0];
    //testView.frame = self.bounds;
    
    //NSLog(@"Text size: %@, self size: %@", NSStringFromSize(self.text.frame.size), NSStringFromSize(self.bounds.size));
}

@end
