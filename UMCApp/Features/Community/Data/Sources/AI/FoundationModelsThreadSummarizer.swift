//
//  FoundationModelsThreadSummarizer.swift
//  CommunityData
//

import Foundation
import FoundationModels
import CommunityDomain

/// Apple Intelligence 온디바이스 모델로 스레드 대화를 요약한다.
///
/// 마크다운 한 덩어리를 받아 앱에서 쪼개면 모델이 불릿 기호나 제목 문구를 조금만 달리해도
/// 요약과 액션 아이템이 뒤섞인다. `@Generable` 구조화 출력으로 받아 그 위험을 없앤다.
///
/// 세션은 요약 한 번마다 새로 만든다. 재사용하면 앞 대화가 transcript 에 남아 다음 요약의
/// 컨텍스트를 갉아먹고, 전혀 다른 스레드의 내용이 섞여 나올 수 있다.
public struct FoundationModelsThreadSummarizer: ThreadSummarizing {

    // MARK: - Init

    public init() {}

    // MARK: - Computed Property

    public var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Function

    public func summarize(
        messages: [ThreadMessage],
        currentMemberName: String?
    ) async throws -> ThreadSummary {
        // 호출자가 배너를 감췄더라도 그 사이에 Apple Intelligence 가 꺼질 수 있다. 마지막 확인은
        // 실제로 세션을 만드는 여기서 한 번 더 한다.
        guard isAvailable else { throw ThreadSummaryError.unavailable }

        let transcript = Self.makeTranscript(from: messages)
        guard !transcript.isEmpty else { throw ThreadSummaryError.emptyTranscript }

        let session = LanguageModelSession(
            instructions: Self.instructions(currentMemberName: currentMemberName)
        )
        let response = try await session.respond(to: transcript, generating: ThreadSummaryDraft.self)

        let summary = ThreadSummary(
            bullets: Self.sanitize(response.content.bullets),
            actionItems: Self.sanitize(response.content.actionItems)
        )
        guard !summary.isEmpty else { throw ThreadSummaryError.emptyResult }
        return summary
    }

    // MARK: - Private Function

    /// 프롬프트에 넣을 대화록. `보낸사람: 내용` 한 줄씩 이어 붙인다.
    static func makeTranscript(from messages: [ThreadMessage]) -> String {
        messages
            // 톰스톤과 미확정 버블은 대화에 없던 말이다. 지운 문장을 요약에 다시 실으면 삭제가
            // 무의미해지고, 전송 실패한 내 문장은 상대가 본 적 없는 내용이라 맥락을 왜곡한다.
            .filter { $0.deletedAt == nil && $0.deliveryState == .sent && !$0.content.isEmpty }
            .suffix(Constants.maxMessageCount)
            .map { "\($0.senderName.isEmpty ? Constants.unknownSender : $0.senderName): \($0.content)" }
            .joined(separator: "\n")
            // 줄 수를 잘라도 장문 몇 줄이면 컨텍스트를 넘긴다. 문자 수로 한 번 더 막는다.
            // 최신 대화가 더 중요하므로 앞(오래된 쪽)을 버린다.
            .suffixLimited(to: Constants.maxTranscriptLength)
    }

    private static func instructions(currentMemberName: String?) -> String {
        let owner = currentMemberName.map { "\"\($0)\"" } ?? "요약을 요청한 본인"
        return """
        당신은 동아리 채팅방의 대화를 정리해 주는 보조 도구입니다.
        주어진 대화록은 `보낸사람: 내용` 형식의 여러 줄입니다.
        대화의 핵심을 짧은 한국어 문장으로 정리하고, \(owner)이(가) 해야 할 일을 따로 뽑아 주세요.
        대화에 없는 내용은 절대 지어내지 마세요. 해당하는 내용이 없으면 빈 목록으로 두세요.
        """
    }

    /// 모델이 붙인 불릿 기호·공백을 걷어 내고 빈 줄을 버린다.
    ///
    /// 화면이 자체 불릿을 그리므로 `- ` 가 남아 있으면 점이 두 개로 보인다.
    private static func sanitize(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            for marker in Constants.bulletMarkers where trimmed.hasPrefix(marker) {
                trimmed = String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

// MARK: - Generable Draft

/// 모델이 채우는 요약 초안.
///
/// 도메인 모델(``ThreadSummary``)에 매크로를 붙이면 Domain 이 `FoundationModels` 에 묶인다.
/// 요약기가 바뀌어도 도메인이 흔들리지 않도록 Data 안에서만 쓰는 초안 타입을 따로 둔다.
@Generable(description: "채팅 대화에서 뽑아낸 요약과 개인 할 일")
private struct ThreadSummaryDraft {

    // MARK: - Property

    @Guide(
        description: """
        대화의 핵심 내용을 한국어 문장으로 정리한 목록입니다.
        한 항목은 한 문장으로 짧게 쓰고, 불릿 기호(-, •)나 번호는 붙이지 마세요.
        누가 무엇을 정했는지가 드러나게 쓰세요.
        """,
        .maximumCount(5)
    )
    var bullets: [String]

    @Guide(
        description: """
        요약을 요청한 본인이 직접 해야 할 일만 담은 목록입니다.
        마감이나 기한이 언급됐다면 함께 적으세요.
        다른 사람의 할 일이나 이미 끝난 일은 넣지 마세요.
        본인이 할 일이 대화에 없으면 빈 목록으로 두세요.
        """,
        .maximumCount(5)
    )
    var actionItems: [String]
}

// MARK: - String Helper

private extension String {

    /// 뒤에서부터 `limit` 자만 남긴다. 상한 안이면 그대로 돌려준다.
    func suffixLimited(to limit: Int) -> String {
        count <= limit ? self : String(suffix(limit))
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// 프롬프트에 넣을 최대 메시지 수.
    ///
    /// 온디바이스 모델의 컨텍스트 창은 서버 모델보다 훨씬 좁아 대화 전체를 밀어 넣으면 초과로
    /// 실패한다. 채팅 한 줄이 대체로 짧아 이 정도면 아래 문자 수 상한 안에 대개 들어온다.
    static let maxMessageCount = 60
    /// 대화록 문자 수 상한. 장문이 몇 줄 섞여도 컨텍스트를 넘기지 않도록 잡은 안전선이다.
    static let maxTranscriptLength = 4_000
    /// 발신자 이름이 비어 온 경우의 표기. 이름 자리를 비우면 모델이 앞줄 화자로 이어 붙인다.
    static let unknownSender = "알 수 없음"
    static let bulletMarkers = ["- ", "* ", "• ", "· "]
}
