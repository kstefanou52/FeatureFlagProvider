// The Swift Programming Language
// https://docs.swift.org/swift-book

@_exported import Foundation
@_exported import SwiftUI

/// The casing style used when converting flag keys into Swift enum cases.
///
/// Use `camelCase` to generate cases like `myFlag`, `pascalCase` for `MyFlag`,
/// or `verbatim` to keep the key as-is (useful if your keys are already valid identifiers).
public enum CaseStyle: Sendable {
    case camelCase
    case pascalCase
    case verbatim
}

/// Generates a type-safe feature flag enumeration from a dictionary of default values.
///
/// Expansion overview:
/// - Declares a public enum named by `enumName` with one case per key in `flags`.
/// - Case names are derived from the keys using `caseStyle`.
/// - Raw values typically preserve the original keys for display/debugging.
/// - The generated declarations are designed to work with the companion feature flag UI.
///
/// Parameters:
/// - flags: A dictionary of default values keyed by flag name.
/// - enumName: The name for the generated enum type (e.g. "AppFeature").
/// - caseStyle: How to transform keys into Swift enum cases.
///
/// Example:
/// ```swift
/// @GenerateFeatureFlags(
///     from: [
///         "newOnboarding": false,
///         "useFastAPI": true,
///         "Show Debug Menu": false
///     ],
///     enumName: "AppFeature",
///     caseStyle: .camelCase
/// )
/// ```
@freestanding(declaration, names: arbitrary)
public macro GenerateFeatureFlags(
    from flags: Dictionary<String, Bool>,
    enumName: String,
    caseStyle: CaseStyle
) = #externalMacro(module: "FeatureFlagProviderMacros", type: "GenerateFeatureFlagsMacro")

/// Generates a simple SwiftUI view named `FeatureFlagUI` that lists and toggles the flags
/// produced by `GenerateFeatureFlags` for the given enum name.
///
/// The generated UI includes:
/// - A list of toggles for each flag.
/// - A leading toolbar button to dismiss the view (xmark icon).
/// - A trailing toolbar button to reset all flags back to their default values (clockwise arrow icon).
///
/// Parameters:
/// - enumName: The name of the feature flag enum previously generated.
///
/// Usage:
/// ```swift
/// // Declarations (typically in a shared file):
/// @GenerateFeatureFlags(
///     from: ["newOnboarding": false, "useFastAPI": true],
///     enumName: "AppFeature",
///     caseStyle: .camelCase
/// )
///
/// @GenerateFeatureFlagsView(enumName: "AppFeature")
///
/// // Presentation (e.g., from a settings screen):
/// struct SettingsView: View {
///     @State private var showFlags = false
///     var body: some View {
///         Button("Feature Flags") { showFlags = true }
///             .sheet(isPresented: $showFlags) { FeatureFlagUI() }
///     }
/// }
/// ```
@freestanding(declaration, names: named(FeatureFlagUI))
public macro GenerateFeatureFlagsView(
    enumName: String
) = #externalMacro(module: "FeatureFlagProviderMacros", type: "GenerateFeatureFlagsViewMacro")

