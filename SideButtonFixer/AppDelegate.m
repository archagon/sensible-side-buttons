//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import "TouchEvents.h"
#import "MGThemingHelper.h"

static NSMutableDictionary<NSNumber*, NSArray<NSDictionary*>*>* swipeInfo = nil;
static NSArray* nullArray = nil;

static NSString *ABOUT_ITEM_KEY = @"swp_about_item";
static NSString *ENABLE_ITEM_KEY = @"swp_enable_item";
static NSString *MODE_ITEM_KEY = @"swp_mode_item";
static NSString *SWAP_ITEM_KEY = @"swp_swap_item";
static NSString *ABOUTTEXT_ITEM_KEY = @"swp_abouttext_item";
static NSString *DONATE_ITEM_KEY = @"swp_donate_item";
static NSString *WEBSITE_ITEM_KEY = @"swp_website_item";
static NSString *ACCESSIBILITY_ITEM_KEY = @"swp_accessibility_item";
static NSString *QUIT_ITEM_KEY = @"swp_quit_item";

static void SBFFakeSwipe(TLInfoSwipeDirection dir) {
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
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

@interface AppDelegate () <NSMenuDelegate>
@property (nonatomic, retain) NSStatusItem* statusItem;
@property (nonatomic, assign) CFMachPortRef tap;
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
    
    swipeInfo = nil;
    nullArray = nil;
}

-(void)setMenuMode:(MenuMode)menuMode {
    _menuMode = menuMode;
    AboutView* view = (AboutView*) [self menuByIdentifier:ABOUTTEXT_ITEM_KEY].view;
    view.menuMode = menuMode;
    [self refreshSettings];
}

-(void) applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
                                                              @"SBFWasEnabled": @YES,
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
    
    NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    // create menu
    {
        NSMenu* menu = [NSMenu new];
        
        menu.autoenablesItems = NO;
        menu.delegate = self;
        
        NSMenuItem* aboutItem = [[NSMenuItem alloc]
                               initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"About %@", null), appName]
                               action:@selector(orderFrontStandardAboutPanel:)
                               keyEquivalent:@""];
        aboutItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        
        [aboutItem setIdentifier:ABOUT_ITEM_KEY];
        
        [menu addItem:aboutItem];
        
        NSMenuItem* enabledItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Enable", null)
                                                             action:@selector(enabledToggle:)
                                                      keyEquivalent:NSLocalizedString(@"ENABLE_ABBR", null)];

        [enabledItem setIdentifier:ENABLE_ITEM_KEY];
        [menu addItem:enabledItem];
        
        NSMenuItem* modeItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Trigger on Mouse Down", null)
                                                          action:@selector(mouseDownToggle:)
                                                   keyEquivalent:NSLocalizedString(@"TRIGGER_ABBR", null)];
        modeItem.state = NSControlStateValueOn;
        
        [modeItem setIdentifier:MODE_ITEM_KEY];
        [menu addItem:modeItem];

        NSMenuItem* swapItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Swap Buttons", null)
                                                          action:@selector(swapToggle:)
                                                   keyEquivalent:NSLocalizedString(@"SWAP_ABBR", null)];
        swapItem.state = NSControlStateValueOff;
        
        [swapItem setIdentifier:SWAP_ITEM_KEY];
        [menu addItem:swapItem];
        
