//
//  PresentableError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// View에 표시할 에러 정보
public struct PresentableError: Identifiable, Equatable {
    // MARK: - Property

    public let id: UUID
    public let error: AppError
    public let context: ErrorContext
    public let dismissAction: () -> Void
    public let retryAction: (() async -> Void)?

    // MARK: - Computed Property

    /// Alert 타이틀
    public var title: String {
        switch error.severity {
        case .info:
            return "알림"
        case .warning:
            return "오류"
        case .critical:
            return "문제 발생"
        }
    }

    /// 사용자에게 표시할 메시지
    public var message: String {
        error.userMessage
    }

    /// 재시도 버튼 표시 여부
    public var showRetry: Bool {
        error.isRetryable && retryAction != nil
    }

    // MARK: - Init

    public init(
        error: AppError,
        context: ErrorContext,
        dismissAction: @escaping () -> Void,
        retryAction: (() async -> Void)? = nil
    ) {
        self.id = UUID()
        self.error = error
        self.context = context
        self.dismissAction = dismissAction
        self.retryAction = retryAction
    }

    // MARK: - Equatable

    public static func == (lhs: PresentableError, rhs: PresentableError) -> Bool {
        lhs.id == rhs.id
    }
}
