//
//  ErrorContext.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 에러가 발생한 위치와 재시도 정보를 담는 컨텍스트.
///
/// 동일한 에러라도 발생 위치에 따라 다른 처리가 필요합니다:
/// - 공지사항 조회 중 네트워크 에러 → "공지사항을 불러올 수 없습니다"
/// - 출석 체크 중 네트워크 에러 → "출석 체크에 실패했습니다"
///
/// ## Usage
///
/// ```swift
/// errorHandler.handle(error, context: ErrorContext(
///     feature: "Notice",
///     action: "fetchList",
///     retryAction: { [weak self] in
///         await self?.fetchNotices()
///     }
/// ))
/// ```
///
/// - SeeAlso: ``ErrorHandler``, ``PresentableError``
public struct ErrorContext: Equatable {

    // MARK: - Property

    /// 에러가 발생한 Feature 이름.
    ///
    /// Feature 폴더명과 일치시키는 것을 권장합니다.
    ///
    /// - Note: PascalCase 사용 (예: `"Notice"`, `"Auth"`, `"Attendance"`)
    public let feature: String

    /// 에러가 발생한 액션 이름.
    ///
    /// 해당 Feature 내에서 어떤 작업 중 에러가 발생했는지를 나타냅니다.
    ///
    /// - Note: camelCase, 동사로 시작 (예: `"fetchList"`, `"login"`, `"submitAttendance"`)
    public let action: String

    /// 에러 발생 시 재시도할 수 있는 클로저.
    ///
    /// 이 값이 `nil`이면 UI에서 재시도 버튼이 표시되지 않습니다.
    ///
    /// - Important: 클로저 내부에서 `[weak self]`를 사용하여 순환 참조를 방지하세요.
    public let retryAction: (() async -> Void)?

    // MARK: - Init

    /// 새로운 ErrorContext를 생성합니다.
    ///
    /// - Parameters:
    ///   - feature: 에러가 발생한 Feature 이름.
    ///   - action: 에러가 발생한 액션 이름.
    ///   - retryAction: 재시도 클로저. 기본값은 `nil`.
    public init(
        feature: String,
        action: String,
        retryAction: (() async -> Void)? = nil
    ) {
        self.feature = feature
        self.action = action
        self.retryAction = retryAction
    }

    // MARK: - Equatable

    /// 두 ErrorContext가 같은 위치를 나타내는지 비교합니다.
    public static func == (lhs: ErrorContext, rhs: ErrorContext) -> Bool {
        lhs.feature == rhs.feature && lhs.action == rhs.action
    }
}
