//
//  AppDelegate.m
//  SideButtonFixer
//
//  Created by Alexei Baboulevitch on 2017-6-6.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

#import "AppDelegate.h"
#import "TouchEvents.h"

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

static CGEventRef SBFMouseCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    int64_t number = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    BOOL down = (CGEventGetType(event) == kCGEventOtherMouseDown);
    BOOL mouseDown = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"];
    
    if (number == 3) {
        if ((mouseDown && down) || (!mouseDown && !down)) {
            SBFFakeSwipe(kTLInfoSwipeLeft);
        }
        
        return NULL;
    }
    else if (number == 4) {
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
    AboutView* view = (AboutView*)self.statusItem.menu.itemArray[3].view;
    view.menuMode = menuMode;
    [self refreshSettings];
}

-(void) applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
                                                              @"SBFWasEnabled": @YES,
                                                              @"SBFMouseDown": @YES,
                                                              @"SBFDonated": @NO,
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
        
        if (self.statusItem.button != nil) {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuIcon"];
        }
    }
    
    // create menu
    {
        NSMenu* menu = [NSMenu new];
        
        menu.autoenablesItems = NO;
        menu.delegate = self;
        
        NSMenuItem* enabledItem = [[NSMenuItem alloc] initWithTitle:@"Enabled" action:@selector(enabledToggle:) keyEquivalent:@"e"];
        [menu addItem:enabledItem];
        
        NSMenuItem* modeItem = [[NSMenuItem alloc] initWithTitle:@"Trigger on Mouse Down" action:@selector(mouseDownToggle:) keyEquivalent:@""];
        modeItem.state = NSControlStateValueOn;
        [menu addItem:modeItem];
        
        //[menu addItem:[NSMenuItem separatorItem]];
        //NSMenuItem* mouseItem = [[NSMenuItem alloc] initWithTitle:@"G403" action:@selector(act:) keyEquivalent:@""];
        //mouseItem.state = NSControlStateValueOn;
        //[menu addItem:mouseItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        AboutView* text = [[AboutView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)]; //arbitrary frame
        NSMenuItem* aboutText = [[NSMenuItem alloc] initWithTitle:@"Title" action:NULL keyEquivalent:@""];
        aboutText.view = text;
        [menu addItem:aboutText];
        
        NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Donation Webpage" action:@selector(donate:) keyEquivalent:@""]];
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ Website", appName] action:@selector(website:) keyEquivalent:@""]];
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Open Accessibility Whitelist" action:@selector(accessibility:) keyEquivalent:@""]];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem* quit = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
        quit.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        [menu addItem:quit];
        
        self.statusItem.menu = menu;
    }
    
    [self updateMenuMode];
    [self refreshSettings];
    
    [self startTap:[[NSUserDefaults standardUserDefaults] boolForKey:@"SBFWasEnabled"]];
}

-(void) updateMenuMode {
    [self updateMenuMode:YES];
}

-(void) updateMenuMode:(BOOL)active {
    //NSDictionary* options = @{ (__bridge id)kAXTrustedCheckOptionPrompt: @(active ? YES : NO) };
    //BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
    BOOL accessibilityEnabled = YES;
    
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
}

-(void) refreshSettings {
    self.statusItem.menu.itemArray[0].state = self.tap != NULL && CGEventTapIsEnabled(self.tap);
    self.statusItem.menu.itemArray[1].state = [[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"];
    
    switch (self.menuMode) {
        case MenuModeAccessibility:
            self.statusItem.menu.itemArray[0].enabled = NO;
            self.statusItem.menu.itemArray[1].enabled = NO;
            self.statusItem.menu.itemArray[4].hidden = YES;
            self.statusItem.menu.itemArray[5].hidden = YES;
            self.statusItem.menu.itemArray[6].hidden = NO;
            break;
        case MenuModeDonation:
            self.statusItem.menu.itemArray[0].enabled = YES;
            self.statusItem.menu.itemArray[1].enabled = YES;
            self.statusItem.menu.itemArray[4].hidden = NO;
            self.statusItem.menu.itemArray[5].hidden = NO;
            self.statusItem.menu.itemArray[6].hidden = YES;
            break;
        case MenuModeNormal:
            self.statusItem.menu.itemArray[0].enabled = YES;
            self.statusItem.menu.itemArray[1].enabled = YES;
            self.statusItem.menu.itemArray[4].hidden = YES;
            self.statusItem.menu.itemArray[5].hidden = NO;
            self.statusItem.menu.itemArray[6].hidden = YES;
            break;
    }
    
    AboutView* view = (AboutView*)self.statusItem.menu.itemArray[3].view;
    NSRect rect = [view.text.string boundingRectWithSize:NSMakeSize(350 - [view margin], INFINITY) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: view.text.font }];
    view.frame = NSMakeRect(0, 0, rect.size.width + [view margin], rect.size.height + 8);
    [view layoutSubtreeIfNeeded];
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

-(void) enabledToggle:(id)sender {
    [self startTap:self.tap == NULL];
    [self refreshSettings];
}

-(void) mouseDownToggle:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:@"SBFMouseDown"] forKey:@"SBFMouseDown"];
    [self refreshSettings];
}

