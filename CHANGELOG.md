# Changelog

## 2.0.0

Complete Swift rewrite and modernization of the codebase.

### Added
- SwiftUI app lifecycle (`@main` entry point)
- Graceful failure handling — if gesture synthesis fails, the button press passes through instead of being swallowed
- Menu bar icon flash on synthesis failure
- Periodic Accessibility (TCC) permission monitoring — disables gracefully if permission revoked
- Global hotkey ⌘⇧B to toggle menu bar icon visibility
- macOS version check — warns if running on an untested release
- Event tap re-enable backoff (prevents tight loop if system keeps disabling)
- Hardened runtime enabled
- Universal binary (arm64 + x86_64)
- GitHub Actions CI — automatic build and release on merge to master
- `NSSupportsAutomaticTermination` / `NSSupportsSuddenTermination` lifecycle declarations

### Changed
- Replaced Carbon `RegisterEventHotKey` with modern `NSEvent` monitors
- Menu item state tracking uses tags instead of fragile title-string lookups
- TCC permission polling interval reduced from 5s to 30s (saves battery)
- `SwipeDirection` is now a proper `RawRepresentable` enum
- Bundle identifier changed to `com.santoru.sensible-side-buttons`
- Copyright updated to 2018–2026

### Fixed
- `kAXTrustedCheckOptionPrompt` memory leak (`takeUnretainedValue` instead of `takeRetainedValue`)

### Removed
- Carbon.HIToolbox dependency

## 1.x

Original Objective-C implementation by [Archagon](https://sensible-side-buttons.archagon.net).
