//
//  AppDelegate.swift
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

import Cocoa

// CGEventTap C constants are not exported to Swift; define using raw values.
// See CGEventTypes.h: cgHIDEventTap=0, cgHeadInsertEventTap=0, cgEventTapOptionDefault=0
// Force-unwrap is safe: these raw values are defined in CGEventTypes.h.
private let cgHIDEventTap           = CGEventTapLocation(rawValue: 0)!
private let cgHeadInsertEventTap    = CGEventTapPlacement(rawValue: 0)!
private let cgEventTapOptionDefault = CGEventTapOptions(rawValue: 0)!

// MARK: - Module-level globals for C callback
//
// Plain C enums (without NS_ENUM) import as UInt32 typealiases in Swift,
// and their constants import as plain Int. We cast to UInt32 at call sites.

private var swipeInfo: [UInt32: [NSDictionary]] = [:]
private var nullArray: NSArray = []

// MARK: - C-compatible free functions

private func fakeSwipe(_ direction: UInt32) {
    guard let events = swipeInfo[direction] else { return }
    // TouchEvents.h is not in a CF-audited region, so Swift imports the return
    // as Unmanaged<CGEvent>?. takeRetainedValue() transfers ownership to ARC.
    let e1 = tl_CGEventCreateFromGesture(events[0] as CFDictionary, nullArray as CFArray)?.takeRetainedValue()
    let e2 = tl_CGEventCreateFromGesture(events[1] as CFDictionary, nullArray as CFArray)?.takeRetainedValue()
    e1?.post(tap: cgHIDEventTap)
    e2?.post(tap: cgHIDEventTap)
}

