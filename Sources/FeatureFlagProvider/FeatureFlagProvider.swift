// The Swift Programming Language
// https://docs.swift.org/swift-book

@_exported import Foundation
@_exported import SwiftUI

/// A tiny utility for reading a property list (plist) of feature flags from a bundle.
/// 
/// PlistReader provides two convenience helpers:
/// - `asNSDectionary(...)` to load the plist as `NSDictionary` (untyped).
/// - `asDectionary(...)` to load and validate the plist as `[String: Bool]` (typed).
///
/// By default, both helpers look for a file named `FeatureFlag.plist` in the provided
/// bundle (the main bundle by default). You can override the file name and bundle via
/// parameters.
///
/// Typical use:
/// ```swift
/// // Load as a strongly-typed dictionary of flags
/// let flags: [String: Bool] = try PlistReader.asDectionary()
/// // Or load the raw dictionary if you need non-Boolean values
/// let raw: NSDictionary = try PlistReader.asNSDectionary()
/// ```
///
/// Notes:
/// - All operations are synchronous. For very large plists, consider calling from a
///   background context if this is on a performance‑critical path.
/// - The plist must contain a top‑level dictionary. `asDectionary(...)` additionally
///   requires `String` keys and `Bool` values.
/// - Errors are thrown as `PlistReader.Error`.
///
/// Thread-safety:
/// - The functions do not maintain internal mutable state and are safe to call from
///   any thread; however, I/O is synchronous as noted above.
public enum PlistReader {
    
    /// Represents failures that can occur while reading and decoding a plist.
    ///
    /// Cases:
    /// - `missingKey`: A required key was not found (not currently used by the provided APIs,
    ///   reserved for potential future validation).
    /// - `invalidValue`: A value exists but is of an unexpected type or invalid content
    ///   (not currently used by the provided APIs, reserved for potential future validation).
    /// - `missingFile`: The specified plist file could not be located in the bundle.
    /// - `wrongFormat`: The plist exists but does not match the expected structure or types
    ///   (e.g., not a dictionary or not `[String: Bool]` when using `asDectionary`).
    ///
    public enum Error: Swift.Error {
        case missingKey, invalidValue, missingFile, wrongFormat
    }
    
    /// Loads a property list as an `NSDictionary` from the given bundle and resource name.
    ///
    /// This is useful when you want the raw, untyped contents of the plist (e.g., when values
    /// are not strictly `Bool`).
    ///
    /// - Parameters:
    ///   - bundle: The bundle that contains the plist. Defaults to `.main`.
    ///   - resourceName: The name of the plist resource without the `.plist` extension.
    ///     Defaults to `"FeatureFlag"`.
    /// - Returns: An `NSDictionary` representing the top‑level contents of the plist.
    /// - Throws:
    ///   - `PlistReader.Error.missingFile` if the file cannot be found.
    ///   - An error if the file cannot be parsed as a property list.
    /// - Important: The plist must contain a top‑level dictionary.
    /// - Example:
    /// ```swift
    /// let raw: NSDictionary = try PlistReader.asNSDectionary()
    public static func asNSDictionary(
        bundle: Bundle = .main,
        resourceName: String = "FeatureFlag"
    ) throws -> NSDictionary {
        guard let fileURL = bundle.url(forResource: resourceName, withExtension: "plist") else {
            throw Error.missingFile
        }
        
        return try NSDictionary(contentsOf: fileURL, error: ())
    }
    
    /// Loads a property list and validates it as `[String: Bool]`.
    ///
    /// Use this when your plist is intended to represent feature flags where each key is a
    /// flag name and each value is its Boolean default.
    ///
    /// - Note: The method name contains a historical misspelling (`asDectionary`). It returns
    ///   a Swift `Dictionary` as documented.
    /// - Parameters:
    ///   - bundle: The bundle that contains the plist. Defaults to `.main`.
    ///   - resourceName: The name of the plist resource without the `.plist` extension.
    ///     Defaults to `"FeatureFlag"`.
    /// - Returns: A dictionary of feature flags keyed by `String` with `Bool` values.
    /// - Throws:
    ///   - `PlistReader.Error.missingFile` if the file cannot be found.
    ///   - `PlistReader.Error.wrongFormat` if the plist cannot be cast to `[String: Bool]`.
    /// - Example:
    /// ```swift
    /// let flags: [String: Bool] = try PlistReader.asDectionary()
    /// let isNewFlowEnabled = flags["newOnboarding"] ?? false
    /// ```
    public static func asDictionary(
        bundle: Bundle = .main,
        resourceName: String = "FeatureFlag"
    ) throws -> [String: Bool] {
        guard let dictionary =  try Self.asNSDictionary(bundle: bundle, resourceName: resourceName) as? Dictionary<String, Bool> else {
            throw Error.wrongFormat
        }
        return dictionary
    }
}

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
    from flags: [String: Bool],
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

