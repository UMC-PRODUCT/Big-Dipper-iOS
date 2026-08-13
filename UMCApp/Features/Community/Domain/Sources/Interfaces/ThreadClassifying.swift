//
//  ThreadClassifying.swift
//  CommunityDomain
//

import Foundation

/// 스레드 자동 분류 결과.
///
/// 카테고리와 아이콘만 돌려주면 화면은 "왜 이렇게 정해졌는지" 를 설명할 방법이 없고, 사용자는
/// 결과를 검토하는 대신 그냥 받아들이거나 통째로 무시하게 된다. 근거를 결과의 일부로 못 박아
/// 두면 화면이 그 3요소를 항상 같이 보여 줄 수 있다.
public struct ThreadClassification: Sendable, Equatable {

    // MARK: - Property

    public let category: CommunityThreadCategory
    /// 지정된 아이콘. 구현이 카테고리 기본 이모지로 채우므로 비어 있지 않다.
    public let icon: String
    /// 이 카테고리를 고른 이유. 한 문장.
    public let reason: String

    // MARK: - Init

    public init(category: CommunityThreadCategory, icon: String, reason: String) {
        self.category = category
        self.icon = icon
        self.reason = reason
    }
}

/// 분류가 실패하는 방식.
///
/// 폼을 막지 않고 카드 안에서 인라인으로 보여 주므로 사용자가 읽을 수 있는 문구를 그대로 든다.
public enum ThreadClassificationError: LocalizedError, Equatable {
    /// Apple Intelligence 를 쓸 수 없는 기기·설정.
    case unavailable
    /// 분류할 특징 텍스트가 비어 있다.
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 Apple Intelligence 자동 분류를 사용할 수 없어요."
        case .emptyInput:
            return "스레드 특징을 입력하면 분류할 수 있어요."
        }
    }
}

/// 스레드 분류기 계약.
///
/// 구현이 Apple Intelligence 에 붙는지, 서버에 붙는지, 테스트 대역인지를 Presentation 이 알 필요가
/// 없다. 기기 지원 여부까지 계약에 포함해야 화면이 `FoundationModels` 를 직접 import 하지 않고도
/// "다시 분류하기" 를 잠그고 수동 선택 안내로 바꿔 그릴 수 있다.
public protocol ThreadClassifying: Sendable {

    /// 이 기기에서 자동 분류를 시도해 볼 수 있는지.
    var isAvailable: Bool { get }

    /// - Parameters:
    ///   - title: 스레드 제목. 특징만으로 애매한 경우의 보조 단서다.
    ///   - description: 시안의 "스레드 특징". 분류의 주 입력이다.
    func classify(title: String, description: String) async throws -> ThreadClassification
}
