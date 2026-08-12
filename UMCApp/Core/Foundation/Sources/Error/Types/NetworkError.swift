//
//  NetworkError.swift
//  UMCFoundation
//
//  Created by euijjang97 on 1/9/26.
//

import Foundation

// MARK: - NetworkError

/// 네트워크 계층에서 발생하는 모든 에러를 정의하는 열거형입니다.
///
/// NetworkClient, TokenStore, TokenRefreshService에서 발생 가능한 에러를 타입 안전하게 표현합니다.
///
/// - Important:
///   - **Sendable**: Actor 간 안전한 에러 전파
///   - **Equatable**: Loadable<T: Equatable> 상태 관리 지원
///   - **LocalizedError**: 사용자 친화적 에러 메시지 제공
///
/// - Usage:
/// ```swift
/// do {
///     let data = try await networkClient.request(urlRequest)
/// } catch NetworkError.unauthorized {
///     // 로그아웃 처리
/// } catch NetworkError.tokenRefreshFailed {
///     // 재로그인 유도
/// } catch NetworkError.requestFailed(let statusCode, _) {
///     // 서버 에러 처리
/// }
/// ```
public enum NetworkError: Error, Sendable, Equatable {
    // MARK: - Cases

    /// 인증이 필요한 요청에 토큰이 없음 (401 Unauthorized)
    ///
    /// - 발생 시점: 로그인하지 않은 상태에서 인증 필요 API 호출
    /// - 해결 방법: 로그인 화면으로 이동
    case unauthorized

    /// 리프레시 토큰을 사용한 토큰 갱신 실패
    ///
    /// - Parameter reason: 갱신 실패 원인 설명 (네트워크 에러, 서버 에러 등)
    ///
    /// - 발생 시점:
    ///   - 리프레시 토큰 만료
    ///   - 서버 토큰 갱신 API 호출 실패
    ///   - 네트워크 연결 끊김
    ///
    /// - 해결 방법: 재로그인 필요
    ///
    /// - Note: Equatable 준수를 위해 Error? → String?로 변경
    case tokenRefreshFailed(reason: String?)

    /// 저장소에 리프레시 토큰이 없음
    ///
    /// - 발생 시점:
    ///   - 로그아웃 상태
    ///   - Keychain 데이터 손실
    ///
    /// - 해결 방법: 로그인 화면으로 이동
    case noRefreshToken

    /// API 요청 실패 (2xx 이외의 상태 코드)
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 상태 코드 (400, 403, 404, 500 등)
    ///   - data: 서버 응답 데이터 (에러 메시지 파싱 가능)
    ///
    /// - 발생 시점:
    ///   - 잘못된 요청 (400 Bad Request)
    ///   - 권한 없음 (403 Forbidden)
    ///   - 리소스 없음 (404 Not Found)
    ///   - 서버 에러 (500 Internal Server Error)
    ///
    /// - 해결 방법: 상태 코드별 적절한 에러 처리
    ///
    /// - Note: Data는 Equatable이 아니므로 비교 시 제외
    case requestFailed(statusCode: Int, data: Data?)

    /// 서버 응답이 HTTPURLResponse가 아님
    ///
    /// - 발생 시점: 네트워크 설정 오류, 프록시 에러 등
    /// - 해결 방법: 네트워크 연결 확인
    case invalidResponse

    /// 토큰 갱신 재시도 횟수 초과
    ///
    /// - 발생 시점: 401 에러 발생 후 재시도 횟수(기본 1회) 초과
    /// - 해결 방법: 재로그인 필요
    case maxRetryExceeded

    /// 네트워크 연결 없음
    ///
    /// - 발생 시점: 인터넷 연결이 끊긴 상태에서 API 호출
    /// - 해결 방법: 네트워크 연결 확인 후 재시도
    case noNetwork

    /// 요청 시간 초과
    ///
    /// - 발생 시점: 서버 응답이 timeout 시간 내에 오지 않음
    /// - 해결 방법: 네트워크 상태 확인 후 재시도
    case timeout

    // MARK: - Equatable

    /// Equatable 비교 구현
    ///
    /// - Note: requestFailed의 Data는 비교에서 제외 (Equatable 아님)
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):
            return true
        case (.tokenRefreshFailed(let lReason), .tokenRefreshFailed(let rReason)):
            return lReason == rReason
        case (.noRefreshToken, .noRefreshToken):
            return true
        case (.requestFailed(let lCode, _), .requestFailed(let rCode, _)):
            return lCode == rCode  // Data는 비교 제외
        case (.invalidResponse, .invalidResponse):
            return true
        case (.maxRetryExceeded, .maxRetryExceeded):
            return true
        case (.noNetwork, .noNetwork):
            return true
        case (.timeout, .timeout):
            return true
        default:
            return false
        }
    }
}

