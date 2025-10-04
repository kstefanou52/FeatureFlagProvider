//
//  ParsedArgs.swift
//  FeatureFlagProvider
//
//  Created by Kostis Stefanou on 3/10/25.
//

import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

import Foundation

struct ParsedArgs {
    var flags: [String: Bool] = [:]
    var enumName: String = ""
    var caseStyle: String = ""
}

private enum ParsedArgsDiagnostic: DiagnosticMessage {
    case missingLabel
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidFlagsType
    case invalidFlagKeyNotString
    case invalidFlagKeyInterpolated
    case invalidFlagValueNotBool
    case invalidEnumNameType
    case invalidEnumNameInterpolated
    case invalidCaseStyleType
    case unsupportedCaseStyle(String)

    private static let domain = "FeatureFlagProvider.ParsedArgs"

    var message: String {
        switch self {
        case .missingLabel:
            return "Positional arguments are not supported. Use labeled arguments such as 'flags:', 'enumName:', and 'caseStyle:'."
        case .unknownArgument(let label):
            return "Unknown argument label '\(label)'. Supported labels are 'flags', 'enumName', and 'caseStyle'."
        case .duplicateArgument(let label):
            return "Duplicate argument for label '\(label)'. Later values override earlier ones."
        case .invalidFlagsType:
            return "The 'flags' argument must be a dictionary literal of type [String: Bool]."
        case .invalidFlagKeyNotString:
            return "Flag keys must be string literals."
        case .invalidFlagKeyInterpolated:
            return "Flag keys must be simple string literals without interpolation."
        case .invalidFlagValueNotBool:
            return "Flag values must be boolean literals (true/false)."
        case .invalidEnumNameType:
            return "The 'enumName' argument must be a string literal or nil."
        case .invalidEnumNameInterpolated:
            return "The 'enumName' must be a simple string literal without interpolation."
        case .invalidCaseStyleType:
            return "The 'caseStyle' argument must be a member access like .camelCase, .pascalCase, or .verbatim."
        case .unsupportedCaseStyle(let name):
            return "Unsupported caseStyle '.\(name)'. Use .camelCase, .pascalCase, or .verbatim."
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .missingLabel:
            return MessageID(domain: Self.domain, id: "missingLabel")
        case .unknownArgument:
            return MessageID(domain: Self.domain, id: "unknownArgument")
        case .duplicateArgument:
            return MessageID(domain: Self.domain, id: "duplicateArgument")
        case .invalidFlagsType:
            return MessageID(domain: Self.domain, id: "invalidFlagsType")
        case .invalidFlagKeyNotString:
            return MessageID(domain: Self.domain, id: "invalidFlagKeyNotString")
        case .invalidFlagKeyInterpolated:
            return MessageID(domain: Self.domain, id: "invalidFlagKeyInterpolated")
        case .invalidFlagValueNotBool:
            return MessageID(domain: Self.domain, id: "invalidFlagValueNotBool")
        case .invalidEnumNameType:
            return MessageID(domain: Self.domain, id: "invalidEnumNameType")
        case .invalidEnumNameInterpolated:
            return MessageID(domain: Self.domain, id: "invalidEnumNameInterpolated")
        case .invalidCaseStyleType:
            return MessageID(domain: Self.domain, id: "invalidCaseStyleType")
        case .unsupportedCaseStyle:
            return MessageID(domain: Self.domain, id: "unsupportedCaseStyle")
        }
    }

    var severity: DiagnosticSeverity {
        switch self {
            // Treat duplicate as a warning; others as errors
        case .duplicateArgument:
            return .warning
        default:
            return .error
        }
    }
}

func parseArgs(from node: some FreestandingMacroExpansionSyntax, context: some MacroExpansionContext) -> ParsedArgs {
    var result = ParsedArgs()

    var seenLabels = Set<String>()

    for arg in node.arguments {
        let expr = arg.expression

        guard let labelToken = arg.label else {
            context.diagnose(Diagnostic(node: Syntax(arg), message: ParsedArgsDiagnostic.missingLabel))
            continue
        }
        let label = labelToken.text

        let (inserted, _) = seenLabels.insert(label)
        if !inserted {
            context.diagnose(Diagnostic(node: Syntax(labelToken), message: ParsedArgsDiagnostic.duplicateArgument(label)))
        }

        switch label {
        case "from":
            if let dictExpr = expr.as(DictionaryExprSyntax.self) {
                var dict: [String: Bool] = [:]
                switch dictExpr.content {
                case .elements(let elements):
                    for element in elements {
                        let keyExpr = element.key
                        let valExpr = element.value

                        guard let keyLit = keyExpr.as(StringLiteralExprSyntax.self) else {
                            context.diagnose(Diagnostic(node: Syntax(keyExpr), message: ParsedArgsDiagnostic.invalidFlagKeyNotString))
                            continue
                        }
                        if keyLit.segments.count != 1 || keyLit.segments.first?.as(StringSegmentSyntax.self) == nil {
                            context.diagnose(Diagnostic(node: Syntax(keyLit), message: ParsedArgsDiagnostic.invalidFlagKeyInterpolated))
                            continue
                        }
                        let key = keyLit.segments.first!.as(StringSegmentSyntax.self)!.content.text

                        guard let boolLit = valExpr.as(BooleanLiteralExprSyntax.self) else {
                            context.diagnose(Diagnostic(node: Syntax(valExpr), message: ParsedArgsDiagnostic.invalidFlagValueNotBool))
                            continue
                        }
                        dict[key] = (boolLit.literal.text == "true")
                    }
                case .colon(_):
                    // Empty dictionary literal [:]
                    break
                }
                result.flags = dict
            } else {
                context.diagnose(Diagnostic(node: Syntax(expr), message: ParsedArgsDiagnostic.invalidFlagsType))
            }

        case "enumName":
            if expr.is(NilLiteralExprSyntax.self) {
                // Accept nil: leave default value
            } else if let lit = expr.as(StringLiteralExprSyntax.self) {
                if lit.segments.count != 1 || lit.segments.first?.as(StringSegmentSyntax.self) == nil {
                    context.diagnose(Diagnostic(node: Syntax(lit), message: ParsedArgsDiagnostic.invalidEnumNameInterpolated))
                } else if let first = lit.segments.first?.as(StringSegmentSyntax.self) {
                    result.enumName = first.content.text
                }
            } else {
                context.diagnose(Diagnostic(node: Syntax(expr), message: ParsedArgsDiagnostic.invalidEnumNameType))
            }

        case "caseStyle":
            if let member = expr.as(MemberAccessExprSyntax.self) {
                let name = member.declName.baseName.text
                switch name {
                case "camelCase", "pascalCase", "verbatim":
                    result.caseStyle = name
                default:
                    context.diagnose(Diagnostic(node: Syntax(member), message: ParsedArgsDiagnostic.unsupportedCaseStyle(name)))
                }
            } else {
                context.diagnose(Diagnostic(node: Syntax(expr), message: ParsedArgsDiagnostic.invalidCaseStyleType))
            }

        default:
            context.diagnose(Diagnostic(node: Syntax(labelToken), message: ParsedArgsDiagnostic.unknownArgument(label)))
        }
    }

    return result
}
