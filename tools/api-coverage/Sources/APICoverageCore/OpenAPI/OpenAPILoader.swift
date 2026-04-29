import Foundation

public struct BasicAuth: Sendable, Equatable {
    public let user: String
    public let password: String

    public init(user: String, password: String) {
        self.user = user
        self.password = password
    }

    var headerValue: String {
        "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    }
}

public enum OpenAPISource: Sendable {
    case url(URL, auth: BasicAuth?)
    case file(URL)
    case data(Data)
}

public actor OpenAPILoader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func load(_ source: OpenAPISource) async throws -> OpenAPIDocument {
        switch source {
        case .url(let url, let auth):
            var request = URLRequest(url: url)
            if let auth {
                request.setValue(auth.headerValue, forHTTPHeaderField: "Authorization")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APICoverageError.openAPINetwork("no HTTPURLResponse")
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw APICoverageError.openAPIHTTPStatus(httpResponse.statusCode)
                }
                return try OpenAPIParser.parse(data)
            } catch let error as APICoverageError {
                throw error
            } catch {
                throw APICoverageError.openAPINetwork(error.localizedDescription)
            }

        case .file(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw APICoverageError.fileNotFound(url.path)
            }
            let data = try Data(contentsOf: url)
            return try OpenAPIParser.parse(data)

        case .data(let data):
            return try OpenAPIParser.parse(data)
        }
    }
}
