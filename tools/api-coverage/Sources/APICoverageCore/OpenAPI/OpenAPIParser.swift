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
                    summary: opDict["summary"] as? String
                ))
            }
        }
        return OpenAPIDocument(title: title, version: version, operations: ops.sorted {
            $0.key.path == $1.key.path
                ? $0.key.method.rawValue < $1.key.method.rawValue
                : $0.key.path < $1.key.path
        })
    }
}
