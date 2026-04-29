import Foundation
import SwiftParser
import SwiftSyntax

public struct RouterEnumParser: Sendable {
    public init() {}

    public func parse(file: URL) throws -> [RouterCase] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let tree = Parser.parse(source: source)
        let locationConverter = SourceLocationConverter(fileName: file.path, tree: tree)
        let visitor = RouterEnumVisitor(filePath: file.path, locationConverter: locationConverter)
        visitor.walk(tree)
        return visitor.finalize()
    }
}

private final class RouterEnumVisitor: SyntaxVisitor {
    let filePath: String
    private var cases: [RouterCase] = []

    private let locationConverter: SourceLocationConverter
    private var currentEnum: String?
    private var pathArmsByEnum: [String: [String: String]] = [:]
    private var methodArmsByEnum: [String: [String: String]] = [:]

    init(filePath: String, locationConverter: SourceLocationConverter) {
        self.filePath = filePath
        self.locationConverter = locationConverter
        super.init(viewMode: .all)
    }

    func finalize() -> [RouterCase] {
        cases.map { existing in
            RouterCase(
                routerEnum: existing.routerEnum,
                caseName: existing.caseName,
                filePath: existing.filePath,
                line: existing.line,
                pathArm: pathArmsByEnum[existing.routerEnum]?[existing.caseName],
                methodArm: methodArmsByEnum[existing.routerEnum]?[existing.caseName],
                summary: existing.summary
            )
        }
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isRouterEnum(node) else {
            return .skipChildren
        }

        currentEnum = node.name.text
        for member in node.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                handle(caseDecl: caseDecl)
            } else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                capture(variableDecl: variableDecl)
            }
        }
        currentEnum = nil

        return .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isTargetTypeExtension(node) else {
            return .skipChildren
        }

        currentEnum = node.extendedType.trimmedDescription
        for member in node.memberBlock.members {
            if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                capture(variableDecl: variableDecl)
            }
        }
        currentEnum = nil

        return .skipChildren
    }

    private func isRouterEnum(_ node: EnumDeclSyntax) -> Bool {
        if node.name.text.hasSuffix("Router") {
            return true
        }

        guard let inheritance = node.inheritanceClause else {
            return false
        }
        let inheritedTypes = inheritance.inheritedTypes.map { $0.type.trimmedDescription }
        return inheritedTypes.contains { type in
            type == "BaseTargetType" || type == "TargetType"
        }
    }

    private func isTargetTypeExtension(_ node: ExtensionDeclSyntax) -> Bool {
        guard node.extendedType.trimmedDescription.hasSuffix("Router"),
              let inheritance = node.inheritanceClause
        else {
            return false
        }

        let inheritedTypes = inheritance.inheritedTypes.map { $0.type.trimmedDescription }
        return inheritedTypes.contains { type in
            type == "BaseTargetType" || type == "TargetType"
        }
    }

    private func handle(caseDecl: EnumCaseDeclSyntax) {
        guard let enumName = currentEnum else {
            return
        }

        let summary = extractDocComment(from: caseDecl)
        for element in caseDecl.elements {
            let line = locationConverter
                .location(for: element.positionAfterSkippingLeadingTrivia)
                .line

            cases.append(RouterCase(
                routerEnum: enumName,
                caseName: element.name.text,
                filePath: filePath,
                line: line,
                pathArm: nil,
                methodArm: nil,
                summary: summary
            ))
        }
    }

    private func capture(variableDecl: VariableDeclSyntax) {
        guard let currentEnum else {
            return
        }
        guard let binding = variableDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation,
              let body = binding.accessorBlock?.accessors.as(CodeBlockItemListSyntax.self)
        else {
            return
        }

        let propertyName = identifier.identifier.text
        let typeName = typeAnnotation.type.trimmedDescription

        if propertyName == "path", typeName == "String" {
            var arms = pathArmsByEnum[currentEnum] ?? [:]
            captureSwitchArms(body, into: &arms, valueExtractor: stringLiteralValue)
            pathArmsByEnum[currentEnum] = arms
        } else if propertyName == "method", typeName.hasSuffix("Method") {
            var arms = methodArmsByEnum[currentEnum] ?? [:]
            captureSwitchArms(body, into: &arms, valueExtractor: memberAccessName)
            methodArmsByEnum[currentEnum] = arms
        }
    }

    private func captureSwitchArms(
        _ body: CodeBlockItemListSyntax,
        into output: inout [String: String],
        valueExtractor: (ExprSyntax) -> String?
    ) {
        for switchExpression in switchExpressions(in: Syntax(body)) {
            for syntaxCase in switchExpression.cases {
                guard let switchCase = syntaxCase.as(SwitchCaseSyntax.self),
                      let label = switchCase.label.as(SwitchCaseLabelSyntax.self)
                else {
                    continue
                }

                let returnExpression = switchCase.statements.compactMap { item -> ExprSyntax? in
                    item.item.as(ReturnStmtSyntax.self)?.expression
                }.first

                guard let returnExpression,
                      let value = valueExtractor(returnExpression)
                else {
                    continue
                }

                for caseItem in label.caseItems {
                    if let caseName = caseName(from: caseItem.pattern) {
                        output[caseName] = value
                    }
                }
            }
        }
    }

    private func switchExpressions(in syntax: Syntax) -> [SwitchExprSyntax] {
        var result: [SwitchExprSyntax] = []
        if let switchExpression = syntax.as(SwitchExprSyntax.self) {
            result.append(switchExpression)
        }

        for child in syntax.children(viewMode: .all) {
            result.append(contentsOf: switchExpressions(in: child))
        }
        return result
    }

    private func caseName(from pattern: PatternSyntax) -> String? {
        let description = pattern.trimmedDescription
        guard let dotIndex = description.firstIndex(of: ".") else {
            return nil
        }

        let afterDot = description[description.index(after: dotIndex)...]
        let name = afterDot.prefix { character in
            character == "_" || character.isLetter || character.isNumber
        }
        return name.isEmpty ? nil : String(name)
    }

    private func stringLiteralValue(_ expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else {
            return nil
        }

        var result = ""
        for segment in literal.segments {
            if let stringSegment = segment.as(StringSegmentSyntax.self) {
                result += stringSegment.content.text
            } else if let expressionSegment = segment.as(ExpressionSegmentSyntax.self) {
                let inner = expressionSegment.expressions.first?.expression.trimmedDescription ?? ""
                result += "\\(\(inner))"
            }
        }
        return result
    }

    private func memberAccessName(_ expression: ExprSyntax) -> String? {
        expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }

    private func extractDocComment(from node: EnumCaseDeclSyntax) -> String? {
        let lines = node.leadingTrivia.compactMap { piece -> String? in
            guard case .docLineComment(let text) = piece else {
                return nil
            }
            return text
        }

        guard !lines.isEmpty else {
            return nil
        }

        return lines
            .map { line in
                line
                    .replacingOccurrences(of: "/// ", with: "")
                    .replacingOccurrences(of: "///", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
