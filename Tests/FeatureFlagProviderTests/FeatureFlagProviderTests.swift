import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import Foundation

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FeatureFlagProviderMacros)
import FeatureFlagProviderMacros

let testMacros: [String: Macro.Type] = [
    "GenerateFeatureFlags": GenerateFeatureFlagsMacro.self,
]
#endif

final class FeatureFlagProviderTests: XCTestCase {
    func testGenerateFeatureFlagsEmptyExpansion() throws {
        #if canImport(FeatureFlagProviderMacros)
        let source = """
        #GenerateFeatureFlags(
            from: [
                "FOO_FEATURE": true,
                "BAR": false
            ],
            enumName: "FeatureFlag",
            caseStyle: .camelCase
        )
        """

        assertMacroExpansion(
            source,
            expandedSource: "",
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