-(void) donate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://www.google.com"]];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SBFDonated"];
    
    [self updateMenuMode];
    [self refreshSettings];
}

-(void) website:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://beta-blog.archagon.net"]];
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

-(CGFloat) margin {
    return 16;
}

-(void)setMenuMode:(MenuMode)menuMode {
    _menuMode = menuMode;
    
    CGFloat color = 120;
    NSFont* font = [NSFont menuFontOfSize:14];
    
    NSFontDescriptor* boldFontDesc = [NSFontDescriptor fontDescriptorWithFontAttributes:@{
                                                                                          NSFontFamilyAttribute: font.familyName,
                                                                                          NSFontFaceAttribute: @"Bold"
                                                                                          }];
    NSFont* boldFont = [NSFont fontWithDescriptor:boldFontDesc size:font.pointSize];
    if (!boldFont) { boldFont = font; }
    
    CGFloat boldHue = color;
    NSColor* boldColor = [NSColor colorWithRed:boldHue/255.0 green:boldHue/255.0 blue:160/255.0 alpha:1];
    
    NSDictionary* attributes = @{
                                 NSFontAttributeName: font,
                                 NSForegroundColorAttributeName: [NSColor colorWithRed:color/255.0 green:color/255.0 blue:160/255.0 alpha:1]
                                 };
    
    NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString* appDescription = [NSString stringWithFormat:@"%@ %@", appName, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    
    switch (menuMode) {
        case MenuModeAccessibility: {
            NSString* text = [NSString stringWithFormat:@"Uh-oh! It looks like %@ is not whitelisted in the Accessibility panel of your Security & Privacy System Preferences. The app needs this permission to process global mouse events. (Otherwise, it would have to run as root!) Please open the Accessibility panel below and add the app to the whitelist.", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string addAttribute:NSForegroundColorAttributeName value:boldColor range:[text rangeOfString:appDescription]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
        case MenuModeDonation: {
            NSString* text = [NSString stringWithFormat:@"Thank you for using %@! This app is free because I consider it a missing core feature of the OS. However, if you have the time and inclination to leave a small donation, I would be incredibly thankful. 😊", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string addAttribute:NSForegroundColorAttributeName value:boldColor range:[text rangeOfString:appDescription]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
        case MenuModeNormal: {
            NSString* text = [NSString stringWithFormat:@"Thank you for considering a donation to %@! Hope you have a great and productive day. 😊", appDescription];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
            [string addAttribute:NSFontAttributeName value:boldFont range:[text rangeOfString:appDescription]];
            [string addAttribute:NSForegroundColorAttributeName value:boldColor range:[text rangeOfString:appDescription]];
            
            [self.text.textStorage setAttributedString:string];
        } break;
    }
    
    [self setNeedsLayout:YES];
}

-(instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    
    if (self) {
        self.text = [NSTextView new];
        self.text.backgroundColor = NSColor.clearColor;
        [self.text setEditable:NO];
        [self.text setSelectable:NO];
        [self addSubview:self.text];
        self.text.frame = self.bounds;
        
        self.menuMode = MenuModeNormal;
    }
    
    return self;
}

-(void)layout {
    [super layout];
    
    CGFloat margin = [self margin];
    self.text.frame = NSMakeRect(margin, 0, self.bounds.size.width - margin, self.bounds.size.height);
}

@end
