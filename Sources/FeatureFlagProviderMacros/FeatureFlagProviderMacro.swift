import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

typealias FeatureFlag = (name: String, value: Bool)

public struct GenerateFeatureFlagsMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        // Parse arguments
        let args = parseArgs(from: node, context: context)

        // Extract keys from flags dictionary
        let flags: [FeatureFlag] = args.flags
            .map { key, value in
                FeatureFlag(key, value)
            }
            .sorted(by: { $0.name < $1.name })
        
        if flags.isEmpty {
            // No flags provided; nothing to generate
            return []
        }

        // Map caseStyle into a transform
        let style = (args.caseStyle)
        let sanitizedFlags: [FeatureFlag] = flags.map { flag in
            let words = splitWords(flag.name)
            let base: String
            switch style {
            case "camelCase":
                base = toCamelCase(words)
            case "pascalCase":
                base = toPascalCase(words)
            case "verbatim":
                base = flag.name
            default:
                base = toCamelCase(words)
            }
            return FeatureFlag(sanitizeIdentifier(base), flag.value)
        }

        // Derive enum name from argument, preserve provided casing
        let providedEnumName = args.enumName
        let enumName = sanitizeIdentifier(providedEnumName)

        // Build and return the enum declaration
        let decl = makeEnumDecl(enumName: enumName, flags: sanitizedFlags)
        return [decl]
    }
}

// MARK: - Diagnostics

private struct GenerationError: DiagnosticMessage {
    let message: String
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { .init(domain: "GenerateFeatureFlags", id: "generation_error") }
}

// MARK: - Name sanitization and case transforms

private func splitWords(_ input: String) -> [String] {
    // Split on non-alphanumeric boundaries and underscores
    let scalars = input.unicodeScalars
    var words: [String] = []
    var current = ""
    for s in scalars {
        if CharacterSet.alphanumerics.contains(s) {
            current.unicodeScalars.append(s)
        } else {
            if !current.isEmpty { words.append(current); current.removeAll(keepingCapacity: true) }
        }
    }
    if !current.isEmpty { words.append(current) }
    return words
}

private func toCamelCase(_ words: [String]) -> String {
    guard let first = words.first else { return "" }
    let head = first.lowercased()
    let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    return head + tail
}

private func toPascalCase(_ words: [String]) -> String {
    return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
}

func sanitizeIdentifier(_ name: String) -> String {
    // Replace illegal leading characters and ensure it's a valid Swift identifier
    var result = name
    if result.isEmpty { return "_" }
    // If it starts with a digit, prefix underscore
    if let first = result.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
        result = "_" + result
    }
    // Collapse any remaining illegal characters to underscores
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    result = String(result.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    // Avoid consecutive underscores noise
    while result.contains("__") { result = result.replacingOccurrences(of: "__", with: "_") }
    return result
}

private func makeEnumDecl(enumName: String, flags: [FeatureFlag]) -> DeclSyntax {
    let body = flags.map { "case \($0.name)" }.joined(separator: "\n    ")
    let defaultValue = flags.map { "case .\($0.name): \($0.value)" }.joined(separator: "\n        ")
    let userDefaultsKey = flags.map { "case .\($0.name): \"kFFProvider_\($0.name)\"" }.joined(separator: "\n        ")
    
    return DeclSyntax(stringLiteral:
        """
        enum \(enumName): String, CaseIterable, Sendable {
        
            \(body)
        
            var defaultValue: Bool {
                switch self {
                \(defaultValue)
                }
            }
        
            var userDefaultsKey: String {
                switch self {
                \(userDefaultsKey)
                }
            }
        
            var overridedValue: Bool? {
                getUserDefaultsValue()
            }
        
            var displayName: String {
                rawValue.replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression,
                    range: nil
                )
                .capitalized
            }
        
            func getUserDefaultsValue() -> Bool? {
                if UserDefaults.standard.object(forKey: userDefaultsKey) != nil {
                    return UserDefaults.standard.bool(forKey: userDefaultsKey)
                } else {
                    return nil
                }
            }
        
            func saveUserDefaultValue(_ value: Bool) {
                UserDefaults.standard.set(value, forKey: userDefaultsKey)
            }
        }
        """
    )
}

@main
struct FeatureFlagProviderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerateFeatureFlagsMacro.self,
        GenerateFeatureFlagsViewMacro.self
    ]
}
