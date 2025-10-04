//
//  PlistError.swift
//  FeatureFlagProvider
//
//  Created by Kostis Stefanou on 3/10/25.
//

import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

struct PlistError: DiagnosticMessage {
    let message: String
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { .init(domain: "GenerateFeatureFlags", id: "plist") }
}

func diagnose(
    _ message: String,
    at node: some SyntaxProtocol,
    context: some MacroExpansionContext
) {
    context.diagnose(Diagnostic(node: Syntax(node), message: PlistError(message: message)))
}
