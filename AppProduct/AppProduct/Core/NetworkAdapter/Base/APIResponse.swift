//
//  APIResponse.swift
//  AppProduct
//
//  Created by euijjang97 on 1/9/26.
//

import Foundation

/// 서버 공통 응답 DTO
///
/// Spring 백엔드의 `ApiResponse<T>` 형식과 매핑됩니다.
///
/// ## 서버 응답 형식
/// ```json
/// {
///   "success": true,
///   "code": "200",
///   "message": "성공",
///   "result": { ... }
/// }
/// ```
///
/// ## 사용 예시
/// ```swift
/// let response = try JSONDecoder().decode(
///     APIResponse<UserDTO>.self,
///     from: data
/// )
///
/// guard response.isSuccess, let user = response.result else {
///     throw RepositoryError.serverError(
///         code: response.code,
///         message: response.message
///     )
/// }
/// ```
struct APIResponse<T: Codable>: Codable {

    // MARK: - Property

    /// 요청 성공 여부
    let isSuccess: Bool

    /// 응답 코드 (e.g., "200", "AUTH001")
    let code: String?

    /// 응답 메시지 (e.g., "성공", "인증에 실패했습니다")
    let message: String?

    /// 응답 데이터 (성공 시에만 존재)
    let result: T?

    /// 실패 응답에서 result가 String일 때 캡처한 서버 상세 메시지
    let resultMessage: String?

    // MARK: - CodingKeys

    /// Spring `@JsonProperty("success")` 매핑
    private enum CodingKeys: String, CodingKey {
        case isSuccess = "success"
        case code
        case message
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSuccess = try container.decode(Bool.self, forKey: .isSuccess)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        result = try container.decodeIfPresent(T.self, forKey: .result)
        if result == nil {
            resultMessage = try? container.decodeIfPresent(String.self, forKey: .result)
        } else {
            resultMessage = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isSuccess, forKey: .isSuccess)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(result, forKey: .result)
    }
}

// MARK: - Convenience

extension APIResponse {

    /// 성공 응답인지 확인하고 result를 반환
    ///
    /// - Throws: `RepositoryError.serverError` (실패 시)
    /// - Returns: result 값
    func unwrap() throws -> T {
        guard isSuccess else {
            throw RepositoryError.serverError(code: code, message: resultMessage ?? message)
        }

        if let result {
            return result
        }

        // result가 없는 성공 응답은 EmptyResult로 복구합니다.
        if T.self == EmptyResult.self, let empty = EmptyResult() as? T {
            return empty
        }

        throw RepositoryError.serverError(code: code, message: message)
    }

    /// 성공 여부만 검증합니다.
    ///
    /// `result`가 없는 성공 응답(PATCH/DELETE 등)을 처리할 때 사용합니다.
    /// - Throws: `RepositoryError.serverError` (실패 시)
    func validateSuccess() throws {
        guard isSuccess else {
            throw RepositoryError.serverError(code: code, message: resultMessage ?? message)
        }
    }

    /// 에러 메시지 (실패 시 사용)
    var errorMessage: String {
        message ?? "알 수 없는 오류가 발생했습니다"
    }

    /// 에러 코드 (실패 시 사용)
    var errorCode: String {
        code ?? "UNKNOWN"
    }
}

// MARK: - Empty Result

/// 결과 데이터가 없는 API 응답용 (DELETE 등)
struct EmptyResult: Codable, Sendable, Equatable {}
