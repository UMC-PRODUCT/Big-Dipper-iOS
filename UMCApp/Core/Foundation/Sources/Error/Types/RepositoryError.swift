//
//  RepositoryError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 2/3/26.
//

import Foundation

/// Repository 계층에서 발생하는 에러
///
/// 서버 응답의 `isSuccess: false` 또는 데이터 변환 실패 시 발생합니다.
///
/// ## 사용 예시
/// ```swift
/// func getUser() async throws -> User {
///     let response = try await adapter.request(UserAPI.getMe)
///     let dto = try JSONDecoder().decode(CommonDTO<UserDTO>.self, from: response.data)
///
///     guard dto.isSuccess, let userDTO = dto.result else {
///         throw RepositoryError.serverError(code: dto.code, message: dto.message)
///     }
///
///     return userDTO.toDomain()
/// }
/// ```
public enum RepositoryError: Error, LocalizedError, Sendable, Equatable {

    // MARK: - Cases

    /// 서버에서 실패 응답 반환 (isSuccess: false)
    ///
    /// - Parameters:
    ///   - code: 에러 코드 (e.g., "AUTH001", "USER404")
    ///   - message: 에러 메시지
    case serverError(code: String?, message: String?)

    /// 응답 데이터 디코딩 실패
    case decodingError(detail: String?)

    /// 디코딩 자체는 성공했지만 응답 내용이 의미상 유효하지 않음
    /// (e.g. 필수 필드가 비어 있음)
    case invalidResponse(detail: String?)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .serverError(_, let message):
            return message ?? "서버 오류가 발생했습니다"
        case .decodingError(let detail):
            return "데이터 파싱 실패: \(detail ?? "알 수 없는 오류")"
        case .invalidResponse(let detail):
            return "서버 응답이 유효하지 않습니다: \(detail ?? "알 수 없는 오류")"
        }
    }

    // MARK: - Properties

    /// 에러 코드 (서버 에러인 경우)
    public var code: String? {
        switch self {
        case .serverError(let code, _):
            return code
        case .decodingError, .invalidResponse:
            return nil
        }
    }

    /// 사용자에게 표시할 메시지
    public var userMessage: String {
        errorDescription ?? "알 수 없는 오류가 발생했습니다"
    }

    /// 재시도 가능 여부
    public var isRetryable: Bool {
        switch self {
        case .serverError:
            return true
        case .decodingError, .invalidResponse:
            return false
        }
    }
}
