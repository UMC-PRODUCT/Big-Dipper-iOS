//
//  TokenRefreshServiceImpl.swift
//  CoreNetwork
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// TokenRefreshService 프로토콜의 실제 구현체입니다.
///
/// 서버의 `/api/v1/auth/token/renew` 엔드포인트를 호출하여 리프레시 토큰으로 새로운 토큰 쌍을 발급받습니다.
///
/// - Important:
///   - **NetworkClient와 독립적**: NetworkClient를 사용하지 않음 (무한 루프 방지)
///   - **APIResponse 사용**: 서버의 공통 응답 포맷 사용
///   - **JSON Body 전송**: 서버 문서 스펙에 맞춰 리프레시 토큰을 Request Body에 전송
struct TokenRefreshServiceImpl: TokenRefreshService {
    // MARK: - Property

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    nonisolated init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    // MARK: - TokenRefreshService

    /// 리프레시 토큰으로 새로운 토큰 쌍을 발급받습니다.
    ///
    /// ## 요청 형식
    /// ```
    /// POST /api/v1/auth/token/renew
    /// Content-Type: application/json
    ///
    /// { "refreshToken": "..." }
    /// ```
    func refresh(_ refreshToken: String) async throws -> TokenPair {
        // 1. URL 생성
        let url = baseURL.appending(path: "api/v1/auth/token/renew")

        // 2. URLRequest 구성
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RefreshTokenRequestBody(refreshToken: refreshToken)
        )

        // 3. 네트워크 요청 실행
        let (data, response) = try await session.data(for: request)

        // 4. HTTPURLResponse 형변환
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenRefreshError.invalidResponse
        }

        // 5. 상태 코드 확인 (2xx 성공)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TokenRefreshError.serverError(statusCode: httpResponse.statusCode)
        }

        // 6. 응답 디코딩 (APIResponse 사용)
        let tokenResponse = try decoder.decode(APIResponse<TokenResult>.self, from: data)

        // 7. 성공 여부 확인
        guard tokenResponse.isSuccess, let result = tokenResponse.result else {
            throw TokenRefreshError.refreshFailed(message: tokenResponse.message)
        }

        // 8. TokenPair 생성
        return TokenPair(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken
        )
    }
}

// MARK: - RefreshTokenRequestBody

private struct RefreshTokenRequestBody: Encodable {
    let refreshToken: String
}

// MARK: - TokenResult

/// 토큰 갱신 API 응답의 result 필드를 파싱하는 내부 모델입니다.
private struct TokenResult: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - TokenRefreshError

/// 토큰 갱신 과정에서 발생하는 에러를 정의하는 열거형입니다.
///
/// - Important: NetworkClient는 이 에러를 `NetworkError.tokenRefreshFailed`로 래핑합니다.
enum TokenRefreshError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case refreshFailed(message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "잘못된 서버 응답"
        case .serverError(let statusCode):
            return "서버 에러 (status: \(statusCode))"
        case .refreshFailed(let message):
            return message ?? "토큰 갱신 실패"
        }
    }
}
