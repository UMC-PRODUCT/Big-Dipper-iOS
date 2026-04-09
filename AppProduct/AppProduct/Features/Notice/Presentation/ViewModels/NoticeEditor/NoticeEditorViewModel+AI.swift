//
//  NoticeEditorViewModel+AI.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import FoundationModels
import UIKit

extension NoticeEditorViewModel {

    // MARK: - AI Content Improvement

    /// Foundation Model을 사용해 공지 본문을 개선합니다.
    ///
    /// 현재 본문 텍스트를 온디바이스 언어 모델로 개선하여 재작성합니다.
    /// 처리 중에는 `isAIProcessing`이 true가 되며, 스트리밍 진행 상황은 `aiStreamingText`에 반영됩니다.
    @MainActor
    func improveContentWithAI() async {
        let plainText = richAttributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plainText.isEmpty else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        isAIProcessing = true
        aiStreamingText = ""

        defer {
            isAIProcessing = false
            aiStreamingText = ""
        }

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 작성 전문가입니다.
                주어진 글의 핵심 내용과 의도는 그대로 유지하면서, 더 명확하고 자연스럽게 개선하여 다시 작성해주세요.
                별도의 설명이나 메타 텍스트 없이 개선된 글만 출력하세요.
                """
            }

            let stream = session.streamResponse(to: plainText)
            var fullText = ""
            for try await partial in stream {
                fullText = partial.content
                aiStreamingText = fullText
            }

            if !fullText.isEmpty {
                let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
                    ?? UIFont.preferredFont(forTextStyle: .body)
                richAttributedContent = MarkdownSerializer.deserialize(fullText, baseFont: baseFont)
                content = MarkdownSerializer.serialize(richAttributedContent)
            }
        } catch {
            errorHandler?.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "improveContentWithAI"
                )
            )
        }
    }
}