//        [menu addItem:[NSMenuItem separatorItem]];
//        NSMenuItem* mouseItem = [[NSMenuItem alloc] initWithTitle:@"G403" action:@selector(act:) keyEquivalent:@""];
//        mouseItem.state = NSControlStateValueOn;
//
//        [mouseItem setIdentifier:@"swp_mouse_item"];
//        [menu addItem:mouseItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        AboutView* text = [[AboutView alloc] initWithFrame:NSMakeRect(0, 0, 320, 100)]; //arbitrary height

        NSMenuItem* aboutTextItem = [[NSMenuItem alloc] initWithTitle:@"Text" action:NULL keyEquivalent:@""];
        aboutTextItem.view = text;
        
        
        [aboutTextItem setIdentifier:ABOUTTEXT_ITEM_KEY];
        [menu addItem:aboutTextItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem* donateItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ Website", null), appName]
                                                 action:@selector(donate:)
                                          keyEquivalent:NSLocalizedString(@"DONATE_ABBR", null)];

        [donateItem setIdentifier:DONATE_ITEM_KEY];

        [menu addItem:donateItem];

        NSMenuItem* websiteItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ Website", null), appName]
                                                             action:@selector(website:)
                                                      keyEquivalent:NSLocalizedString(@"WEBSITE_ABBR", null)];

        [websiteItem setIdentifier:WEBSITE_ITEM_KEY];
        [menu addItem:websiteItem];
        
        NSMenuItem* accessibilityItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Accessibility Whitelist", null)
                                                                   action:@selector(accessibility:)
                                                            keyEquivalent:NSLocalizedString(@"ACCESSIBILITY_ABBR", null)];
        
        [accessibilityItem setIdentifier:ACCESSIBILITY_ITEM_KEY];
        [menu addItem:accessibilityItem];

        [menu addItem:[NSMenuItem separatorItem]];

        NSMenuItem* quitItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", null)
                                                      action:@selector(quit:)
                                               keyEquivalent:NSLocalizedString(@"QUIT_ABBR", null)];
        quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        
        [quitItem setIdentifier:QUIT_ITEM_KEY];
        [menu addItem:quitItem];
        
        self.statusItem.menu = menu;
    }
    
    [self startTap:[[NSUserDefaults standardUserDefaults] boolForKey:@"SBFWasEnabled"]];
    
    [self updateMenuMode];
    [self refreshSettings];
}

-(AboutView *) aboutView {
    NSMenuItem *aboutTextItem = [self menuByIdentifier:ABOUTTEXT_ITEM_KEY];
    if (aboutTextItem != NULL)
        return (AboutView *) aboutTextItem.view;
    return (AboutView *) NULL;
}

-(void) updateMenuMode {
    [self updateMenuMode:YES];
}

-(void) updateMenuMode:(BOOL)active {
    //NSDictionary* options = @{ (__bridge id)kAXTrustedCheckOptionPrompt: @(active ? YES : NO) };
    //BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
    BOOL accessibilityEnabled = YES; //is accessibility even required? seems to work fine without it
    
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
    self.menuMode = arc4random_uniform(3);
}

- (NSMenuItem*) menuByIdentifier:(NSString*)identifier {
    if (self.statusItem != NULL && self.statusItem.menu != NULL) {
        for (NSMenuItem* menuItem in self.statusItem.menu.itemArray) {
            if ([[menuItem identifier] isEqualToString:identifier]) {
                return menuItem;
            }
        }
    }
    return NULL;
}

-(void) refreshSettings {
    [self menuByIdentifier:ENABLE_ITEM_KEY].state = self.tap != NULL && CGEventTapIsEnabled(self.tap);
    [self menuByIdentifier:MODE_ITEM_KEY].state = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"];
    [self menuByIdentifier:SWAP_ITEM_KEY].state = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFSwapButtons"];
    
    switch (self.menuMode) {
        case MenuModeAccessibility:
            [self menuByIdentifier:ENABLE_ITEM_KEY].enabled = NO;
            [self menuByIdentifier:MODE_ITEM_KEY].enabled = NO;
            [self menuByIdentifier:SWAP_ITEM_KEY].enabled = NO;
            [self menuByIdentifier:DONATE_ITEM_KEY].hidden = YES;
            [self menuByIdentifier:WEBSITE_ITEM_KEY].hidden = NO;
            [self menuByIdentifier:ACCESSIBILITY_ITEM_KEY].hidden = NO;
            break;
        case MenuModeDonation:
            [self menuByIdentifier:ENABLE_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:MODE_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:SWAP_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:DONATE_ITEM_KEY].hidden = NO;
            [self menuByIdentifier:WEBSITE_ITEM_KEY].hidden = YES;
            [self menuByIdentifier:ACCESSIBILITY_ITEM_KEY].hidden = YES;
            break;
        case MenuModeNormal:
            [self menuByIdentifier:ENABLE_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:MODE_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:SWAP_ITEM_KEY].enabled = YES;
            [self menuByIdentifier:DONATE_ITEM_KEY].hidden = YES;
            [self menuByIdentifier:WEBSITE_ITEM_KEY].hidden = NO;
            [self menuByIdentifier:ACCESSIBILITY_ITEM_KEY].hidden = YES;
            break;
    }
    
    AboutView *view = (AboutView *) [self menuByIdentifier:ABOUTTEXT_ITEM_KEY].view;
    [view layoutSubtreeIfNeeded]; //used to auto-calculate the text view size
    view.frame = NSMakeRect(0, 0, view.bounds.size.width, view.text.frame.size.height);
    
    if (self.statusItem.button != nil) {
        if (self.tap != NULL && CGEventTapIsEnabled(self.tap)) {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuIcon"];
        }
        else {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuIconDisabled"];
        }
    }
}

