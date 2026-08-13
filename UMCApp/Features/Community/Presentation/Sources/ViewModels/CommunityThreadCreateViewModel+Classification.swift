//
//  CommunityThreadCreateViewModel+Classification.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// 온디바이스 스레드 자동 분류.
///
/// 카테고리와 아이콘을 사용자가 처음부터 고르게 하면, 스레드를 만들려던 사람이 분류 체계부터
/// 배워야 한다. 특징 한 줄로 먼저 채워 주고 검토만 하게 하는 것이 이 확장의 일이다.
///
/// 분류 실패는 전역 Alert 으로 올리지 않는다 — 폼은 그대로 쓸 수 있고 카테고리·아이콘을 손으로
/// 고르는 길이 늘 열려 있어, 화면 안 인라인이 맞는 자리다 (에러 처리 규약: 도메인 실패는
/// `Loadable`).
extension CommunityThreadCreateViewModel {

    // MARK: - Computed Property

    /// 이 기기에서 자동 분류를 시도해 볼 수 있는지.
    ///
    /// 미지원이어도 카드를 감추지 않는다. 요약 배너와 달리 여기서는 "AI 가 채워 줄 줄 알았는데
    /// 아무 일도 안 일어나는" 상황이 되므로, 직접 고르라는 안내를 대신 띄운다.
    public var isClassificationAvailable: Bool {
        classifier.isAvailable
    }

    /// "다시 분류하기" 를 누를 수 있는지. 미지원 기기에서는 항상 `false` 라 버튼이 잠긴다.
    public var canClassify: Bool {
        isClassificationAvailable
            && !threadDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !classification.isLoading
    }

    /// 카테고리 시트에 "AI 추천" 배지를 붙일 항목. 분류 전에는 `nil` 이라 배지도 없다.
    public var recommendedCategory: CommunityThreadCategory? {
        classification.value?.category
    }

    /// 카드 안에 인라인으로 띄울 실패 메시지.
    ///
    /// `userMessage` 는 분류기가 알 수 없는 에러를 한 문장으로 뭉개므로, 분류기가 직접 쓴
    /// 문구가 있으면 그쪽을 먼저 쓴다.
    public var classificationErrorMessage: String? {
        guard case .failed(let error) = classification else { return nil }
        return error.errorDescription ?? error.userMessage
    }

    // MARK: - Function

    /// 제목·특징으로 카테고리와 아이콘을 지정한다. 최초 분류와 "다시 분류하기" 가 함께 쓴다.
    ///
    /// 결과는 폼에 바로 반영한다 — 카드에만 띄우고 사용자가 옮겨 담게 하면 "자동 지정" 이 아니라
    /// 제안이 되고, 옮기지 않은 채 제출하는 사고가 난다. 마음에 안 들면 카테고리 시트와 이모지
    /// 칸에서 그대로 덮어쓸 수 있다.
    public func classify() async {
        guard canClassify else { return }
        classification = .loading

        do {
            let result = try await classifier.classify(
                title: title,
                description: threadDescription
            )
            classification = .loaded(result)
            category = result.category
            icon = result.icon
        } catch {
            // 취소는 화면을 벗어난 정상 흐름이다. 실패 카드로 바꾸면 돌아왔을 때 에러부터 보인다.
            guard !(error is CancellationError) else { return }
            classification = .failed(AppError.from(error))
        }
    }
}
