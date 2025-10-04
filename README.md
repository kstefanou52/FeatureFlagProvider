# FeatureFlagProvider

A tiny macro-powered library that generates type-safe feature flags and a ready-to-use SwiftUI interface to toggle them at runtime.

- Generate an enum from a dictionary of default flags.
- Present a built-in UI to view, toggle, and reset flags.
- Keep your code clean: declare once, use everywhere.

## Requirements
- Xcode 16.2 (Swift 6.2, compatible with swift-syntax 602.x)
- iOS 16+
- macOS 13+
- tvOS 13+
- watchOS 6+ and macCatalyst 13+

This package targets Swift 6.2. If your app uses a different Xcode/Swift version, adjust swift-tools-version and pin swift-syntax to the matching major version (e.g., 510.x for Swift 5.10, 509.x for Swift 5.9), then re-resolve packages.

## Installation (Swift Package Manager)
1. In Xcode: File > Add Packages…
2. Enter the repository URL for this package.
3. Add the library to your app target.

Alternatively, in `Package.swift`:
```swift
.package(url: "https://github.com/your-org/FeatureFlagProvider.git", from: "1.0.0")