-(void) startTap:(BOOL)start {
    if (start) {
        if (self.tap == NULL) {
            self.tap = CGEventTapCreate(kCGHIDEventTap,
                                        kCGHeadInsertEventTap,
                                        kCGEventTapOptionDefault,
                                        CGEventMaskBit(kCGEventOtherMouseUp) |
                                        CGEventMaskBit(kCGEventOtherMouseDown),
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
    
    bool enabled = self.tap != NULL && CGEventTapIsEnabled(self.tap);

    NSLog(@"The functionality will be %s", enabled ? "enabled" : "disabled");
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"SBFWasEnabled"];
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: NSLocalizedString(@"DONATION_WEBSITE", null)]];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SBFDonated"];
    
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) website:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: NSLocalizedString(@"WEBSITE", null)]];
}

-(void) accessibility:(id)sender {
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) quit:(id)sender {
    [NSApp terminate:self];
}

- (void)menuWillOpen:(NSMenu *)menu {
    // TODO: theoretically, accessibility can be disabled while the menu is opened, but this is unlikely
    [self updateMenuMode:NO];
    [self refreshSettings];
}

@end

@implementation AboutView

static MGThemingHelper *helper;

-(Boolean) isDarkMode {
    if (helper == NULL) {
        helper = [MGThemingHelper fromString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]];
    }
    
    return [helper getCurrent] == Dark;
}

-(CGFloat) margin {
    return 17;
}

-(void)setMenuMode:(MenuMode)menuMode {
    _menuMode = menuMode;
    
    CGFloat baseColor = [self isDarkMode] ? 200.f : 100.f;
    
    NSFont* font = [NSFont menuFontOfSize:13];
    
    NSFontDescriptor* boldFontDesc = [NSFontDescriptor fontDescriptorWithFontAttributes:
                                      @{
                                        NSFontFamilyAttribute: font.familyName,
                                        NSFontFaceAttribute: @"Bold"
                                        }
                                      ];
    
    NSFont* boldFont = [NSFont fontWithDescriptor:boldFontDesc size:font.pointSize];
    
    boldFont = !boldFont ? font : boldFont;
    
    CGFloat boldHue = baseColor;
    
    NSColor* normalColor = [NSColor colorWithRed:boldHue/255.0 green:boldHue/255.0 blue:boldHue/255.0 alpha:1];
    NSColor* alertColor = [NSColor colorWithRed:229.f/255.f green:57.f/255.f blue:53.f/255.f alpha:1.f];
    NSColor* boldColor = [NSColor colorWithRed:boldHue/255.0 green:boldHue/255.0 blue:boldHue/255.0 alpha:1];
    
    NSMutableDictionary* attributes = [NSMutableDictionary new];
    NSMutableDictionary* boldAttributes = [NSMutableDictionary new];
    
    [attributes setObject:font forKey:NSFontAttributeName];
    [attributes setObject:normalColor forKey:NSForegroundColorAttributeName];
    
    [boldAttributes setObject:boldFont forKey:NSFontAttributeName];
    [boldAttributes setObject:boldColor forKey:NSForegroundColorAttributeName];
    
    NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString* appDescription = [NSString stringWithFormat:@"%@ %@", appName, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    NSString* appCopyright = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"NSHumanReadableCopyright"];
    
    NSString* localizedString = nil;
    
    switch (menuMode) {
        case MenuModeAccessibility: {
            localizedString = NSLocalizedString(@"MenuModeAccessibilityAboutViewText", "");
            [attributes setObject:alertColor forKey:NSForegroundColorAttributeName];
            [boldAttributes setObject:alertColor forKey:NSForegroundColorAttributeName];
        } break;
        case MenuModeDonation: {
            localizedString = NSLocalizedString(@"MenuModeDonationAboutViewText", "");
        } break;
        case MenuModeNormal: {
            localizedString = NSLocalizedString(@"MenuModeNormalAboutViewText", "");
        } break;
    }
    
    if (localizedString != nil) {
        
        NSString* text = [NSString stringWithFormat:localizedString, appDescription];
        
        text = [text stringByAppendingFormat:@"\n%@", appCopyright];
        
        NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
        [string addAttributes:boldAttributes range:[text rangeOfString:appDescription]];
        
        [self.text.textStorage setAttributedString:string];
    }
    
    [self setNeedsLayout:YES];
}

-(instancetype)initWithFrame:(NSRect)frameRect {
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

-(void)layout {
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
