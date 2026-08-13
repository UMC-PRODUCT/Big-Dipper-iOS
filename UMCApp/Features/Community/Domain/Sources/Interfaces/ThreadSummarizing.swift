//
//  ThreadSummarizing.swift
//  CommunityDomain
//

import Foundation

/// 온디바이스 요약 결과.
///
/// 요약문과 액션 아이템을 한 덩어리 문자열로 받으면 화면이 다시 쪼개야 하는데, 그 파싱 규칙은
/// 모델이 형식을 조금만 바꿔도 무너진다. 처음부터 두 배열로 나눠 받아 파싱 자체를 없앤다.
public struct ThreadSummary: Sendable, Equatable {

    // MARK: - Property

    /// 대화 흐름 요약. 화면에서 불릿 목록으로 보여 준다.
    public let bullets: [String]
    /// 요약 대상 중 **내가** 해야 할 일. 없으면 빈 배열이다 — 없는 일을 지어내는 것보다 낫다.
    public let actionItems: [String]

    // MARK: - Init

    public init(bullets: [String], actionItems: [String]) {
        self.bullets = bullets
        self.actionItems = actionItems
    }

    // MARK: - Computed Property

    /// 모델이 형식만 맞추고 내용을 비운 경우. 빈 카드를 띄우느니 실패로 다루려고 둔다.
    public var isEmpty: Bool {
        bullets.isEmpty && actionItems.isEmpty
    }
}

/// 요약이 실패하는 방식.
///
/// 전역 Alert 으로 올리지 않고 시트 안에서 인라인으로 보여 주므로, 사용자가 읽을 수 있는
/// 문구를 그대로 들고 다닌다.
public enum ThreadSummaryError: LocalizedError, Equatable {
    /// Apple Intelligence 를 쓸 수 없는 기기·설정. 화면은 이 경우 진입 자체를 막는다.
    case unavailable
    /// 요약할 말이 남지 않은 구간. 삭제된 메시지와 미전송 버블만 걸러 내고 나면 생길 수 있다.
    case emptyTranscript
    /// 모델이 형식만 채우고 내용을 비운 경우.
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 온디바이스 요약을 사용할 수 없어요."
        case .emptyTranscript:
            return "요약할 대화가 없어요."
        case .emptyResult:
            return "요약할 내용을 찾지 못했어요."
        }
    }
}

/// 대화 요약기 계약.
///
/// 구현이 Apple Intelligence 에 붙는지, 서버에 붙는지, 테스트 대역인지를 Presentation 이 알 필요가
/// 없다. 기기 지원 여부까지 이 계약에 포함해야 화면이 `FoundationModels` 를 직접 import 하지 않고도
/// 진입점(배너)을 감출 수 있다.
public protocol ThreadSummarizing: Sendable {

    /// 이 기기에서 요약을 시도해 볼 수 있는지.
    ///
    /// 미지원 기기에 진입점을 노출해 놓고 눌렀을 때 실패를 보여 주는 건 사용자에게 아무 선택지도
    /// 주지 못한다. 배너를 아예 감추는 판단에 쓴다.
    var isAvailable: Bool { get }

    /// - Parameters:
    ///   - messages: 요약 대상 구간. 표시 순서(오래된 것 → 최신)를 그대로 넘긴다.
    ///   - currentMemberName: 액션 아이템의 주인을 가리키는 힌트. 내 이름을 모를 수 있어 옵셔널이다.
    func summarize(
        messages: [ThreadMessage],
        currentMemberName: String?
    ) async throws -> ThreadSummary
}
