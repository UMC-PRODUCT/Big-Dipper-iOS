//
//  NetworkError+Mapping.swift
//  UMCFoundation
//
//  HTTP 상태코드 / URLError 를 NetworkError 로 변환하는 단일 진실원 팩토리와,
//  케이스 구조와 디커플링된 소비처용 헬퍼를 제공합니다.
//

import Foundation

extension NetworkError {

    // MARK: - Factory

    /// HTTP 상태코드를 시맨틱 케이스로 매핑합니다. 알려지지 않은 코드는 `.requestFailed` 폴백.
    ///
    /// - Note: 401 은 `NetworkClient` 가 refresh 흐름에서 먼저 처리하므로 여기 도달하지 않습니다.
    public static func from(statusCode: Int, data: Data?) -> NetworkError {
        switch statusCode {
        case 400:
            return .badRequest(data: data)
        case 403:
            return .forbidden(data: data)
        case 404:
            return .notFound(data: data)
        case 409:
            return .conflict(data: data)
        case 422:
            return .unprocessable(data: data)
        case 500...599:
            return .serverError(statusCode: statusCode, data: data)
        default:
            return .requestFailed(statusCode: statusCode, data: data)
        }
    }

    /// 전송 계층 URLError 를 흡수 케이스로 매핑합니다.
    public static func from(urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noNetwork
        case .timedOut:
            return .timeout
        default:
            return .transport(reason: urlError.localizedDescription)
        }
    }

    // MARK: - Accessors

    /// HTTP 상태를 표현하는 케이스면 상태코드를, 아니면 nil.
    public var httpStatusCode: Int? {
        switch self {
        case .badRequest:
            return 400
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .conflict:
            return 409
        case .unprocessable:
            return 422
        case .serverError(let statusCode, _):
            return statusCode
        case .requestFailed(let statusCode, _):
            return statusCode
        default:
            return nil
        }
    }

    /// 서버 응답 본문을 실은 케이스면 그 데이터를, 아니면 nil.
    public var responseBody: Data? {
        switch self {
        case .badRequest(let data), .forbidden(let data), .notFound(let data),
             .conflict(let data), .unprocessable(let data):
            return data
        case .serverError(_, let data), .requestFailed(_, let data):
            return data
        default:
            return nil
        }
    }
}
