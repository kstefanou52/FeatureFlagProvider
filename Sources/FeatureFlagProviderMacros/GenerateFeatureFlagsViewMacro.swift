//
//  GenerateFeatureFlagsViewMacro.swift
//  FeatureFlagProvider
//
//  Created by Kostis Stefanou on 4/10/25.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

private enum ViewArgsDiagnostic: DiagnosticMessage {
    case invalidEnumNameType
    case invalidEnumNameInterpolated

    private static let domain = "FeatureFlagProvider.GenerateFeatureFlagsView"

    var message: String {
        switch self {
        case .invalidEnumNameType:
            return "The 'enumName' argument must be a string literal or nil."
        case .invalidEnumNameInterpolated:
            return "The 'enumName' must be a simple string literal without interpolation."
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .invalidEnumNameType:
            return MessageID(domain: Self.domain, id: "invalidEnumNameType")
        case .invalidEnumNameInterpolated:
            return MessageID(domain: Self.domain, id: "invalidEnumNameInterpolated")
        }
    }

    var severity: DiagnosticSeverity { .error }
}

public struct GenerateFeatureFlagsViewMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        // Try to parse a labeled `enumName:` argument using the same logic as ParsedArgs
        var providedEnumNameFromLabel: String? = nil
        for arg in node.arguments {
            guard let label = arg.label, label.text == "enumName" else { continue }
            let expr = arg.expression
            if expr.is(NilLiteralExprSyntax.self) {
                // Accept nil: leave default/fallback behavior
                providedEnumNameFromLabel = ""
            } else if let lit = expr.as(StringLiteralExprSyntax.self) {
                if lit.segments.count != 1 || lit.segments.first?.as(StringSegmentSyntax.self) == nil {
                    context.diagnose(Diagnostic(node: Syntax(lit), message: ViewArgsDiagnostic.invalidEnumNameInterpolated))
                } else if let first = lit.segments.first?.as(StringSegmentSyntax.self) {
                    providedEnumNameFromLabel = first.content.text
                }
            } else {
                context.diagnose(Diagnostic(node: Syntax(expr), message: ViewArgsDiagnostic.invalidEnumNameType))
            }
            break
        }

        let enumTypeName: String = {
            if let fromLabel = providedEnumNameFromLabel, !fromLabel.isEmpty {
                return fromLabel
            }
            guard let first = node.arguments.first?.expression else {
                return "FeatureFlags"
            }
            return first.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let viewName = sanitizeIdentifier("\(enumTypeName)UI")

        let decl = DeclSyntax(stringLiteral:
            """
            struct \(viewName): View {
                @Environment(\\.dismiss) private var dismiss
                
                struct FlagItem: Identifiable {
                    var flag: \(enumTypeName)
                    var value: Bool
                    var id: String { flag.rawValue }
                }
                
                @State private var featureFlags: [FlagItem] = {
                    \(enumTypeName).allCases.map { FlagItem(flag: $0, value: $0.defaultValue) }
                }()
                
                var body: some View {
                    List {
                        ForEach($featureFlags) { $item in
                            Toggle(isOn: $item.value) {
                                VStack(alignment: .leading) {
                                    Text(item.flag.displayName)
                                    
                                    if let overridedValue = item.flag.overridedValue,
                                       overridedValue == item.value {
                                        Text("Overrided, Default value is \\(item.flag.defaultValue.description)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button("Save", action: {
                            save()
                            dismiss()
                        })
                        .foregroundStyle(.white)
                        .font(.body)
                        .fontWeight(.semibold)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .toolbar {
                        #if os(macOS)
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                resetToDefaults()
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                            }
                        }
                        #else
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                resetToDefaults()
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                            }
                        }
                        #endif
                    }
                    .navigationTitle("Feature Flags")
                }
                
                private func save() {
                    for item in featureFlags where item.flag.defaultValue != item.value {
                        item.flag.saveUserDefaultValue(item.value)
                    }
                }
                
                private func resetToDefaults() {
                    featureFlags = \(enumTypeName).allCases.map { FlagItem(flag: $0, value: $0.defaultValue) }
                }
            }
            """
        )
        return [decl]
    }
}

