<img src="icon.png" width=150 />

# Sensible Side Buttons

macOS mostly ignores the M4/M5 mouse buttons, commonly used for navigation. Third-party apps can bind them to ⌘+[ and ⌘+], but this only works in a small number of apps and feels janky. With this tool, your side buttons will simulate 3-finger swipes, allowing you to navigate almost any window with a history. As seen in the Logitech MX Master!

Extensive information on this tweak can be found here: http://sensible-side-buttons.archagon.net

## System Requirements

- **macOS 11.0 (Big Sur)** or later
- Intel or Apple Silicon Mac

> **Note**: Version 1.1.0+ requires macOS 11.0 or later. For older macOS versions, use version 1.0.6.

## Installation

### Running at Startup

To ensure SensibleSideButtons opens whenever you start your computer:

1. Go to System Preferences
1. Click Users & Groups
1. Click your username in the left panel
1. Click Login Items at the top
1. Click the plus button at the bottom
1. Go to wherever you put the app (probably your Applications folder) and double-click it

### Accessibility Permissions

For the app to work properly, you'll need to grant it Accessibility permissions:

1. Open System Preferences
2. Go to Security & Privacy
3. Click the Accessibility tab
4. Add SensibleSideButtons to the list

## Building from Source

### Requirements
- macOS 11.0 or later
- Xcode 12.0 or later
- Apple Developer account (optional - for code signing and notarization only)

### Build Steps

1. Clone the repository
2. Open `SwipeSimulator.xcodeproj` in Xcode
3. Select the "SideButtonFixer" scheme
4. Press Cmd+B to build

## Recent Changes (v1.1.0)

This release modernizes the codebase for current and future macOS versions:

- ✅ Updated minimum deployment target to macOS 11.0 (Big Sur)
- ✅ Updated Xcode project configuration for modern build standards
- ✅ Added proper entitlements for input monitoring
- ✅ Verified compatibility with current Xcode versions

See [CHANGELOG.md](CHANGELOG.md) for detailed changes.
