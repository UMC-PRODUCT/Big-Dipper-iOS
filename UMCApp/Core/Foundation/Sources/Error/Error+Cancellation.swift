//
//  Error+Cancellation.swift
//  UMCFoundation
//
//  Created by euijjang97 on 7/5/26.
//
//  Swift Concurrency 취소를 판별하기 위한 공용 헬퍼.
//  Task 취소는 실패가 아니므로 에러 Alert/로깅 대상에서 제외해야 합니다.
//

import Foundation

public extension Error {

    /// 이 에러가 "취소"에 해당하는지 여부.
    ///
    /// `CancellationError`(구조적 동시성 취소)와 `URLError(.cancelled)`(네트워크 요청 취소)를
    /// 모두 취소로 간주합니다. ViewModel에서 취소된 작업을 사용자 에러로 표시하지 않도록
    /// 분기할 때 사용합니다.
    ///
    /// ```swift
    /// do {
    ///     try await useCase.execute()
    /// } catch {
    ///     guard !error.isCancellation else { return }
    ///     errorHandler.handle(error, context: ...)
    /// }
    /// ```
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }
}