// Must be a free function (not a closure) to serve as a C function pointer.
private func mouseCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent?,
    _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let event = event else { return nil }

    let number = event.getIntegerValueField(.mouseEventButtonNumber)
    let isDown = (type == .otherMouseDown)

    let defaults = UserDefaults.standard
    let triggerOnDown = defaults.bool(forKey: "SBFMouseDown")
    let swapButtons   = defaults.bool(forKey: "SBFSwapButtons")

    let backButton: Int64    = swapButtons ? 4 : 3
    let forwardButton: Int64 = swapButtons ? 3 : 4
    let shouldTrigger = (triggerOnDown && isDown) || (!triggerOnDown && !isDown)

    if number == backButton {
        if shouldTrigger { fakeSwipe(UInt32(kTLInfoSwipeLeft)) }
        return nil
    } else if number == forwardButton {
        if shouldTrigger { fakeSwipe(UInt32(kTLInfoSwipeRight)) }
        return nil
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Enums

private enum MenuMode {
    case accessibility, donation, normal
}

private enum MenuItem: Int {
    case enabled = 0
    case enabledSeparator
    case triggerOnMouseDown
    case swapButtons
    case optionsSeparator
    case startAtLogin
    case startupHide
    case startupHideInfo
    case startupSeparator
    case aboutText
    case aboutSeparator
    case donate
    case website
    case accessibility
    case linkSeparator
    case quit
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var tap: CFMachPort?

    private var menuMode: MenuMode = .normal {
        didSet {
            (statusItem.menu?.items[MenuItem.aboutText.rawValue].view as? AboutView)?.menuMode = menuMode
            refreshSettings()
        }
    }

    // MARK: - NSApplicationDelegate

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if #available(macOS 10.12, *) {
            statusItem.isVisible = true
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "SBFWasEnabled":  true,
            "SBFMouseDown":   true,
            "SBFDonated":     false,
            "SBFSwapButtons": false,
        ])

        setupGlobals()
        setupStatusItem()
        buildMenu()

        startTap(UserDefaults.standard.bool(forKey: "SBFWasEnabled"))
        updateMenuMode()
        refreshSettings()
    }

    // MARK: - Setup

    private func setupGlobals() {
        nullArray = []
        // kTLInfoSwipeUp/Down/Left/Right are plain C enum constants (Int in Swift); cast to UInt32.
        let directions = [kTLInfoSwipeUp, kTLInfoSwipeDown, kTLInfoSwipeLeft, kTLInfoSwipeRight].map { UInt32($0) }
        for dir in directions {
            let phase1: NSDictionary = [
                kTLInfoKeyGestureSubtype: NSNumber(value: UInt32(kTLInfoSubtypeSwipe)),
                kTLInfoKeyGesturePhase:   NSNumber(value: UInt32(1)),
            ]
            let phase2: NSDictionary = [
                kTLInfoKeyGestureSubtype:  NSNumber(value: UInt32(kTLInfoSubtypeSwipe)),
                kTLInfoKeySwipeDirection:  NSNumber(value: dir),
                kTLInfoKeyGesturePhase:    NSNumber(value: UInt32(4)),
            ]
            swipeInfo[dir] = [phase1, phase2]
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(enabledToggle(_:)), keyEquivalent: "e")
        menu.addItem(enabledItem)
        assert(menu.items.count - 1 == MenuItem.enabled.rawValue)

        menu.addItem(.separator())
        assert(menu.items.count - 1 == MenuItem.enabledSeparator.rawValue)

        let modeItem = NSMenuItem(title: "Trigger on Mouse Down", action: #selector(mouseDownToggle(_:)), keyEquivalent: "")
        modeItem.state = .on
        menu.addItem(modeItem)
        assert(menu.items.count - 1 == MenuItem.triggerOnMouseDown.rawValue)

        let swapItem = NSMenuItem(title: "Swap Buttons", action: #selector(swapToggle(_:)), keyEquivalent: "")
        swapItem.state = .off
        menu.addItem(swapItem)
        assert(menu.items.count - 1 == MenuItem.swapButtons.rawValue)

        menu.addItem(.separator())
        assert(menu.items.count - 1 == MenuItem.optionsSeparator.rawValue)

        let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(startAtLoginToggle(_:)), keyEquivalent: "")
        menu.addItem(startAtLoginItem)
        assert(menu.items.count - 1 == MenuItem.startAtLogin.rawValue)

        let hideItem = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(hideMenubarItem(_:)), keyEquivalent: "")
        menu.addItem(hideItem)
        assert(menu.items.count - 1 == MenuItem.startupHide.rawValue)

        let hideInfoItem = NSMenuItem(title: "Relaunch application to show again", action: nil, keyEquivalent: "")
        hideInfoItem.isEnabled = false
        menu.addItem(hideInfoItem)
        assert(menu.items.count - 1 == MenuItem.startupHideInfo.rawValue)

        menu.addItem(.separator())
        assert(menu.items.count - 1 == MenuItem.startupSeparator.rawValue)

        let aboutView = AboutView(frame: NSRect(x: 0, y: 0, width: 320, height: 100))
        let aboutItem = NSMenuItem(title: "Text", action: nil, keyEquivalent: "")
        aboutItem.view = aboutView
        menu.addItem(aboutItem)
        assert(menu.items.count - 1 == MenuItem.aboutText.rawValue)

        menu.addItem(.separator())
        assert(menu.items.count - 1 == MenuItem.aboutSeparator.rawValue)

        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        menu.addItem(NSMenuItem(title: "\(appName) Website", action: #selector(donate(_:)), keyEquivalent: ""))
        assert(menu.items.count - 1 == MenuItem.donate.rawValue)

        menu.addItem(NSMenuItem(title: "\(appName) Website", action: #selector(website(_:)), keyEquivalent: ""))
        assert(menu.items.count - 1 == MenuItem.website.rawValue)

        menu.addItem(NSMenuItem(title: "Open Accessibility Whitelist", action: #selector(accessibility(_:)), keyEquivalent: ""))
        assert(menu.items.count - 1 == MenuItem.accessibility.rawValue)

        menu.addItem(.separator())
        assert(menu.items.count - 1 == MenuItem.linkSeparator.rawValue)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
        assert(menu.items.count - 1 == MenuItem.quit.rawValue)

        statusItem.menu = menu
    }

    // MARK: - Event tap

    private func startTap(_ start: Bool) {
        if start {
            guard tap == nil else { return }
            let mask = CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
                     | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            tap = CGEvent.tapCreate(tap: cgHIDEventTap, place: cgHeadInsertEventTap, options: cgEventTapOptionDefault,
                                    eventsOfInterest: mask, callback: mouseCallback, userInfo: nil)
            if let tap {
                if let source = CFMachPortCreateRunLoopSource(nil, tap, 0) {
                    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                }
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        } else {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
                // CFMachPort is ARC-managed; no CFRelease needed.
            }
            tap = nil
        }
        let enabled = tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        UserDefaults.standard.set(enabled, forKey: "SBFWasEnabled")
    }

    // MARK: - Menu mode

    private func updateMenuMode(active: Bool = true) {
        // TODO: this actually returns YES if SSB is deleted (not disabled) from Accessibility
        // kAXTrustedCheckOptionPrompt imports as Unmanaged<CFString>; unwrap before use as dict key.
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: active] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if accessibilityEnabled {
            menuMode = UserDefaults.standard.bool(forKey: "SBFDonated") ? .normal : .donation
        } else {
            menuMode = .accessibility
        }
    }

    private func refreshSettings() {
        guard let menu = statusItem.menu else { return }

        let tapEnabled = tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        menu.items[MenuItem.enabled.rawValue].state              = tapEnabled ? .on : .off
        menu.items[MenuItem.triggerOnMouseDown.rawValue].state   = UserDefaults.standard.bool(forKey: "SBFMouseDown") ? .on : .off
        menu.items[MenuItem.swapButtons.rawValue].state          = UserDefaults.standard.bool(forKey: "SBFSwapButtons") ? .on : .off
        menu.items[MenuItem.startAtLogin.rawValue].state         = isStartAtLoginEnabled ? .on : .off

        switch menuMode {
        case .accessibility:
            menu.items[MenuItem.enabled.rawValue].isEnabled             = false
            menu.items[MenuItem.triggerOnMouseDown.rawValue].isEnabled  = false
            menu.items[MenuItem.swapButtons.rawValue].isEnabled         = false
            menu.items[MenuItem.donate.rawValue].isHidden               = true
            menu.items[MenuItem.website.rawValue].isHidden              = false
            menu.items[MenuItem.accessibility.rawValue].isHidden        = false
        case .donation:
            menu.items[MenuItem.enabled.rawValue].isEnabled             = true
            menu.items[MenuItem.triggerOnMouseDown.rawValue].isEnabled  = true
            menu.items[MenuItem.swapButtons.rawValue].isEnabled         = true
            menu.items[MenuItem.donate.rawValue].isHidden               = false
            menu.items[MenuItem.website.rawValue].isHidden              = true
            menu.items[MenuItem.accessibility.rawValue].isHidden        = true
        case .normal:
            menu.items[MenuItem.enabled.rawValue].isEnabled             = true
            menu.items[MenuItem.triggerOnMouseDown.rawValue].isEnabled  = true
            menu.items[MenuItem.swapButtons.rawValue].isEnabled         = true
            menu.items[MenuItem.donate.rawValue].isHidden               = true
            menu.items[MenuItem.website.rawValue].isHidden              = false
            menu.items[MenuItem.accessibility.rawValue].isHidden        = true
        }

        if let aboutView = menu.items[MenuItem.aboutText.rawValue].view as? AboutView {
            aboutView.layoutSubtreeIfNeeded()
            aboutView.frame = NSRect(x: 0, y: 0, width: aboutView.bounds.width, height: aboutView.text.frame.height)
        }

        if #available(macOS 10.12, *) {
            menu.items[MenuItem.startupHide.rawValue].isHidden     = false
            menu.items[MenuItem.startupHideInfo.rawValue].isHidden = false
        } else {
            menu.items[MenuItem.startupHide.rawValue].isHidden     = true
            menu.items[MenuItem.startupHideInfo.rawValue].isHidden = true
        }

        if let button = statusItem.button {
            button.image = tapEnabled
                ? NSImage(named: "MenuIcon")
                : NSImage(named: "MenuIconDisabled")
        }
    }

    // MARK: - Actions

    @objc private func enabledToggle(_ sender: Any) {
        startTap(tap == nil)
        refreshSettings()
    }

    @objc private func mouseDownToggle(_ sender: Any) {
        let key = "SBFMouseDown"
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
        refreshSettings()
    }

    @objc private func swapToggle(_ sender: Any) {
        let key = "SBFSwapButtons"
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
        refreshSettings()
    }

    @objc private func donate(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://sensible-side-buttons.archagon.net#donations")!)
        UserDefaults.standard.set(true, forKey: "SBFDonated")
        updateMenuMode()
        refreshSettings()
    }

    @objc private func website(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://sensible-side-buttons.archagon.net")!)
    }

    @objc private func accessibility(_ sender: Any) {
        updateMenuMode()
        refreshSettings()
    }

    @objc private func hideMenubarItem(_ sender: Any) {
        if #available(macOS 10.12, *) {
            statusItem.isVisible = false
        }
    }

    @objc private func quit(_ sender: Any) {
        NSApp.terminate(self)
    }

    // MARK: - Start at Login

    private var launchAgentPlistPath: String {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
        return (dir as NSString).appendingPathComponent("\(bundleId).plist")
    }

    private var isStartAtLoginEnabled: Bool {
        return FileManager.default.fileExists(atPath: launchAgentPlistPath)
    }

    private func setStartAtLogin(_ enabled: Bool) {
        let path = launchAgentPlistPath
        if enabled {
            let plist: NSDictionary = [
                "Label":     Bundle.main.bundleIdentifier ?? "",
                "Program":   Bundle.main.executablePath ?? "",
                "RunAtLoad": true,
            ]
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            plist.write(toFile: path, atomically: true)
        } else {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @objc private func startAtLoginToggle(_ sender: Any) {
        setStartAtLogin(!isStartAtLoginEnabled)
        refreshSettings()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // TODO: theoretically, accessibility can be disabled while the menu is opened, but this is unlikely
        updateMenuMode(active: false)
        refreshSettings()
    }
}

// MARK: - AboutView

private class AboutView: NSView {

    let text = NSTextView()
    var menuMode: MenuMode = .normal { didSet { updateText() } }

    private var margin: CGFloat { 17 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        text.backgroundColor = .clear
        text.isEditable = false
        text.isSelectable = false
        addSubview(text)
        updateText()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func updateText() {
        let font = NSFont.menuFont(ofSize: 13)

        let boldDescriptor = font.fontDescriptor.withSymbolicTraits(.bold)
        let boldFont = NSFont(descriptor: boldDescriptor, size: font.pointSize) ?? font

        let regularColor = NSColor.secondaryLabelColor
        let alertColor   = NSColor.systemRed

        let regularAttrs: [NSAttributedString.Key: Any]     = [.font: font,                        .foregroundColor: regularColor]
        let alertAttrs:   [NSAttributedString.Key: Any]     = [.font: font,                        .foregroundColor: alertColor]
        let smallReturnAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 3)]

        let appName   = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        let version   = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let appDesc   = "\(appName) \(version)"
        let copyright = "Copyright © 2018 Alexei Baboulevitch."

        let result = NSMutableAttributedString()

        switch menuMode {
        case .accessibility:
            let body = "Uh-oh! It looks like \(appDesc) is not whitelisted in the Accessibility panel of your Security & Privacy System Preferences. This app needs to be on the Accessibility whitelist in order to process global mouse events. Please open the Accessibility panel below and add the app to the whitelist."
            let s = NSMutableAttributedString(string: body, attributes: alertAttrs)
            if let r = body.range(of: appDesc) { s.addAttribute(.font, value: boldFont, range: NSRange(r, in: body)) }
            result.append(s)

        case .donation:
            let body = "Thanks for using \(appDesc)!\nIf you find this utility useful, please consider making a purchase through the Amazon affiliate link on the website below. It won't cost you an extra cent! 😊"
            let s = NSMutableAttributedString(string: body, attributes: regularAttrs)
            if let r = body.range(of: appDesc) { s.addAttribute(.font, value: boldFont, range: NSRange(r, in: body)) }
            result.append(s)

        case .normal:
            let body = "Thanks for using \(appDesc)!"
            let s = NSMutableAttributedString(string: body, attributes: regularAttrs)
            if let r = body.range(of: appDesc) { s.addAttribute(.font, value: boldFont, range: NSRange(r, in: body)) }
            result.append(s)
        }

        result.append(NSAttributedString(string: "\n", attributes: regularAttrs))
        result.append(NSAttributedString(string: "\n", attributes: smallReturnAttrs))
        result.append(NSAttributedString(string: copyright, attributes: regularAttrs))

        text.textStorage?.setAttributedString(result)
        if #available(macOS 10.12, *) { needsLayout = true }
    }

    override func layout() {
        super.layout()
        let arbitraryHeight: CGFloat = 100
        text.frame = NSRect(x: margin, y: 0, width: bounds.width - margin, height: arbitraryHeight)
        text.sizeToFit()
        text.frame = NSRect(x: text.frame.origin.x,
                            y: bounds.height - text.frame.height,
                            width: text.frame.width,
                            height: text.frame.height)
    }
}
