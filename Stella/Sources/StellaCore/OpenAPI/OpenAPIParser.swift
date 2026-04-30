import Foundation

public enum OpenAPIParseError: Error, Equatable {
    case invalidJSON
    case missingField(String)
}

public enum OpenAPIParser {
    public static func parse(_ data: Data) throws -> OpenAPIDocument {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAPIParseError.invalidJSON
        }
        guard let info = root["info"] as? [String: Any],
              let title = info["title"] as? String,
              let version = info["version"] as? String
        else { throw OpenAPIParseError.missingField("info.title|info.version") }

        guard let paths = root["paths"] as? [String: Any] else {
            throw OpenAPIParseError.missingField("paths")
        }

        var ops: [OpenAPIOperation] = []
        for (path, methodMap) in paths {
            guard let methods = methodMap as? [String: Any] else { continue }
            for (methodStr, op) in methods {
                guard let method = HTTPMethod(rawValue: methodStr.uppercased()) else { continue }
                guard let opDict = op as? [String: Any] else { continue }
                let tags = (opDict["tags"] as? [String]) ?? []
                ops.append(OpenAPIOperation(
                    key: OpenAPIKey(method: method, path: path),
                    tag: tags.first,
                    operationId: opDict["operationId"] as? String,
                    summary: opDict["summary"] as? String,
                    description: opDict["description"] as? String,
                    parameters: parseParameters(opDict["parameters"]),
                    requestBody: parseRequestBody(opDict["requestBody"]),
                    requestBodyExample: parseRequestBodyExample(opDict["requestBody"], root: root),
                    responses: parseResponses(opDict["responses"], root: root)
                ))
            }
        }
        return OpenAPIDocument(title: title, version: version, operations: ops.sorted {
            $0.key.path == $1.key.path
                ? $0.key.method.rawValue < $1.key.method.rawValue
                : $0.key.path < $1.key.path
        })
    }

    private static func parseParameters(_ raw: Any?) -> [OpenAPIParameter] {
        guard let parameters = raw as? [[String: Any]] else { return [] }
        return parameters.compactMap { item in
            guard let name = item["name"] as? String,
                  let location = item["in"] as? String else { return nil }
            return OpenAPIParameter(
                name: name,
                location: location,
                required: item["required"] as? Bool ?? false,
                description: item["description"] as? String,
                schema: compactDescription(item["schema"])
            )
        }
    }

    private static func parseRequestBody(_ raw: Any?) -> String? {
        guard let body = raw as? [String: Any] else { return nil }
        var parts: [String] = []
        if let description = body["description"] as? String {
            parts.append(description)
        }
        if let required = body["required"] as? Bool, required {
            parts.append("required")
        }
        if let content = body["content"] as? [String: Any], !content.isEmpty {
            parts.append("content: " + content.keys.sorted().joined(separator: ", "))
        }
        return parts.isEmpty ? compactDescription(raw) : parts.joined(separator: " · ")
    }

    private static func parseRequestBodyExample(_ raw: Any?, root: [String: Any]) -> String? {
        guard let body = raw as? [String: Any],
              let content = body["content"] as? [String: Any] else { return nil }

        let preferred = ["application/json", "application/*+json"]
        let media = preferred.compactMap { content[$0] as? [String: Any] }.first
            ?? content.values.compactMap { $0 as? [String: Any] }.first
        guard let schema = media?["schema"] else { return nil }

        let example = exampleValue(from: schema, root: root, depth: 0)
        guard JSONSerialization.isValidJSONObject(example),
              let data = try? JSONSerialization.data(
                withJSONObject: example,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              )
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func parseResponses(_ raw: Any?, root: [String: Any]) -> [OpenAPIResponse] {
        guard let responses = raw as? [String: Any] else { return [] }
        return responses.keys.sorted().map { status in
            let item = responses[status] as? [String: Any]
            return OpenAPIResponse(
                statusCode: status,
                description: item?["description"] as? String,
                content: parseContentSummary(item?["content"]),
                example: parseContentExample(item?["content"], root: root)
            )
        }
    }

    private static func parseContentSummary(_ raw: Any?) -> String? {
        guard let content = raw as? [String: Any], !content.isEmpty else { return nil }
        return "content: " + content.keys.sorted().joined(separator: ", ")
    }

    private static func parseContentExample(_ raw: Any?, root: [String: Any]) -> String? {
        guard let content = raw as? [String: Any],
              let schema = preferredMedia(from: content)?["schema"] else {
            return nil
        }

        let example = exampleValue(from: schema, root: root, depth: 0)
        guard JSONSerialization.isValidJSONObject(example),
              let data = try? JSONSerialization.data(
                withJSONObject: example,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              )
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func preferredMedia(from content: [String: Any]) -> [String: Any]? {
        let preferred = ["application/json", "application/*+json"]
        return preferred.compactMap { content[$0] as? [String: Any] }.first
            ?? content.values.compactMap { $0 as? [String: Any] }.first
    }

    private static func compactDescription(_ raw: Any?) -> String? {
        guard let raw else { return nil }
        if let string = raw as? String { return string }
        if let dict = raw as? [String: Any] {
            if let ref = dict["$ref"] as? String { return ref }
            if let type = dict["type"] as? String { return type }
            if let schema = dict["schema"] { return compactDescription(schema) }
        }
        if JSONSerialization.isValidJSONObject(raw),
           let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }

    private static func exampleValue(from raw: Any, root: [String: Any], depth: Int) -> Any {
        guard depth < 10, let schema = raw as? [String: Any] else {
            return ""
        }

        if let example = schema["example"] {
            return example
        }
        if let defaultValue = schema["default"] {
            return defaultValue
        }
        if let enumValues = schema["enum"] as? [Any], let first = enumValues.first {
            return first
        }
        if let ref = schema["$ref"] as? String,
           let resolved = resolve(ref: ref, root: root) {
            return exampleValue(from: resolved, root: root, depth: depth + 1)
        }
        if let allOf = schema["allOf"] as? [Any] {
            return mergeObjectExamples(allOf.map { exampleValue(from: $0, root: root, depth: depth + 1) })
        }
        if let oneOf = schema["oneOf"] as? [Any], let first = oneOf.first {
            return exampleValue(from: first, root: root, depth: depth + 1)
        }
        if let anyOf = schema["anyOf"] as? [Any], let first = anyOf.first {
            return exampleValue(from: first, root: root, depth: depth + 1)
        }

        let type = schema["type"] as? String
        if type == "array" {
            return [exampleValue(from: schema["items"] ?? [:], root: root, depth: depth + 1)]
        }

        if type == "object" || schema["properties"] != nil {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            var object: [String: Any] = [:]
            for key in properties.keys.sorted() {
                object[key] = exampleValue(from: properties[key] ?? [:], root: root, depth: depth + 1)
            }
            return object
        }

        switch schema["format"] as? String {
        case "int32", "int64": return 0
        case "float", "double": return 0.0
        case "boolean": return false
        case "date": return "2026-04-29"
        case "date-time": return "2026-04-29T00:00:00Z"
        default: break
        }

        switch type {
        case "integer": return 0
        case "number": return 0.0
        case "boolean": return false
        case "string": return "string"
        default: return "string"
        }
    }

    private static func resolve(ref: String, root: [String: Any]) -> Any? {
        guard ref.hasPrefix("#/") else { return nil }
        let parts = ref.dropFirst(2).split(separator: "/").map {
            $0.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
        }
        var current: Any = root
        for part in parts {
            guard let dict = current as? [String: Any],
                  let next = dict[part] else { return nil }
            current = next
        }
        return current
    }

    private static func mergeObjectExamples(_ values: [Any]) -> Any {
        var merged: [String: Any] = [:]
        for value in values {
            if let object = value as? [String: Any] {
                merged.merge(object) { _, new in new }
            }
        }
        return merged.isEmpty ? (values.first ?? [:]) : merged
    }
}
