//
//  FoundationModelsThreadClassifier.swift
//  CommunityData
//

import Foundation
import FoundationModels
import CommunityDomain

/// Apple Intelligence 온디바이스 모델로 스레드 카테고리와 아이콘을 지정한다.
///
/// 자유 문장으로 받아 앱에서 카테고리를 골라내면 "스터디인 것 같아요" 같은 출력에 걸려 매번
/// 폴백으로 떨어진다. `@Generable` 구조화 출력 + `.anyOf` 로 후보를 서버 enum 4종에 묶어 그
/// 파싱 자체를 없앤다.
///
/// 세션은 분류 한 번마다 새로 만든다. 재사용하면 앞 스레드의 특징이 transcript 에 남아
/// "다시 분류하기" 가 직전 결과를 되풀이한다.
public struct FoundationModelsThreadClassifier: ThreadClassifying {

    // MARK: - Init

    public init() {}

    // MARK: - Computed Property

    public var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Function

    public func classify(title: String, description: String) async throws -> ThreadClassification {
        // 화면이 버튼을 잠갔더라도 그 사이에 Apple Intelligence 가 꺼질 수 있다. 마지막 확인은
        // 실제로 세션을 만드는 여기서 한 번 더 한다.
        guard isAvailable else { throw ThreadClassificationError.unavailable }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else { throw ThreadClassificationError.emptyInput }

        let session = LanguageModelSession(instructions: Constants.instructions)
        let response = try await session.respond(
            to: Self.makePrompt(title: title, description: trimmedDescription),
            generating: ThreadClassificationDraft.self
        )

        // `.anyOf` 를 걸어 두어도 모델이 후보 밖 값을 낼 여지는 남는다. 그때는 실패로 올리는
        // 대신 명세가 정한 기본 카테고리로 떨어뜨린다 — 사용자가 고쳐 쓸 수 있으면 충분하다.
        let category = CommunityThreadCategory(rawValue: response.content.category)
            ?? Constants.fallbackCategory

        return ThreadClassification(
            category: category,
            icon: Self.normalizedIcon(response.content.icon, category: category),
            reason: Self.normalizedReason(response.content.reason, category: category)
        )
    }

    // MARK: - Private Function

    private static func makePrompt(title: String, description: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return "특징: \(description)" }
        return """
        제목: \(trimmedTitle)
        특징: \(description)
        """
    }

    /// 모델이 이모지가 아닌 글자나 여러 개를 낼 수 있다. 폼과 서버가 쓰는 규칙을 그대로 태워
    /// 하나만 남기고, 남는 게 없으면 카테고리 기본 이모지로 채운다.
    private static func normalizedIcon(
        _ icon: String,
        category: CommunityThreadCategory
    ) -> String {
        let normalized = CommunityThreadCreateRule.normalizedIcon(icon)
        return normalized.isEmpty ? category.defaultIcon : normalized
    }

    /// 근거는 결과 카드의 3요소 중 하나라 비면 카드가 반쪽이 된다. 모델이 비워 보낸 경우
    /// 이유를 지어내는 대신 무엇을 했는지만 사실대로 적는다.
    private static func normalizedReason(
        _ reason: String,
        category: CommunityThreadCategory
    ) -> String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return "입력한 특징을 바탕으로 \(category.displayName) 카테고리로 정했어요."
    }
}

// MARK: - Generable Draft

/// 모델이 채우는 분류 초안.
///
/// 도메인 모델(``ThreadClassification``)에 매크로를 붙이면 Domain 이 `FoundationModels` 에 묶인다.
/// 분류기가 바뀌어도 도메인이 흔들리지 않도록 Data 안에서만 쓰는 초안 타입을 따로 둔다.
@Generable(description: "동아리 채팅 스레드의 카테고리 분류 결과")
private struct ThreadClassificationDraft {

    // MARK: - Property

    @Guide(
        description: """
        스레드 성격에 가장 가까운 카테고리 코드입니다.
        STUDY 는 함께 공부하는 모임, QNA 는 질문과 답변, PROJECT 는 결과물을 만드는 협업,
        FREE 는 나머지 잡담과 친목입니다. 애매하면 FREE 를 고르세요.
        """,
        .anyOf(CommunityThreadCategory.allCases.map(\.rawValue))
    )
    var category: String

    @Guide(
        description: """
        스레드를 한눈에 알아볼 수 있는 이모지 문자 하나입니다.
        설명이나 이름이 아니라 이모지 글자 자체만 쓰고, 두 개 이상 붙이지 마세요.
        """
    )
    var icon: String

    @Guide(
        description: """
        이 카테고리를 고른 이유를 한국어 한 문장으로 짧게 적습니다.
        입력에 실제로 있던 단서만 근거로 들고, 없는 내용은 지어내지 마세요.
        """
    )
    var reason: String
}

// MARK: - Constants

fileprivate enum Constants {
    /// 후보 밖 값이 왔을 때 떨어질 카테고리. 명세의 미지원 폴백과 같은 값으로 맞춘다.
    static let fallbackCategory: CommunityThreadCategory = .free

    static let instructions = """
    당신은 동아리 앱의 채팅 스레드를 분류해 주는 보조 도구입니다.
    주어진 스레드 제목과 특징을 읽고 카테고리 하나와 어울리는 이모지 하나를 정하세요.
    입력에 없는 내용은 추측하지 말고, 단서가 부족하면 자유(FREE) 카테고리로 두세요.
    """
}
