# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-05-08

### Changed
- **BREAKING**: Updated minimum macOS deployment target from 10.10/10.12 to **macOS 11.0 (Big Sur)**
  - This ensures compatibility with current and future versions of macOS
  - Removes support for older macOS versions (10.10, 10.11, 10.12, 10.13, 10.14, 10.15)
- Updated Xcode project configuration for modern build standards
- Updated build settings for compatibility with current Xcode versions
- Updated copyright year to 2018-2026

### Added
- Added USB device security entitlements for proper input monitoring
- Added this CHANGELOG file
- Added .gitignore for Xcode build artifacts

### Fixed
- Project now builds successfully with modern Xcode versions
- Resolved future macOS compatibility issues

### Deprecated
- Support for macOS versions prior to 11.0 is no longer provided

## [1.0.6] - 2018

### Original Release
- Initial public release
- Support for macOS 10.10+
- Mouse side button remapping to 3-finger swipes
