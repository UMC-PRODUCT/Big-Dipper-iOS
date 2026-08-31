//
//  Error+TransportFailure.swift
//  UMCFoundation
//
//  Created by euijjang97 on 8/12/26.
//
//  요청이 서버에 도달하지 못한 실패를 판별하기 위한 공용 헬퍼.
//  세션 만료(서버의 토큰 거부)와 구분해야 하는 지점에서 사용합니다.
//

import Foundation

public extension Error {

    /// 요청이 서버에 도달하지 못한 전송 계층 실패인지 여부.
    ///
    /// 저장된 토큰의 유효성과 무관한 실패이므로, 이 경우 토큰을 삭제하면 안 됩니다.
    /// 서버가 응답한 실패(401/403/5xx 등)는 포함되지 않습니다.
    ///
    /// ```swift
    /// } catch {
    ///     if canAutoLogin, !error.isTransportFailure {
    ///         try? await repository.logout()
    ///     }
    /// }
    /// ```
    var isTransportFailure: Bool {
        if let networkError = self as? NetworkError {
            return networkError == .noNetwork || networkError == .timeout
        }
        return self is URLError && !isCancellation
    }
}