// MARK: - NetworkError + URLError

extension NetworkError {
    /// 전송 계층 실패(`URLError`)를 대응하는 전용 케이스로 변환합니다.
    ///
    /// 요청이 서버에 도달하지 못한 실패이므로 저장된 토큰의 유효성과는 무관합니다.
    /// 전용 케이스가 없는 코드(취소, DNS 실패 등)는 `nil`을 반환해 호출부가 원본 `URLError`를
    /// 그대로 전파할 수 있게 합니다.
    public static func transientFailure(from error: URLError) -> NetworkError? {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noNetwork
        case .timedOut:
            return .timeout
        default:
            return nil
        }
    }
}

// MARK: - NetworkError + LocalizedError

extension NetworkError: LocalizedError {
    /// 사용자에게 표시할 에러 메시지를 반환합니다.
    ///
    /// - Returns: 에러 유형에 맞는 한글 에러 메시지
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "인증이 필요합니다."
        case .tokenRefreshFailed(let reason):
            return "토큰 갱신 실패: \(reason ?? "알 수 없음")"
        case .noRefreshToken:
            return "리프레시 토큰이 없습니다."
        case .requestFailed(let statusCode, _):
            return "요청 실패 status: \(statusCode)"
        case .invalidResponse:
            return "잘못된 서버 응답"
        case .maxRetryExceeded:
            return "최대 재시도 횟수 초과"
        case .noNetwork:
            return "네트워크 연결이 없습니다."
        case .timeout:
            return "요청 시간이 초과되었습니다."
        }
    }

    /// 사용자에게 표시할 친화적 메시지
    ///
    /// ErrorHandler와의 일관성을 위해 제공됩니다.
    public var userMessage: String {
        switch self {
        case .unauthorized:
            return "로그인이 필요합니다."
        case .tokenRefreshFailed, .noRefreshToken:
            return "세션이 만료되었습니다. 다시 로그인해주세요."
        case .maxRetryExceeded:
            return "인증 정보를 확인하지 못했어요. 잠시 후 다시 시도해주세요."
        case .requestFailed(let statusCode, let data):
            if let serverMessage = Self.parseServerMessage(from: data) {
                return serverMessage
            }
            switch statusCode {
            case 400...499:
                return "요청을 처리할 수 없습니다. 다시 시도해주세요."
            case 500...599:
                return "서버에 일시적인 오류가 발생했습니다."
            default:
                return "네트워크 연결이 원활하지 않습니다."
            }
        case .invalidResponse:
            return "네트워크 연결이 원활하지 않습니다."
        case .noNetwork:
            return "인터넷 연결을 확인해주세요."
        case .timeout:
            return "서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요."
        }
    }

    /// 서버 응답 데이터에서 에러 메시지를 추출합니다.
    private static func parseServerMessage(from data: Data?) -> String? {
        guard let data else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String,
              !message.isEmpty else {
            return nil
        }
        return message
    }

    /// 에러 심각도
    ///
    /// 로깅 및 알림 우선순위 결정에 사용됩니다.
    public var severity: ErrorSeverity {
        switch self {
        case .unauthorized, .tokenRefreshFailed, .noRefreshToken:
            return .critical  // 즉시 로그아웃/재로그인 필요
        case .maxRetryExceeded:
            return .critical  // 인증 확인 실패 — 세션은 유지하되 즉시 알림
        case .requestFailed(let statusCode, _):
            switch statusCode {
            case 500...599:
                return .critical  // 서버 에러
            default:
                return .warning   // 클라이언트 에러
            }
        case .invalidResponse:
            return .warning
        case .noNetwork, .timeout:
            return .warning
        }
    }

    /// 재시도 가능 여부
    ///
    /// ErrorHandler의 재시도 버튼 표시 여부 결정에 사용됩니다.
    public var isRetryable: Bool {
        switch self {
        case .unauthorized, .tokenRefreshFailed, .noRefreshToken:
            return false  // 로그인 필요
        case .maxRetryExceeded:
            return true   // 세션은 유지되므로 네트워크 복구 후 재시도 가능
        case .requestFailed(let statusCode, _):
            switch statusCode {
            case 500...599:
                return true  // 서버 에러는 재시도 가능
            default:
                return false // 클라이언트 에러는 재시도 불가
            }
        case .invalidResponse:
            return true  // 네트워크 연결 재시도 가능
        case .noNetwork, .timeout:
            return true
        }
    }
}
