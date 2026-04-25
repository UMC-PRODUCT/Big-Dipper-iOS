//
//  APIError.swift
//  UMCFoundation
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// 서버가 비즈니스 레벨 실패를 응답한 경우(`isSuccess == false`) 던져지는 에러입니다.
///
/// `APIResponse.unwrap()` / `validateSuccess()`가 이 에러를 throw 하며,
/// 호출 측 Repository에서 catch 후 도메인 에러(`RepositoryError` 등)로 변환합니다.
///
/// - Note: HTTP 전송 계층 에러는 `NetworkError`, 서버 응답 비즈니스 에러는 `APIError`로 분리.
public enum APIError: Error, LocalizedError, Equatable, Sendable {
    
    /// 서버 비즈니스 에러 응답 (`isSuccess == false` 또는 result 누락)
    /// - Parameters:
    ///   - code: 서버 정의 에러 코드 (예: "AUTH001")
    ///   - message: 서버 메시지
    case serverError(code: String?, message: String?)
    public var errorDescription: String? {
        switch self {
        case .serverError(let code, let message):
            return "[\(code ?? "UNKNOWN")] \(message ?? "알 수 없는 오류가 발생했습니다")"
        }
    }
}
