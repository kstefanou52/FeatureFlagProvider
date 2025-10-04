# FeatureFlagProvider

A tiny macro-powered library that generates type-safe feature flags and a ready-to-use SwiftUI interface to toggle them at runtime.

- Generate an enum from a dictionary of default flags.
- Present a built-in UI to view, toggle, and reset flags.
- Keep your code clean: declare once, use everywhere.

## Requirements
- Xcode 15.3+ (Swift macros)
- iOS 17+, macOS 14+, watchOS 10+, tvOS 17+ (adjust as needed for your project)

## Installation (Swift Package Manager)
1. In Xcode: File > Add Packages…
2. Enter the repository URL for this package.
3. Add the library to your app target.

Alternatively, in `Package.swift`:
```swift
.package(url: "https://github.com/your-org/FeatureFlagProvider.git", from: "1.0.0")
