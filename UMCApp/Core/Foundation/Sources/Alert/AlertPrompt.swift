//
//  AlertPrompt.swift
//  UMCFoundation
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// 사용자 확인/취소 다이얼로그를 표시하기 위한 데이터 모델입니다.
///
/// 파괴적 작업(삭제, 초기화 등) 전 확인이 필요하거나, 사용자 선택이 필요한 분기점에서 사용합니다.
///
/// - Important: SwiftUI의 `.alert(item:)` modifier와 함께 사용하도록 설계되었습니다.
///
/// - Usage:
/// ```swift
/// @Observable
/// final class SomeViewModel {
///     var alertPrompt: AlertPrompt?
///
///     func deleteButtonTapped() {
///         alertPrompt = AlertPrompt(
///             title: "삭제 확인",
///             message: "정말 삭제하시겠습니까?",
///             positiveBtnTitle: "삭제",
///             positiveBtnAction: { [weak self] in
///                 self?.delete()
///             },
///             negativeBtnTitle: "취소",
///             isPositiveBtnDestructive: true
///         )
///     }
/// }
///
/// // View
/// .alertPrompt(item: $viewModel.alertPrompt)
/// ```
public struct AlertPrompt: Identifiable {
    // MARK: - Property

    /// Alert의 고유 식별자 (SwiftUI Identifiable 프로토콜 요구사항)
    public var id: UUID

    /// Alert 제목
    public let title: String

    /// Alert 메시지 본문
    public let message: String

    /// 긍정 버튼 텍스트 (예: "확인", "삭제", "저장")
    ///
    /// - Note: nil인 경우 긍정 버튼이 표시되지 않습니다.
    public let positiveBtnTitle: String?

    /// 긍정 버튼 탭 시 실행될 액션
    public let positiveBtnAction: (() -> Void)?

    /// 보조 버튼 텍스트 (3번째 선택지)
    ///
    /// - Note: nil인 경우 보조 버튼이 표시되지 않습니다.
    public let secondaryBtnTitle: String?

    /// 보조 버튼 탭 시 실행될 액션
    public let secondaryBtnAction: (() -> Void)?

    /// 부정 버튼 텍스트 (예: "취소")
    ///
    /// - Note: nil인 경우 부정 버튼이 표시되지 않습니다.
    public let negativeBtnTitle: String?

    /// 부정 버튼 탭 시 실행될 액션
    ///
    /// - Note: 일반적으로 취소 동작은 별도 액션 없이 Alert를 닫기만 합니다.
    public let negativeBtnAction: (() -> Void)?

    /// 긍정 버튼이 파괴적 작업인지 여부 (true일 경우 빨간색으로 표시)
    ///
    /// - Note: 삭제, 초기화 등 되돌릴 수 없는 작업에 사용합니다.
    public let isPositiveBtnDestructive: Bool

    // MARK: - Initializer

    /// AlertPrompt 초기화
    ///
    /// - Parameters:
    ///   - id: Alert 고유 식별자 (기본값: 새로운 UUID 생성)
    ///   - title: Alert 제목
    ///   - message: Alert 메시지 본문
    ///   - positiveBtnTitle: 긍정 버튼 텍스트 (기본값: nil)
    ///   - positiveBtnAction: 긍정 버튼 탭 액션 (기본값: nil)
    ///   - secondaryBtnTitle: 보조 버튼 텍스트 (기본값: nil)
    ///   - secondaryBtnAction: 보조 버튼 탭 액션 (기본값: nil)
    ///   - negativeBtnTitle: 부정 버튼 텍스트 (기본값: nil)
    ///   - negativeBtnAction: 부정 버튼 탭 액션 (기본값: nil)
    ///   - isPositiveBtnDestructive: 긍정 버튼이 파괴적 작업인지 여부 (기본값: false)
    public init(
        id: UUID = .init(),
        title: String,
        message: String,
        positiveBtnTitle: String? = nil,
        positiveBtnAction: (() -> Void)? = nil,
        secondaryBtnTitle: String? = nil,
        secondaryBtnAction: (() -> Void)? = nil,
        negativeBtnTitle: String? = nil,
        negativeBtnAction: (() -> Void)? = nil,
        isPositiveBtnDestructive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.positiveBtnTitle = positiveBtnTitle
        self.positiveBtnAction = positiveBtnAction
        self.secondaryBtnTitle = secondaryBtnTitle
        self.secondaryBtnAction = secondaryBtnAction
        self.negativeBtnTitle = negativeBtnTitle
        self.negativeBtnAction = negativeBtnAction
        self.isPositiveBtnDestructive = isPositiveBtnDestructive
    }
}
